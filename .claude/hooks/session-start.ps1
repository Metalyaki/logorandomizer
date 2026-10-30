# SessionStart hook (startup, resume, clear, compact).
# Gives Claude a short orientation: branch, uncommitted files, the active plan and its next step,
# and problems with the setup itself. Also records where the session started, so the quality gate
# knows which commits belong to this session.

. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/checks.ps1')
if (-not (Test-FullLanguage)) { exit 0 }

try {
    $hook = Read-HookInput
    $projectDir = Get-ProjectDir $hook
    $source = [string]$hook.source
    $lines = New-Object System.Collections.Generic.List[string]

    $cfgState = Test-TeamConfigValid $projectDir
    if ($cfgState -ne 'ok') { $lines.Add('WARNING: .claude/team.json is ' + $cfgState + '. Hooks fall back to defaults; tell the user.') }
    $cfg = Get-TeamConfig $projectDir

    $gi = Get-GitInfo $projectDir
    if ($gi) {
        $dirty = Get-DirtyFiles $projectDir $gi.Prefix
        $branch = $gi.Branch
        if (-not $branch) { $branch = '(detached HEAD)' }
        $lines.Add('Branch: ' + $branch + '. Uncommitted files: ' + $dirty.All.Count + '.')
        $protected = @(Get-Cfg $cfg 'guard.protectedBranches' @('main', 'master', 'develop', 'release/*', 'production'))
        foreach ($b in $protected) { if ($gi.Branch -and $gi.Branch -like $b) { $lines.Add('You are on a protected branch. Create a feature or fix branch before changing code.'); break } }

        if ($hook.session_id -and $gi.Head) {
            $statePath = Get-StateFile $projectDir 'gate'
            $state = Read-State $statePath
            if (-not ($state['sessions'] -is [hashtable])) { $state['sessions'] = @{} }
            $sid = [string]$hook.session_id
            if (-not $state.sessions[$sid]) { $state.sessions[$sid] = @{ startHead = $gi.Head; t = [DateTime]::UtcNow.Ticks } }
            $cut = [DateTime]::UtcNow.Ticks - (7 * [TimeSpan]::TicksPerDay)
            foreach ($k in @($state.sessions.Keys)) {
                $t = 0L
                try { $t = [long]$state.sessions[$k].t } catch { }
                if ($t -lt $cut) { $state.sessions.Remove($k) }
            }
            Write-State $statePath $state
        }
    }

    # Active plan: the most recently changed plan file that still has unchecked steps.
    $planGlob = [string](Get-Cfg $cfg 'workflow.plans' 'docs/specs/*.plan.md')
    $planDir = Join-Path $projectDir (Split-Path -Parent $planGlob)
    $planFilter = Split-Path -Leaf $planGlob
    if (Test-Path -LiteralPath $planDir) {
        $plans = @(Get-ChildItem -LiteralPath $planDir -Filter $planFilter -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        foreach ($p in $plans) {
            $text = Get-Content -LiteralPath $p.FullName -Raw -Encoding UTF8
            $open = @([regex]::Matches($text, '(?m)^\s*[-*] \[ \] (.+)$'))
            $done = @([regex]::Matches($text, '(?m)^\s*[-*] \[[xX]\] '))
            if ($open.Count -gt 0) {
                $relPlan = Get-ProjectRelativePath $p.FullName $projectDir
                $next = $open[0].Groups[1].Value.Trim()
                if ($next.Length -gt 160) { $next = $next.Substring(0, 160) + '...' }
                $lines.Add('Active plan: ' + $relPlan + ' (' + $done.Count + ' of ' + ($done.Count + $open.Count) + ' steps done). Next: ' + $next)
                break
            }
        }
    }

    # Phased project: the first unchecked phase of the roadmap.
    $roadmap = Join-Path (Join-Path (Join-Path $projectDir 'docs') 'project') 'roadmap.md'
    if (Test-Path -LiteralPath $roadmap -PathType Leaf) {
        $rtext = Get-Content -LiteralPath $roadmap -Raw -Encoding UTF8
        $rOpen = @([regex]::Matches($rtext, '(?m)^\s*[-*] \[ \] (P\d+.*)$'))
        $rDone = @([regex]::Matches($rtext, '(?m)^\s*[-*] \[[xX]\] P\d+'))
        if ($rOpen.Count -gt 0) {
            $cur = $rOpen[0].Groups[1].Value.Trim()
            if ($cur.Length -gt 160) { $cur = $cur.Substring(0, 160) + '...' }
            $lines.Add('Phased project: ' + $rDone.Count + ' of ' + ($rDone.Count + $rOpen.Count) + ' phases done. Current: ' + $cur)
        }
    }

    # Latest session handoff: where the previous session stopped and what comes next.
    $handoff = Join-Path (Join-Path $projectDir 'docs') 'handoff.md'
    if (Test-Path -LiteralPath $handoff -PathType Leaf) {
        $htext = Get-Content -LiteralPath $handoff -Raw -Encoding UTF8
        foreach ($m in [regex]::Matches($htext, '(?ms)^## ([^\r\n]+)\r?\n(.*?)(?=^## |\z)')) {
            $heading = $m.Groups[1].Value.Trim()
            if ($heading -match 'YYYY') { continue }
            $body = $m.Groups[2].Value
            $nextLine = [regex]::Match($body, '(?m)^\s*[-*]\s*\*\*Next\*\*:\s*(.+)$')
            $openQ = [regex]::Match($body, '(?m)^\s*[-*]\s*\*\*Open questions\*\*:\s*(.+)$')
            $msg = 'Latest handoff (' + $heading + ')'
            if ($nextLine.Success) { $msg += '. Next: ' + $nextLine.Groups[1].Value.Trim() }
            if ($openQ.Success -and $openQ.Groups[1].Value.Trim() -notmatch '^(none|no|-)\.?$') { $msg += '. Open questions: ' + $openQ.Groups[1].Value.Trim() }
            if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + '...' }
            $lines.Add($msg + ' (full entry in docs/handoff.md)')
            break
        }
    }

    if ($source -eq 'clear') {
        $lines.Add('Context was cleared. If the next request continues earlier work, read the latest handoff entry and the active plan first.')
    }
    if ($source -eq 'compact' -or $source -eq 'resume') {
        $what = 'resumed'
        if ($source -eq 'compact') { $what = 'compacted' }
        $lines.Add('This session was ' + $what + '. Before continuing, read the latest handoff entry and the active plan, and check git status; do not rely on memory of earlier steps.')
    }

    if ($lines.Count -eq 0) { exit 0 }
    $ctx = 'Dev team session info:' + "`n- " + ($lines -join "`n- ")
    Write-HookJson @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx } }
} catch { }
exit 0

# Stop and SubagentStop hook: Claude may not finish while the checks for what it changed are red.
#
# - Which checks run, and for which files, is configured in .claude/team.json (quality.checks).
# - Checks only run for changed files, and a check that already passed on the exact same tree is not rerun.
# - A failing check blocks the stop up to quality.maxBlocks times per turn. After that Claude may stop and
#   you see a warning, so you are never stuck in a loop.
# - When Claude's last message ends with a question to you, the stop is allowed with a warning.
# - Set the environment variable CLAUDE_QUALITYGATE=off to disable it for a session.
#
# Never blocks on its own errors: a crash here lets Claude stop (Stop hooks cannot fail closed).

. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/checks.ps1')
Exit-IfConstrained

$hook = Read-HookInput
if ($null -eq $hook) { exit 0 }
if ($env:CLAUDE_QUALITYGATE -eq 'off') { exit 0 }
if ([string]$hook.permission_mode -eq 'plan') { exit 0 }

$projectDir = Get-ProjectDir $hook
$cfg = Get-TeamConfig $projectDir
if ((Get-Cfg $cfg 'quality.enabled' $true) -eq $false) { exit 0 }

$isSub = ([string]$hook.hook_event_name -eq 'SubagentStop')
$agent = Get-AgentName $hook
$set = 'stop'
if ($isSub) {
    $set = 'subagent'
    $gated = @(Get-Cfg $cfg 'quality.subagentGate' @('backend', 'frontend', 'debugger', 'devops'))
    if (-not $agent -or -not ($gated -contains $agent)) { exit 0 }
}

$gi = Get-GitInfo $projectDir
if (-not $gi) { exit 0 }

Set-CheckEnvironment
$lock = Enter-Lock ((Get-StateFile $projectDir 'gate') + '.lock') 600
if (-not $lock) {
    Write-HookJson @{ systemMessage = 'Quality gate skipped: another check run on this repository did not finish within 10 minutes.' }
    exit 0
}

try {
    $statePath = Get-StateFile $projectDir 'gate'
    $state = Read-State $statePath
    foreach ($k in @('sessions', 'checks', 'blocks')) { if (-not ($state[$k] -is [hashtable])) { $state[$k] = @{} } }

    # Prune counters older than two days.
    $now = [DateTime]::UtcNow
    foreach ($k in @($state.blocks.Keys)) {
        $t = 0L
        try { $t = [long]$state.blocks[$k].t } catch { }
        if (($now.Ticks - $t) -gt (2 * [TimeSpan]::TicksPerDay)) { $state.blocks.Remove($k) }
    }

    $dirty = Get-DirtyFiles $projectDir $gi.Prefix
    $fp = Get-TreeFingerprint $projectDir $gi $dirty

    # Changed files: uncommitted work plus commits since the last green state or the start of this session.
    $sessionId = [string]$hook.session_id
    $base = $null
    if ($state.lastGreenHead -and (Test-IsAncestor $projectDir ([string]$state.lastGreenHead) $gi.Head)) {
        $base = [string]$state.lastGreenHead
    } elseif ($state.sessions[$sessionId] -and $state.sessions[$sessionId].startHead -and (Test-IsAncestor $projectDir ([string]$state.sessions[$sessionId].startHead) $gi.Head)) {
        $base = [string]$state.sessions[$sessionId].startHead
    }
    $changed = @(@($dirty.All) + @(Get-ChangedBetween $projectDir $gi.Prefix $base $gi.Head) | Select-Object -Unique)

    $counterKey = $sessionId
    if ($isSub) { $counterKey = $sessionId + '/' + [string]$hook.agent_id }
    $hasActive = ($null -ne $hook.PSObject.Properties['stop_hook_active'])
    if ($hasActive -and -not $hook.stop_hook_active) { $state.blocks.Remove($counterKey) }

    $checks = Get-ApplicableChecks $cfg $set $agent $changed $false
    $failed = $null
    $failedCheck = $null
    foreach ($c in $checks) {
        $key = Get-CheckKey $c
        if ([string]$state.checks[$key] -eq $fp) { continue }
        $r = Invoke-Check $c $projectDir
        if ($r.Status -eq 'passed') { $state.checks[$key] = $fp; continue }
        if ($r.Status -eq 'skipped') { continue }
        $failed = $r
        $failedCheck = $c
        break
    }

    if (-not $failed) {
        if (-not $isSub) { $state.lastGreenHead = $gi.Head; $state.lastGreenFingerprint = $fp }
        $state.blocks.Remove($counterKey)
        Write-State $statePath $state
        exit 0
    }

    $blocks = 0
    if ($state.blocks[$counterKey]) { $blocks = [int]$state.blocks[$counterKey].n }
    $max = [int](Get-Cfg $cfg 'quality.maxBlocks' 3)
    $lastMsg = ([string]$hook.last_assistant_message).TrimEnd()
    $asking = (-not $isSub) -and $lastMsg.EndsWith('?')
    $where = ''
    if ($failedCheck.cwd -and [string]$failedCheck.cwd -ne '.') { $where = ' (in ' + $failedCheck.cwd + ')' }

    if ($blocks -ge $max -or $asking) {
        $state.blocks.Remove($counterKey)
        Write-State $statePath $state
        $why = 'after ' + $blocks + ' attempts'
        if ($asking) { $why = 'while Claude asks you a question' }
        $who = 'Claude'
        if ($isSub) { $who = 'The ' + $agent + ' agent' }
        Write-HookJson @{ systemMessage = ('Quality gate: check "' + $failed.Name + '" is still RED ' + $why + '. ' + $who + ' was allowed to stop so you can decide. See the output with: pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ' + $set) }
        exit 0
    }

    $state.blocks[$counterKey] = @{ n = $blocks + 1; t = $now.Ticks }
    Write-State $statePath $state

    $tail = [int](Get-Cfg $cfg 'quality.tailLines' 40)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('Quality gate: check "').Append($failed.Name).Append('" failed (exit ').Append($failed.Code).Append(', ').Append($failed.Seconds).Append(" s).`n")
    [void]$sb.Append('Command: ').Append([string]$failedCheck.run).Append($where).Append("`n`n")
    [void]$sb.Append((Get-FailureExcerpt $failed.Output $tail)).Append("`n`n")
    if ($isSub) {
        [void]$sb.Append('Fix what your change broke before you finish. Do not weaken, skip or delete tests. If the failure is not caused by your change, say so clearly in your final report to the lead.')
    } else {
        [void]$sb.Append('Fix the cause, then finish again (attempt ').Append($blocks + 1).Append(' of ').Append($max).Append('). Do not weaken, skip or delete tests to get green. If the failure is outside this task or needs a decision from the user, explain it and end your message with a question to the user. Rerun the checks with: pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set stop')
    }
    Write-HookJson @{ decision = 'block'; reason = $sb.ToString() }
    exit 0
} finally {
    Exit-Lock $lock
}

# Check engine shared by qualitygate.ps1 (Stop and SubagentStop hooks) and run-checks.ps1 (/verify and /ship).
# Requires lib/common.ps1. Pure ASCII, Windows PowerShell 5.1 compatible.

function Get-GitInfo([string]$projectDir) {
    $top = Invoke-Git $projectDir @('rev-parse', '--show-toplevel')
    if ($top.Code -ne 0) { return $null }
    $prefix = (Invoke-Git $projectDir @('rev-parse', '--show-prefix')).Out.Trim()
    $head = Invoke-Git $projectDir @('rev-parse', 'HEAD')
    $sha = ''
    if ($head.Code -eq 0) { $sha = $head.Out.Trim() }
    $branch = (Invoke-Git $projectDir @('branch', '--show-current')).Out.Trim()
    return @{ Top = $top.Out.Trim(); Prefix = $prefix; Head = $sha; Branch = $branch }
}

function Convert-RepoToProjectPath([string]$path, [string]$prefix) {
    if ([string]::IsNullOrEmpty($prefix)) { return $path }
    if ($path.StartsWith($prefix)) { return $path.Substring($prefix.Length) }
    return $null
}

# Files that differ from HEAD: staged, unstaged and untracked (not ignored).
function Get-DirtyFiles([string]$projectDir, [string]$prefix) {
    $r = Invoke-Git $projectDir @('status', '--porcelain=v1', '-z', '--untracked-files=all')
    $all = New-Object System.Collections.Generic.List[string]
    $untracked = New-Object System.Collections.Generic.List[string]
    if ($r.Code -ne 0) { return @{ All = $all; Untracked = $untracked } }
    $parts = $r.Out.Split([char]0)
    $i = 0
    while ($i -lt $parts.Length) {
        $e = $parts[$i]; $i++
        if ($e.Length -lt 4) { continue }
        $xy = $e.Substring(0, 2)
        $path = $e.Substring(3)
        if ($xy[0] -eq 'R' -or $xy[0] -eq 'C') { $i++ }
        $rel = Convert-RepoToProjectPath $path $prefix
        if ($null -eq $rel) { continue }
        $all.Add($rel)
        if ($xy -eq '??') { $untracked.Add($rel) }
    }
    return @{ All = $all; Untracked = $untracked }
}

function Get-ChangedBetween([string]$projectDir, [string]$prefix, [string]$from, [string]$to) {
    $list = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrEmpty($from) -or [string]::IsNullOrEmpty($to) -or $from -eq $to) { return $list }
    $r = Invoke-Git $projectDir @('diff', '--name-only', '-z', $from, $to)
    if ($r.Code -ne 0) { return $list }
    foreach ($p in $r.Out.Split([char]0)) {
        if ([string]::IsNullOrEmpty($p)) { continue }
        $rel = Convert-RepoToProjectPath $p $prefix
        if ($null -ne $rel) { $list.Add($rel) }
    }
    return $list
}

function Test-IsAncestor([string]$projectDir, [string]$ancestor, [string]$descendant) {
    if ([string]::IsNullOrEmpty($ancestor) -or [string]::IsNullOrEmpty($descendant)) { return $false }
    return ((Invoke-Git $projectDir @('merge-base', '--is-ancestor', $ancestor, $descendant)).Code -eq 0)
}

function Get-DefaultBranch([string]$projectDir) {
    $r = Invoke-Git $projectDir @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
    if ($r.Code -eq 0 -and $r.Out.Trim()) { return $r.Out.Trim() }
    foreach ($b in @('main', 'master', 'origin/main', 'origin/master')) {
        if ((Invoke-Git $projectDir @('rev-parse', '--verify', '--quiet', $b)).Code -eq 0) { return $b }
    }
    return $null
}

# A hash of the exact working tree content: HEAD plus all uncommitted and untracked changes.
function Get-TreeFingerprint([string]$projectDir, [hashtable]$gi, [hashtable]$dirty) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($gi.Head).Append("`n")
    $d = Invoke-Git $projectDir @('diff', 'HEAD', '--binary', '--no-color', '--no-ext-diff')
    [void]$sb.Append($d.Out)
    foreach ($u in $dirty.Untracked) {
        $full = Join-Path $projectDir $u
        [void]$sb.Append("`n?? ").Append($u)
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $fi = Get-Item -LiteralPath $full
            if ($fi.Length -le 4MB) {
                [void]$sb.Append(' ').Append((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash)
            } else {
                [void]$sb.Append(' ').Append($fi.Length).Append(' ').Append($fi.LastWriteTimeUtc.Ticks)
            }
        }
    }
    return (Get-Sha256Hex $sb.ToString())
}

function Get-CheckKey($check) {
    return ([string]$check.name + '|' + (Get-Sha256Hex ([string]$check.run + '|' + [string]$check.cwd)).Substring(0, 12))
}

# Checks from team.json that belong to $set ('stop', 'subagent', 'verify' or 'ship') and whose
# 'when' globs match at least one changed file (or all of them when $all is set).
function Get-ApplicableChecks($cfg, [string]$set, [string]$agent, $changed, [bool]$all) {
    $result = @()
    foreach ($c in @(Get-Cfg $cfg 'quality.checks' @())) {
        if ($null -eq $c -or -not $c.name -or -not $c.run) { continue }
        if ($c.enabled -eq $false) { continue }
        $on = @($c.on)
        if ($on.Count -eq 0 -or $null -eq $on[0]) { $on = @('stop', 'verify', 'ship') }
        if (-not ($on -contains $set)) { continue }
        if ($set -eq 'subagent' -and $c.agents) {
            if (-not $agent -or -not (@($c.agents) -contains $agent)) { continue }
        }
        if (-not $all) {
            $when = @($c.when)
            if ($when.Count -gt 0 -and $null -ne $when[0]) {
                $hit = $false
                foreach ($f in $changed) { if (Test-PathMatch $f $when) { $hit = $true; break } }
                if (-not $hit) { continue }
            }
        }
        $result += $c
    }
    return ,$result
}

function Set-CheckEnvironment {
    $env:CI = 'true'
    $env:DOTNET_NOLOGO = '1'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    $env:MSBUILDDISABLENODEREUSE = '1'
    $env:NG_CLI_ANALYTICS = 'false'
    $env:NO_COLOR = '1'
    $env:FORCE_COLOR = '0'
    $env:NUGET_XMLDOC_MODE = 'skip'
}

# Folder of the .slnx or .sln to build: the project root first, then up to three levels down.
# Falls back to the folder of the only .csproj. Returns $null when nothing unambiguous is found.
function Find-DotnetSolutionDir([string]$root) {
    foreach ($pattern in @('*.slnx', '*.sln')) {
        $hit = @(Get-ChildItem -LiteralPath $root -Filter $pattern -File -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($hit.Count -gt 0) { return $root }
    }
    $skip = '[\\/](bin|obj|node_modules|\.git|\.angular|dist)[\\/]'
    foreach ($pattern in @('*.slnx', '*.sln')) {
        $hit = @(Get-ChildItem -LiteralPath $root -Filter $pattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $skip } | Sort-Object FullName)
        if ($hit.Count -gt 0) { return $hit[0].DirectoryName }
    }
    $proj = @(Get-ChildItem -LiteralPath $root -Filter '*.csproj' -File -Recurse -Depth 4 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $skip })
    if ($proj.Count -eq 1) { return $proj[0].DirectoryName }
    return $null
}

function Invoke-Check($check, [string]$projectDir) {
    $name = [string]$check.name
    $cwd = $projectDir
    if ([string]$check.cwd -eq '{solution-dir}') {
        $cwd = Find-DotnetSolutionDir $projectDir
        if (-not $cwd) {
            return @{ Name = $name; Status = 'skipped'; Code = 0; Output = 'no .slnx or .sln (or single .csproj) found; set "cwd" of this check in .claude/team.json'; Seconds = 0 }
        }
    } elseif ($check.cwd -and [string]$check.cwd -ne '.') { $cwd = Join-Path $projectDir ([string]$check.cwd) }
    if (-not (Test-Path -LiteralPath $cwd -PathType Container)) {
        return @{ Name = $name; Status = 'skipped'; Code = 0; Output = 'folder not found: ' + $check.cwd; Seconds = 0 }
    }
    foreach ($req in @($check.requires)) {
        if ($req -and -not (Get-Command $req -ErrorAction SilentlyContinue)) {
            return @{ Name = $name; Status = 'skipped'; Code = 0; Output = 'requires ' + $req + ', which is not installed'; Seconds = 0 }
        }
    }
    $run = [string]$check.run
    if ($run.Contains('{base}')) {
        $base = $null
        $def = Get-DefaultBranch $projectDir
        if ($def) {
            $mb = Invoke-Git $projectDir @('merge-base', $def, 'HEAD')
            if ($mb.Code -eq 0 -and $mb.Out.Trim()) { $base = $mb.Out.Trim() }
        }
        if (-not $base) {
            return @{ Name = $name; Status = 'skipped'; Code = 0; Output = 'no default branch to compare with ({base} could not be resolved)'; Seconds = 0 }
        }
        $run = $run.Replace('{base}', $base)
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lines = @()
    $code = 0
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $cwd
    try {
        $global:LASTEXITCODE = 0
        $lines = @(Invoke-Expression ($run + ' 2>&1') | ForEach-Object { [string]$_ })
        $code = $global:LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
    } catch {
        $lines += $_.ToString()
        $code = 1
    } finally {
        Pop-Location
        $ErrorActionPreference = $oldEap
    }
    $sw.Stop()
    $text = ($lines -join "`n")
    $failed = ($code -ne 0)
    if (-not $failed -and $check.failOn -and $text -match [string]$check.failOn) { $failed = $true }
    $status = 'passed'
    if ($failed) { $status = 'failed' }
    return @{ Name = $name; Status = $status; Code = $code; Output = $text; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}

# Short, useful excerpt of a failing check: the error looking lines plus the tail.
function Get-FailureExcerpt([string]$output, [int]$tailLines) {
    $all = @($output -split "`r?`n" | Where-Object { $_ -ne $null })
    $pattern = '(?i)(\berror\b|\bfailed\b|\bfail\b|exception|assert|expected|actual|\bnot ok\b|\u2716|\u00d7)'
    $key = New-Object System.Collections.Generic.List[string]
    foreach ($l in $all) {
        if ($key.Count -ge 25) { break }
        if ($l -match $pattern -and -not $key.Contains($l.Trim())) { $key.Add($l.Trim()) }
    }
    $tail = $all
    if ($all.Count -gt $tailLines) { $tail = $all[($all.Count - $tailLines)..($all.Count - 1)] }
    $sb = New-Object System.Text.StringBuilder
    if ($key.Count -gt 0) {
        [void]$sb.Append("Key lines:`n").Append(($key -join "`n")).Append("`n`n")
    }
    [void]$sb.Append('Last ').Append($tail.Count).Append(" lines:`n").Append(($tail -join "`n"))
    $s = $sb.ToString()
    if ($s.Length -gt 6000) { $s = '...' + $s.Substring($s.Length - 6000) }
    return $s
}

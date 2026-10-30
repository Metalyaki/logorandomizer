<#
.SYNOPSIS
  Runs the checks from .claude/team.json for what changed. Used by /verify, /ship and the quality gate.

.EXAMPLE
  pwsh -NoProfile -File .claude/hooks/run-checks.ps1                 # verify set, changed areas only
  pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ship       # everything that must pass before a PR
  pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -All            # all checks of the set, changed or not
  pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Only dotnet-test
  pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -List           # show what would run
#>
param(
    [ValidateSet('stop', 'subagent', 'verify', 'ship')]
    [string]$Set = 'verify',
    [switch]$All,
    [string[]]$Only,
    [switch]$List,
    [switch]$NoCache,
    [string]$Agent
)

. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/checks.ps1')

$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$cfg = Get-TeamConfig $projectDir
if ($null -eq $cfg) { Write-Output 'No valid .claude/team.json found.'; exit 2 }

$gi = Get-GitInfo $projectDir
if (-not $gi) { Write-Output 'Not a git repository.'; exit 2 }

$dirty = Get-DirtyFiles $projectDir $gi.Prefix
$changed = @($dirty.All)
$scope = 'uncommitted changes'
$default = Get-DefaultBranch $projectDir
if ($default -and $gi.Head) {
    $mb = Invoke-Git $projectDir @('merge-base', $default, 'HEAD')
    if ($mb.Code -eq 0 -and $mb.Out.Trim() -and $mb.Out.Trim() -ne $gi.Head) {
        $changed = @($changed + @(Get-ChangedBetween $projectDir $gi.Prefix $mb.Out.Trim() $gi.Head) | Select-Object -Unique)
        $scope = 'changes since ' + $default + ' plus uncommitted changes'
    }
}
if ($Set -eq 'ship') { $All = $true }

$checks = Get-ApplicableChecks $cfg $Set $Agent $changed ([bool]$All)
if ($Only) {
    $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $checks = @($checks | Where-Object { $Only -contains $_.name })
}

$scopeText = $scope
if ($All) { $scopeText = 'all checks in the set' }
Write-Output ('Set "' + $Set + '": ' + $changed.Count + ' changed files (' + $scopeText + ').')
if ($checks.Count -eq 0) { Write-Output 'No checks apply. Nothing to run.'; exit 0 }

if ($List) {
    foreach ($c in $checks) {
        $dir = '.'
        if ($c.cwd) { $dir = [string]$c.cwd }
        Write-Output ('  ' + $c.name.PadRight(22) + ' ' + $dir.PadRight(12) + ' ' + $c.run)
    }
    exit 0
}

Set-CheckEnvironment
$lock = Enter-Lock ((Get-StateFile $projectDir 'gate') + '.lock') 600
if (-not $lock) { Write-Output 'Another check run is still busy on this repository. Try again later.'; exit 2 }
try {
    $statePath = Get-StateFile $projectDir 'gate'
    $state = Read-State $statePath
    if (-not ($state['checks'] -is [hashtable])) { $state['checks'] = @{} }
    $fp = Get-TreeFingerprint $projectDir $gi $dirty

    $results = @()
    foreach ($c in $checks) {
        $key = Get-CheckKey $c
        if (-not $NoCache -and [string]$state.checks[$key] -eq $fp) {
            $results += @{ Name = $c.name; Status = 'passed'; Seconds = 0; Output = ''; Cached = $true; Code = 0 }
            continue
        }
        Write-Output ('  running ' + $c.name + ' ...')
        $r = Invoke-Check $c $projectDir
        $r.Cached = $false
        $r.Check = $c
        if ($r.Status -eq 'passed') { $state.checks[$key] = $fp; Write-State $statePath $state }
        $results += $r
    }
} finally {
    Exit-Lock $lock
}

Write-Output ''
$anyFailed = $false
foreach ($r in $results) {
    $label = 'PASS'
    if ($r.Status -eq 'failed') { $label = 'FAIL'; $anyFailed = $true }
    if ($r.Status -eq 'skipped') { $label = 'SKIP' }
    $note = '' + $r.Seconds + ' s'
    if ($r.Cached) { $note = 'cached, same tree passed before' }
    if ($r.Status -eq 'skipped') { $note = $r.Output }
    Write-Output ('  ' + $label + '  ' + ([string]$r.Name).PadRight(22) + ' ' + $note)
}
$tail = [int](Get-Cfg $cfg 'quality.tailLines' 40)
foreach ($r in $results) {
    if ($r.Status -ne 'failed') { continue }
    $where = '.'
    if ($r.Check.cwd) { $where = [string]$r.Check.cwd }
    Write-Output ''
    Write-Output ('---- ' + $r.Name + ' (exit ' + $r.Code + ') : ' + $r.Check.run + '   [in ' + $where + ']')
    Write-Output (Get-FailureExcerpt $r.Output $tail)
}
if ($anyFailed) { exit 1 }
exit 0

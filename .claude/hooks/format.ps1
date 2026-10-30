# PostToolUse hook for Edit, Write and MultiEdit: formats the file Claude just changed.
#
# Formatters come from .claude/team.json (format). Each entry has:
#   when      globs the file must match
#   run       command; {file} is the absolute path, {relpath} the path relative to cwd, {name} the file name
#   cwd       "project" (default), "file" (the file's folder) or "nearest:<marker>" (closest folder upwards,
#             inside the project, that contains <marker>; skipped when none is found)
#   requires  executable that must be on PATH, otherwise the entry is skipped
#   enabled   false to switch an entry off
# Only the first matching entry runs. Never blocks: formatting problems are left to the checks and reviewer.

. (Join-Path $PSScriptRoot 'lib/common.ps1')
if (-not (Test-FullLanguage)) { exit 0 }

try {
    $hook = Read-HookInput
    if ($null -eq $hook) { exit 0 }
    $file = [string]$hook.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($file) -or -not (Test-Path -LiteralPath $file -PathType Leaf)) { exit 0 }

    $projectDir = Get-ProjectDir $hook
    $cfg = Get-TeamConfig $projectDir
    $rel = Get-ProjectRelativePath $file $projectDir
    if ($null -eq $rel) { exit 0 }

    $entry = $null
    foreach ($e in @(Get-Cfg $cfg 'format' @())) {
        if ($null -eq $e -or $e.enabled -eq $false -or -not $e.run) { continue }
        if (Test-PathMatch $rel @($e.when)) { $entry = $e; break }
    }
    if (-not $entry) { exit 0 }
    foreach ($req in @($entry.requires)) {
        if ($req -and -not (Get-Command $req -ErrorAction SilentlyContinue)) { exit 0 }
    }

    $fileDir = Split-Path -Parent $file
    $cwd = $projectDir
    $mode = [string]$entry.cwd
    if ($mode -eq 'file') {
        $cwd = $fileDir
    } elseif ($mode -like 'nearest:*') {
        $marker = $mode.Substring(8)
        $dir = $fileDir
        $root = (ConvertTo-NormPath $projectDir).TrimEnd('/')
        $cwd = $null
        while ($dir) {
            if (Test-Path -LiteralPath (Join-Path $dir $marker)) { $cwd = $dir; break }
            if ((ConvertTo-NormPath $dir).TrimEnd('/') -ieq $root) { break }
            $parent = Split-Path -Parent $dir
            if (-not $parent -or $parent -eq $dir) { break }
            $dir = $parent
        }
        if (-not $cwd) { exit 0 }
    }

    $relToCwd = Get-ProjectRelativePath $file $cwd
    if ($null -eq $relToCwd) { $relToCwd = $file }
    function Quote([string]$s) { return "'" + $s.Replace("'", "''") + "'" }
    $run = ([string]$entry.run).Replace('{file}', (Quote $file)).Replace('{relpath}', (Quote $relToCwd)).Replace('{name}', (Quote (Split-Path -Leaf $file)))

    $env:DOTNET_NOLOGO = '1'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $cwd
    try { $null = Invoke-Expression ($run + ' 2>&1') } finally { Pop-Location }
} catch { }
exit 0

# Status line: model, effort, context use and plan usage, so you can see when to /handoff and /clear.
# Example: Sonnet 5.5 medium | ctx 34% | 5h 23% | week 41% | feature/0007-booking
# Claude Code runs this after each response. Keep it fast and never fail loudly.

$ErrorActionPreference = 'SilentlyContinue'
try {
    $stdin = [Console]::OpenStandardInput()
    $ms = New-Object System.IO.MemoryStream
    $stdin.CopyTo($ms)
    $data = [System.Text.Encoding]::UTF8.GetString($ms.ToArray()) | ConvertFrom-Json
} catch { $data = $null }

$parts = New-Object System.Collections.Generic.List[string]
$hints = New-Object System.Collections.Generic.List[string]

if ($data) {
    $model = [string]$data.model.display_name
    if ($model) {
        $effort = [string]$data.effort.level
        if ($effort) { $model = $model + ' ' + $effort }
        $parts.Add($model)
    }
    $ctx = $data.context_window.used_percentage
    if ($null -ne $ctx) {
        $c = [int][math]::Round([double]$ctx)
        $parts.Add('ctx ' + $c + '%')
        if ($c -ge 60) { $hints.Add('context high: /handoff then /clear') }
    }
    $five = $data.rate_limits.five_hour.used_percentage
    if ($null -ne $five) {
        $f = [int][math]::Round([double]$five)
        $parts.Add('5h ' + $f + '%')
        if ($f -ge 80) { $hints.Add('5 hour limit close') }
    }
    $week = $data.rate_limits.seven_day.used_percentage
    if ($null -ne $week) {
        $w = [int][math]::Round([double]$week)
        $parts.Add('week ' + $w + '%')
        if ($w -ge 80) { $hints.Add('weekly limit close') }
    }
    $dir = [string]$data.workspace.current_dir
    if (-not $dir) { $dir = [string]$data.cwd }
    if ($dir -and (Test-Path -LiteralPath $dir)) {
        $branch = (& git -C $dir branch --show-current 2>$null)
        if ($branch) { $parts.Add([string]$branch) }
    }
}

$line = ($parts -join ' | ')
if ($hints.Count -gt 0) { $line = $line + ' | ' + ($hints -join ', ') }
$bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
$out = [Console]::OpenStandardOutput()
$out.Write($bytes, 0, $bytes.Length)
$out.Flush()

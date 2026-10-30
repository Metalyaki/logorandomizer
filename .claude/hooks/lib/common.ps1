# Shared helpers for the dev team hooks.
# Works on Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS and Linux.
# Keep this file pure ASCII: Windows PowerShell 5.1 reads BOM less files in the ANSI code page.

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:GlobCache = @{}

# ---------------------------------------------------------------- language mode

function Test-FullLanguage {
    return ($ExecutionContext.SessionState.LanguageMode -eq 'FullLanguage')
}

function Exit-IfConstrained {
    if (Test-FullLanguage) { return }
    $msg = 'Claude dev team hook cannot run: PowerShell is in ' + $ExecutionContext.SessionState.LanguageMode + ' mode (AppLocker or WDAC). Ask IT to sign or allow list the scripts in .claude/hooks. See README, section Troubleshooting.'
    Write-Error -Message $msg -ErrorAction Continue
    exit 1
}

# ---------------------------------------------------------------- stdin and stdout (always UTF-8)

function Read-HookStdin {
    $stdin = [Console]::OpenStandardInput()
    $ms = New-Object System.IO.MemoryStream
    $stdin.CopyTo($ms)
    $text = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return $text
}

function Read-HookInput {
    $raw = Read-HookStdin
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return ($raw | ConvertFrom-Json) } catch { return $null }
}

function Write-Utf8Stdout([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $out = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
}

function Write-HookJson($obj) {
    Write-Utf8Stdout ($obj | ConvertTo-Json -Depth 10 -Compress)
}

function Write-PreToolDecision([string]$decision, [string]$reason) {
    Write-HookJson @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = $decision; permissionDecisionReason = $reason } }
}

# ---------------------------------------------------------------- hook context

function Get-ProjectDir($hook) {
    if ($env:CLAUDE_PROJECT_DIR) { return $env:CLAUDE_PROJECT_DIR }
    if ($hook -and $hook.cwd) { return [string]$hook.cwd }
    return (Get-Location).Path
}

function Get-AgentName($hook) {
    if (-not $hook) { return $null }
    $a = [string]$hook.agent_type
    if ([string]::IsNullOrWhiteSpace($a)) { return $null }
    if ($a.Contains(':')) { $a = $a.Substring($a.LastIndexOf(':') + 1) }
    return $a.ToLowerInvariant()
}

function Test-IsSubagent($hook) {
    if (-not $hook) { return $false }
    return (-not [string]::IsNullOrWhiteSpace([string]$hook.agent_id))
}

# ---------------------------------------------------------------- team.json

function Get-TeamConfig([string]$projectDir) {
    $candidates = @()
    if ($projectDir) { $candidates += (Join-Path (Join-Path $projectDir '.claude') 'team.json') }
    $candidates += (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'team.json')
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            try { return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
        }
    }
    return $null
}

function Test-TeamConfigValid([string]$projectDir) {
    $p = Join-Path (Join-Path $projectDir '.claude') 'team.json'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return 'missing' }
    try { $null = (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json); return 'ok' } catch { return 'invalid: ' + $_.Exception.Message }
}

# Reads a dotted path such as 'quality.maxBlocks' from the config, with a default.
function Get-Cfg($cfg, [string]$path, $default) {
    if ($null -eq $cfg) { return $default }
    $node = $cfg
    foreach ($part in $path.Split('.')) {
        if ($null -eq $node) { return $default }
        $prop = $node.PSObject.Properties[$part]
        if ($null -eq $prop) { return $default }
        $node = $prop.Value
    }
    if ($null -eq $node) { return $default }
    return $node
}

# ---------------------------------------------------------------- paths

function Test-AbsPath([string]$p) {
    return ($p -match '^(/|[a-zA-Z]:/|//)')
}

# Normalizes separators to '/', maps /c/... to c:/... on Windows and resolves '.' and '..' textually.
function ConvertTo-NormPath([string]$p) {
    if ([string]::IsNullOrEmpty($p)) { return $p }
    $s = $p.Trim() -replace '\\', '/'
    if ($script:IsWin -and $s -match '^/([a-zA-Z])(/|$)') { $s = $Matches[1] + ':' + $s.Substring(2) }
    $lead = ''
    if ($s.StartsWith('//')) { $lead = '//'; $s = $s.Substring(2) }
    $s = $s -replace '/{2,}', '/'
    $isRoot = $s.StartsWith('/')
    $stack = New-Object System.Collections.Generic.List[string]
    foreach ($seg in $s.Split('/')) {
        if ($seg -eq '' -or $seg -eq '.') { continue }
        if ($seg -eq '..') {
            if ($stack.Count -gt 0 -and $stack[$stack.Count - 1] -ne '..' -and $stack[$stack.Count - 1] -notmatch '^[a-zA-Z]:$') {
                $stack.RemoveAt($stack.Count - 1)
            } elseif (-not $isRoot) {
                $stack.Add('..')
            }
            continue
        }
        $stack.Add($seg)
    }
    $r = ($stack -join '/')
    if ($isRoot) { $r = '/' + $r }
    if ($r -match '^[a-zA-Z]:$') { $r += '/' }
    if ($r -eq '' -and -not $isRoot) { $r = '.' }
    return $lead + $r
}

# Returns the path relative to the project root with '/' separators, '' for the root itself,
# or $null when the path is outside the project.
function Get-ProjectRelativePath([string]$path, [string]$root) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $f = ConvertTo-NormPath $path
    if (-not (Test-AbsPath $f)) {
        if ($f -eq '.') { return '' }
        if ($f -eq '..' -or $f.StartsWith('../') -or $f.StartsWith('~')) { return $null }
        return $f
    }
    $r = (ConvertTo-NormPath $root).TrimEnd('/')
    if ([string]::IsNullOrEmpty($r)) { return $null }
    $cmp = [StringComparison]::Ordinal
    if ($script:IsWin) { $cmp = [StringComparison]::OrdinalIgnoreCase }
    if ($f.Equals($r, $cmp)) { return '' }
    if ($f.StartsWith($r + '/', $cmp)) { return $f.Substring($r.Length + 1) }
    return $null
}

# ---------------------------------------------------------------- globs (gitignore style)

function ConvertFrom-Glob([string]$glob) {
    if ($script:GlobCache.ContainsKey($glob)) { return $script:GlobCache[$glob] }
    $g = $glob -replace '\\', '/'
    $anchored = $false
    if ($g.StartsWith('/')) { $anchored = $true; $g = $g.Substring(1) }
    if ($g.StartsWith('./')) { $anchored = $true; $g = $g.Substring(2) }
    $hasSlash = $g.TrimEnd('/').Contains('/')
    if ($g.EndsWith('/')) { $g = $g + '**' }
    $braces = ($g.Split('{').Count -eq $g.Split('}').Count)
    $sb = New-Object System.Text.StringBuilder
    $depth = 0
    $i = 0
    while ($i -lt $g.Length) {
        $c = $g[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $g.Length -and $g[$i + 1] -eq '*') {
                $i += 2
                if ($i -lt $g.Length -and $g[$i] -eq '/') { [void]$sb.Append('(?:.*/)?'); $i++ } else { [void]$sb.Append('.*') }
                continue
            }
            [void]$sb.Append('[^/]*'); $i++; continue
        }
        if ($c -eq '?') { [void]$sb.Append('[^/]'); $i++; continue }
        if ($braces -and $c -eq '{') { [void]$sb.Append('(?:'); $depth++; $i++; continue }
        if ($braces -and $c -eq '}' -and $depth -gt 0) { [void]$sb.Append(')'); $depth--; $i++; continue }
        if ($c -eq ',' -and $depth -gt 0) { [void]$sb.Append('|'); $i++; continue }
        if ($c -eq '[') {
            $j = $g.IndexOf(']', $i + 1)
            if ($j -gt $i + 1) {
                $cls = $g.Substring($i + 1, $j - $i - 1)
                if ($cls.StartsWith('!')) { $cls = '^' + $cls.Substring(1) }
                [void]$sb.Append('[' + $cls + ']'); $i = $j + 1; continue
            }
        }
        [void]$sb.Append([regex]::Escape([string]$c)); $i++
    }
    $body = $sb.ToString()
    if (-not $hasSlash -and -not $anchored) { $body = '(?:.*/)?' + $body }
    $re = '^' + $body + '(?:/.*)?$'
    $script:GlobCache[$glob] = $re
    return $re
}

# Last matching pattern wins; a pattern starting with '!' negates (gitignore semantics).
function Test-PathMatch([string]$path, $globs) {
    if ($null -eq $path) { return $false }
    $matched = $false
    foreach ($gl in @($globs)) {
        if ([string]::IsNullOrEmpty([string]$gl)) { continue }
        $neg = $gl.StartsWith('!')
        $pat = $gl
        if ($neg) { $pat = $gl.Substring(1) }
        if ([regex]::IsMatch($path, (ConvertFrom-Glob $pat), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { $matched = -not $neg }
    }
    return $matched
}

# ---------------------------------------------------------------- native processes

function ConvertTo-ArgString([string[]]$argv) {
    $parts = foreach ($a in $argv) {
        if ($a -eq '') { '""' }
        elseif ($a -notmatch '[\s"]') { $a }
        else {
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append('"')
            $bs = 0
            foreach ($ch in $a.ToCharArray()) {
                if ($ch -eq '\') { $bs++; continue }
                if ($ch -eq '"') { [void]$sb.Append('\' * ($bs * 2 + 1)); [void]$sb.Append('"'); $bs = 0; continue }
                if ($bs -gt 0) { [void]$sb.Append('\' * $bs); $bs = 0 }
                [void]$sb.Append($ch)
            }
            if ($bs -gt 0) { [void]$sb.Append('\' * ($bs * 2)) }
            [void]$sb.Append('"')
            $sb.ToString()
        }
    }
    return ($parts -join ' ')
}

# Runs git with UTF-8 output decoding, independent of the console code page.
function Invoke-Git([string]$cwd, [string[]]$argv) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = ConvertTo-ArgString (@('-c', 'core.quotepath=off') + $argv)
    $psi.WorkingDirectory = $cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    try { $p = [System.Diagnostics.Process]::Start($psi) } catch { return @{ Code = -1; Out = ''; Err = $_.Exception.Message } }
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return @{ Code = $p.ExitCode; Out = $out; Err = $errTask.Result }
}

# ---------------------------------------------------------------- state files and hashing

function Get-Sha256Hex([string]$text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $b = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))
        return (($b | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

function Get-StateDir {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) 'claude-dev-team'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Get-StateFile([string]$projectDir, [string]$name) {
    $key = (Get-Sha256Hex ((ConvertTo-NormPath $projectDir).ToLowerInvariant())).Substring(0, 16)
    return (Join-Path (Get-StateDir) ($name + '-' + $key + '.json'))
}

function ConvertTo-Hashtable($obj) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [hashtable]) { return $obj }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $h
    }
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
        $list = @()
        foreach ($x in $obj) { $list += ,(ConvertTo-Hashtable $x) }
        return ,$list
    }
    return $obj
}

function Read-State([string]$path) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { $h = ConvertTo-Hashtable (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json); if ($h -is [hashtable]) { return $h } } catch { }
    }
    return @{}
}

function Write-State([string]$path, [hashtable]$state) {
    $json = $state | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# Exclusive lock so parallel subagents do not run builds on the same tree at the same time.
function Enter-Lock([string]$path, [int]$timeoutSec) {
    $deadline = [DateTime]::UtcNow.AddSeconds($timeoutSec)
    while ($true) {
        try {
            return [System.IO.File]::Open($path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        } catch {
            if ([DateTime]::UtcNow -gt $deadline) { return $null }
            Start-Sleep -Milliseconds 500
        }
    }
}

function Exit-Lock($handle) {
    if ($handle) { try { $handle.Dispose() } catch { } }
}

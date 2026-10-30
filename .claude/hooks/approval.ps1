<#
.SYNOPSIS
  Records a fingerprint of an approved spec or plan, so a later session notices when it changed after the user approved it.

.EXAMPLE
  pwsh -NoProfile -File .claude/hooks/approval.ps1 record docs/specs/0007-booking.md
  pwsh -NoProfile -File .claude/hooks/approval.ps1 check docs/specs/0007-booking.md docs/specs/0007-booking.plan.md

  record  writes or replaces the line "Approved: sha256:<fingerprint> on <date>" under the Status line.
  check   compares each file with its recorded fingerprint.

  The fingerprint ignores what may change after approval: the Status value in the header, checkbox ticks,
  the "Decisions log" and "Progress log" sections, blank lines, spacing, table padding and line endings.
  Anything else that changes needs a new approval and a new record.

  Exit codes: 0 unchanged or recorded, 1 changed since approval, 2 no approval recorded, 3 usage error or file not found.
#>
param(
    [Parameter(Position = 0)][string]$Mode,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Files
)

. (Join-Path $PSScriptRoot 'lib/common.ps1')
Exit-IfConstrained

$script:ApprovedRe = '^\s*Approved:\s*sha256:([0-9a-f]+)(.*)$'

function Read-TextFile([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return @{ Text = $text; Bom = $bom }
}

function Get-ApprovalFingerprint([string]$text) {
    $norm = ($text -replace "`r`n", "`n") -replace "`r", "`n"
    $kept = New-Object System.Collections.Generic.List[string]
    $inHeader = $true
    $skip = $false
    foreach ($raw in ($norm -split "`n")) {
        $line = $raw
        if ($line -match '^#{1,2}\s') {
            if ($line -match '^##\s') { $inHeader = $false }
            $skip = ($line -match '^##\s+(Decisions|Progress)\s+log\b')
        }
        if ($skip) { continue }
        if ($line -match $script:ApprovedRe) { continue }
        if ($inHeader) { $line = $line -replace '\bStatus:.*$', 'Status:' }
        $line = $line -replace '^(\s*[-*+]\s+)\[[ xX]\]', '$1[ ]'
        $line = ($line -replace '\s+', ' ').Trim()
        if ($line -match '^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?$') { $line = ($line -replace '-{3,}', '---') -replace '\s', '' }
        if ($line -eq '') { continue }
        $kept.Add($line)
    }
    return (Get-Sha256Hex ($kept -join "`n")).Substring(0, 16)
}

# Replaces an existing Approved line, or inserts one under the Status line of the header,
# else under the first heading, else at the top. Keeps the file's line endings.
function Set-ApprovalLine([string]$text, [string]$approvalLine) {
    $nl = "`n"
    if ($text.Contains("`r`n")) { $nl = "`r`n" }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($l in (($text -replace "`r`n", "`n") -split "`n")) { $lines.Add($l) }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $script:ApprovedRe) {
            $lines[$i] = $approvalLine
            return ($lines -join $nl)
        }
    }
    $at = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s') { break }
        if ($lines[$i] -match '\bStatus:') { $at = $i + 1; break }
    }
    if ($at -lt 0) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^#\s') { $at = $i + 1; break }
        }
    }
    if ($at -lt 0) { $at = 0 }
    $lines.Insert($at, $approvalLine)
    return ($lines -join $nl)
}

# Suggests the command that shows what changed since the approval was committed.
function Get-DiffHint([string]$full, [string]$show, [string]$hex) {
    try {
        $r = Invoke-Git (Split-Path -Parent $full) @('log', '-n', '1', '--format=%h', ('-S' + $hex), '--', (Split-Path -Leaf $full))
        if ($r.Code -eq 0 -and $r.Out.Trim()) { return ('git diff ' + $r.Out.Trim() + ' -- ' + $show) }
        if ($r.Code -eq 0) { return ('git diff HEAD -- ' + $show + ' (the approval is not committed yet)') }
    } catch { }
    return 'compare the file with the version the user approved'
}

$usage = 'Usage: approval.ps1 record|check <spec or plan file> [more files]'
if ([string]::IsNullOrWhiteSpace($Mode)) { Write-Output $usage; exit 3 }
$Mode = $Mode.ToLowerInvariant()
if (@('record', 'check') -notcontains $Mode) { Write-Output $usage; exit 3 }
$list = @($Files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($list.Count -eq 0) { Write-Output $usage; exit 3 }

$cwd = (Get-Location).ProviderPath
$anyMissing = $false
$anyChanged = $false
$anyNone = $false
foreach ($f in $list) {
    $show = $f -replace '\\', '/'
    try {
        $full = $f
        if (-not [System.IO.Path]::IsPathRooted($full)) { $full = Join-Path $cwd $f }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Write-Output ('MISSING   ' + $show)
            $anyMissing = $true
            continue
        }
        $file = Read-TextFile $full
        $fp = Get-ApprovalFingerprint $file.Text
        $opts = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        $m = [regex]::Match($file.Text, $script:ApprovedRe, $opts)

        if ($Mode -eq 'record') {
            if ($m.Success -and $m.Groups[1].Value -eq $fp) {
                Write-Output ('RECORDED  ' + $show + '  sha256:' + $fp + ' (unchanged, kept the existing line)')
                continue
            }
            $lineText = 'Approved: sha256:' + $fp + ' on ' + (Get-Date).ToString('yyyy-MM-dd')
            $newText = Set-ApprovalLine $file.Text $lineText
            [System.IO.File]::WriteAllText($full, $newText, (New-Object System.Text.UTF8Encoding($file.Bom)))
            Write-Output ('RECORDED  ' + $show + '  sha256:' + $fp)
            continue
        }

        if (-not $m.Success) {
            Write-Output ('NONE      ' + $show + '  no approval recorded')
            $anyNone = $true
            continue
        }
        $old = $m.Groups[1].Value
        if ($old -eq $fp) {
            Write-Output ('OK        ' + $show + '  sha256:' + $fp + $m.Groups[2].Value.TrimEnd())
            continue
        }
        $anyChanged = $true
        Write-Output ('CHANGED   ' + $show + '  approved sha256:' + $old + ', now sha256:' + $fp + '. Show the change: ' + (Get-DiffHint $full $show $old))
    } catch {
        Write-Output ('ERROR     ' + $show + '  ' + $_.Exception.Message)
        $anyMissing = $true
    }
}
if ($anyMissing) { exit 3 }
if ($anyChanged) { exit 1 }
if ($anyNone) { exit 2 }
exit 0

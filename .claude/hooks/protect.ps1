# PreToolUse hook for Edit, Write, MultiEdit and NotebookEdit.
#
# Enforces what prompts alone cannot:
#   - secret files (.env, keys, certificates, secrets.json) are never written
#   - the team setup (settings, hooks, agents, skills, rules, team.json, CLAUDE.md) changes only with approval
#   - generated output and lockfiles are never edited by hand
#   - migrations that are already committed are not edited
#   - each role writes only inside its scope (scopes in .claude/team.json), e.g. tester only test files,
#     reviewer and security only their own memory folder
#   - new content is scanned for credentials (cloud keys, tokens, private keys, passwords)
#
# Subagents cannot get approval from the user, so for them "ask" becomes "deny".
# Fails closed: if the input cannot be read, the edit is denied.

. (Join-Path $PSScriptRoot 'lib/common.ps1')
Exit-IfConstrained

$hook = Read-HookInput
if ($null -eq $hook) {
    Write-PreToolDecision 'deny' 'The protect hook could not read its input, so the edit was blocked to be safe. Tell the user; they can inspect the hook with /hooks.'
    exit 0
}

$tool = [string]$hook.tool_name
$ti = $hook.tool_input
$path = [string]$ti.file_path
if (-not $path) { $path = [string]$ti.notebook_path }
if (-not $path) { exit 0 }

$content = ''
switch ($tool) {
    'Write' { $content = [string]$ti.content }
    'Edit' { $content = [string]$ti.new_string }
    'MultiEdit' { $content = (@($ti.edits) | ForEach-Object { [string]$_.new_string }) -join "`n" }
    'NotebookEdit' { $content = [string]$ti.new_source }
}

$projectDir = Get-ProjectDir $hook
$cfg = Get-TeamConfig $projectDir
$agent = Get-AgentName $hook
$isSub = Test-IsSubagent $hook
$norm = ConvertTo-NormPath $path
$rel = Get-ProjectRelativePath $path $projectDir
$shown = $norm
if ($null -ne $rel) { $shown = $rel }

$script:Denies = New-Object System.Collections.Generic.List[string]
$script:Asks = New-Object System.Collections.Generic.List[string]
function Deny([string]$r) { if (-not $script:Denies.Contains($r)) { $script:Denies.Add($r) } }
function Ask([string]$r) { if (-not $script:Asks.Contains($r)) { $script:Asks.Add($r) } }

# ------------------------------------------------------------------ configuration with defaults

$secretFiles = @(Get-Cfg $cfg 'protect.secretFiles' @('**/.env', '**/.env.*', '!**/.env.example', '!**/.env.sample', '!**/.env.template', '!**/.env.defaults', '**/*.pfx', '**/*.p12', '**/*.pem', '**/*.key', '**/*.jks', '**/*.keystore', '**/*.ppk', '**/*.publishsettings', '**/secrets.json', '**/id_rsa*', '**/id_ed25519*', '!**/*.pub', '**/.git-credentials', '**/.ssh/**', '**/.aws/credentials', '**/UserSecrets/**', '**/usersecrets/**'))
$setupFiles = @(Get-Cfg $cfg 'protect.setupFiles' @('.claude/settings.json', '.claude/settings.local.json', '.claude/team.json', '.claude/hooks/**', '.claude/agents/**', '.claude/skills/**', '.claude/rules/**', '.claude/templates/**', '.mcp.json', 'CLAUDE.md', 'CLAUDE.local.md', 'REVIEW.md'))
$generated = @(Get-Cfg $cfg 'protect.generated' @('**/bin/**', '**/obj/**', '**/node_modules/**', '**/.angular/**', '**/.next/**', '**/dist/**', '**/coverage/**', '**/TestResults/**', '**/__pycache__/**', '**/.venv/**', '**/vendor/**'))
$lockfiles = @(Get-Cfg $cfg 'protect.lockfiles' @('**/package-lock.json', '**/npm-shrinkwrap.json', '**/pnpm-lock.yaml', '**/yarn.lock', '**/bun.lockb', '**/packages.lock.json', '**/poetry.lock', '**/uv.lock', '**/Pipfile.lock', '**/composer.lock', '**/Cargo.lock', '**/go.sum'))
$migrations = @(Get-Cfg $cfg 'protect.committedMigrations' @('**/Migrations/*.cs'))
$scanSkip = @(Get-Cfg $cfg 'protect.secretScanSkip' @('.claude/hooks/tests/**'))
$testGlobs = @(Get-Cfg $cfg 'scopes.tester' @('**/tests/**', '**/test/**', '**/*.spec.ts', '**/*.test.ts'))
$scopes = Get-Cfg $cfg 'scopes' $null

# ------------------------------------------------------------------ path rules

if (Test-PathMatch $norm $secretFiles) {
    Deny ('"' + $shown + '" is a secret file. Secrets never go into files Claude writes: use dotnet user-secrets or a gitignored .env that the user fills in, Azure Key Vault in production, and keep placeholders in .env.example.')
}

$userClaudeFiles = @('**/.claude/settings.json', '**/.claude/settings.local.json', '**/.claude/hooks/**', '**/.claude.json', '**/managed-settings.json', '**/.claude/CLAUDE.md', '**/.claude/agents/**', '**/.claude/skills/**')
if ($null -eq $rel) {
    if (Test-PathMatch $norm $userClaudeFiles) { Ask ('This changes Claude Code configuration outside the project: ' + $norm) }
} else {
    if (Test-PathMatch $rel $setupFiles) {
        Ask ('"' + $rel + '" is part of the dev team setup (settings, hooks, agents, skills, rules or project instructions). Changes to it need the user''s approval.')
    }
    if (Test-PathMatch $rel $generated) {
        Deny ('"' + $rel + '" is generated output or third party code. Change the source or the generator instead.')
    }
    if (Test-PathMatch $rel $lockfiles) {
        Deny ('"' + $rel + '" is a lockfile. Never edit it by hand; let the package manager regenerate it (and ask the user before adding packages).')
    }
    if (Test-PathMatch $rel $migrations) {
        $inHead = (Invoke-Git $projectDir @('cat-file', '-e', ('HEAD:' + $rel))).Code -eq 0
        if ($inHead) {
            Ask ('"' + $rel + '" is a migration that is already committed. Add a new migration instead of editing it; only edit it if it has never been applied to any shared database.')
        }
    }
}

# ------------------------------------------------------------------ role scopes

if ($agent -and $scopes -and $null -ne $scopes.PSObject.Properties[$agent]) {
    $allowed = @($scopes.PSObject.Properties[$agent].Value) + @('.claude/agent-memory/' + $agent + '/**')
    $ok = ($null -ne $rel) -and (Test-PathMatch $rel $allowed)
    if (-not $ok) {
        $list = (@($allowed) -join ', ')
        Deny ('The ' + $agent + ' agent may only write inside: ' + $list + '. "' + $shown + '" is outside that scope. Report the needed change to the lead instead.')
    }
}

# ------------------------------------------------------------------ credentials in the new content

if ($content -and -not (($null -ne $rel) -and (Test-PathMatch $rel $scanSkip))) {
    $high = @(
        @{ n = 'private key block'; p = '-----BEGIN (RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----' },
        @{ n = 'AWS access key'; p = '\b(AKIA|ASIA)[0-9A-Z]{16}\b' },
        @{ n = 'GitHub token'; p = '\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b' },
        @{ n = 'GitLab token'; p = '\bglpat-[A-Za-z0-9_\-]{20,}\b' },
        @{ n = 'Slack token'; p = '\bxox[baprs]-[A-Za-z0-9-]{10,}' },
        @{ n = 'Stripe live key'; p = '\b[rs]k_live_[0-9a-zA-Z]{20,}' },
        @{ n = 'Google API key'; p = '\bAIza[0-9A-Za-z_\-]{35}\b' },
        @{ n = 'Anthropic API key'; p = '\bsk-ant-[A-Za-z0-9_\-]{20,}' },
        @{ n = 'OpenAI API key'; p = '\bsk-(proj-|svcacct-)?[A-Za-z0-9_\-]{32,}' },
        @{ n = 'npm token'; p = '\bnpm_[A-Za-z0-9]{36}\b' },
        @{ n = 'Azure storage account key'; p = '(?i)AccountKey=[A-Za-z0-9+/]{60,}={0,2}' },
        @{ n = 'Azure shared access key'; p = '(?i)SharedAccessKey=[A-Za-z0-9+/]{40,}={0,2}' },
        @{ n = 'Azure SAS signature'; p = '(?i)[?&]sig=[A-Za-z0-9%+/]{40,}' },
        @{ n = 'Azure AD client secret'; p = '\b[A-Za-z0-9_~.\-]{3}\dQ~[A-Za-z0-9_~.\-]{31,34}\b' }
    )
    $placeholder = '(?i)(example|sample|placeholder|changeme|change_me|your[_-]?|dummy|fake|test|xxx|\*\*\*|<|>|\$\{|\{\{|redacted|todo|localdev|local_dev|password123|p@ssw0rd)'
    $medium = @(
        @{ n = 'password in a connection string or config'; p = '(?i)\b(password|pwd)\s*=\s*([^;"''\s<>{}]{8,})' },
        @{ n = 'hard coded API key or client secret'; p = '(?i)\b(api[_-]?key|client[_-]?secret|secret[_-]?key|access[_-]?token|auth[_-]?token|bearer)\b["'']?\s*[:=]\s*["'']([A-Za-z0-9_\-+/=.]{24,})["'']' }
    )
    $hits = @()
    foreach ($h in $high) {
        if ($content -match $h.p) { $hits += $h.n }
    }
    if ($hits.Count -gt 0) {
        Deny ('The new content contains what looks like a real credential (' + ($hits -join ', ') + '). Never write secrets into files: use dotnet user-secrets, a gitignored .env the user fills in, or Key Vault, and reference them by name.')
    }
    $isTest = ($null -ne $rel) -and (Test-PathMatch $rel $testGlobs)
    if (-not $isTest) {
        $mhits = @()
        foreach ($m in $medium) {
            foreach ($mm in [regex]::Matches($content, $m.p)) {
                $val = $mm.Groups[2].Value
                if ($val -and $val -notmatch $placeholder -and $val -match '[0-9]' -and $val -match '[A-Za-z]') { $mhits += $m.n; break }
            }
        }
        if ($mhits.Count -gt 0) {
            Ask ('The new content may contain a real secret (' + ($mhits -join ', ') + '). Use configuration (user-secrets, environment variables, Key Vault) or an obvious placeholder instead.')
        }
    }
}

# ------------------------------------------------------------------ decision

if ($script:Denies.Count -gt 0) {
    Write-PreToolDecision 'deny' ('Blocked by the dev team protect hook: ' + ($script:Denies -join ' '))
    exit 0
}
if ($script:Asks.Count -gt 0) {
    if ($isSub) {
        Write-PreToolDecision 'deny' ('Needs the user''s approval, which a subagent cannot get: ' + ($script:Asks -join ' ') + ' Report this to the lead instead of working around it.')
    } else {
        Write-PreToolDecision 'ask' ('Dev team protect hook: ' + ($script:Asks -join ' '))
    }
    exit 0
}
exit 0

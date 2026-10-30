# PreToolUse hook for the Bash, PowerShell and Monitor tools.
#
# Denies commands that destroy work or data, asks before risky or outward facing ones, and keeps read
# only roles (reviewer, security, architect, analyst) from changing anything through the shell.
# The command is split into its parts (;, &&, ||, |, newlines, nested bash -c / pwsh -Command and
# $( ) substitutions) and each part is checked on its own.
#
# Output: JSON permissionDecision deny or ask with a reason. Subagents cannot get approval from the user,
# so for them "ask" becomes "deny" with a note to report back to the lead.
# Fails closed: if the input cannot be read, the command is denied (onFailure is "block" in settings.json).
#
# This is a guardrail against mistakes, not a sandbox. A determined script can always find another way.

. (Join-Path $PSScriptRoot 'lib/common.ps1')
Exit-IfConstrained

$hook = Read-HookInput
if ($null -eq $hook) {
    Write-PreToolDecision 'deny' 'The guard hook could not read its input, so the command was blocked to be safe. Tell the user; they can inspect the hook with /hooks.'
    exit 0
}
$cmd = [string]$hook.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

$projectDir = Get-ProjectDir $hook
$cfg = Get-TeamConfig $projectDir
$agent = Get-AgentName $hook
$isSub = Test-IsSubagent $hook

$script:Findings = New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$level, [string]$reason) {
    foreach ($f in $script:Findings) { if ($f.Reason -eq $reason) { return } }
    $script:Findings.Add(@{ Level = $level; Reason = $reason })
}
function Deny([string]$reason) { Add-Finding 'deny' $reason }
function Ask([string]$reason) { Add-Finding 'ask' $reason }

# ------------------------------------------------------------------ configuration

$protectedBranches = @(Get-Cfg $cfg 'guard.protectedBranches' @('main', 'master', 'develop', 'release/*', 'production'))
$buildOutputs = @(Get-Cfg $cfg 'guard.buildOutputs' @('bin', 'obj', 'node_modules', 'dist', '.angular', 'coverage', 'TestResults', 'out', 'build', '.next', '.nuxt', '.turbo', '.vite', '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache', 'artifacts', 'publish', '.cache', 'tmp', 'temp', '.venv', 'venv', 'playwright-report', 'test-results'))
$npxAllow = @(Get-Cfg $cfg 'guard.npxAllow' @('prettier', 'eslint', 'tsc', 'typescript', 'ng', '@angular/cli', 'vitest', 'jest', 'playwright', '@playwright/test', '@playwright/cli', 'playwright-cli', 'tsx', 'ts-node', 'rimraf', 'next', 'vite', 'nx', 'stylelint', 'npm-check-updates', 'ncu', 'concurrently', 'cross-env', 'http-server', 'serve', 'create-next-app', '@angular/create', 'wp-env', '@wordpress/env', 'markdownlint-cli2', 'pyright'))
$readOnlyAgents = @(Get-Cfg $cfg 'guard.readOnlyAgents' @('reviewer', 'security', 'architect', 'analyst', 'explore'))
$extraRules = @(Get-Cfg $cfg 'guard.extraRules' @())

$uvxAllow = @(Get-Cfg $cfg 'guard.uvxAllow' @('ruff', 'black', 'pytest', 'mypy', 'pyright', 'pre-commit', 'tox', 'nox', 'pip-audit'))

$secretPathRe = '(?i)(^|[\s"''=:/\\(])(\.env(\.(?!example\b|sample\b|template\b|dist\b|defaults?\b)[\w.-]+)?|[\w.-]+\.(pfx|p12|pem|key|jks|keystore|ppk|kdbx|publishsettings)|secrets\.json|id_(rsa|ed25519|ecdsa|dsa)(?!\.pub)\b|\.git-credentials|\.ssh[\\/]|\.aws[\\/]credentials|\.azure[\\/]|\.kube[\\/]config|\.docker[\\/]config\.json|usersecrets[\\/])(?=$|[\s"'';|)&>]|[\\/])'

$readers = @('cat', 'type', 'gc', 'get-content', 'more', 'less', 'head', 'tail', 'bat', 'xxd', 'od', 'hexdump', 'strings', 'base64', 'scp', 'curl', 'wget', 'iwr', 'irm', 'invoke-webrequest', 'invoke-restmethod', 'select-string', 'sls', 'grep', 'egrep', 'rg', 'ag', 'findstr', 'sed', 'awk', 'notepad', 'code', 'vim', 'vi', 'nano', 'emacs', 'openssl', 'certutil', 'jq', 'yq', 'tar', 'zip', '7z', 'compress-archive', 'nc', 'ncat', 'import-csv', 'format-hex', 'fhx', 'iconv', 'dos2unix', 'clip', 'set-clipboard', 'scb')
$copiers = @('cp', 'copy', 'copy-item', 'cpi', 'mv', 'move', 'move-item', 'mi', 'rsync', 'robocopy', 'xcopy')
$harmless = @('ls', 'dir', 'gci', 'get-childitem', 'test-path', 'echo', 'write-host', 'write-output', 'touch', 'stat', 'get-item', 'gi', 'cd', 'set-location', 'pushd', 'popd', 'which', 'where', 'where.exe', 'get-command', 'git')
$writers = @('rm', 'rmdir', 'rd', 'del', 'erase', 'remove-item', 'ri', 'mv', 'move', 'move-item', 'mi', 'cp', 'copy', 'copy-item', 'cpi', 'set-content', 'sc', 'add-content', 'ac', 'out-file', 'tee', 'tee-object', 'new-item', 'ni', 'mkdir', 'md', 'rename-item', 'ren', 'rni', 'touch', 'truncate', 'chmod', 'chown', 'ln', 'patch', 'clear-content', 'clc', 'install', 'unzip', 'expand-archive', 'tar', 'dd')
$dbClients = @('sqlcmd', 'osql', 'invoke-sqlcmd', 'psql', 'mysql', 'mariadb', 'sqlite3', 'mongo', 'mongosh', 'redis-cli', 'sqlpackage', 'bcp')
$shells = @('bash', 'sh', 'zsh', 'dash', 'ksh', 'pwsh', 'powershell', 'cmd', 'wsl')

# ------------------------------------------------------------------ tokenizing

function Split-Segments([string]$text) {
    $t = $text -replace '`\r?\n', ' '
    $t = $t -replace '\\\r?\n', ' '
    $parts = [regex]::Split($t, '\r?\n|;|&&|\|\||\|&|\||(?<![<>&0-9])&(?![>&])')
    return @($parts | Where-Object { $_ -and $_.Trim() })
}

function Get-Tokens([string]$seg) {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($seg, '"((?:[^"\\`]|\\.|`.)*)"|''([^'']*)''|(\S+)')) {
        if ($m.Groups[1].Success) { $list.Add($m.Groups[1].Value) }
        elseif ($m.Groups[2].Success) { $list.Add($m.Groups[2].Value) }
        else { $list.Add($m.Groups[3].Value.Trim('"', "'")) }
    }
    return ,$list.ToArray()
}

function Get-VerbName([string]$token) {
    $v = $token.Trim('"', "'") -replace '\\', '/'
    if ($v.Contains('/')) { $v = $v.Substring($v.LastIndexOf('/') + 1) }
    $v = $v.ToLowerInvariant()
    $v = $v -replace '\.(exe|cmd|bat|ps1|com)$', ''
    return $v
}

# Returns @{ Verb; Rest; Sudo } after skipping env assignments and wrapper commands.
function Get-Command-Parts($tokens) {
    $i = 0
    $sudo = $false
    $wrappers = @('sudo', 'doas', 'env', 'command', 'exec', 'time', 'nohup', 'nice', 'ionice', 'stdbuf', 'timeout', '&', '.', 'call', 'builtin')
    while ($i -lt $tokens.Count) {
        $t = $tokens[$i]
        if ($t -match '^[A-Za-z_][A-Za-z0-9_]*=') { $i++; continue }
        $v = Get-VerbName $t
        if ($wrappers -contains $v) {
            if ($v -eq 'env' -and $i -eq $tokens.Count - 1) { break }
            if ($v -eq 'sudo' -or $v -eq 'doas') { $sudo = $true }
            $i++
            if ($v -eq 'timeout' -and $i -lt $tokens.Count -and $tokens[$i] -match '^\d') { $i++ }
            while ($i -lt $tokens.Count -and $tokens[$i].StartsWith('-') -and $v -ne '&' -and $v -ne '.') {
                if (($v -in @('sudo', 'doas') -and $tokens[$i] -in @('-u', '-g', '-C', '-D', '-r', '-t', '-h')) -or ($v -in @('nice', 'ionice') -and $tokens[$i] -in @('-n', '-c'))) { $i++ }
                $i++
            }
            continue
        }
        break
    }
    if ($i -ge $tokens.Count) { return @{ Verb = $null; Rest = @(); Sudo = $sudo } }
    $rest = @()
    if ($i + 1 -lt $tokens.Count) { $rest = $tokens[($i + 1)..($tokens.Count - 1)] }
    return @{ Verb = (Get-VerbName $tokens[$i]); Rest = @($rest); Sudo = $sudo }
}

function Get-Positional($rest) {
    return @($rest | Where-Object { $_ -and -not $_.StartsWith('-') })
}

function Test-ProtectedBranch([string]$ref) {
    $r = $ref -replace '^refs/heads/', ''
    foreach ($b in $protectedBranches) {
        if ($r -like $b) { return $true }
    }
    return $false
}

# ------------------------------------------------------------------ analyzers

function Test-GitCommand($rest, [string]$seg) {
    $i = 0
    while ($i -lt $rest.Count) {
        $t = $rest[$i]
        if (@('-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path') -ccontains $t) { $i += 2; continue }
        if ($t.StartsWith('-')) { $i++; continue }
        break
    }
    if ($i -ge $rest.Count) { return }
    $sub = $rest[$i].ToLowerInvariant()
    $o = @()
    if ($i + 1 -lt $rest.Count) { $o = @($rest[($i + 1)..($rest.Count - 1)]) }
    $pos = @(Get-Positional $o)

    switch ($sub) {
        'push' {
            if ($o | Where-Object { $_ -ceq '--force' -or $_ -cmatch '^-[a-zA-Z]*f[a-zA-Z]*$' }) { Deny 'git push --force rewrites remote history and can destroy other people''s work.' }
            if ($o -contains '--mirror') { Deny 'git push --mirror can overwrite or delete every branch on the remote.' }
            if ($o | Where-Object { $_.StartsWith('+') }) { Deny 'git push with a +refspec is a force push.' }
            if ($o | Where-Object { $_ -like '--force-with-lease*' -or $_ -like '--force-if-includes*' }) { Ask 'git push --force-with-lease still rewrites remote history.' }
            if ($o | Where-Object { $_ -ceq '-d' -or $_ -ceq '--delete' -or ($_.StartsWith(':') -and $_.Length -gt 1) }) { Ask 'This deletes a branch or tag on the remote.' }
            if ($o -contains '--no-verify') { Ask 'git push --no-verify skips the repository''s push hooks.' }
            if ($o -contains '--all' -or $o -contains '--tags') { Ask 'This pushes all branches or all tags.' }
            $targets = @()
            if ($pos.Count -ge 2) { $targets = $pos[1..($pos.Count - 1)] }
            if ($targets.Count -eq 0) {
                $cur = (Invoke-Git $projectDir @('branch', '--show-current')).Out.Trim()
                if ($cur) { $targets = @($cur) }
            }
            foreach ($t in $targets) {
                $dst = $t
                if ($t.Contains(':')) { $dst = $t.Substring($t.IndexOf(':') + 1) }
                if ($dst -eq 'HEAD') { $dst = (Invoke-Git $projectDir @('branch', '--show-current')).Out.Trim() }
                if ($dst -and (Test-ProtectedBranch $dst)) { Ask ('This pushes directly to the protected branch "' + $dst + '". The normal flow is a feature branch and a pull request.') }
            }
        }
        'reset' {
            if ($o -contains '--hard') { Deny 'git reset --hard throws away uncommitted work. Ask the user to run it if it is really intended, or use git stash.' }
        }
        'clean' {
            $dry = ($o | Where-Object { $_ -ceq '-n' -or $_ -eq '--dry-run' })
            if (-not $dry -and ($o | Where-Object { $_ -eq '--force' -or $_ -cmatch '^-[a-zA-Z]*f' })) { Deny 'git clean -f permanently deletes untracked files, which git cannot bring back.' }
        }
        'checkout' {
            $dd = [array]::IndexOf([string[]]$o, '--')
            if ($dd -ge 0) {
                $paths = @()
                if ($dd + 1 -lt $o.Count) { $paths = $o[($dd + 1)..($o.Count - 1)] }
                if ($paths | Where-Object { $_ -in @('.', '*', ':/', './', ':/*') }) { Deny 'git checkout -- . discards all uncommitted changes.' }
                elseif ($paths.Count -gt 0) { Ask ('git checkout -- discards uncommitted changes in: ' + ($paths -join ', ')) }
            } elseif ($pos -contains '.' -or $pos -contains ':/') {
                Deny 'git checkout . discards all uncommitted changes.'
            }
            if ($o | Where-Object { $_ -ceq '-f' -or $_ -eq '--force' }) { Ask 'git checkout --force discards local changes.' }
        }
        'switch' {
            if ($o | Where-Object { $_ -ceq '-f' -or $_ -eq '--force' -or $_ -eq '--discard-changes' }) { Ask 'git switch --force discards local changes.' }
        }
        'restore' {
            $staged = ($o -contains '--staged' -or $o -ccontains '-S')
            $worktree = ($o -contains '--worktree' -or $o -ccontains '-W')
            if (-not $staged -or $worktree) {
                $paths = @($pos | Where-Object { $_ -notmatch '^--' })
                if ($paths | Where-Object { $_ -in @('.', '*', ':/', './', ':/*') }) { Deny 'git restore . discards all uncommitted changes.' }
                elseif ($paths.Count -gt 0) { Ask ('git restore discards uncommitted changes in: ' + ($paths -join ', ')) }
            }
        }
        'stash' {
            if ($pos.Count -gt 0 -and @('drop', 'clear') -contains $pos[0].ToLowerInvariant()) { Ask 'git stash drop or clear deletes stashed work.' }
        }
        'branch' {
            if ($o | Where-Object { $_ -ceq '-D' -or $_ -cmatch '^-[a-zA-Z]*D' }) { Ask 'git branch -D force deletes a branch; unmerged commits can be lost.' }
            if (($o -contains '--delete' -or $o -ccontains '-d') -and ($o -contains '--force' -or $o -ccontains '-f')) { Ask 'Force deleting a branch can lose unmerged commits.' }
        }
        'filter-branch' { Deny 'Rewriting repository history is not allowed from Claude. Ask the user to do it.' }
        'filter-repo' { Deny 'Rewriting repository history is not allowed from Claude. Ask the user to do it.' }
        'reflog' {
            if ($pos.Count -gt 0 -and @('expire', 'delete') -contains $pos[0].ToLowerInvariant()) { Deny 'Expiring or deleting reflog entries removes the safety net for lost commits.' }
        }
        'gc' {
            if ($o | Where-Object { $_ -like '--prune=now*' }) { Ask 'git gc --prune=now permanently removes unreachable commits.' }
        }
        'update-ref' {
            if ($o -ccontains '-d') { Ask 'git update-ref -d deletes a ref.' }
        }
        'commit' {
            if ($o -contains '--no-verify' -or $o -ccontains '-n') { Ask 'git commit --no-verify skips the repository''s commit hooks.' }
        }
        'config' {
            $read = ($o | Where-Object { $_ -in @('--get', '--get-all', '--list', '-l', '--get-regexp', '--show-origin') })
            if (-not $read -and ($o -contains '--global' -or $o -contains '--system')) { Ask 'This changes git configuration outside this repository.' }
        }
        'rm' {
            $rec = ($o | Where-Object { $_ -cmatch '^-[a-zA-Z]*r' })
            if ($rec -and -not ($o -contains '--cached') -and ($pos | Where-Object { $_ -in @('.', '*', ':/', './') })) { Deny 'git rm -r . deletes every tracked file.' }
        }
        'worktree' {
            if ($pos.Count -gt 0 -and $pos[0] -eq 'remove' -and ($o | Where-Object { $_ -ceq '-f' -or $_ -eq '--force' })) { Ask 'Force removing a worktree deletes its uncommitted changes.' }
        }
        'submodule' {
            if ($pos.Count -gt 0 -and $pos[0] -eq 'deinit' -and ($o | Where-Object { $_ -ceq '-f' -or $_ -eq '--force' -or $_ -eq '--all' })) { Ask 'Force deinit of submodules discards their local changes.' }
        }
        'add' {
            if ($o | Where-Object { $_ -ceq '-f' -or $_ -eq '--force' }) { Ask 'git add --force adds files that .gitignore excludes, often build output or secrets.' }
        }
    }
}

function Test-TargetForDelete([string]$target) {
    $t = $target.Trim().Trim('"', "'")
    if ($t -match '(?i)^(\$home|\$\{home\}|\$env:(userprofile|home|homepath|systemroot|windir|programfiles|appdata|localappdata)|%(userprofile|homepath|systemroot|windir|appdata|localappdata)%)([\\/]\*?)?$') { Deny ('Recursive delete of ' + $t + ' would wipe a home or system folder.'); return }
    if ($t -match '[\$`%]') { Ask ('Recursive delete of a path built from a variable: ' + $t); return }
    $n = ConvertTo-NormPath $t
    $low = $n.ToLowerInvariant().TrimEnd('/')
    if ($low -eq '') { $low = '/' }
    $catastrophic = '^(/|/\*|~|~/\*|\*|\.|\./\*|\.\.|\.\./\*|[a-z]:|[a-z]:/|[a-z]:/\*|\$home|%userprofile%)$'
    $systemDirs = '^(/(home|users|etc|usr|var|bin|sbin|lib|lib64|opt|boot|root|mnt|srv|sys|proc|dev|system|applications|library|windows|program files( \(x86\))?|programdata)|[a-z]:/(users|windows|program files( \(x86\))?|programdata))(/[^/]+)?/?\*?$'
    if ($low -match $catastrophic -or $low -match $systemDirs) { Deny ('Recursive delete of ' + $t + ' would wipe a root, home, system or whole project folder.'); return }
    if ($t.StartsWith('~')) { Ask ('Recursive delete in your home folder: ' + $t); return }
    $rel = Get-ProjectRelativePath $n $projectDir
    if ($null -eq $rel) {
        if (Test-AbsPath $n) {
            $root = (ConvertTo-NormPath $projectDir).TrimEnd('/').ToLowerInvariant()
            if ($root.StartsWith($low + '/')) { Deny ('Recursive delete of ' + $t + ' would delete the project itself.'); return }
        }
        Ask ('Recursive delete outside the project: ' + $t); return
    }
    if ($rel -eq '') { Deny 'Recursive delete of the project root.'; return }
    $segs = @($rel.Split('/') | Where-Object { $_ -and $_ -ne '*' -and $_ -ne '**' })
    $leaf = ''
    if ($segs.Count -gt 0) { $leaf = $segs[$segs.Count - 1] }
    foreach ($b in $buildOutputs) { if ($leaf -ieq $b) { return } }
    if ($rel -match '(^|/)\.git(/|$)') { Deny 'Deleting the .git folder destroys the repository history.'; return }
    Ask ('Recursive delete of ' + $t + '. Untracked files in it cannot be restored with git.')
}

function Test-DeleteCommand([string]$verb, $rest) {
    $cmdStyle = @('rd', 'rmdir', 'del', 'erase') -contains $verb
    $recursive = $false
    foreach ($a in $rest) {
        if ($a -cmatch '^-[rRfivdIP]{1,5}$' -and $a -cmatch '[rR]') { $recursive = $true }
        if ($a -eq '--recursive') { $recursive = $true }
        if ($a -match '^-r(e(c(u(r(s(e)?)?)?)?)?)?(:\$true)?$') { $recursive = $true }
        if ($cmdStyle -and $a -match '^/s$') { $recursive = $true }
    }
    if (-not $recursive) { return }
    $targets = @()
    $skipNext = $false
    foreach ($a in $rest) {
        if ($skipNext) { $skipNext = $false; continue }
        if ($a -match '^-(include|exclude|filter|erroraction|ea|warningaction|wa)$') { $skipNext = $true; continue }
        if ($a -match '^-(path|literalpath|lp)$') { continue }
        if ($a.StartsWith('-')) { continue }
        if ($cmdStyle -and $a -match '^/[a-zA-Z]$') { continue }
        $targets += $a
    }
    if ($targets.Count -eq 0) { Ask 'Recursive delete of piped or unknown paths.'; return }
    foreach ($t in $targets) { Test-TargetForDelete $t }
}

function Test-DbText([string]$seg) {
    if ($seg -match '(?i)\bdrop\s+(database|schema|table)\b') { Deny 'Destructive SQL (DROP DATABASE, SCHEMA or TABLE). Ask the user to run it.' }
    if ($seg -match '(?i)\btruncate\s+table\b') { Deny 'Destructive SQL (TRUNCATE TABLE). Ask the user to run it.' }
    if ($seg -match '(?i)\bdrop\s+(view|procedure|proc|function|login|user|index|constraint|trigger)\b') { Ask 'This SQL drops a database object.' }
    if ($seg -match '(?i)\bdelete\s+from\b' -and $seg -notmatch '(?i)\bwhere\b') { Ask 'DELETE without a WHERE clause removes every row.' }
    if ($seg -match '(?i)\bupdate\s+[\w\[\]."]+\s+set\b' -and $seg -notmatch '(?i)\bwhere\b') { Ask 'UPDATE without a WHERE clause changes every row.' }
    if ($seg -match '(?i)\balter\s+table\b.*\bdrop\b') { Ask 'This SQL drops a column or constraint.' }
    if ($seg -match '(?i)\b(flushall|flushdb|dropdatabase)\b') { Deny 'This wipes a database.' }
}

function Test-Segment([string]$seg, [int]$depth) {
    if ($depth -gt 3) { Ask 'Command nesting is too deep to check.'; return }
    $tokens = Get-Tokens $seg
    if ($tokens.Count -eq 0) { return }
    $p = Get-Command-Parts $tokens
    $verb = $p.Verb
    $rest = @($p.Rest)
    if (-not $verb) { return }
    $restLow = @($rest | ForEach-Object { $_.ToLowerInvariant() })
    $restText = ($rest -join ' ')
    if ($p.Sudo) { Ask 'This runs a command with elevated rights (sudo).' }

    # Nested shells: check the inner command too.
    if ($shells -contains $verb) {
        for ($k = 0; $k -lt $rest.Count; $k++) {
            $a = $rest[$k].ToLowerInvariant()
            if (($verb -eq 'pwsh' -or $verb -eq 'powershell') -and $a -match '^-(e|ec|en|enc|enco|encod|encode|encoded|encodedc\w*)$') {
                Deny 'An encoded PowerShell command cannot be checked. Run the plain command instead.'
                return
            }
            if ($a -in @('-c', '-lc', '-ic', '-command', '/c', '/k', '-com', '-comm', '-comma', '-comman', '-e') -and $k + 1 -lt $rest.Count) {
                $inner = ($rest[($k + 1)..($rest.Count - 1)] -join ' ')
                foreach ($s in (Split-Segments $inner)) { Test-Segment $s ($depth + 1) }
                return
            }
        }
        if ($verb -eq 'wsl' -and $rest.Count -gt 0) {
            Test-Segment (($rest | Where-Object { -not $_.StartsWith('-') }) -join ' ') ($depth + 1)
        }
        return
    }

    if ($verb -eq 'xargs') {
        $k = 0
        while ($k -lt $rest.Count -and $rest[$k].StartsWith('-')) {
            if ($rest[$k] -in @('-I', '-n', '-P', '-L', '-d', '-E', '-s')) { $k++ }
            $k++
        }
        if ($k -lt $rest.Count) { Test-Segment ($rest[$k..($rest.Count - 1)] -join ' ') ($depth + 1) }
        return
    }

    switch -regex ($verb) {
        '^git$' { Test-GitCommand $rest $seg }
        '^(rm|rmdir|rd|del|erase|remove-item|ri)$' { Test-DeleteCommand $verb $rest }
        '^find$' {
            if ($restLow -contains '-delete') { Ask 'find -delete removes every matching file.' }
            if (($restLow -contains '-exec' -or $restLow -contains '-execdir') -and ($restText -match '(?i)\b(rm|del|remove-item|shred)\b')) { Ask 'find -exec rm removes every matching file.' }
        }
        '^robocopy$' { if ($restLow -contains '/mir' -or $restLow -contains '/purge') { Ask 'robocopy /MIR or /PURGE deletes files in the destination.' } }
        '^rsync$' { if ($restLow | Where-Object { $_ -like '--delete*' }) { Ask 'rsync --delete removes files in the destination.' } }
        '^(format|format-volume|diskpart|fdisk|parted|mkfs.*|clear-disk|initialize-disk|remove-partition|bcdedit|shutdown|reboot|halt|poweroff|restart-computer|stop-computer)$' { Deny ('"' + $verb + '" changes disks or shuts the machine down. Not allowed from Claude.') }
        '^dd$' { if ($restText -match '(?i)of=/dev/') { Deny 'dd to a device overwrites a disk.' } }
        '^vssadmin$' { if ($restLow -contains 'delete') { Deny 'Deleting shadow copies removes backups.' } }
        '^cipher$' { if ($restLow | Where-Object { $_ -like '/w*' }) { Deny 'cipher /w wipes free disk space.' } }
        '^(reg)$' { if ($restLow -contains 'delete' -or $restLow -contains 'add' -or $restLow -contains 'import') { Ask 'This changes the Windows registry.' } }
        '^(set-itemproperty|new-itemproperty|remove-itemproperty|sp|rp)$' { if ($restText -match '(?i)\bHK(LM|CU|CR|U|CC)[:\\]') { Ask 'This changes the Windows registry.' } }
        '^set-executionpolicy$' { Ask 'This changes the PowerShell execution policy.' }
        '^(chmod|chown)$' { if ($restLow -contains '-r' -or $restLow -contains '--recursive' -or $restText -match '\b777\b') { Ask 'Recursive or world writable permission change.' } }
        '^(icacls|takeown|cacls)$' { Ask 'This changes file ownership or access control lists.' }
        '^(taskkill|stop-process|kill|spps|pkill|killall)$' {
            if ($restLow -contains '/im' -or $restLow -contains '-name' -or $restLow -contains '-processname' -or $verb -eq 'pkill' -or $verb -eq 'killall') { Ask 'Killing processes by name can stop unrelated programs, including editors and Claude itself. Kill by process id instead.' }
        }
        '^(stop-service|remove-service|sc)$' { if ($verb -ne 'sc' -or ($restLow -contains 'stop' -or $restLow -contains 'delete' -or $restLow -contains 'config')) { Ask 'This stops or changes a Windows service.' } }
        '^(iex|invoke-expression)$' { Ask 'Invoke-Expression runs a string as code, which this hook cannot check.' }
        '^(printenv)$' { if ($rest.Count -eq 0) { Deny 'Printing all environment variables can expose tokens and keys. Print a specific, non secret variable instead.' } }
        '^env$' { if ($rest.Count -eq 0) { Deny 'Printing all environment variables can expose tokens and keys. Print a specific, non secret variable instead.' } }
        '^set$' { if ($rest.Count -eq 0) { Deny 'Printing all environment variables can expose tokens and keys.' } }
        '^(get-childitem|gci|ls|dir)$' { if ($restText -match '(?i)(^|\s)env:') { Deny 'Listing the Env: drive can expose tokens and keys. Read a specific, non secret variable instead.' } }
        '^dotnet$' {
            if ($restLow.Count -ge 1 -and $restLow[0] -eq 'ef') {
                $efText = ($restLow -join ' ')
                if ($efText -match '\bdatabase\s+drop\b') { Deny 'dotnet ef database drop deletes the database. Ask the user to run it.' }
                elseif ($efText -match '\bdatabase\s+update\b') { Ask 'dotnet ef database update changes the database in the configured connection string. Only run it against a local development database.' }
                if ($efText -match '\bmigrations\s+remove\b') { Ask 'dotnet ef migrations remove deletes the last migration; if it was already applied anywhere this breaks that database.' }
            }
            if ($restLow.Count -ge 1 -and $restLow[0] -eq 'user-secrets') {
                if ($restLow -contains 'list') { Deny 'dotnet user-secrets list prints secret values into the conversation. Ask the user which keys exist instead.' }
                elseif ($restLow -contains 'set' -or $restLow -contains 'remove' -or $restLow -contains 'clear') { Ask 'This changes user secrets, and a value typed here ends up in the transcript. Prefer that the user runs it.' }
            }
            if ($restLow.Count -ge 2 -and $restLow[0] -eq 'nuget' -and $restLow[1] -eq 'push') { Ask 'dotnet nuget push publishes a package.' }
            if ($restLow.Count -ge 2 -and $restLow[0] -eq 'tool' -and $restLow[1] -eq 'install') { Ask 'dotnet tool install adds a new tool (supply chain). Confirm it is wanted.' }
            if ($restLow.Count -ge 1 -and $restLow[0] -eq 'add' -and $restLow -contains 'package') { Ask 'Adding a NuGet package needs the user''s approval (supply chain).' }
            if ($restLow.Count -ge 2 -and $restLow[0] -eq 'workload' -and $restLow[1] -eq 'install') { Ask 'dotnet workload install changes the SDK installation.' }
            if ($restLow.Count -ge 2 -and $restLow[0] -eq 'dev-certs' -and ($restLow -contains '--clean' -or $restLow -contains '--trust')) { Ask 'This changes the trusted development certificates.' }
        }
        '^(npm|pnpm|yarn|bun)$' {
            $sub = ''
            if ($restLow.Count -gt 0) { $sub = $restLow[0] }
            $pkgs = @()
            if ($restLow.Count -gt 1) { $pkgs = @($rest[1..($rest.Count - 1)] | Where-Object { -not $_.StartsWith('-') }) }
            if ($sub -in @('install', 'i', 'add', 'isntall', 'in') -and $pkgs.Count -gt 0) { Ask ('Adding packages needs the user''s approval (supply chain): ' + ($pkgs -join ', ')) }
            if ($sub -in @('install', 'i', 'add') -and ($restLow -contains '-g' -or $restLow -contains '--global')) { Ask 'Installing a global package changes the machine.' }
            if ($sub -in @('publish', 'deprecate', 'owner', 'access', 'token', 'dist-tag')) { Ask ('"' + $verb + ' ' + $sub + '" changes the package registry.') }
            if ($sub -eq 'unpublish') { Deny 'Unpublishing a package breaks everyone who depends on it.' }
            if ($sub -eq 'audit' -and $restLow -contains 'fix' -and $restLow -contains '--force') { Ask 'npm audit fix --force can install breaking major versions.' }
            if ($sub -eq 'config' -and $restLow -contains 'set') { Ask 'This changes npm configuration.' }
            if ($sub -eq 'dlx' -or ($verb -eq 'bun' -and $sub -eq 'x')) { Test-Npx ($rest[1..($rest.Count - 1)]) }
            if ($sub -eq 'exec' -and $verb -eq 'npm') { Test-Npx ($rest[1..($rest.Count - 1)]) }
        }
        '^(npx|bunx|pnpx)$' { Test-Npx $rest }
        '^(pip|pip3|uv|poetry|pipx|composer|conda|mamba|gem|cargo|go)$' {
            $t = ($restLow -join ' ')
            if ($t -match '^(install|add|require|global require)\b' -and $t -notmatch '(^|\s)(-r|--requirement|-e|--editable)\s' -and $t -notmatch '^install\s*$' -and $t -notmatch '^install\s+(-e\s+)?\.(\s|$)' -and $t -notmatch '^install\s+(--no-dev|--frozen|--locked|--sync)') { Ask ('Adding packages needs the user''s approval (supply chain): ' + $verb + ' ' + $t) }
            if ($t -match '^pip\s+install\b' -and $t -notmatch '(-r|--requirement|-e)\s') { Ask ('Adding packages needs the user''s approval (supply chain): ' + $verb + ' ' + $t) }
            if ($t -match '^(publish|upload)\b') { Ask 'This publishes a package.' }
            if ($verb -eq 'pipx' -and $t -match '^run\b') { Ask 'pipx run downloads and runs a package.' }
        }
        '^(twine)$' { if ($restLow -contains 'upload') { Ask 'twine upload publishes a package.' } }
        '^(uvx)$' {
            $first = @($rest | Where-Object { -not $_.StartsWith('-') } | Select-Object -First 1)
            $name = ''
            if ($first.Count -gt 0) { $name = ($first[0] -replace '[@=<>].*$', '').ToLowerInvariant() }
            if (-not ($uvxAllow -contains $name)) { Ask ('uvx downloads and runs the package "' + $name + '". Confirm the name or add it to guard.uvxAllow in .claude/team.json.') }
        }
        '^(winget|choco|scoop|apt|apt-get|brew|dnf|yum|install-module|install-package|install-script|install-psresource|update-module)$' {
            if ($verb -like 'install-*' -or $verb -eq 'update-module' -or $restLow -contains 'install' -or $restLow -contains 'upgrade' -or $restLow -contains 'uninstall' -or $restLow -contains 'remove') { Ask 'This installs or removes software on the machine.' }
        }
        '^az$' {
            $t = ($restLow -join ' ')
            if ($t -match '\bkeyvault\s+secret\s+(show|download)\b' -or $t -match '\bstorage\s+account\s+keys\s+list\b' -or $t -match '\b(list-keys|list-connection-strings|list-publishing-credentials|credential\s+list)\b' -or $t -match '\baccount\s+get-access-token\b') { Deny 'This prints secrets or keys into the conversation.' }
            elseif ($t -match '\b(group|keyvault|sql\s+server|sql\s+db|storage\s+account|cosmosdb|webapp|functionapp|aks|vm|network\s+vnet)\s+delete\b' -or $t -match '\bkeyvault\s+purge\b' -or $t -match '\b(group|keyvault)\b.*\bpurge\b') { Deny 'Deleting Azure resources is not allowed from Claude. Ask the user to do it.' }
            elseif ($t -match '\b(create|update|delete|set|remove|deploy|start|stop|restart|scale|assign|add|import|swap|reset|regenerate|renew|upload|sync|purge|apply|invoke|run-command)\b' -and $t -notmatch '\bwhat-if\b|\bvalidate\b') { Ask 'This changes Azure resources.' }
        }
        '^azd$' {
            $t = ($restLow -join ' ')
            if ($t -match '^down\b' -and ($t -match '--purge' -or $t -match '--force')) { Deny 'azd down --purge deletes all Azure resources of the environment permanently.' }
            elseif ($t -match '^(up|deploy|provision|down|env\s+set|hooks\s+run|pipeline\s+config)\b') { Ask ('azd ' + $t + ' changes Azure resources or their configuration.') }
        }
        '^(terraform|tofu)$' {
            $t = ($restLow -join ' ')
            if ($t -match '^destroy\b' -or $t -match '^apply\b.*-destroy') { Deny 'terraform destroy deletes infrastructure.' }
            elseif ($t -match '^(apply|import|taint|untaint|force-unlock|state\s+(rm|mv|push)|workspace\s+delete)\b') { Ask ('terraform ' + $t + ' changes real infrastructure or its state.') }
        }
        '^(kubectl|oc)$' { if ($restLow.Count -gt 0 -and $restLow[0] -in @('delete', 'apply', 'create', 'replace', 'patch', 'edit', 'scale', 'rollout', 'drain', 'cordon', 'taint', 'set', 'label', 'annotate', 'exec')) { Ask ('kubectl ' + $restLow[0] + ' changes a cluster.') } }
        '^helm$' { if ($restLow.Count -gt 0 -and $restLow[0] -in @('install', 'upgrade', 'uninstall', 'delete', 'rollback')) { Ask ('helm ' + $restLow[0] + ' changes a cluster.') } }
        '^(docker|podman)$' {
            $t = ($restLow -join ' ')
            if ($t -match '^(system|volume|image|container|network|builder)\s+prune\b' -or $t -match '^volume\s+rm\b') { Ask 'This deletes Docker data, possibly including database volumes.' }
            if ($t -match '^compose\b.*\bdown\b.*(-v\b|--volumes)') { Ask 'docker compose down -v deletes the volumes, including local databases.' }
            if ($t -match '^(push|login)\b' -or $t -match '^(image|manifest)\s+push\b' -or $t -match '^buildx\s+build\b.*--push') { Ask 'This pushes images or credentials to a registry.' }
            if ($t -match '--privileged' -or $t -match '(-v|--volume)\s+/:/' -or $t -match '(-v|--volume)\s+[a-z]:\\?:') { Ask 'This gives a container full access to the host.' }
            foreach ($db in $dbClients) { if ($restLow -contains $db) { Test-DbText $seg } }
        }
        '^gh$' {
            $t = ($restLow -join ' ')
            if ($t -match '^repo\s+delete\b') { Deny 'Deleting a repository is not allowed from Claude.' }
            elseif ($t -match '^auth\s+token\b' -or $t -match '--show-token') { Deny 'This prints a GitHub token into the conversation.' }
            elseif ($t -match '^(pr\s+(merge|close|ready|review)|release\s+(create|delete|edit|upload)|secret\s+(set|delete|remove)|variable\s+(set|delete)|workflow\s+(run|enable|disable)|repo\s+(edit|archive|rename|create|fork)|issue\s+(delete|transfer|close|lock)|run\s+(cancel|rerun|delete)|label\s+(create|delete|edit)|ruleset|cache\s+delete)\b') { Ask ('gh ' + $t + ' changes GitHub.') }
            elseif ($t -match '^api\b' -and ($t -match '(-x|--method)\s*(post|put|patch|delete)' -or $t -match '\s(-f|-F|--field|--raw-field|--input)\s')) { Ask 'gh api call that changes GitHub.' }
        }
        '^(wp)$' {
            $t = ($restLow -join ' ')
            if ($t -match '^(db\s+(drop|reset|clean)|site\s+(empty|delete))\b') { Deny ('wp ' + $t + ' wipes WordPress data.') }
            elseif ($t -match '^db\s+(query|import)\b') { Test-DbText $seg; Ask ('wp ' + $t + ' changes the database directly.') }
            elseif ($t -match '^search-replace\b' -and $t -notmatch '--dry-run') { Ask 'wp search-replace rewrites the database. Run with --dry-run first.' }
            elseif ($t -match '^(plugin|theme|core|language)\s+(install|delete|update|uninstall|activate|deactivate)\b' -or $t -match '^(user|post|term|comment|option)\s+(delete|update|create)\b') { Ask ('wp ' + $t + ' changes the WordPress site.') }
        }
        default { }
    }

    if ($dbClients -contains $verb) {
        Test-DbText $seg
        if ($verb -eq 'sqlpackage' -and $restText -match '(?i)/a(ction)?:publish') { Ask 'sqlpackage publish deploys a schema to a database.' }
    }

    # Secrets: reading or copying secret files, echoing secret variables.
    if ($seg -match $secretPathRe) {
        $redirTargets = @([regex]::Matches($seg, '(?<![-=0-9&])>{1,2}\s*["'']?([^\s"''|;&<>]+)') | ForEach-Object { $_.Groups[1].Value })
        $redirSecret = @($redirTargets | Where-Object { (' ' + $_ + ' ') -match $secretPathRe })
        $secretToks = @($rest | Where-Object { (' ' + $_ + ' ') -match $secretPathRe -and -not ($redirTargets -contains $_) })
        $positional = @(Get-Positional $rest | Where-Object { -not ($redirTargets -contains $_) -and $_ -notmatch '^>' })
        if ($copiers -contains $verb) {
            $sources = @()
            if ($positional.Count -ge 2) { $sources = $positional[0..($positional.Count - 2)] }
            if ($sources | Where-Object { (' ' + $_ + ' ') -match $secretPathRe }) { Deny 'This would copy a secret file (.env, key, certificate, secrets.json or credentials) somewhere else.' }
        } elseif ($verb -eq 'git') {
            if ($secretToks.Count -gt 0 -and $restLow.Count -gt 0 -and $restLow[0] -in @('add', 'show', 'diff', 'log', 'blame', 'cat-file')) { Deny 'This would read or commit a secret file (.env, key, certificate, secrets.json or credentials). Secrets stay out of git and out of the conversation.' }
        } elseif ($readers -contains $verb -and $secretToks.Count -gt 0) {
            Deny 'This would read a secret file (.env, key, certificate, secrets.json or credentials) into the conversation. Ask the user for the specific non secret value you need, or use .env.example.'
        } elseif ($redirSecret.Count -gt 0) {
            Ask ('This writes into a secret file: ' + ($redirSecret -join ', '))
        } elseif ($secretToks.Count -gt 0 -and -not ($harmless -contains $verb)) {
            Ask ('This command touches a secret file (' + ($secretToks -join ', ') + ').')
        }
    }
    if ($seg -match '(?i)\[(system\.)?environment\]::getenvironmentvariables\(\s*\)') { Deny 'Dumping all environment variables can expose tokens and keys.' }
    if ($verb -in @('echo', 'write-host', 'write-output', 'printf', 'print', 'write', 'say') -and $seg -match '(?i)(\$env:|\$\{?|%)[A-Za-z_]*(token|secret|password|passwd|apikey|api_key|access_key|private_key|connectionstring|connection_string|conn_str|client_secret|sas_?key)\w*') {
        Deny 'Printing a secret variable exposes it in the conversation and logs.'
    }

    # Changes to the team setup itself through the shell.
    if ($seg -match '(?i)\.claude[\\/](settings(\.local)?\.json|team\.json|hooks[\\/]|agents[\\/]|skills[\\/]|rules[\\/])') {
        if ($writers -contains $verb -or $seg -match '(?<![-=0-9])>' -or ($verb -eq 'sed' -and $restLow -contains '-i') -or ($verb -eq 'git' -and $restLow.Count -gt 0 -and $restLow[0] -in @('checkout', 'restore', 'rm', 'mv', 'reset'))) {
            Ask 'This changes the dev team setup (settings, hooks, agents, skills or rules) through the shell.'
        }
    }

    # Read only roles may inspect, build and test, but not change files, git state or remote systems.
    if ($agent -and ($readOnlyAgents -contains $agent)) {
        $mut = $false
        if ($writers -contains $verb) { $mut = $true }
        if ($seg -match '(?<![-=0-9&])>{1,2}(?!\s*(\$null|/dev/null|nul\b|&))') { $mut = $true }
        if ($verb -eq 'sed' -and ($restLow | Where-Object { $_ -like '-i*' })) { $mut = $true }
        if ($verb -eq 'git' -and $restLow.Count -gt 0) {
            $g = $restLow[0]
            if ($g -in @('add', 'commit', 'push', 'pull', 'reset', 'checkout', 'switch', 'restore', 'merge', 'rebase', 'cherry-pick', 'revert', 'clean', 'rm', 'mv', 'apply', 'am', 'tag', 'update-ref', 'worktree', 'submodule', 'init', 'clone', 'notes', 'replace')) { $mut = $true }
            if ($g -eq 'stash' -and -not ($restLow -contains 'list' -or $restLow -contains 'show')) { $mut = $true }
            if ($g -eq 'branch' -and (@($rest | Select-Object -Skip 1 | Where-Object { -not $_.StartsWith('-') }).Count -gt 0 -or ($restLow | Where-Object { $_ -cmatch '^-[dDmMcC]$' -or $_ -in @('--delete', '--move', '--copy') }))) { $mut = $true }
            if ($g -eq 'config' -and -not ($restLow | Where-Object { $_ -in @('--get', '--get-all', '--list', '-l', '--get-regexp') })) { $mut = $true }
        }
        if ($verb -eq 'dotnet' -and $restLow.Count -gt 0) {
            $d = $restLow[0]
            if ($d -in @('add', 'remove', 'new', 'tool', 'workload', 'nuget', 'pack', 'publish', 'user-secrets', 'sln', 'dev-certs')) { $mut = $true }
            if ($d -eq 'ef' -and ($restLow -contains 'migrations' -or $restLow -contains 'database') -and -not ($restLow -contains 'list' -or $restLow -contains 'script' -or $restLow -contains 'has-pending-model-changes')) { $mut = $true }
            if ($d -eq 'format' -and -not ($restLow -contains '--verify-no-changes')) { $mut = $true }
        }
        if ($verb -in @('npm', 'pnpm', 'yarn', 'bun') -and $restLow.Count -gt 0) {
            $n = $restLow[0]
            if ($n -in @('install', 'i', 'add', 'uninstall', 'remove', 'rm', 'update', 'up', 'upgrade', 'publish', 'version', 'link', 'unlink', 'dedupe', 'prune', 'init', 'create', 'pkg', 'set-script')) { $mut = $true }
            if ($n -in @('run', 'run-script') -and $restLow.Count -gt 1 -and $restLow[1] -notmatch '^(build|test|lint|typecheck|type-check|check|format:check|audit|e2e)(:|$)') { $mut = $true }
            if ($n -eq 'audit' -and $restLow -contains 'fix') { $mut = $true }
        }
        if ($verb -eq 'ng' -and $restLow.Count -gt 0 -and $restLow[0] -in @('generate', 'g', 'add', 'update', 'new', 'deploy', 'config', 'extract-i18n')) { $mut = $true }
        if ($verb -in @('pip', 'pip3', 'uv', 'poetry', 'composer') -and $restLow.Count -gt 0 -and $restLow[0] -in @('install', 'add', 'remove', 'uninstall', 'require', 'update', 'lock', 'sync')) { $mut = $true }
        if ($verb -in @('curl', 'iwr', 'irm', 'invoke-webrequest', 'invoke-restmethod', 'wget') -and $restText -match '(?i)(-X\s*(POST|PUT|PATCH|DELETE)|-Method\s+(Post|Put|Patch|Delete)|\s(-d|--data\S*|-F|--form|-T|--upload-file|-Body|-InFile|-OutFile|-o|-O)\s)') { $mut = $true }
        if ($verb -eq 'gh' -and $restLow.Count -gt 0 -and ($restLow -join ' ') -match '^(pr\s+(create|merge|close|comment|review|edit|ready|checkout)|issue\s+(create|comment|close|edit|reopen|delete)|release|repo\s+(create|edit|delete|fork|clone)|secret|variable|workflow\s+run|label|api\b.*(-x|--method)\s*(post|put|patch|delete))') { $mut = $true }
        if ($mut) {
            Deny ('The ' + $agent + ' agent is a read only role: it may read, search, build and run tests, but not change files, git state, packages or remote systems. Report the change as a finding instead.')
        }
    }
}

function Test-Npx($rest) {
    $pkg = $null
    $k = 0
    $noInstall = $false
    while ($k -lt $rest.Count) {
        $a = $rest[$k]
        if ($a -eq '--no-install' -or $a -eq '--no') { $noInstall = $true; $k++; continue }
        if ($a -in @('-p', '--package')) { if ($k + 1 -lt $rest.Count) { $pkg = $rest[$k + 1] }; $k += 2; continue }
        if ($a -like '--package=*') { $pkg = $a.Substring(10); $k++; continue }
        if ($a.StartsWith('-')) { $k++; continue }
        if (-not $pkg) { $pkg = $a }
        break
    }
    if ($noInstall -or -not $pkg) { return }
    $name = $pkg
    if ($name.StartsWith('@')) {
        $at = $name.IndexOf('@', 1)
        if ($at -gt 0) { $name = $name.Substring(0, $at) }
    } elseif ($name.Contains('@')) {
        $name = $name.Substring(0, $name.IndexOf('@'))
    }
    if ($npxAllow -contains $name.ToLowerInvariant()) { return }
    Ask ('This downloads and runs the package "' + $pkg + '" from the registry. Confirm the exact name (typosquatting) or add it to guard.npxAllow in .claude/team.json.')
}

# ------------------------------------------------------------------ whole command checks

$flat = ($cmd -replace '\s+', ' ')
if ($flat -match '(?i)\b(curl|wget|iwr|irm|invoke-webrequest|invoke-restmethod|fetch)\b[^|]*\|\s*(sudo\s+)?(sh|bash|zsh|dash|pwsh|powershell|iex|invoke-expression|python3?|node|perl|ruby|cmd)\b') {
    Deny 'Piping a download straight into a shell runs unreviewed code. Download it, let the user review it, then run it.'
}
if ($flat -match '(?i)(\$\(|`)\s*(curl|wget|iwr|irm)\b' -and $flat -match '(?i)\b(sh|bash|iex|invoke-expression|eval)\b') {
    Deny 'Running downloaded code through command substitution is not allowed.'
}
if ($flat -match '(?i)\[scriptblock\]::create|\.invokescript\(|frombase64string\(.*\)\s*\|\s*(iex|invoke-expression)') {
    Deny 'Building code from strings at run time cannot be checked.'
}
if ($flat -match ':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:') { Deny 'Fork bomb.' }
if ($flat -match '(?i)>\s*/dev/(sd[a-z]|nvme|disk\d)') { Deny 'Writing directly to a disk device.' }

foreach ($rule in $extraRules) {
    if ($rule -and $rule.pattern -and $flat -match [string]$rule.pattern) {
        $lvl = 'ask'
        if ([string]$rule.decision -eq 'deny') { $lvl = 'deny' }
        Add-Finding $lvl ([string]$rule.reason)
    }
}

# ------------------------------------------------------------------ per segment checks

$segments = New-Object System.Collections.Generic.List[string]
foreach ($s in (Split-Segments $cmd)) { $segments.Add($s) }
foreach ($m in [regex]::Matches($cmd, '\$\(([^()]*(?:\([^()]*\)[^()]*)*)\)')) {
    foreach ($s in (Split-Segments $m.Groups[1].Value)) { $segments.Add($s) }
}
foreach ($s in $segments) { Test-Segment $s 0 }

# ------------------------------------------------------------------ decision

if ($script:Findings.Count -eq 0) { exit 0 }
$denies = @($script:Findings | Where-Object { $_.Level -eq 'deny' } | ForEach-Object { $_.Reason })
$asks = @($script:Findings | Where-Object { $_.Level -eq 'ask' } | ForEach-Object { $_.Reason })

if ($denies.Count -gt 0) {
    Write-PreToolDecision 'deny' ('Blocked by the dev team guard: ' + ($denies -join ' ') + ' If it is really intended, ask the user to run it themselves.')
    exit 0
}
if ($isSub) {
    Write-PreToolDecision 'deny' ('Needs the user''s approval, which a subagent cannot get: ' + ($asks -join ' ') + ' Do not try another way around it. Finish what you can and report this step to the lead, who will ask the user.')
    exit 0
}
Write-PreToolDecision 'ask' ('Dev team guard: ' + ($asks -join ' '))
exit 0

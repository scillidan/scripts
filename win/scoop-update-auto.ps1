# Called by scoop.cmd (this folder) for `scoop update ...`.
# When scoop refuses to update because the app is still running, list the
# offending processes and, on confirmation, close them and retry.
# If closing would kill the shell that launched us (e.g. `scoop update pwsh`
# from pwsh), the kill+update is handed to a detached window instead, so the
# update survives our console closing.
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)

if ($Rest -and $Rest[0] -eq 'update') { $Rest = @($Rest | Select-Object -Skip 1) }

$ScoopRoot = $env:SCOOP
if (-not $ScoopRoot) { $ScoopRoot = Join-Path $env:USERPROFILE 'Scoop' }
$ScoopPs1 = Join-Path $ScoopRoot 'apps\scoop\current\bin\scoop.ps1'

function scoop-exec([string[]]$ScoopArgs) {
    # Run scoop.ps1 via Windows PowerShell, not the shims\scoop.cmd shim: the
    # shim prefers pwsh, so 'scoop update pwsh' always sees its own pwsh
    # (running from the app dir) as a blocking process.
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScoopPs1 @ScoopArgs
}

function Get-AncestorIds {
    $id = $PID
    while ($true) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue
        if (-not $p) { break }
        $id = $p.ParentProcessId
        if (-not $id) { break }
        $id
    }
}
$ancestors = @(Get-AncestorIds)

for ($i = 0; $i -lt 5; $i++) {
    $out = scoop-exec update @Rest *>&1 | Out-String
    Write-Host $out
    # scoop exits 0 even when it skips an update for running processes
    # (scoop-update.ps1 "Running process detected, skip updating."); treat that as failure
    $skipped = $out -match 'Running process detected, skip updating\.'
    if ($global:LASTEXITCODE -eq 0 -and -not $skipped) {
        # `scoop update <app>` can also end right after scoop's own self-update,
        # with the app half silently dropped (no per-app output at all); retry then
        $appsRequested = @($Rest | Where-Object { $_ -notlike '-*' })
        if ($appsRequested.Count -gt 0 -and $out -notmatch "Updating '" -and $out -notmatch '\(latest version\)') {
            $global:LASTEXITCODE = 1
        } else {
            exit 0
        }
    }
    if ($skipped) { $global:LASTEXITCODE = 1 }

    $locked = [regex]::Matches($out, 'instances of "([^"]+)" are still running') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    if (-not $locked) {
        # the skip message doesn't name the app; recover from "app: old -> new" lines
        $locked = [regex]::Matches($out, '(?m)^([-\w.]+): .+ -> .+$') |
            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    }
    if (-not $locked) { exit $global:LASTEXITCODE }

    foreach ($app in $locked) {
        $dir = scoop-exec prefix $app 2>$null | Select-Object -First 1
        if (-not $dir) { continue }
        # prefix returns the 'current' junction, but processes report the real versioned dir
        $target = (Get-Item $dir -ErrorAction SilentlyContinue).Target
        if ($target) { $dir = $target }
        $procs = @(Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($dir) })
        if ($procs.Count -eq 0) { continue }

        Write-Host ''
        Write-Host "[$app] processes using the install dir:" -ForegroundColor Yellow
        $procs | Format-Table Id, ProcessName, Path -AutoSize | Out-String | Write-Host
        $ans = Read-Host "Close them and continue updating $app ? [y/N]"
        if ($ans -notin 'y', 'Y') { Write-Host "skipped: $app" -ForegroundColor DarkYellow; exit $global:LASTEXITCODE }

        if (@($procs.Id | Where-Object { $ancestors -contains $_ }).Count -gt 0) {
            # target includes our own parent shell: detached window takes over
            $script = "Start-Sleep -Seconds 2; " +
                      "Get-Process | Where-Object { `$_.Path -and `$_.Path.StartsWith('$dir') } | Stop-Process -Force; " +
                      "powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$ScoopPs1' update $app"
            Start-Process powershell.exe -ArgumentList '-NoExit', '-NoProfile', '-Command', $script
            Write-Host "update of $app continues in a new window; this window may close." -ForegroundColor Cyan
            exit 0
        }

        $procs | Stop-Process -Force
        Start-Sleep -Milliseconds 500
    }
}
exit $global:LASTEXITCODE

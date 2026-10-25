# Revert scoop-shortcuts-patch.ps1: restore shortcuts.ps1 to pristine state.
# Locates the `if ($env:SCOOP_MENU_DIR) { ... }` block (plus its comment line) and removes it.
$ScoopRoot = $env:SCOOP
if (-not $ScoopRoot) { $ScoopRoot = Join-Path $env:USERPROFILE 'Scoop' }
$file = Join-Path $ScoopRoot 'apps\scoop\current\lib\shortcuts.ps1'
if (-not (Test-Path -LiteralPath $file)) { Write-Warning "not found: $file"; exit 1 }

$lines = [IO.File]::ReadAllLines($file)
$ifIdx = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'if \(\$env:SCOOP_MENU_DIR\)' })
if ($ifIdx -lt 0) { Write-Host 'not patched, nothing to do'; exit 0 }

$start = $ifIdx
while ($start -gt 0 -and $lines[$start-1] -match '^\s*#') { $start-- }

$end = $ifIdx
while ($end -lt $lines.Count -and $lines[$end] -ne '    }') { $end++ }
if ($end -ge $lines.Count) { Write-Warning 'patch block looks corrupted; manual check needed'; exit 1 }

$out = @()
if ($start -gt 0) { $out += $lines[0..($start-1)] }
if ($end + 1 -lt $lines.Count) { $out += $lines[($end+1)..($lines.Count-1)] }
[IO.File]::WriteAllLines($file, $out)
Write-Host "unpatched: $file"

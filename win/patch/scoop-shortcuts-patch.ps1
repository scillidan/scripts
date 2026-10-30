# Idempotently patch scoop's shortcuts.ps1 so $env:SCOOP_MENU_DIR overrides the
# hardcoded 'Start Menu\Programs\Scoop Apps' shortcut folder.
# Re-run after `scoop update` reverts it, or just run scoop-shortcut.cmd
# in this folder.
$ScoopRoot = $env:SCOOP
if (-not $ScoopRoot) { $ScoopRoot = Join-Path $env:USERPROFILE 'Scoop' }
$file = Join-Path $ScoopRoot 'apps\scoop\current\lib\shortcuts.ps1'
if (-not (Test-Path -LiteralPath $file)) { Write-Warning "not found: $file"; exit 1 }

$lines = [IO.File]::ReadAllLines($file)
if ($lines -match 'SCOOP_MENU_DIR') { Write-Host 'already patched'; exit 0 }

$idx = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match "return Convert-Path \(ensure \(\[System\.IO\.Path\]::Combine" })
if ($idx -lt 0) { Write-Warning 'scoop shortcuts.ps1 looks different than expected; patch NOT applied'; exit 1 }

$block = @(
    '    # shortcut: SCOOP_MENU_DIR override; managed by scoop-shortcuts-patch.ps1 (scoop update reverts it)',
    '    if ($env:SCOOP_MENU_DIR) {',
    '        return Convert-Path (ensure $env:SCOOP_MENU_DIR)',
    '    }'
)
$out = @()
if ($idx -gt 0) { $out += $lines[0..($idx-1)] }
$out += $block
$out += $lines[$idx..($lines.Count-1)]
[IO.File]::WriteAllLines($file, $out)
Write-Host "patched: $file"

# Usage: scoop-home-browser.ps1 <app>
# Opens the app homepage in %BROWSER% instead of the system default browser.
# Called from scoop.cmd: scoop's own `home` ends in Start-Process <url>, which
# goes through the shell and always picks the default browser (Edge here).
# shortcut: %BROWSER% must be a single executable path, not "exe --args".
param($app)

$root = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\Scoop" }
$lib = "$root\apps\scoop\current\lib"

# Same libs bin\scoop.ps1 plus libexec\scoop-home.ps1 load, so Get-Manifest
# resolves buckets, installed versions and aliases exactly like scoop does.
. "$lib\core.ps1"
. "$lib\buckets.ps1"
. "$lib\versions.ps1"
. "$lib\manifest.ps1"
. "$lib\download.ps1"

$null, $manifest, $null, $null = Get-Manifest $app
if (!$manifest) { abort "Could not find manifest for '$app'." }
if (!$manifest.homepage) { abort "Could not find homepage in manifest for '$app'." }

Start-Process $env:BROWSER $manifest.homepage

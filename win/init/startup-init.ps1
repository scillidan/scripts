$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Ollama.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Caffeine.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\DeskPins.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\dnGREP.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\EarTrumpet.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Espanso.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Keyboard Locker.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Keypirinha.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\RBTray.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\resizer2.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Sizer.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\virgo.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Zeal.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\AltBacktick.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\CenterTaskbar.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Ditto.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Everything.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\GoldenDict.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Magpie.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\RectangleWin.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Reduce Memory.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\T-Clock.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Tailscale.lnk"
    # "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Scoop Apps\Win10_BrightnessSlider.lnk"
)

$binPath = @(
    # @{ Path = "$env:LOCALAPPDATA\Microsoft\WindowsApps\Snipaste.exe"; Arguments = ""; WorkingDir = "" }
    # @{ Path = "$env:ProgramFiles\Clash Verge\clash-verge.exe"; Arguments = ""; WorkingDir = "" }
)

foreach ($app in $lnkPath) {
    Copy-Item -Path $app -Destination $startupDir -Force
}

foreach ($exe in $binPath) {
    $exePath = $exe.Path
    $exeArgs = $exe.Arguments
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
    $shortcutPath = Join-Path -Path $startupDir -ChildPath "$exeName.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath

    if ($exeArgs -ne "") {
        $shortcut.Arguments = $exeArgs
    }

    if ($exe.WorkingDir -ne "") {
        $shortcut.WorkingDirectory = $exe.WorkingDir
    }

    $shortcut.Save()
}

Read-Host -Prompt "Press Enter to exit"
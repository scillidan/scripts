#NoEnv
SetWorkingDir %A_ScriptDir%

Menu, Tray, DeleteAll
RegRead, isStartup, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, UserAHK
Menu, Tray, Add, Start with Windows, ToggleStartup
if (isStartup != "")
    Menu, Tray, Check, Start with Windows
Menu, Tray, Add, Edit Config, EditConfig
Menu, Tray, Add
Menu, Tray, Add, Reload, ReloadApp
Menu, Tray, Add, Exit, ExitScript

ToggleStartup:
    RegRead, startupValue, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, UserAHK
    if (startupValue = "") {
        RegWrite, REG_SZ, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, UserAHK, "%A_ScriptFullPath%"
        Menu, Tray, Check, Start with Windows
    } else {
        RegDelete, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, UserAHK
        Menu, Tray, Uncheck, Start with Windows
    }
return

EditConfig:
    Run, edit "%A_ScriptFullPath%"
return

ReloadApp:
    Reload
return

ExitScript:
    ExitApp
return

^!+c::
    Send, ^c
    Sleep, 100
    Run, wezterm-gui start bash _pylanguagetool.sh --api-url "http://localhost:8040/v2/"
    return
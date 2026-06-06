@echo off

setlocal

rem Custom user environment variables here
set "MPVC_VIDEO=%USERHOME%\Usr\Data\mpvc_video"
set "MPVC_MUSIC=%USERHOME%\Usr\Data\mpvc_music"
set "MPVC_MANGA=%USERHOME%\Usr\Data\mpvc_manga"

set "config=%1"

if "%config%"=="video" (
    set "CONFIG_DIR=%MPVC_VIDEO%"
    goto :mpvc
) else if "%config%"=="music" (
    set "CONFIG_DIR=%MPVC_MUSIC%"
    goto :mpvc
) else if "%config%"=="manga" (
    set "CONFIG_DIR=%MPVC_MANGA%"
    goto :mpvc
) else (
    echo Invalid config
    goto :end
)

:mpvc
start "" mpv.exe --config-dir="%CONFIG_DIR%" --force-window --keep-open=yes %2
goto :end

:end
endlocal

exit /b
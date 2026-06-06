@echo off
rem Personal setup script

setlocal

set "PEGASUS_HOME=%SCOOP%\apps\pegasus\current"
set "RETROARCH_HOME=%SCOOP%\apps\retroarch\current"
rem Custom user environment variables here
set "PEGASUS_CONF=%USERHOME%\Usr\File\file_pegasus-frontend"
set "PEGASUS_SRC=%USERHOME%\Usr\Source\pegasus"
set "PEGASUS_DL=%USERHOME%\Usr\Download\pegasus"

rmdir /S /Q "%PEGASUS_HOME%\RetroArch"
mklink /J "%PEGASUS_HOME%\RetroArch" "%RETROARCH_HOME%"
rmdir /S /Q "%PEGASUS_HOME%\RetroArch\cheats"
rmdir /S /Q "%PEGASUS_HOME%\RetroArch\config"
rmdir /S /Q "%PEGASUS_HOME%\RetroArch\cores"
rmdir /S /Q "%PEGASUS_HOME%\RetroArch\downloads"
rmdir /S /Q "%PEGASUS_HOME%\RetroArch\system"
mklink /J "%PEGASUS_HOME%\RetroArch\cheats" "%PEGASUS_DL%\pegasus-g\RetroArch\cheats"
mklink /J "%PEGASUS_HOME%\RetroArch\config" "%PEGASUS_DL%\pegasus-g\RetroArch\config"
mklink /J "%PEGASUS_HOME%\RetroArch\cores" "%PEGASUS_DL%\pegasus-g\RetroArch\cores"
mklink /J "%PEGASUS_HOME%\RetroArch\downloads" "%PEGASUS_DL%\pegasus-g\RetroArch\downloads"
mklink /J "%PEGASUS_HOME%\RetroArch\system" "%PEGASUS_DL%\pegasus-g\RetroArch\system"

rmdir /S /Q "%PEGASUS_HOME%\config"
mkdir "%PEGASUS_HOME%\config"
mklink "%PEGASUS_HOME%\config\game_dirs.txt" "%PEGASUS_CONF%\config\game_dirs.txt"
mklink "%PEGASUS_HOME%\config\settings.txt" "%PEGASUS_CONF%\config\settings.txt"

mkdir "%PEGASUS_HOME%\config\themes"
for /d %%i in (%PEGASUS_SRC%\*) do mklink /J "%PEGASUS_HOME%\config\themes\%%~nxi" "%%i"

rmdir /S /Q "%PEGASUS_HOME%\Roms"
mklink /D "%PEGASUS_HOME%\Roms" "%PEGASUS_DL%\pegasus-g\Roms"
for %%f in ("%PEGASUS_HOME%\Roms\*") do (
    if exist "%%f\metadata.pegasus.txt" (
        del "%%f\metadata.pegasus.txt"
    )
)
for /d %%d in ("%PEGASUS_HOME%\Roms\*") do (
    if exist "%PEGASUS_CONF%\metadata\%%~nxd\metadata.pegasus.txt" (
        del "%%d\metadata.pegasus.txt"
        mklink "%%d\metadata.pegasus.txt" "%PEGASUS_CONF%\metadata\%%~nxd\metadata.pegasus.txt"
    )
)

rem mkdir "%RETROARCH_HOME%\Emulators"

endlocal

pause
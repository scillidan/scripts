@echo off
setlocal enabledelayedexpansion
rem scoop-check-depends.cmd - one-shot dependency check for a new scoop manifest
rem Usage: scoop-check-depends.cmd <exe-file | extracted-app-dir>
rem Covers: DIE framework scan, import table (VC++/Qt/wx/GTK/WebView2/Python),
rem         bundled-DLL check, WebView2 runtime registry probe.
rem Not covered (manual): ProcMon behavior check, official docs "System Requirements".

if "%~1"=="" (echo Usage: %~nx0 ^<exe ^| dir^> & exit /b 1)
set "TARGET=%~f1"
if not exist "%TARGET%" (echo Not found: %TARGET% & exit /b 1)

if defined SCOOP (set "APPS=%SCOOP%\apps") else set "APPS=%USERPROFILE%\Scoop\apps"
set "DIEC=%APPS%\detect-it-easy\current\diec.exe"
set "DEPS=dependencies.exe"
set "RND=%RANDOM%%RANDOM%"
set "MODLOG=%TEMP%\scd-mods-%RND%.log"
set "DIELOG=%TEMP%\scd-die-%RND%.log"
set "EXELOG=%TEMP%\scd-exes-%RND%.txt"
set "NETLOG=%TEMP%\scd-net-%RND%.log"
set "WV2STRLOG=%TEMP%\scd-wv2-%RND%.log"
type nul > "%MODLOG%"
type nul > "%DIELOG%"
type nul > "%NETLOG%"
type nul > "%WV2STRLOG%"

echo === [1/4] Collect exe(s) ===
if /i "%TARGET:~-4%"==".exe" (
  echo %TARGET% > "%EXELOG%"
) else (
  dir /b /s "%TARGET%\*.exe" > "%EXELOG%" 2>nul
)
for /f %%e in ('type "%EXELOG%"') do echo   %%e
if not exist "%EXELOG%" goto :summary

echo.
echo === [2/4] Detect-It-Easy scan + binary string probes ===
rem findstr on the raw binary: catches self-contained .NET (DIE sees only the native host)
rem and COM-loaded WebView2 (no WebView2Loader.dll in the import table)
for /f %%e in ('type "%EXELOG%"') do (
  findstr /m /c:"Microsoft.NETCore.App" "%%e" >>"%NETLOG%" 2>nul
  findstr /m /c:"WebView2" "%%e" >>"%WV2STRLOG%" 2>nul
)
if not exist "%DIEC%" (
  echo   diec.exe not found at %DIEC%, skipped.
) else for /f %%e in ('type "%EXELOG%"') do (
  echo   --- %%~nxe ---
  "%DIEC%" "%%e" 2>nul | findstr /v "^$"
  "%DIEC%" "%%e" 2>nul >> "%DIELOG%"
)

echo.
echo === [3/4] Import table (Dependencies) ===
for /f %%e in ('type "%EXELOG%"') do (
  echo   --- %%~nxe ---
  %DEPS% -imports "%%e" 2>nul | findstr /i /c:"Import from module" | %SystemRoot%\System32\sort.exe /unique
  %DEPS% -imports "%%e" 2>nul | findstr /i /c:"Import from module" >> "%MODLOG%"
)

echo.
echo === [4/4] Analysis ===
set "HAS_VC=0" & set "HAS_QT=0" & set "HAS_WX=0" & set "HAS_GTK=0"
set "HAS_WV2=0" & set "HAS_PY=0" & set "HAS_JAVA=0" & set "HAS_NET=0" & set "HAS_ELECTRON=0"

findstr /i /r "MSVCR.*dll MSVCP.*dll CONCRT.*dll VCRUNTIME.*dll" "%MODLOG%" >nul && set "HAS_VC=1"
findstr /i /r "Qt[56].*dll" "%MODLOG%" >nul && set "HAS_QT=1"
findstr /i /r "wx.*dll" "%MODLOG%" >nul && set "HAS_WX=1"
findstr /i /r "libgtk.* gtk-.*dll" "%MODLOG%" >nul && set "HAS_GTK=1"
findstr /i "WebView2Loader.dll" "%MODLOG%" >nul && set "HAS_WV2=1"
for %%F in ("%WV2STRLOG%") do if %%~zF gtr 0 if "%HAS_WV2%"=="0" (
  set "HAS_WV2=2"
)
findstr /i /r "python[0-9].*dll" "%MODLOG%" >nul && set "HAS_PY=1"
findstr /i "jvm.dll" "%MODLOG%" >nul && set "HAS_JAVA=1"
findstr /i ".NET" "%DIELOG%" >nul && set "HAS_NET=1"
findstr /i "Electron" "%DIELOG%" >nul && set "HAS_ELECTRON=1"
for %%F in ("%NETLOG%") do if %%~zF gtr 0 if "%HAS_NET%"=="0" set "HAS_NET=2"

if "%HAS_VC%"=="1" (
  echo [VC++ Runtime] MSVCR/MSVCP/VCRUNTIME/CONCRT imports found.
  echo     -^> "depends": "extras/vcredist2022"  ^(match the toolset version to the app^)
  echo     ^(api-ms-win-crt-* alone is in-box UCRT, no depends needed^)
)
if "%HAS_QT%"=="1" call :bundled Qt "Qt*.dll" "Qt framework DLLs"
if "%HAS_WX%"=="1" call :bundled WX "wx*.dll" "wxWidgets DLLs"
if "%HAS_GTK%"=="1" call :bundled GTK "libgtk*.dll" "GTK DLLs"
if "%HAS_PY%"=="1" (
  echo [Python] python##.dll imported.
  echo     -^> "depends": "python"  ^(if not embedded/bundled^)
)
if "%HAS_JAVA%"=="1" (
  echo [Java] jvm.dll referenced.
  echo     -^> "depends": "java/openjdk"  ^(check if a bundled JRE ships with the app^)
)
if "%HAS_NET%"=="2" (
  echo [.NET] self-contained .NET bundle ^(Microsoft.NETCore.App strings in binary^) - no depends needed.
)
if "%HAS_NET%"=="1" (
  echo [.NET] DIE detected .NET assembly.
  dir /b "%TARGET%\*.runtimeconfig.json" >nul 2>&1 ^
    && echo     .NET Core/5+: check runtimeconfig.json -^> e.g. "depends": "windowsdesktop-runtime-lts" ^
    || echo     .NET Framework ^(usually in OS^) -^> mention in "notes"
)
if "%HAS_ELECTRON%"=="1" echo [Electron] no extra runtime dep, but check architecture and large install size.

if not "%HAS_WV2%"=="0" (
  if "%HAS_WV2%"=="1" (echo [WebView2] WebView2Loader.dll found in imports.) else echo [WebView2] "WebView2" strings found in binary ^(COM dynamic load - ldd cannot see this^).
  reg query "HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv >nul 2>nul || reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv >nul 2>nul
  if !errorlevel! equ 0 (echo     Runtime installed on this machine.) else echo     Runtime NOT found -^> prompt user in "notes" or depend on a webview2 runtime package.
)

rem Directory-level hints even when import table is clean (COM/dlopen loaders hide there)
set "DIRHINT=0"
if exist "%TARGET%\WebView2Loader.dll" (echo [Dir hint] WebView2Loader.dll bundled next to exe. & set "DIRHINT=1")
dir /b "%TARGET%\jvm.dll" "%TARGET%\bin\jvm.dll" >nul 2>&1 && (echo [Dir hint] bundled JRE found - no Java depends needed. & set "DIRHINT=1")
if "%DIRHINT%"=="0" if "%HAS_VC%%HAS_QT%%HAS_WX%%HAS_GTK%%HAS_WV2%%HAS_PY%%HAS_JAVA%%HAS_NET%"=="00000000" (
  echo No obvious runtime deps detected. Remaining checks are manual:
)

:summary
echo.
echo === Manual follow-ups ===
echo   1. Read the vendor's "System Requirements" / "Prerequisites" docs.
echo   2. Search extras/main bucket for a similar app's manifest and copy its
echo      depends/suggest/notes style.
echo   3. Still unsure ^(WebView2/GPU/.NET probing^): run ProcMon once against the app.
echo   4. Run scoop-ldd.cmd ^<exe^> for the classic missing-DLL listing.
del /q "%MODLOG%" "%DIELOG%" "%EXELOG%" "%NETLOG%" "%WV2STRLOG%" >nul 2>nul
endlocal
exit /b 0

:bundled
rem %1=tag %2=file-glob %3=label
set "BUNDLE=0"
dir /b "%TARGET%\%~2" >nul 2>&1 && set "BUNDLE=1"
if "%BUNDLE%"=="1" (
  echo [%~1] imports %~3 and they are bundled in the app dir - no depends needed.
) else (
  echo [%~1] imports %~3 but they are NOT in the app dir -^> investigate before writing the manifest.
)
exit /b 0

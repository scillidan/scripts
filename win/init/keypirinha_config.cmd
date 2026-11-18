set "L=%SCOOP%\apps\keypirinha\current\portable\Profile\InstalledPackages"
set "S=%USERHOME%\Share\caches\packages.win\keypirinha"
rmdir "%L%" 2>nul
if exist "%L%\" move "%L%" "%L%.bak" >nul
mklink /J "%L%" "%S%"
@echo off

set "ORIG_CD=%CD%"
pushd "%SCOOP%\apps\scoop\current"

pwsh bin\formatjson.ps1 -App %1 -Dir %ORIG_CD%\bucket
pwsh bin\checkver.ps1 -App %1 -Dir %ORIG_CD%\bucket

popd
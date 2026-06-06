@echo off

set target=%1
set source=%2

rm "%USERPROFILE%\.local\bin\%target%"
mklink "%USERPROFILE%\.local\bin\%target%" "%CD%\%source%"
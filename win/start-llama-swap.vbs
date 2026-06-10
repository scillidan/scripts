Option Explicit

Dim WshShell
Set WshShell = CreateObject("WScript.Shell")

WshShell.CurrentDirectory = "C:\Users\User\Scoop\apps\llama-swap\current"

WshShell.Run _
  "cmd /c llama-swap.exe -config ""C:\Users\User\Share\dotfiles\.config\llama-swap\config.yaml"" -listen 127.0.0.1:8010", _
  0, _
  False

Set WshShell = Nothing
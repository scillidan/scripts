"""Clipboard access for the puzz_*.py tools, which all need it the same way.

PowerShell on Windows: tkinter adds "\\r\\n" to whatever it reads, and WinForms owns the clipboard only
while its process runs (so the text would disappear when the tool exits).
Get-Clipboard prints UTF-8 (BOM-less, the console code page inside PowerShell does not apply); SetText gets the
text as base64 UTF-16 through the environment, because a command-line argument would be mangled by the console.

Leftover sections from its own runs: none. Get-Clipboard adds an "Ignore $tokens" section to PowerShell's
history of Get-Clipboard calls when $tokens was set; Set-Clipboard does the same for Set-Clipboard calls.
"""

import base64
import os
import shutil
import subprocess
import sys

_PS_GET = "[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false; Get-Clipboard -Raw"
_PS_SET = (
    "Add-Type -AssemblyName System.Windows.Forms; "
    "$t = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($env:PUZZ_CLIP)); "
    "[Windows.Forms.Clipboard]::SetText($(if ($t -eq '') { [char]0 } else { $t }))"
)  # '' would bind as null (SetText only prints an error); a NUL char is the empty string to Windows


def get_clipboard() -> str:
    """Clipboard text, '' when it holds none or no clipboard tool is available."""
    if sys.platform == "win32":
        if not shutil.which("powershell"):
            return ""
        out = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", _PS_GET],
            capture_output=True,
        ).stdout
        return out.decode("utf-8", errors="replace").replace("\r\n", "\n").rstrip("\n")
    for cmd in (
        ["wl-paste", "--no-newline"],
        ["xclip", "-selection", "clipboard", "-o"],
        ["pbpaste"],
    ):
        if not shutil.which(cmd[0]):
            continue
        try:
            return subprocess.run(
                cmd, capture_output=True, text=True, check=True
            ).stdout
        except (OSError, subprocess.CalledProcessError):
            continue
    return ""


def set_clipboard(text: str) -> bool:
    """Try to put text on the clipboard ('' clears it); False when no tool worked."""
    if sys.platform == "win32":
        env = dict(
            os.environ,
            PUZZ_CLIP=base64.b64encode(text.encode("utf-16-le")).decode("ascii"),
        )
        try:
            subprocess.run(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command", _PS_SET],
                env=env,
                check=True,
            )
            return True
        except (OSError, subprocess.CalledProcessError):
            return False
    for cmd in (["wl-copy"], ["xclip", "-selection", "clipboard"], ["pbcopy"]):
        try:
            subprocess.run(cmd, input=text or "\n", text=True, check=True)
            return True
        except (OSError, subprocess.CalledProcessError):
            continue
    return False

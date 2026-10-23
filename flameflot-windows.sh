#!/bin/sh
# flameflot-windows.sh - capture a specific window with Flameshot:
# detect the window bounds (ctypes/user32 on Windows, xdotool on Linux/X11),
# then open `flameshot gui --region WxH+X+Y` with that area pre-selected
# (Snipaste-like window capture).
# Deps: uv (runner) + flameshot; Linux/X11 also needs xdotool (xwininfo for --frame).
# The line below is a sh/python polyglot: shell re-execs this file via uv, python
# sees it as a string literal.
''''exec uv run --script "$0" "$@" # '''

# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///

import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass


@dataclass
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def region(self) -> str:  # Flameshot --region format
        return f"{self.w}x{self.h}+{self.x}+{self.y}"


# --- Windows: ctypes + user32, no extra deps ---

_WIN = None


def _win():
    global _WIN
    if _WIN is None:
        import ctypes
        from ctypes import wintypes

        user32 = ctypes.WinDLL("user32", use_last_error=True)
        user32.GetForegroundWindow.restype = wintypes.HWND
        user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
        user32.WindowFromPoint.argtypes = [wintypes.POINT]
        user32.WindowFromPoint.restype = wintypes.HWND
        user32.GetAncestor.argtypes = [wintypes.HWND, ctypes.c_uint]
        user32.GetAncestor.restype = wintypes.HWND
        user32.GetCursorPos.argtypes = [ctypes.POINTER(wintypes.POINT)]
        dwm = ctypes.WinDLL("dwmapi")
        dwm.DwmGetWindowAttribute.argtypes = [wintypes.HWND, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD]
        dwm.DwmGetWindowAttribute.restype = wintypes.LONG
        try:
            ctypes.WinDLL("shcore").SetProcessDpiAwareness(2)  # physical pixels under DPI scaling
        except Exception:
            pass
        _WIN = (user32, dwm, ctypes, wintypes)
    return _WIN


def _win_rect(hwnd) -> Rect:
    user32, dwm, ctypes, wintypes = _win()
    if not hwnd:
        sys.exit("no window found")
    r = wintypes.RECT()
    # DWM visible frame bounds: GetWindowRect includes the invisible resize
    # border (~7px at 96 DPI) that Chromium/Qt apps leave transparent.
    if dwm.DwmGetWindowAttribute(hwnd, 9, ctypes.byref(r), ctypes.sizeof(r)) == 0 and r.right > r.left:
        return Rect(r.left, r.top, r.right - r.left, r.bottom - r.top)
    if not user32.GetWindowRect(hwnd, ctypes.byref(r)):
        sys.exit("GetWindowRect failed")
    return Rect(r.left, r.top, r.right - r.left, r.bottom - r.top)


def _win_active() -> Rect:
    return _win_rect(_win()[0].GetForegroundWindow())


def _win_select() -> Rect:
    # Windows has no crosshair picker: hover the mouse over the target window.
    user32, _, ctypes, wintypes = _win()
    for i in range(3, 0, -1):
        print(f"hover over the target window... {i}s ", end="\r", flush=True)
        time.sleep(1)
    print(" " * 40, end="\r")
    pt = wintypes.POINT()
    user32.GetCursorPos(ctypes.byref(pt))
    hwnd = user32.WindowFromPoint(pt)
    if not hwnd:
        sys.exit("no window under the mouse")
    # GA_ROOT: top-level window, not a child control
    return _win_rect(user32.GetAncestor(hwnd, 2))


# --- Linux/X11: xdotool ---


def _xdotool(*args) -> str:
    r = subprocess.run(["xdotool", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"xdotool {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def _x11_rect(hwid: str, frame: bool) -> Rect:
    if not frame:
        # getwindowgeometry is the client area only (no title bar/border)
        kv = dict(re.findall(r"^(\w+)=(\S+)$", _xdotool("getwindowgeometry", "--shell", hwid), re.M))
        return Rect(int(kv["X"]), int(kv["Y"]), int(kv["WIDTH"]), int(kv["HEIGHT"]))
    if not shutil.which("xwininfo"):
        sys.exit("--frame needs xwininfo (package x11-utils)")
    out = subprocess.run(["xwininfo", "-id", hwid], capture_output=True, text=True, check=True).stdout

    def grab(pattern):
        m = re.search(pattern, out)
        return int(m.group(1)) if m else 0

    return Rect(grab(r"Absolute upper-left X:\s*(-?\d+)"), grab(r"Absolute upper-left Y:\s*(-?\d+)"),
                grab(r"Width:\s*(\d+)"), grab(r"Height:\s*(\d+)"))


def get_rect(args) -> Rect:
    if platform.system() == "Windows":
        if args.select:
            return _win_select()
        if args.delay:
            print(f"bring the target window to front... {args.delay}s", flush=True)
            time.sleep(args.delay)
        return _win_active()

    if os.environ.get("WAYLAND_DISPLAY") or os.environ.get("XDG_SESSION_TYPE", "").lower() == "wayland":
        sys.exit('Wayland not supported: xdotool needs X11 (try: grim -g "$(slurp -w)")')
    if not shutil.which("xdotool"):
        sys.exit("xdotool not found (e.g. sudo apt install xdotool)")
    if args.select:
        print("click the target window...", flush=True)
        hwid = _xdotool("selectwindow")
    else:
        if args.delay:
            print(f"bring the target window to front... {args.delay}s", flush=True)
            time.sleep(args.delay)
        hwid = _xdotool("getactivewindow")
    return _x11_rect(hwid, args.frame)


def run_flameshot(rect: Rect, args) -> None:
    exe = shutil.which("flameshot") or shutil.which("flameshot.exe")
    if not exe:
        sys.exit("flameshot not found in PATH")
    cmd = [exe, "gui", "--region", rect.region]
    if args.clipboard:
        cmd.append("-c")
    if args.path:
        cmd += ["-p", os.path.expanduser(args.path)]
    subprocess.run(cmd)


def main() -> None:
    p = argparse.ArgumentParser(description="Capture a specific window with Flameshot.")
    p.add_argument("--select", action="store_true",
                   help="pick the window with the mouse (3s hover on Windows, crosshair on X11)")
    p.add_argument("--delay", type=float, default=0, metavar="SEC",
                   help="wait N seconds before grabbing the active window")
    p.add_argument("--frame", action="store_true",
                   help="include title bar/border (X11 only; Windows always includes them)")
    p.add_argument("-c", "--clipboard", action="store_true", help="also copy the shot to the clipboard")
    p.add_argument("-p", "--path", metavar="DIR", help="save directory (default: Flameshot settings)")
    args = p.parse_args()

    rect = get_rect(args)
    print(f"window region: {rect.region}")
    run_flameshot(rect, args)


if __name__ == "__main__":
    main()

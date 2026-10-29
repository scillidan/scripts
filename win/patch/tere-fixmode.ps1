# Fixes the console input mode for tere.
#
# If a previous program (e.g. a killed MSYS/Cygwin bash, or any TUI killed
# mid-run) leaves ENABLE_VIRTUAL_TERMINAL_INPUT (0x200) enabled on the shared
# console, ConPTY starts delivering arrow keys as ESC [ D *character* events
# instead of keyboard events. Crossterm-based TUIs like tere then insert
# literal "[D" into the search box instead of navigating.
#
# This script clears only that bit and preserves everything else.
# See: https://github.com/microsoft/terminal/issues/6737 (record dump showing
# uc=0x1b / 0x5b / 0x42 char events when the input mode is 0x200).

Add-Type -Namespace TereFix -Name ConsoleMode -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr hConsoleHandle, uint dwMode);
'@

$handle = [TereFix.ConsoleMode]::GetStdHandle(-10) # STD_INPUT_HANDLE
$mode = [uint32]0
if ([TereFix.ConsoleMode]::GetConsoleMode($handle, [ref]$mode) -and ($mode -band 0x200)) {
    $fixed = $mode -bxor 0x200 # bit is set here, so xor == clear
    [void][TereFix.ConsoleMode]::SetConsoleMode($handle, [uint32]$fixed)
}

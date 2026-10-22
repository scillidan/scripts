---
name: scripts-context
description: Use when working with the POSIX sh batch/SendTo scripts in scripts/context/ — error tracking, pause-on-exit, safe file replacement, clipboard fallback, or wrapping Python helpers in thin .sh launchers.
---

# Shell SendTo Conventions

## Rules

- **Naming:** `<format>_<action-or-tool>.<ext>` — format first, never tool first (`imgs_rimage.sh`, `vids_mtn.sh`, `pdfs_presse.sh`).
- **Shebang:** `#!/bin/sh`
- **Error tracking:** `error=0` → set to 1 on failure → `exit $error` at end. Always `continue` after error.
- **Pause logic:** Info scripts (print results to user) → always pause before exit so user can read output. Transform scripts (convert/modify files) → pause only on error (`if [ $error -ne 0 ]; then echo "..."; read; fi`).
- **File replacement:** temp file → validate `[ -s ]` → `mv` with rollback.
- **No-args check:** `if [ $# -eq 0 ]; then ...; echo "Press Enter to exit..."; read; exit 1; fi`. Info scripts always pause; transform scripts may skip pause if they auto-close anyway.
- **Python helpers:** When a task needs Python, put logic in `lib/<name>.py` (with PEP 723 `# /// script` header for dependencies) and wrap it in a thin `<name>.sh` that calls `python "$script_dir/lib/<name>.py" "$file"`. The .sh follows all shell conventions (error tracking, pause, no-args check); the .py handles the actual work.
- **Clipboard:** `clip.exe` (Windows) → `xclip` → `xsel`. Always `echo -n`.
- **Prompts:** `printf` (no trailing newline), default via `${var:-default}`.
- **Comment placeholders:** In Usage comment blocks, use `script.sh` as the command-line placeholder, not the actual script filename.

## Key Decisions

- Process all files even if one fails — don't abort early.
- `2>/dev/null` on ffmpeg/magick calls, explicit error messages instead.

---
name: lid-proof
description: Toggle lid-close sleep prevention on this Mac. Use when the user runs /lid-proof (with on/off/status) to keep the laptop awake while the lid is closed.
allowed-tools: Bash
---

Run the helper script and report its output verbatim.

The user's argument (`$ARGUMENTS`) will be one of: `on`, `off`, `status`, or empty.
- Empty → treat as `status`.
- Anything else → still pass through; the script prints a usage error.

Invoke:

```
~/.claude/skills/lid-proof/lid-proof.sh <arg>
```

Notes:
- `on` requires sudo (the script uses `sudo pmset -a SleepDisabled 1`). The Bash tool will prompt for the password the first time.
- `on` starts `caffeinate -dimsu` as a detached background process and records its PID in `~/.cache/lid-proof/caffeinate.pid`. It also saves the previous `SleepDisabled` value so `off` can restore it.
- `off` kills the caffeinate process and restores `SleepDisabled` to its prior value.
- Do not run anything else. After executing, just relay what the script printed.

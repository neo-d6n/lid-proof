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

## Script source

For reference and easy install — `lid-proof.sh` is the same content as below:

```bash
#!/usr/bin/env bash
# lid-proof: keep mac awake with lid closed.
#   lid-proof on      enable
#   lid-proof off     disable + restore
#   lid-proof status  show state
set -euo pipefail

STATE_DIR="${HOME}/.cache/lid-proof"
PID_FILE="${STATE_DIR}/caffeinate.pid"
ORIG_FILE="${STATE_DIR}/sleep_disabled.orig"
mkdir -p "$STATE_DIR"

current_sleep_disabled() {
  pmset -g | awk '/SleepDisabled/ {print $2; exit}'
}

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

cmd="${1:-status}"

case "$cmd" in
  on)
    if is_running; then
      echo "lid-proof already ON (caffeinate pid $(cat "$PID_FILE"))"
      exit 0
    fi
    orig=$(current_sleep_disabled)
    orig=${orig:-0}
    echo "$orig" > "$ORIG_FILE"
    sudo pmset -a SleepDisabled 1 >/dev/null
    nohup caffeinate -dimsu >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    disown || true
    echo "lid-proof ON. close the lid freely. SleepDisabled was $orig."
    echo "heads-up: with the lid closed and no external cooling, the machine can run hot since it's running at full tilt under the closed lid — fine for short stints, worth watching for long ones."
    ;;
  off)
    if is_running; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    orig=0
    [[ -f "$ORIG_FILE" ]] && orig=$(cat "$ORIG_FILE")
    sudo pmset -a SleepDisabled "$orig" >/dev/null
    rm -f "$ORIG_FILE"
    echo "lid-proof OFF. SleepDisabled restored to $orig."
    ;;
  status)
    sd=$(current_sleep_disabled)
    if is_running; then
      echo "lid-proof: ON  (caffeinate pid $(cat "$PID_FILE"), SleepDisabled=$sd)"
    else
      echo "lid-proof: OFF (SleepDisabled=$sd)"
    fi
    ;;
  *)
    echo "usage: lid-proof {on|off|status}" >&2
    exit 2
    ;;
esac
```

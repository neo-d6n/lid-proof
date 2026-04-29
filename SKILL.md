---
name: lid-proof
description: Toggle lid-close sleep prevention on this Mac. Use when the user runs /lid-proof (with on/off/status) to keep the laptop awake while the lid is closed.
allowed-tools: Bash
---

Run the bash block under `## Script` via `bash -s -- <arg>`, passing the user's `$ARGUMENTS` as `<arg>`. Substitute the entire script body — do not pass the literal placeholder.

The user's argument will be one of: `on`, `off`, `status`, or empty.
- Empty → pass `status`.
- Anything else → pass through; the script prints a usage error.

Invocation pattern (heredoc, single-quoted delimiter so `$` isn't expanded):

```
bash -s -- <arg> <<'BASH'
# ... entire ## Script body ...
BASH
```

Notes:
- `on` and `off` need root for `pmset -a SleepDisabled`. The script uses `sudo -n` (non-interactive) and will fail fast if no cached credentials. Two ways to make this work from the Bash tool:
  - **Per-session:** the user types `! sudo -v` in the prompt to cache credentials for ~5 minutes, then re-runs the command.
  - **Permanent:** the user adds a sudoers drop-in:
    ```
    sudo visudo -f /etc/sudoers.d/lid-proof
    # then add:
    YOUR_USERNAME ALL=(root) NOPASSWD: /usr/bin/pmset -a SleepDisabled *
    ```
  If `on` returns a sudo error, surface it and offer those two options — don't retry blindly.
- `on` starts `caffeinate -dimsu` as a detached background process and records its PID in `~/.cache/lid-proof/caffeinate.pid`. It also saves the previous `SleepDisabled` value so `off` can restore it.
- `off` kills the caffeinate process and restores `SleepDisabled` to its prior value.
- After executing, just relay what the script printed.

## Script

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
  local v
  v=$(pmset -g | awk '/SleepDisabled/ {print $2; exit}')
  echo "${v:-0}"
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
    echo "$orig" > "$ORIG_FILE"
    sudo -n pmset -a SleepDisabled 1 >/dev/null
    nohup caffeinate -dimsu >/dev/null 2>&1 </dev/null &
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
    sudo -n pmset -a SleepDisabled "$orig" >/dev/null
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

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
- `on` and `off` need root for `pmset -a SleepDisabled`. The script preflights this with `sudo -n -l` and, if NOPASSWD isn't set up, prints exact setup steps and exits without changing anything. Just relay those instructions to the user — don't try to run sudo, don't loop, don't suggest workarounds.
- `status` works without sudo and never triggers the preflight.
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

preflight_sudo() {
  # NOPASSWD entry must allow `pmset -a SleepDisabled <value>` non-interactively.
  if sudo -n -l /usr/bin/pmset -a SleepDisabled 1 >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<EOF
lid-proof: passwordless sudo for pmset is not configured.

Claude Code's Bash tool has no TTY, so sudo can't prompt. To enable on/off,
add a one-line sudoers rule (one-time setup):

  1. Open a regular terminal (Terminal.app or iTerm — outside Claude Code).
  2. Run:
       sudo visudo -f /etc/sudoers.d/lid-proof
  3. Paste this single line:
       ${USER} ALL=(root) NOPASSWD: /usr/bin/pmset -a SleepDisabled *
  4. Save and exit.

Then re-run /lid-proof on (or off) — it will work silently from then on.
The rule is scoped strictly to 'pmset -a SleepDisabled', nothing else.
EOF
  return 1
}

cmd="${1:-status}"

case "$cmd" in
  on)
    preflight_sudo
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
    preflight_sudo
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

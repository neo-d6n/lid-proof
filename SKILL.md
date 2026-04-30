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
- The skill toggles `pmset -a disablesleep`, the modern macOS knob (Sequoia+) that prevents the system from sleeping at all, including on lid-close. The older `SleepDisabled` key was removed.
- `on` and `off` need root for `pmset`. The script preflights this with `sudo -n -l` and, if NOPASSWD isn't set up for `pmset -a disablesleep`, prints exact setup steps and exits without changing anything. Just relay those instructions to the user — don't try to run sudo, don't loop, don't suggest workarounds.
- `status` works without sudo and reads a local state flag (`~/.cache/lid-proof/active`); it never triggers the preflight.
- After executing, just relay what the script printed.

## Script

```bash
#!/usr/bin/env bash
# lid-proof: keep mac awake with lid closed via pmset disablesleep.
#   lid-proof on      enable
#   lid-proof off     disable
#   lid-proof status  show state
set -euo pipefail

STATE_DIR="${HOME}/.cache/lid-proof"
STATE_FILE="${STATE_DIR}/active"
mkdir -p "$STATE_DIR"

is_active() { [[ -f "$STATE_FILE" ]]; }

preflight_sudo() {
  # NOPASSWD entry must allow `pmset -a disablesleep <value>` non-interactively.
  if sudo -n -l /usr/bin/pmset -a disablesleep 1 >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<EOF
lid-proof: passwordless sudo for pmset is not configured.

Your current AI Agent's bash tool has no TTY, so sudo can't prompt. To enable on/off,
add a one-line sudoers rule (one-time setup):

  1. Open a regular terminal (Terminal.app or iTerm — outside your AI Agent).
  2. Run:
       sudo visudo -f /etc/sudoers.d/lid-proof
  3. Paste this single line:
       ${USER} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep *
  4. Save and exit.

Then re-run /lid-proof on (or off) — it will work silently from then on.
The rule is scoped strictly to 'pmset -a disablesleep', nothing else.
EOF
  return 1
}

cmd="${1:-status}"

case "$cmd" in
  on)
    preflight_sudo
    if is_active; then
      echo "lid-proof already ON."
      exit 0
    fi
    sudo -n pmset -a disablesleep 1 >/dev/null
    : > "$STATE_FILE"
    echo "lid-proof ON. close the lid freely; the Mac will not sleep."
    echo "heads-up: with the lid closed and no external cooling, the machine can run hot since it's running at full tilt under the closed lid — fine for short stints, worth watching for long ones."
    ;;
  off)
    preflight_sudo
    sudo -n pmset -a disablesleep 0 >/dev/null
    rm -f "$STATE_FILE"
    echo "lid-proof OFF. normal sleep behavior restored."
    ;;
  status)
    if is_active; then
      echo "lid-proof: ON"
    else
      echo "lid-proof: OFF"
    fi
    ;;
  *)
    echo "usage: lid-proof {on|off|status}" >&2
    exit 2
    ;;
esac
```

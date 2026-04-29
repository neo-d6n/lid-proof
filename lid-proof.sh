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

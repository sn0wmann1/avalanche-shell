#!/usr/bin/env bash
# Brightness status for the top bar pill. Fast: reads once, caches to /tmp,
# then only re-reads DDC every BRIGHT_POLL_S (default 10s) to avoid slow (~5s)
# ddcutil calls on every poll. Switches icon by level.
set -euo pipefail

CACHE="/tmp/brightness-pill"
POLL_S="${BRIGHT_POLL_S:-10}"

get_val() {
    ddcutil getvcp 10 --brief --display 1 2>/dev/null | awk '/VCP/{print $4}' | tr -d '[:space:]'
}

NOW=$(date +%s)
if [ -f "$CACHE" ]; then
    read -r last_ts last_val <"$CACHE" || true
else
    last_ts=0
    last_val=""
fi

if [ -z "$last_val" ] || [ $((NOW - last_ts)) -ge "$POLL_S" ]; then
    CURR=$(get_val) || CURR=""
    [ -n "$CURR" ] && {
        echo "$NOW $CURR" >"$CACHE"
        last_val="$CURR"
    }
fi

VAL="${last_val:-50}"
# clamp 0..100
VAL=$((VAL))

if [ "$VAL" -le 30 ]; then
    ICON="󰃞"
elif [ "$VAL" -le 70 ]; then
    ICON="󰃟"
else
    ICON="󰃠"
fi

printf '{"percent":"%s","icon":"%s"}\n' "$VAL" "$ICON"

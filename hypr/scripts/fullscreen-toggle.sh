#!/bin/bash
# Super+X: fullscreen toggle. On exit, return window to tiled mode.
set -euo pipefail

FS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.fullscreen // 0')
FLOAT=$(hyprctl activewindow -j 2>/dev/null | jq -r '.floating // "false"')

if [ -n "$FS" ] && [ "$FS" -gt 0 ]; then
    # Exiting fullscreen -> exit + ensure tiled
    hyprctl dispatch fullscreen 0 >/dev/null 2>&1
    if [ "$FLOAT" = "true" ]; then
        hyprctl dispatch settiled >/dev/null 2>&1
    fi
else
    # Entering fullscreen
    hyprctl dispatch fullscreen 0 >/dev/null 2>&1
fi

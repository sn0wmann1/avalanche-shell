#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# qs-to-rgb.sh — bridges avalanche's matugen output into your RGB pipeline.
# avalanche's matugen writes qs_colors.json (catppuccin keys). Your
# rgb-sync.sh reads ~/.cache/skwd-wall/colors.json (`.accent`). This adapter
# maps avalanche's `blue` (its primary/accent) into the accent slot your
# RGB scripts expect, preserving the rest of the color cache.
#
# Called from avalanche's matugen_reload.sh after matugen finishes.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

QS_JSON="$HOME/.config/hypr/scripts/quickshell/qs_colors.json"
TARGET="$HOME/.cache/skwd-wall/colors.json"

[ -f "$QS_JSON" ] || {
  echo "qs_colors.json missing"
  exit 0
}

# Accent = avalanche's `blue` (it maps to matugen primary). Fall back to text.
ACCENT=$(jq -r '.blue // .text // ""' "$QS_JSON" 2>/dev/null || echo "")
[ -n "$ACCENT" ] && [ "$ACCENT" != "null" ] || {
  echo "no accent color"
  exit 0
}
ACCENT="${ACCENT#\#}"

# Merge: keep existing structure, update accent + foreground-ish keys.
if [ -f "$TARGET" ]; then
  jq --arg a "#$ACCENT" '.accent=$a | .primary=$a' "$TARGET" >"$TARGET.tmp" 2>/dev/null &&
    mv "$TARGET.tmp" "$TARGET"
else
  mkdir -p "$(dirname "$TARGET")"
  printf '{\n  "accent": "#%s",\n  "primary": "#%s",\n  "background": "#%s",\n  "foreground": "#%s"\n}\n' \
    "$ACCENT" "$ACCENT" "${ACCENT}" "${ACCENT}" >"$TARGET"
fi

# Sync RGB (accent changed → bridge/direct fades). Debounce-friendly: rgb-sync.sh
# resolves the accent and calls the bridge; it exits fast if nothing changed.
bash "$HOME/Dotfiles/scripts/rgb-sync.sh" >/dev/null 2>&1 &
disown

echo "RGB synced to accent #$ACCENT"

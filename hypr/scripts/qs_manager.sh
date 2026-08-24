#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# GLOBAL VARS
# -----------------------------------------------------------------------------
SCRIPTS_DIR="$HOME/.config/hypr/scripts/quickshell"
SHELL_QML_PATH="$SCRIPTS_DIR/Shell.qml"

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# Must be first — before any sourcing, caching, or pgrep.
# -----------------------------------------------------------------------------
ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    # Send IPC command directly to Main.qml via Quickshell's native IPC handler
    quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "close" "" "" >/dev/null 2>&1

    CMD="workspace $ACTION"
    [[ "$TARGET" == "move" ]] && CMD="movetoworkspace $ACTION"
    hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    exit 0
fi

# -----------------------------------------------------------------------------
# SLOW PATH: Everything below only runs for non-workspace actions
# -----------------------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"

qs_ensure_cache "workspaces"
qs_ensure_cache "network"
qs_ensure_cache "wallpaper_picker"

BT_PID_FILE="$QS_RUN_DIR/bt_scan_pid"
BT_SCAN_LOG="$QS_LOG_DIR/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
THUMB_DIR="$QS_CACHE_WALLPAPER_PICKER/thumbs"
PREP_LOCK="$QS_RUN_DIR/wallpaper_prep.lock"

export MAGICK_THREAD_LIMIT=1

QS_NETWORK_CACHE="$QS_CACHE_NETWORK"
mkdir -p "$QS_NETWORK_CACHE" "$THUMB_DIR"

NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

MANIFEST="$THUMB_DIR/.manifest"

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# Only runs on slow path — not on every workspace switch
# -----------------------------------------------------------------------------

if ! pgrep -f "quickshell.*Shell.qml" >/dev/null; then
    quickshell -p "$SHELL_QML_PATH" >/dev/null 2>&1 &
    disown
fi

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------
build_manifest() {
    find "$THUMB_DIR" -maxdepth 1 -type f ! -name '.source_dir' ! -name '.manifest' \
        -printf "%f\n" | sort >"$MANIFEST"
}

handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"

    (
        if [ -f "$PREP_LOCK" ]; then
            if kill -0 "$(cat "$PREP_LOCK")" 2>/dev/null; then
                exit 0
            fi
        fi
        echo $BASHPID >"$PREP_LOCK"

        export THUMB_DIR SRC_DIR MANIFEST MAGICK_THREAD_LIMIT=1

        THUMB_SOURCE_FILE="$THUMB_DIR/.source_dir"
        if [ -f "$THUMB_SOURCE_FILE" ]; then
            read -r CACHED_SRC <"$THUMB_SOURCE_FILE"
            if [ "$CACHED_SRC" != "$SRC_DIR" ]; then
                find "$THUMB_DIR" -maxdepth 1 -type f \
                    ! -name '.source_dir' ! -name '.manifest' -delete
                echo "$SRC_DIR" >"$THUMB_SOURCE_FILE"
                >"$MANIFEST"
            fi
        else
            echo "$SRC_DIR" >"$THUMB_SOURCE_FILE"
            >"$MANIFEST"
        fi

        [ ! -f "$MANIFEST" ] && build_manifest

        SRC_LIST=$(mktemp)
        find "$SRC_DIR" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
            -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" \
            -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.webp" \) \
            -printf "%f\n" | sort >"$SRC_LIST"

        comm -23 <(sed 's/^000_//' "$MANIFEST" | sort) "$SRC_LIST" | while read -r orphan; do
            rm -f "$THUMB_DIR/$orphan" "$THUMB_DIR/000_$orphan"
            sed -i "/^${orphan}$/d;/^000_${orphan}$/d" "$MANIFEST"
        done

        while IFS= read -r filename; do
            img="$SRC_DIR/$filename"
            [ -f "$img" ] || continue

            extension="${filename##*.}"

            if [[ "${extension,,}" == "webp" ]]; then
                # webp: thumbnail directly (magick reads webp), do NOT convert/delete source
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                    echo "$filename" >>"$MANIFEST"
                fi
                continue
            fi

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 \
                        -threads 1 -f image2 -q:v 2 "$thumb" >/dev/null 2>&1
                    echo "000_$filename" >>"$MANIFEST"
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                    echo "$filename" >>"$MANIFEST"
                fi
            fi
        done < <(comm -23 "$SRC_LIST" <(sed 's/^000_//' "$MANIFEST" | sort))

        rm -f "$SRC_LIST" "$PREP_LOCK"
    ) </dev/null >/dev/null 2>&1 &
}

handle_network_prep() {
    echo "" >"$BT_SCAN_LOG"
    {
        echo "scan on"
        sleep infinity
    } | stdbuf -oL bluetoothctl >"$BT_SCAN_LOG" 2>&1 &
    echo $! >"$BT_PID_FILE"
    (nmcli device wifi rescan) >/dev/null 2>&1 &
}

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "close" "" "" >/dev/null 2>&1
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        (bluetoothctl scan off >/dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    if [[ "$TARGET" == "network" ]]; then
        handle_network_prep
        [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" >"$NETWORK_MODE_FILE"
        quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        # Use skwd wall toggle instead of quickshell wallpaper picker
        skwd wall toggle
        exit 0
    else
        quickshell -p "$SHELL_QML_PATH" ipc call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
    fi
    exit 0
fi

# -----------------------------------------------------------------------------
# RESTART QUICKSHELL
# Usage: qs_manager.sh restart
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "restart" ]]; then
    # Always clear caches so QML changes take effect
    rm -rf "$HOME/.cache/quickshell"/* 2>/dev/null || true
    rm -rf "/run/user/1000/quickshell/by-id"/* 2>/dev/null || true

    if pgrep -f "quickshell.*Shell.qml" >/dev/null; then
        # Shell is running - try graceful reload first
        quickshell -p "$SHELL_QML_PATH" ipc call main forceReload >/dev/null 2>&1
        sleep 1

        # Verify it's still running after reload
        if pgrep -f "quickshell.*Shell.qml" >/dev/null; then
            notify-send -u low "Quickshell" "Reloaded successfully" 2>/dev/null || true
            exit 0
        else
            # Reload caused crash - force restart
            pkill -9 -f "quickshell.*Shell.qml" 2>/dev/null || true
            sleep 1
            quickshell -p "$SHELL_QML_PATH" >/dev/null 2>&1 &
            disown

            sleep 2

            if pgrep -f "quickshell.*Shell.qml" >/dev/null; then
                notify-send -u normal "Quickshell" "Force restarted after crash" 2>/dev/null || true
            else
                notify-send -u critical "Quickshell" "Failed to start" 2>/dev/null || true
            fi
            exit 0
        fi
    else
        # Shell not running - start fresh
        quickshell -p "$SHELL_QML_PATH" >/dev/null 2>&1 &
        disown

        sleep 2

        if pgrep -f "quickshell.*Shell.qml" >/dev/null; then
            notify-send -u normal "Quickshell" "Started successfully" 2>/dev/null || true
        else
            notify-send -u critical "Quickshell" "Failed to start" 2>/dev/null || true
        fi
        exit 0
    fi
fi

# Toggle dark overlay with backspace as delete
toggle_dark_overlay() {
    # Check if overlay window exists
    if hyprctl clients -j | grep -q '"class": "dark_overlay"'; then
        # Close the overlay
        hyprctl dispatch closewindow class:dark_overlay
        notify-send -u low "Dark Overlay" "Disabled"
    else
        # Create dark overlay using hyprland's built-in overlay
        # Use a fullscreen transparent window with dark tint
        hyprctl keyword general:col.active_border 0x00000000
        # Launch a fullscreen kitty with dark background as overlay
        kitty --class dark_overlay \
            --override background_opacity=0.7 \
            --override background=#000000 \
            -e bash -c 'sleep infinity' &
        notify-send -u low "Dark Overlay" "Enabled - Backspace now acts as Delete"

        # Note: For Backspace → Delete remapping, you'd need a separate tool
        # like `ydotool` or `keyd` or a sway/wayland remap
        # This is a basic overlay; key remapping requires additional setup
    fi
}

# Add function to the case/switch statement if one exists
# Look for a case statement in the script

# Toggle clipboard with dark overlay
toggle_clipboard_with_dark_overlay() {
    # Check if dark overlay exists and toggle it
    if hyprctl clients -j | grep -q '"class": "dark_overlay"'; then
        hyprctl dispatch closewindow class:dark_overlay
        notify-send -u low "Dark Overlay" "Disabled"
    else
        hyprctl keyword general:col.active_border 0x00000000
        kitty --class dark_overlay --override background_opacity=0.7 --override background=#000000 -e bash -c 'sleep infinity' &
        notify-send -u low "Dark Overlay" "Enabled"
    fi

    # Then toggle clipboard
    quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml ipc call main handleCommand toggle clipboard >/dev/null 2>&1
}

# stay-active status check
if [[ "$1" == "stay-active-status" ]]; then
    PIDFILE="/tmp/stay-active.pid"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo 1
    else
        echo 0
    fi
    exit 0
fi

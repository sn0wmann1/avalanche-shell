# Avalanche Shell

Avalanche — a custom [Quickshell](https://quickshell.org/)-based desktop shell for Hyprland, evolved from the [serpantinum](https://github.com/ilyamiro/serpantinum) project.

## What it is

A floating top bar + edge widgets + popup panels built on [Quickshell](https://quickshell.org/), driven by Matugen theming. Replaces the caelestia shell on Freezer (snow's desktop).

## Launch

```fish
quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml
```

Added via `exec-once` in `~/.config/hypr/config/autostart.conf`.

## Features

- **TopBar** (`hypr/scripts/quickshell/TopBar.qml`) — floating bar with workspaces, clock, weather, audio, network, battery, tray
- **Floating edge widget** — quick actions, system usage, timer (hides on fullscreen)
- **Popups** — applauncher, settings, music, calendar, network, clipboard, battery, focus time, prayer times
- **Matugen colors** — `MatugenColors.qml` reads `qs_colors.json` on a 1s timer, live-updates on wallpaper change
- **Fullscreen-aware** — bar + floating widget collapse when a window goes fullscreen (Hyprland socket event driven)
- **Brightness/volume OSD** — swayosd native slider+icon via `volume_listener.sh`; brightness uses cached DDC/CI for instant hold-repeat

## Files

```
hypr/scripts/quickshell/   # the shell itself (QML + watchers + panel logic)
hypr/scripts/qs_manager.sh # IPC manager: toggle panels, workspaces
hypr/scripts/fullscreen-toggle.sh # Super+X: fullscreen toggle, restore tiling on exit
```

## Install

Symlink (or copy) `hypr/scripts/quickshell` and `hypr/scripts/qs_manager.sh` into `~/.config/hypr/scripts/`, then add the `exec-once` line to autostart.

## Requirements

- quickshell
- swayosd (OSD)
- matugen (theming)
- skwd (wallpaper daemon)
- playerctl, wpctl (audio), networkmanager

# vibetime

A lightweight macOS menubar app that tracks your developer tool usage. See how long you spend in Cursor, Warp, VS Code, Terminal, and other apps — without lifting a finger.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B%20(Tahoe)-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## What It Tracks

- **Active Time** — the app is frontmost, you're looking at it
- **Running Time** — the app process is alive (could be in the background)
- **Focus Streaks** — longest uninterrupted stretch in a single app
- **Context Switches** — how many times you bounced between tracked apps
- **Session Duration** — total time from first app launch to now
- **7-Day History** — sparkline showing your daily totals at a glance

## How It Works

vibetime listens for macOS workspace notifications — no polling, no timers eating your battery. When you switch apps, macOS tells vibetime. That's it.

- Event-driven tracking via `NSWorkspace` notifications
- Idle detection via `CGEventSource` (pauses tracking when you walk away)
- Data stored locally in `~/Library/Application Support/vibetime/`
- No network calls, no telemetry, no accounts

## Features

- Menubar-only app (no dock icon)
- macOS Tahoe liquid glass UI
- Both active and running time shown per app
- Configurable idle timeout and focus streak threshold
- Daily goal tracking
- Daily wrap notification when your session ends
- Auto-prunes data older than 30 days
- Launch at login support

## Default Tracked Apps

- Warp
- Cursor
- Terminal
- VS Code
- iTerm2

Add or remove apps from Settings inside the dropdown.

## Install

### From GitHub Releases

1. Download the latest `.zip` from [Releases](../../releases)
2. Unzip and drag `vibetime.app` to your Applications folder
3. Launch it — look for the circle in your menubar

### Build from Source

Requires Xcode 26+ (macOS Tahoe SDK).

```bash
git clone https://github.com/MarkTheCoderShark/vibetime.git
cd vibetime
xcodebuild -project vibetime.xcodeproj -scheme vibetime -configuration Release build
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/vibetime-*/Build/Products/Release/vibetime.app`.

## License

MIT

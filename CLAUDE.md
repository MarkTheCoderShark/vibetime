# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

vibetime is a native macOS menubar app (Swift/SwiftUI) that tracks developer tool usage — active time (app is frontmost), running time (app process is alive), focus streaks, and context switches. Targets macOS 26+ (Tahoe) with liquid glass UI.

## Build & Run

```bash
# Build
xcodebuild -project vibetime.xcodeproj -scheme vibetime -configuration Debug build

# Run (after building)
open ~/Library/Developer/Xcode/DerivedData/vibetime-*/Build/Products/Debug/vibetime.app

# Kill running instance
pkill -x vibetime
```

Requires full Xcode (not just Command Line Tools). Xcode developer path must point to `/Applications/Xcode.app/Contents/Developer`.

## Architecture

**Menubar-only app** — no dock icon (`LSUIElement = true`), no main window. Uses `NSPopover` attached to `NSStatusItem` for the dropdown UI.

- **App.swift** — `@main` entry point + `AppDelegate` manages the status item, popover lifecycle, and settings window. AppDelegate is `@MainActor` (Swift 6 concurrency).
- **AppTracker.swift** — Core tracking engine. Listens to `NSWorkspace` notifications (`didActivateApplication`, `didDeactivateApplication`, `didLaunchApplication`, `didTerminateApplication`) for zero-polling event-driven tracking. Handles idle detection via `CGEventSource.secondsSinceLastEventType`. Ticks once per minute to update running times.
- **Storage.swift** — JSON file persistence in `~/Library/Application Support/vibetime/`. One file per day (`yyyy-MM-dd.json`), auto-prunes after 30 days.
- **AppSettings.swift** — `UserDefaults`-backed settings with `@Published` properties. Launch-at-login via `SMAppService`.
- **MenuBarView.swift** — Main popover UI. Shows both active and running time per app inline (no switcher), stat badges with glass effects, week sparkline.
- **SettingsView.swift** — Tabbed settings: General (idle timeout, focus streak threshold, daily goal) and Apps (add/remove tracked apps from running apps or manual bundle ID).

## Key Design Decisions

- **No polling for app tracking** — entirely event-driven via NSWorkspace notifications. The only timers are a 60s tick for accumulating running time and a 30s idle check.
- **Sandbox is disabled** (`com.apple.security.app-sandbox = false`) because NSWorkspace app monitoring and CGEventSource idle detection require it.
- **Sessions are automatic** — start when first tracked app launches, end when last one closes. No manual start/stop.
- **macOS 26 deployment target** — uses Tahoe liquid glass APIs (`.glassEffect()`, `GlassEffectContainer`). These won't compile against older SDKs.
- Default tracked apps: Warp, Cursor, Terminal, VS Code, iTerm2 (bundle IDs in `AppSettings.defaultApps`).

# MenuBar Companion

A macOS menu bar utility built with Swift + SwiftUI that runs external commands and streams output to a popover UI. Designed as the foundation for a Claude Code CLI runner.

## Prerequisites

- **macOS 13.0+** (Ventura or later)
- **Xcode 15.0+**

## Build & Run

### From Xcode

1. Open `MenuBarCompanion.xcodeproj`
2. Select the **MenuBarCompanion** scheme
3. Press **Cmd+R** to build and run

The app launches as a menu bar utility — look for the terminal icon (⌘) in your menu bar. No Dock icon will appear (`LSUIElement = YES`).

### From Command Line

```bash
xcodebuild -project MenuBarCompanion.xcodeproj \
  -scheme MenuBarCompanion \
  -configuration Debug \
  build

# Run the built app
open build/Debug/MenuBarCompanion.app
```

## Usage

1. Click the **terminal icon** in your menu bar to open the popover
2. Type any shell command (e.g., `ls -la`, `whoami`, `echo hello`)
3. Click **Run** (or press Enter) to execute
4. Output streams in real-time to the output area
5. Click **Cancel** to terminate a running process
6. Use **Clear** to reset output, **Copy** to copy to clipboard

### Event System

The app recognizes special event lines in command output:

```
[MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"It worked!"}
```

Try it:
```
echo '[MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"It worked!"}'
```

### Claude CLI Detection

If `claude` is found on your PATH, the UI shows a "Claude CLI" badge. The command runner is designed to be swapped to invoke Claude Code in a future update.

## Project Structure

```
MenuBarCompanion/
├── App/
│   ├── MenuBarCompanionApp.swift   # @main entry point
│   ├── AppDelegate.swift           # NSStatusBar + NSPopover setup
│   └── Info.plist                  # LSUIElement (no dock icon)
├── UI/
│   ├── PopoverView.swift           # SwiftUI popover layout
│   └── PopoverViewModel.swift      # View model, command orchestration
├── Core/
│   ├── CommandRunner.swift         # Process wrapper with streaming output
│   └── EventParser.swift           # [MENUBOT_EVENT] JSON parser
├── Assets.xcassets/
└── MenuBarCompanion.entitlements
```

## Architecture

- **CommandRunner** — wraps `Process` + `Pipe` to stream stdout/stderr line-by-line via callbacks. Supports start, cancel, and completion.
- **EventParser** — recognizes `[MENUBOT_EVENT]` prefixed lines and parses the JSON payload. Currently handles `toast` events; extensible for future types.
- **PopoverViewModel** — coordinates UI state, builds commands, and routes output lines through the event parser.

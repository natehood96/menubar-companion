# Objective 1: Run a Command from the Menu Bar

## Overview

This order delivers the foundational user experience: a macOS menu bar app that the user can click to open a popover, type a free-form command, and have it executed via the Claude Code CLI with streaming output displayed in real time. By the end of this order, the core interaction loop — click icon, type command, see results — is fully functional. This is the minimum "it works" milestone.

## Objectives

### 1.1 Menu Bar Presence & Icon

- App installs and runs as a menu bar icon
- **Default icon**: A friendly smiling blob character — approachable, companion-like, conveys "your pal that's always there for you"
  - Rendered as a monochrome template image so macOS auto-adapts to light/dark mode
  - Sized at 18x18pt @1x / 36x36pt @2x
- App runs as LSUIElement (no dock icon, menu bar only)

**Tech stack applicable to this objective:**

| Layer | Technology |
|---|---|
| App framework | Swift + SwiftUI |
| Menu bar integration | NSStatusBar, NSPopover / SwiftUI popovers |

### 1.2 Popover with Command Input

- Clicking the icon opens a lightweight popover containing:
  - A single command input ("Ask or command...")
  - A **Starred Skills** section (placeholder, wired up in Objective 3)
  - A button/tab to open **All Skills** (placeholder, wired up in Objective 3)

### 1.3 Claude Code CLI Execution & Streaming Output

- Menu-Bot invokes Claude Code locally via CLI and streams output live
- The UI should show:
  - "Running..." state
  - Partial output (optional) and/or progress events
  - Completion state

**Tech stack applicable to this objective:**

| Layer | Technology |
|---|---|
| Process orchestration | Swift `Process` to invoke Claude Code CLI |

## Acceptance Criteria

- [ ] User can install and launch Menu-Bot and see a friendly smiling blob menu bar icon
- [ ] User can open the popover and run a free-form command
- [ ] Running a skill triggers Claude Code via CLI and completes successfully

## Scope Boundary

This objective does NOT include:

- Icon customization / preset selection (Objective 5)
- Event protocol parsing or toast/tooltip notifications (Objective 2)
- Skills directory, skill format, browse/star/run UI (Objective 3)
- Context injection (Objective 4)
- Preinstalled skills (Objective 4)
- Scheduling (Objective 4)
- Safety confirmations, stop/cancel, or activity log (Objective 5)
- Persistence of settings beyond what's needed for basic operation (Objective 5)

## Dependencies

- Depends on: None (this is the first order)
- Feeds into: Objective 2, Objective 3, Objective 4, Objective 5

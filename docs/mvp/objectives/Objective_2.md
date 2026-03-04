# Objective 2: Event Protocol & Notifications

## Overview

This order establishes the structured communication channel between Claude Code and Menu-Bot. Claude Code emits parseable `[MENUBOT_EVENT]` lines in stdout, and Menu-Bot parses them into toast notifications, result displays with action buttons, and error states — all anchored to the menu bar icon. This is the "report back to user" system that makes Menu-Bot feel like a real companion rather than a dumb terminal.

## Objectives

### 2.1 Event Protocol Parsing

Claude Code output must support a parseable prefix for events:

```
[MENUBOT_EVENT] {json}
```

**Supported event types (minimum):**

| Type | Payload | Behavior |
|---|---|---|
| `toast` | title, message, optional action | Show tooltip/toast near menu bar icon |
| `result` | summary, artifacts (file paths/URLs) | Display result with action buttons |
| `error` | message, guidance | Show error state with recovery info |

- Menu-Bot must ignore non-event text safely

### 2.2 Toast / Tooltip Rendering

- Claude Code can emit structured events in stdout that Menu-Bot parses and turns into UI messages
- Menu-Bot must support at least:
  - **Toast message** anchored near the menu bar icon (short-lived tooltip style)
  - **Progress updates** (optional v1; can be minimal)
  - **Action buttons** (e.g. "Open", "Copy", "View")
- Example UX:
  - A bubble drops down from the menu bar icon: *"It's all done! Click to check it out!"*
  - Clicking it performs the attached action (open folder/file/URL)

### 2.3 Error & Result Display

- `error` event type renders an error state with recovery guidance
- `result` event type displays a summary with artifacts (file paths/URLs) and action buttons

## Acceptance Criteria

- [ ] Claude Code can emit a `[MENUBOT_EVENT]` line and Menu-Bot displays a tooltip/toast anchored to the menu bar icon

## Scope Boundary

This objective does NOT include:

- The basic CLI execution and streaming output display (Objective 1)
- Skills directory, format, or UI (Objective 3)
- Context injection or preinstalled skills (Objective 4)
- Scheduling (Objective 4)
- Safety confirmations or activity log (Objective 5)

## Dependencies

- Depends on: Objective 1 (CLI execution and streaming output must exist to layer event parsing on top)
- Feeds into: Objective 3, Objective 4, Objective 5

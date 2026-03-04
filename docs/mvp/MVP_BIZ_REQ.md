# Menu-Bot (macOS) — MVP Business Requirements

> Local Claude Code Companion App

## Summary

Build a lightweight macOS menu bar companion ("Menu-Bot") that lets users run Claude Code-powered skills from a dedicated skills folder, provide optional context (screenshots, active window, etc.), and receive in-app "report back" notifications (tooltip/toast anchored to the menu bar icon). The app is local-first and primarily orchestrates actions via the user's existing Claude Code license.

---

## Goals

- Provide an always-available assistant UI on macOS (menu bar)
- Execute user-invoked "skills" (prompt-based workflows) without polluting the user's main Claude Code skill set
- Support a clean feedback loop where Claude Code can emit structured events that Menu-Bot renders as UI toasts, progress, results, and actionable buttons ("Open", "Copy", "View")
- Keep the initial UI simple and fast, while enabling a scalable skill library experience (browse, star, organize)

## Non-Goals (v1)

- Cross-platform support (Windows/Linux) — macOS only
- Fully autonomous "control the entire OS" agent (mouse/keyboard control) — future scope
- Full marketplace / cloud sync for skills — local skills only

---

## Tech Stack

| Layer | Technology |
|---|---|
| App framework | Swift + SwiftUI |
| Menu bar integration | NSStatusBar, NSPopover / SwiftUI popovers |
| Process orchestration | Swift `Process` to invoke Claude Code CLI |
| Local storage | UserDefaults and/or JSON files; optional SQLite/CoreData only if needed |
| Permissions (optional v1) | macOS Screen Recording / Accessibility prompts |

---

## Core User Experience Requirements

### 1. Menu Bar Presence & Icon

- App installs and runs as a menu bar icon
- **Default icon**: A friendly smiling blob character — approachable, companion-like, conveys "your pal that's always there for you"
  - Rendered as a monochrome template image so macOS auto-adapts to light/dark mode
  - Sized at 18x18pt @1x / 36x36pt @2x
- **Customizable icon**: Users can choose from a set of preset icon options (e.g., blob, ghost, cat, robot, star buddy) via a preferences/settings view
  - Selected icon is persisted in UserDefaults
  - Swapped at runtime via `statusBarItem.button?.image`
- Clicking the icon opens a lightweight popover containing:
  - A single command input ("Ask or command...")
  - A **Starred Skills** section
  - A button/tab to open **All Skills**

### 2. Skills System (Local, Folder-Based)

- Menu-Bot maintains its own dedicated skills directory:
  `~/Library/Application Support/MenuBot/skills/`
- Skills are defined as files in that folder and are discoverable at runtime (no rebuild required)
- A "bridge" Claude Code skill is used that:
  - Instructs Claude Code to scan the Menu-Bot skills directory
  - Defines how Claude Code communicates back to Menu-Bot (see "Event Protocol")
- The user's main Claude Code skills remain untouched; Menu-Bot uses its own contained skills model

### 3. Skills UI (Browse, Star, Run)

- **All Skills** view lists every skill found in the skills directory
- Each skill shows:
  - Name
  - Short description
  - (Optional) icon
- Users can:
  - Star skills (starred appear in the main popover)
  - Optionally group/organize skills (simple categories/tags are enough for v1)
- Clicking a skill opens a **Run Skill** screen:
  - Shows skill description
  - Provides an optional "extra instructions" input
  - "Run" button executes the skill

### 4. Context Injection (Configurable Per Run)

When running a skill (or free-form command), Menu-Bot can attach context:

**Default context (always included):**
- Current time
- Active application name

**Optional context toggles (design for expandability):**
- Screenshot: full screen / active window / user-selected region
- Clipboard contents
- Selected text (where feasible)

Context should be appended in a consistent structured format to Claude Code.

### 5. Claude Code Execution + Streaming Output

- Menu-Bot invokes Claude Code locally via CLI and streams output live
- The UI should show:
  - "Running..." state
  - Partial output (optional) and/or progress events
  - Completion state

### 6. "Report Back to User" Notifications (Tooltip/Toast)

- Claude Code can emit structured events in stdout that Menu-Bot parses and turns into UI messages
- Menu-Bot must support at least:
  - **Toast message** anchored near the menu bar icon (short-lived tooltip style)
  - **Progress updates** (optional v1; can be minimal)
  - **Action buttons** (e.g. "Open", "Copy", "View")
- Example UX:
  - A bubble drops down from the menu bar icon: *"It's all done! Click to check it out!"*
  - Clicking it performs the attached action (open folder/file/URL)

### 7. Preinstalled Skills (Ship With Defaults)

Menu-Bot should ship with a small set of built-in skills placed into the skills directory on first run:

| Skill | Description |
|---|---|
| **Morning Brief** | Daily newsletter/report style output |
| **Create New Skill** | Generates a new skill file in the skills folder |
| **Find File** | Semantic file search + open |
| *(Optional)* Clean Downloads | Showcase skill for organizing files |
| *(Optional)* Work Mode | Showcase skill for focus/productivity |

### 8. Scheduling

- Skills may define a recommended schedule (metadata)
- Menu-Bot supports scheduling at least one recurring task:
  - e.g., Morning Brief runs daily at a chosen time
- Acceptable v1 approaches:
  - macOS LaunchAgent
  - Internal timer + auto-launch at login
- Output must "report back" via toast/notification when complete

### 9. Safety and Transparency

- When a skill triggers external side effects (send email, delete files, etc.), Menu-Bot should:
  - Display what it's about to do (human-readable)
  - Require a confirm step unless the skill is explicitly marked "safe to auto-run"
- Include a **Stop** / **Cancel** for a running skill
- Provide a simple **activity log** of recent runs (even a basic list in v1)

---

## System / Behavior Requirements

### Skill Format & Metadata

Skills must support:
- Name
- Description
- Optional: category/tags, icon, suggested schedule, required permissions

Skills must support prompt templates with variables:
- `{extra_instructions}`
- `{context.screenshot}`
- `{context.clipboard}`
- `{context.active_app}`

### Event Protocol (Claude Code -> Menu-Bot)

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

Menu-Bot must ignore non-event text safely.

### Persistence

Store locally:
- Starred skills
- Skill ordering/groups (if implemented)
- Scheduling settings
- Recent runs (basic history)
- Selected menu bar icon preference

Storage should be local, simple, and resilient.

---

## Acceptance Criteria

- [ ] User can install and launch Menu-Bot and see a friendly smiling blob menu bar icon
- [ ] User can change the menu bar icon from a set of presets in settings
- [ ] User can open the popover and:
  - [ ] Run a free-form command
  - [ ] View starred skills
  - [ ] Open the skills browser
- [ ] User can add a new skill file to the skills folder and it appears in the UI without rebuilding
- [ ] Running a skill triggers Claude Code via CLI and completes successfully
- [ ] Claude Code can emit a `[MENUBOT_EVENT]` line and Menu-Bot displays a tooltip/toast anchored to the menu bar icon
- [ ] Menu-Bot ships with preinstalled skills (Morning Brief + Create New Skill + Find File at minimum)
- [ ] Morning Brief can be scheduled daily and produces a user-visible report back notification

---

## Future Enhancements (Post-MVP)

- OS-level control (mouse/keyboard) via Accessibility APIs (requires strong guardrails)
- Browser automation (Playwright) for reliable "do it for me" web tasks
- Skill marketplace / cloud sync
- Cross-platform support

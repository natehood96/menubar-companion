# Objective 4: Context, Defaults & Scheduling

## Overview

This order makes Menu-Bot useful out of the box. It adds configurable context injection (time, active app, screenshots, clipboard), ships the preinstalled skills that are seeded on first run, and introduces scheduling so skills like Morning Brief can run automatically on a recurring basis. By the end of this order, a new user installs the app and immediately has working skills and a daily briefing.

## Objectives

### 4.1 Context Injection

When running a skill (or free-form command), Menu-Bot can attach context:

**Default context (always included):**
- Current time
- Active application name

**Optional context toggles (design for expandability):**
- Screenshot: full screen / active window / user-selected region
- Clipboard contents
- Selected text (where feasible)

Context should be appended in a consistent structured format to Claude Code.

**Tech stack applicable to this objective:**

| Layer | Technology |
|---|---|
| Permissions (optional v1) | macOS Screen Recording / Accessibility prompts |

### 4.2 Preinstalled Skills

Menu-Bot should ship with a small set of built-in skills placed into the skills directory on first run:

| Skill | Description |
|---|---|
| **Morning Brief** | Daily newsletter/report style output |
| **Create New Skill** | Generates a new skill file in the skills folder |
| **Find File** | Semantic file search + open |
| *(Optional)* Clean Downloads | Showcase skill for organizing files |
| *(Optional)* Work Mode | Showcase skill for focus/productivity |

### 4.3 Scheduling

- Skills may define a recommended schedule (metadata)
- Menu-Bot supports scheduling at least one recurring task:
  - e.g., Morning Brief runs daily at a chosen time
- Acceptable v1 approaches:
  - macOS LaunchAgent
  - Internal timer + auto-launch at login
- Output must "report back" via toast/notification when complete

**Persistence applicable to this objective:**
- Scheduling settings stored locally

## Acceptance Criteria

- [ ] Menu-Bot ships with preinstalled skills (Morning Brief + Create New Skill + Find File at minimum)
- [ ] Morning Brief can be scheduled daily and produces a user-visible report back notification

## Scope Boundary

This objective does NOT include:

- Menu bar icon, popover, or command input (Objective 1)
- CLI execution or streaming output (Objective 1)
- Event protocol parsing or toast rendering (Objective 2)
- Skills directory structure, format, or browse/star/run UI (Objective 3)
- Safety confirmations or stop/cancel (Objective 5)
- Activity log (Objective 5)
- Icon customization (Objective 5)

## Dependencies

- Depends on: Objective 1 (CLI execution), Objective 2 (event protocol and toasts for reporting back), Objective 3 (skills directory, format, and run UI)
- Feeds into: Objective 5

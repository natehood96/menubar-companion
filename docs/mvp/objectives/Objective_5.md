# Objective 5: Safety, Persistence & Polish

## Overview

This order wraps up the MVP with safety guardrails, a complete persistence layer, and icon customization. It adds confirmation flows for dangerous actions, a stop/cancel button for running skills, a basic activity log, the icon preset selector, and ensures all user data (starred skills, ordering, settings, history) is stored locally and resiliently. By the end of this order, the app is safe, polished, and ready to ship.

## Objectives

### 5.1 Safety & Transparency

- When a skill triggers external side effects (send email, delete files, etc.), Menu-Bot should:
  - Display what it's about to do (human-readable)
  - Require a confirm step unless the skill is explicitly marked "safe to auto-run"
- Include a **Stop** / **Cancel** for a running skill

### 5.2 Activity Log

- Provide a simple **activity log** of recent runs (even a basic list in v1)

### 5.3 Icon Customization & Full Persistence

- **Customizable icon**: Users can choose from a set of preset icon options (e.g., blob, ghost, cat, robot, star buddy) via a preferences/settings view
  - Selected icon is persisted in UserDefaults
  - Swapped at runtime via `statusBarItem.button?.image`

**Full persistence layer — store locally:**
- Starred skills
- Skill ordering/groups (if implemented)
- Scheduling settings
- Recent runs (basic history)
- Selected menu bar icon preference

Storage should be local, simple, and resilient.

**Tech stack applicable to this objective:**

| Layer | Technology |
|---|---|
| Local storage | UserDefaults and/or JSON files; optional SQLite/CoreData only if needed |

## Acceptance Criteria

- [ ] User can change the menu bar icon from a set of presets in settings

## Scope Boundary

This objective does NOT include:

- Menu bar shell, popover, or command input (Objective 1)
- CLI execution or streaming output (Objective 1)
- Event protocol parsing or toast rendering (Objective 2)
- Skills directory, format, discovery, or browse/star/run UI (Objective 3)
- Context injection or preinstalled skills (Objective 4)
- Scheduling logic (Objective 4)

## Non-Goals (from source, apply to all objectives)

- Cross-platform support (Windows/Linux) — macOS only
- Fully autonomous "control the entire OS" agent (mouse/keyboard control) — future scope
- Full marketplace / cloud sync for skills — local skills only

## Future Enhancements (Post-MVP, from source)

- OS-level control (mouse/keyboard) via Accessibility APIs (requires strong guardrails)
- Browser automation (Playwright) for reliable "do it for me" web tasks
- Skill marketplace / cloud sync
- Cross-platform support

## Dependencies

- Depends on: Objective 1, Objective 2, Objective 3, Objective 4
- Feeds into: None (this is the final order)

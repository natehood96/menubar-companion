# Objective 3: Skills Library & Management

## Overview

This order builds the full skills system — the dedicated local skills directory, the skill file format and metadata spec, runtime discovery, and the browse/star/run UI. It also includes the "bridge" skill that connects Menu-Bot to Claude Code. By the end of this order, users can add skill files to a folder and immediately browse, star, and run them from the popover without rebuilding the app.

## Objectives

### 3.1 Skills Directory & Discovery

- Menu-Bot maintains its own dedicated skills directory:
  `~/Library/Application Support/MenuBot/skills/`
- Skills are defined as files in that folder and are discoverable at runtime (no rebuild required)
- User can add a new skill file to the skills folder and it appears in the UI without rebuilding

### 3.2 Skill Format & Metadata

Skills must support:
- Name
- Description
- Optional: category/tags, icon, suggested schedule, required permissions

Skills must support prompt templates with variables:
- `{extra_instructions}`
- `{context.screenshot}`
- `{context.clipboard}`
- `{context.active_app}`

### 3.3 Skills Browse, Star & Run UI

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

### 3.4 Bridge Skill

- A "bridge" Claude Code skill is used that:
  - Instructs Claude Code to scan the Menu-Bot skills directory
  - Defines how Claude Code communicates back to Menu-Bot (see Event Protocol in Objective 2)
- The user's main Claude Code skills remain untouched; Menu-Bot uses its own contained skills model

## Acceptance Criteria

- [ ] User can open the popover and view starred skills
- [ ] User can open the popover and open the skills browser
- [ ] User can add a new skill file to the skills folder and it appears in the UI without rebuilding

## Scope Boundary

This objective does NOT include:

- The popover shell or command input (Objective 1)
- Claude Code CLI execution (Objective 1)
- Event protocol parsing or toast rendering (Objective 2)
- Context injection toggles (Objective 4)
- Preinstalled skills / default skill content (Objective 4)
- Scheduling (Objective 4)
- Safety confirmations, stop/cancel, or activity log (Objective 5)
- Persistence of starred skills and ordering (wired in Objective 5, but the starring UI interaction lives here)

## Dependencies

- Depends on: Objective 1 (CLI execution for running skills), Objective 2 (event protocol for skill output)
- Feeds into: Objective 4, Objective 5

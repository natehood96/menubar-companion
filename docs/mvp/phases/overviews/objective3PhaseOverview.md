# Phase 3: Skills Library & Management — Implementation Overview

> **Objective:** [Objective 3](../objectives/Objective_3.md)
> **Depends on:** Phase 1 (CLI execution), Phase 2 (event protocol)
> **Feeds into:** Phase 4, Phase 5

---

## Summary

Phase 3 builds the full skills system: a local skills directory with runtime discovery, a skill file format with metadata and prompt templates, a browse/star/run UI, and the bridge skill that connects Menu-Bot to Claude Code. After this phase, users can drop skill files into a folder and immediately browse, star, and run them from the popover.

---

## Implementation Phases

### 3A — Skill File Format & Data Model

**Goal:** Define the skill file spec and Swift model so the rest of the phase has a concrete type to work with.

**Tasks:**

1. Define the skill file format (JSON or YAML) with required and optional fields:
   - `name` (String, required)
   - `description` (String, required)
   - `prompt` (String, required — the prompt template)
   - `category` (String, optional)
   - `tags` ([String], optional)
   - `icon` (String, optional — SF Symbol name or emoji)
   - `suggested_schedule` (String, optional)
   - `required_permissions` ([String], optional)
2. Define prompt template variable syntax and supported variables:
   - `{extra_instructions}`, `{context.screenshot}`, `{context.clipboard}`, `{context.active_app}`
3. Create `Skill` Swift model (`Codable` struct) that maps to the file format
4. Create `SkillMetadata` or extend `Skill` with runtime properties: `isStarred`, `filePath`
5. Write unit tests for skill file parsing (valid, malformed, missing fields)

**Key decisions:**
- **File format:** JSON is simpler and avoids a YAML dependency. Recommend `.menubotskill.json` extension or simply `.json` files in the skills directory.
- **Template engine:** Simple string replacement (`{var}` → value) is sufficient for v1. No need for a full template engine.

**Output:** `Skill.swift` model, file format documentation, parsing tests.

---

### 3B — Skills Directory & Runtime Discovery

**Goal:** Menu-Bot watches `~/Library/Application Support/MenuBot/skills/` and discovers skill files at runtime without requiring a rebuild.

**Tasks:**

1. Create `SkillsDirectoryManager` (or similar) that:
   - Creates the skills directory on first launch if it doesn't exist
   - Scans the directory for skill files and parses them into `[Skill]`
   - Watches the directory for changes using `DispatchSource.makeFileSystemObjectSource` or `FileManager` polling
2. Emit skill list updates via a `@Published` property or Combine publisher so the UI reacts to changes
3. Handle edge cases:
   - Malformed skill files (log warning, skip file)
   - Empty directory (show empty state in UI)
   - File added/removed/modified while app is running
4. Write unit tests for directory scanning and change detection

**Key decisions:**
- **File watching:** `DispatchSource` (kqueue-based) is lightweight and doesn't require extra dependencies. Falls back to polling on scan if kqueue misses an event.
- **Skill identity:** Use the file path (or filename) as the stable identity key for diffing.

**Output:** `SkillsDirectoryManager.swift`, directory creation logic, file watcher, tests.

---

### 3C — Skills Browse & Star UI

**Goal:** Build the "All Skills" browser view and the starring interaction.

**Tasks:**

1. Create `SkillsListView` — the "All Skills" browser:
   - Lists all discovered skills
   - Each row shows: name, short description, optional icon, star toggle
   - Optional: group by category/tag (simple section headers)
   - Search/filter bar (nice-to-have for v1, can defer)
2. Create `SkillDetailView` — the "Run Skill" screen:
   - Shows full skill description
   - "Extra instructions" text input field
   - "Run" button
3. Wire starring interaction:
   - Tap star icon to toggle starred state
   - Starred skills appear in the main popover's "Starred Skills" section (placeholder from Phase 1)
   - Starred state stored in-memory for now (persistence wired in Phase 5)
4. Wire the "All Skills" button in the popover (placeholder from Phase 1) to navigate to `SkillsListView`
5. Wire the "Starred Skills" section in the popover to show starred skills with tap-to-run

**Key decisions:**
- **Navigation:** Use SwiftUI `NavigationStack` or sheet presentation within the popover. Keep transitions lightweight — the popover is small.
- **Star storage (v1):** In-memory `Set<String>` of skill filenames on the view model. Phase 5 persists to UserDefaults.

**Output:** `SkillsListView.swift`, `SkillDetailView.swift`, updated `PopoverView.swift`, starring logic in view model.

---

### 3D — Skill Execution

**Goal:** Running a skill from the UI invokes Claude Code CLI with the skill's prompt (plus any extra instructions).

**Tasks:**

1. Add a `runSkill(_ skill: Skill, extraInstructions: String?)` method to `PopoverViewModel` (or a dedicated `SkillRunner`):
   - Assembles the final prompt from the skill template + extra instructions
   - Performs variable substitution for `{extra_instructions}` (context variables are Phase 4)
   - Calls the existing `CommandRunner` to execute via Claude Code CLI
2. Show the same running/streaming/completion UI from Phase 1 when a skill is executing
3. Handle the "Run" button tap in `SkillDetailView` to trigger execution
4. Handle skill execution from the starred skills section (tap → run with no extra instructions, or tap → open detail view)

**Key decisions:**
- **Prompt assembly:** Concatenate skill prompt with extra instructions. Strip unused `{context.*}` variables for now (they become live in Phase 4).
- **Reuse CommandRunner:** No new execution path needed — skills are just pre-written prompts.

**Output:** Skill execution wiring, prompt template substitution, integration with existing `CommandRunner`.

---

### 3E — Bridge Skill

**Goal:** Create the bridge skill file that instructs Claude Code how to interact with Menu-Bot's skills system.

**Tasks:**

1. Create the bridge skill file (ships in the skills directory):
   - Instructs Claude Code to scan the Menu-Bot skills directory
   - Defines the `[MENUBOT_EVENT]` protocol for reporting back (references Phase 2)
   - Provides Claude Code with the skills directory path
2. Ensure the bridge skill is placed in the skills directory on first launch (alongside directory creation in 3B)
3. Test end-to-end: run bridge skill → Claude Code reads skills directory → emits events → Menu-Bot renders toast

**Key decisions:**
- **Bridge as a regular skill file:** The bridge skill is just another `.json` skill file in the directory. It can be hidden from the UI or marked with a special `"system": true` flag.
- **Scope:** The bridge skill tells Claude Code *about* the skills system. It doesn't replace the normal skill execution flow.

**Output:** Bridge skill file, first-launch placement logic, end-to-end test.

---

## File Map (Expected New/Modified Files)

| File | Phase | Description |
|---|---|---|
| `Core/Skill.swift` | 3A | Skill model and file parsing |
| `Core/SkillsDirectoryManager.swift` | 3B | Directory scanning and file watching |
| `UI/SkillsListView.swift` | 3C | All Skills browser view |
| `UI/SkillDetailView.swift` | 3C | Run Skill detail view |
| `UI/PopoverView.swift` | 3C | Wire starred skills + All Skills navigation |
| `UI/PopoverViewModel.swift` | 3C, 3D | Starred state, skill execution |
| `Resources/bridge-skill.json` | 3E | Bridge skill file |
| `Tests/SkillParsingTests.swift` | 3A | Skill file parsing tests |
| `Tests/SkillsDirectoryTests.swift` | 3B | Directory scanning tests |

---

## Acceptance Criteria Mapping

| Criterion | Phase |
|---|---|
| User can open the popover and view starred skills | 3C |
| User can open the popover and open the skills browser | 3C |
| User can add a new skill file to the skills folder and it appears in the UI without rebuilding | 3B, 3C |

---

## Risks & Open Questions

1. **Popover size constraints:** The skills browser needs to fit within the popover's dimensions. May need to adjust popover size or use a sheet/separate window for the full browser.
2. **File watching reliability:** `DispatchSource` kqueue doesn't always catch nested changes. A periodic re-scan (e.g., every 5s when popover opens) is a safe fallback.
3. **Skill file format stability:** Changing the format later means migrating existing files. Keep v1 minimal and extensible (extra fields are ignored by default with `Codable`).
4. **Bridge skill scope:** The bridge skill's exact prompt content depends on how Claude Code will be instructed. Draft the prompt early and iterate based on real Claude Code behavior.

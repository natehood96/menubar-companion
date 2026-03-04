# Phase 3.5 — Skill Format Migration (JSON → Directory + Markdown)

- **Phase Number:** 3.5
- **Phase Name:** Skill Format Migration
- **Source:** docs/mvp/objectives/Objective_3.md

---

## 🤖 AI Agent Execution Instructions

> **READ THIS ENTIRE DOCUMENT BEFORE STARTING ANY WORK.**
>
> Once you have read and understood the full document:
>
> 1. Execute each task in order
> 2. After completing a task, come back to this document and add a ✅ checkmark emoji to that task's title
> 3. If you are interrupted or stop mid-execution, the checkmarks show exactly where you left off
> 4. Do NOT check off a task until the work is fully complete
> 5. If you need to reference another doc, b/c the doc you're currently referencing doesn't have the right info you need to fill out the task, check neighboring docs in the same folder to see if you can find the information you're looking for there.

---

## 📋 Task Tracking Instructions

- Tasks use checkboxes
- Engineer checks off each task title with a ✅ emoji AFTER completing the work
- Engineer updates as they go
- Phase cannot advance until checklist complete
- If execution stops, checkmarks indicate progress

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Migrates the skill file format from single `.json` files to a directory-per-skill structure with `skill.json` (metadata) + `prompt.md` (prompt template). This aligns with the Claude Code skills pattern where markdown is the prompt and structured metadata is separate.
- **What already exists from Phase 3:** `Skill.swift` model with Codable JSON parsing (prompt embedded in JSON), `SkillsDirectoryManager.swift` scanning for `.json` files, `SkillsListView.swift`, `SkillDetailView.swift`, `PopoverView.swift` with NavigationStack and starred skills, `PopoverViewModel.swift` with skill execution. Two bundled resource files: `bridge-skill.json` and `sample-skill.json`.
- **What future phases depend on this:** Phase 4 will create preinstalled skill directories (`morning-brief/`, `create-new-skill/`, `find-file/`) using this new format. Phase 4 template variable substitution operates on the `prompt.md` content.

---

## 0. Mental Model (Required)

**Problem:** Phase 3 stores skills as single `.json` files where the prompt template is a JSON string value. This is awkward — prompt templates are natural language with formatting, line breaks, and markdown structure. Embedding them as escaped JSON strings is hard to author and hard to read. Claude Code uses a pattern where each skill is a directory with a markdown file as the prompt, and this is the direction we want to follow.

**Where it fits:** Phase 3.5 is a targeted refactor between Phase 3 (skills system) and Phase 4 (context injection, preinstalled skills, scheduling). It changes the on-disk format and the parsing layer without changing UI behavior. After this phase, the app works identically from the user's perspective, but skills are now directories with markdown prompts instead of flat JSON files.

**Data flow (after migration):**
1. User creates a skill directory in `~/Library/Application Support/MenuBot/skills/my-skill/`
2. Inside the directory: `skill.json` (name, description, icon, category, tags, metadata) and `prompt.md` (the actual prompt template)
3. `SkillsDirectoryManager` scans for subdirectories containing `skill.json`, parses metadata, reads `prompt.md` as a raw string
4. The `Skill` model holds the parsed metadata + the prompt string from the markdown file
5. Everything downstream (UI, execution, starring) works exactly as before

**Core entities:**
- **`Skill`** — struct updated: `prompt` is no longer decoded from JSON, it's read from `prompt.md`
- **`SkillsDirectoryManager`** — scanning logic updated: looks for subdirectories with `skill.json` instead of `.json` files
- **`skill.json`** — metadata only (no `prompt` field)
- **`prompt.md`** — the prompt template, plain markdown with `{extra_instructions}` and `{context.*}` variables

**New directory structure:**
```
~/Library/Application Support/MenuBot/skills/
├── bridge-skill/
│   ├── skill.json        # {"name": "Menu-Bot Bridge", "system": true, ...}
│   └── prompt.md         # The bridge prompt template
├── summarize-clipboard/
│   ├── skill.json        # {"name": "Summarize Clipboard", ...}
│   └── prompt.md         # Summarize the following content...
```

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Migrate the skill format from single `.json` files to directory-per-skill with `skill.json` metadata + `prompt.md` template, without changing any user-facing behavior.

### Prerequisites

- Phase 3 complete: `Skill.swift`, `SkillsDirectoryManager.swift`, `SkillsListView.swift`, `SkillDetailView.swift`, `PopoverView.swift`, `PopoverViewModel.swift` all exist and function
- Two bundled resource files exist: `Resources/bridge-skill.json`, `Resources/sample-skill.json`
- Xcode project builds and runs successfully

### Key Deliverables

- Updated `Skill` model that loads metadata from `skill.json` and prompt from `prompt.md`
- Updated `SkillsDirectoryManager` that scans subdirectories instead of `.json` files
- Migrated bundled resources: `Resources/bridge-skill/skill.json` + `Resources/bridge-skill/prompt.md` (same for sample skill)
- Updated Xcode project references for the new resource structure

### System-Level Acceptance Criteria

- Existing UI behavior is unchanged — browse, star, run all work the same
- Skills are loaded from subdirectory format only — flat `.json` files in the skills root are ignored
- A skill directory missing `prompt.md` is skipped with a console warning
- A skill directory missing `skill.json` is skipped with a console warning
- Malformed `skill.json` is skipped with a console warning (no crash)
- The bridge skill is placed as a directory on first launch
- App builds and runs without warnings or errors

---

## 2. Execution Order

### Blocking Tasks (Sequential Critical Path)

1. **Task 3.5.1** — Update `Skill` model and loading logic
2. **Task 3.5.2** — Update `SkillsDirectoryManager` scanning
3. **Task 3.5.3** — Migrate bundled resource files to directory format
4. **Task 3.5.4** — Update bridge skill placement logic
5. **Task 3.5.5** — End-to-end verification and cleanup

### Parallel Tasks

- Tasks 3.5.3 (resource files) and 3.5.4 (bridge placement) can be done together once 3.5.2 is complete.

### Final Integration

- Verify: drop a skill directory into `~/Library/Application Support/MenuBot/skills/` → appears in UI → star it → run it → output streams
- Verify: bridge skill directory is placed on first launch
- Verify: old flat `.json` files in the skills root are ignored (not loaded)
- Verify: malformed skill directories are skipped gracefully

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Prompt file format | `.md` vs `.txt` vs `.prompt` | `.md` (Markdown) | Aligns with Claude Code convention. Prompts are natural language with formatting. Markdown is universally understood. | None |
| Metadata filename | `skill.json` vs `metadata.json` vs `manifest.json` | `skill.json` | Clear, concise, matches the concept. Claude Code uses `SKILL.md` — we use `skill.json` for metadata since we need structured data for the UI. | None |
| Backward compatibility with flat `.json` | Support both vs directory-only | Directory-only | Clean break. Phase 3 is internal, no external users yet. Simpler code. | None — no users to migrate |
| Skill identity | Filename vs directory name | Directory name (without path) | Stable, human-readable, matches the "each skill is a directory" model. | Low — duplicate directory names would conflict |

---

## 4. Subtasks

### ✅ Task 3.5.1 — Update Skill Model & Loading Logic

#### User Story

As a developer, I need the `Skill` model to load metadata from `skill.json` and the prompt template from a separate `prompt.md` file, so prompts can be authored as natural markdown.

#### Implementation Steps

1. **Modify `Core/Skill.swift`** — Remove `prompt` from `CodingKeys` and JSON decoding. Make `prompt` a `var` that is set after decoding:

```swift
import Foundation

struct Skill: Identifiable, Equatable {
    // Metadata (from skill.json)
    let name: String
    let description: String
    let category: String?
    let tags: [String]?
    let icon: String?
    let suggestedSchedule: String?
    let requiredPermissions: [String]?
    let system: Bool?

    // Prompt template (from prompt.md)
    var prompt: String

    // Runtime properties
    var id: String { directoryName ?? name }
    var directoryName: String?
    var isStarred: Bool = false
}
```

2. **Create a separate `SkillMetadata` Codable struct** for JSON decoding:

```swift
// MARK: - JSON Metadata Decoding

struct SkillMetadata: Codable {
    let name: String
    let description: String
    let category: String?
    let tags: [String]?
    let icon: String?
    let suggestedSchedule: String?
    let requiredPermissions: [String]?
    let system: Bool?

    enum CodingKeys: String, CodingKey {
        case name, description, category, tags, icon
        case suggestedSchedule = "suggested_schedule"
        case requiredPermissions = "required_permissions"
        case system
    }
}
```

3. **Update `Skill.load(from:)`** to accept a directory URL:

```swift
// MARK: - Directory Loading

extension Skill {
    /// Load a skill from a directory containing skill.json and prompt.md
    static func load(from directoryURL: URL) throws -> Skill {
        let metadataURL = directoryURL.appendingPathComponent("skill.json")
        let promptURL = directoryURL.appendingPathComponent("prompt.md")

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(SkillMetadata.self, from: metadataData)

        let prompt = try String(contentsOf: promptURL, encoding: .utf8)

        var skill = Skill(
            name: metadata.name,
            description: metadata.description,
            category: metadata.category,
            tags: metadata.tags,
            icon: metadata.icon,
            suggestedSchedule: metadata.suggestedSchedule,
            requiredPermissions: metadata.requiredPermissions,
            system: metadata.system,
            prompt: prompt
        )
        skill.directoryName = directoryURL.lastPathComponent
        return skill
    }
}
```

4. **Keep `Hashable` conformance** using `id` (now based on `directoryName`).

5. **Keep `assemblePrompt()` unchanged** — it operates on the `prompt` string regardless of where it came from.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/Skill.swift` | Modify | Remove prompt from JSON, add SkillMetadata Codable, update load() to read directory, rename filePath to directoryName |

#### Acceptance Criteria

- [ ] `Skill` struct no longer decodes `prompt` from JSON
- [ ] `SkillMetadata` Codable struct decodes `skill.json` correctly
- [ ] `Skill.load(from:)` reads `skill.json` and `prompt.md` from a directory URL
- [ ] Missing `skill.json` throws a clear error
- [ ] Missing `prompt.md` throws a clear error
- [ ] `assemblePrompt()` still substitutes `{extra_instructions}` and strips `{context.*}` variables
- [ ] `id` is now based on `directoryName`
- [ ] Hashable conformance still works for NavigationStack

---

### ✅ Task 3.5.2 — Update SkillsDirectoryManager Scanning

#### User Story

As a user, I want to drop a skill directory (containing `skill.json` + `prompt.md`) into the skills folder and have it appear in the UI automatically.

#### Implementation Steps

1. **Modify `Core/SkillsDirectoryManager.swift`** — Update `scan()` to iterate subdirectories instead of `.json` files:

```swift
func scan() {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
        at: Self.skillsDirectoryURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        skills = []
        return
    }

    let parsed = contents
        .filter { url in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            return isDir.boolValue
        }
        .compactMap { dirURL -> Skill? in
            do {
                return try Skill.load(from: dirURL)
            } catch {
                print("[SkillsDirectoryManager] Failed to load skill from \(dirURL.lastPathComponent): \(error)")
                return nil
            }
        }
        .filter { $0.system != true }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    self.skills = parsed
}
```

2. **Update `ensureBridgeSkillExists()`** — see Task 3.5.4.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/SkillsDirectoryManager.swift` | Modify | Update scan() to iterate subdirectories containing skill.json + prompt.md |

#### Acceptance Criteria

- [ ] `scan()` finds skill directories (not flat `.json` files)
- [ ] Each subdirectory with `skill.json` + `prompt.md` is parsed into a `Skill`
- [ ] Subdirectories missing `skill.json` or `prompt.md` are skipped with a console warning
- [ ] Flat `.json` files in the skills root directory are ignored
- [ ] System skills (`"system": true`) are still filtered out of the browseable list
- [ ] File watcher still triggers re-scan on directory changes

---

### ✅ Task 3.5.3 — Migrate Bundled Resource Files

#### User Story

As a developer, I need the bundled skill resources converted from flat JSON files to directory format so they match the new skill structure.

#### Implementation Steps

1. **Delete** `MenuBarCompanion/Resources/bridge-skill.json` and `MenuBarCompanion/Resources/sample-skill.json`

2. **Create** `MenuBarCompanion/Resources/bridge-skill/skill.json`:

```json
{
    "name": "Menu-Bot Bridge",
    "description": "Connects Claude Code to the Menu-Bot skills system. Instructs Claude Code to scan the skills directory and communicate results back via the event protocol.",
    "category": "System",
    "tags": ["bridge", "system"],
    "icon": "link",
    "system": true
}
```

3. **Create** `MenuBarCompanion/Resources/bridge-skill/prompt.md`:

```markdown
You are interacting with Menu-Bot, a macOS menu bar companion app. Menu-Bot has a skills directory at ~/Library/Application Support/MenuBot/skills/ containing skill directories. Each skill directory has a skill.json (metadata) and prompt.md (prompt template).

Your task:
1. Scan the skills directory and list all available skills
2. For each skill, report its name and description
3. Use the [MENUBOT_EVENT] protocol to communicate results back to Menu-Bot

To send an event, output a line in this exact format:
[MENUBOT_EVENT] {"type":"toast","title":"Skills Found","message":"Found N skills in the directory"}

{extra_instructions}
```

4. **Create** `MenuBarCompanion/Resources/sample-skill/skill.json`:

```json
{
    "name": "Summarize Clipboard",
    "description": "Summarize whatever is currently on the clipboard.",
    "category": "Productivity",
    "tags": ["clipboard", "summary"],
    "icon": "doc.on.clipboard"
}
```

5. **Create** `MenuBarCompanion/Resources/sample-skill/prompt.md`:

```markdown
Summarize the following content concisely:

{context.clipboard}

{extra_instructions}
```

6. **Update Xcode project** — Remove old `.json` file references. Add the new directories as **folder references** so both files in each directory are included in "Copy Bundle Resources."

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/bridge-skill.json` | Delete | Old flat format |
| `MenuBarCompanion/Resources/sample-skill.json` | Delete | Old flat format |
| `MenuBarCompanion/Resources/bridge-skill/skill.json` | Create | Bridge skill metadata |
| `MenuBarCompanion/Resources/bridge-skill/prompt.md` | Create | Bridge skill prompt template |
| `MenuBarCompanion/Resources/sample-skill/skill.json` | Create | Sample skill metadata |
| `MenuBarCompanion/Resources/sample-skill/prompt.md` | Create | Sample skill prompt template |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Update bundle resource references |

#### Acceptance Criteria

- [ ] Old flat `.json` resource files are removed from the project
- [ ] New skill directories exist under `Resources/` with `skill.json` + `prompt.md` each
- [ ] Both directories are included in the "Copy Bundle Resources" build phase
- [ ] `Bundle.main.url(forResource:withExtension:subdirectory:)` can locate the new resources at runtime

---

### ✅ Task 3.5.4 — Update Bridge Skill Placement Logic

#### User Story

As the system, I need to copy the bridge skill directory (not a single file) from the app bundle to the user's skills directory on first launch.

#### Implementation Steps

1. **Modify `ensureBridgeSkillExists()` in `SkillsDirectoryManager.swift`**:

```swift
private func ensureBridgeSkillExists() {
    let bridgeDirURL = Self.skillsDirectoryURL.appendingPathComponent("bridge-skill")
    let fm = FileManager.default

    // Skip if directory already exists
    guard !fm.fileExists(atPath: bridgeDirURL.path) else { return }

    // Copy from bundle
    if let bundledURL = Bundle.main.url(forResource: "bridge-skill", withExtension: nil) {
        do {
            try fm.copyItem(at: bundledURL, to: bridgeDirURL)
        } catch {
            print("[SkillsDirectoryManager] Failed to copy bridge skill: \(error)")
        }
    }
}
```

2. **Also place the sample skill** on first launch (add a similar method `ensureSampleSkillExists()`):

```swift
private func ensureSampleSkillExists() {
    let sampleDirURL = Self.skillsDirectoryURL.appendingPathComponent("sample-skill")
    let fm = FileManager.default
    guard !fm.fileExists(atPath: sampleDirURL.path) else { return }
    if let bundledURL = Bundle.main.url(forResource: "sample-skill", withExtension: nil) {
        try? fm.copyItem(at: bundledURL, to: sampleDirURL)
    }
}
```

3. **Call both from `init()`** after `ensureDirectoryExists()` and before `scan()`.

4. **Clean up old flat bridge-skill.json** — If the user's skills directory has a leftover `bridge-skill.json` from Phase 3, remove it during the migration:

```swift
private func cleanupLegacyFiles() {
    let legacyBridge = Self.skillsDirectoryURL.appendingPathComponent("bridge-skill.json")
    let legacySample = Self.skillsDirectoryURL.appendingPathComponent("sample-skill.json")
    let fm = FileManager.default
    if fm.fileExists(atPath: legacyBridge.path) {
        try? fm.removeItem(at: legacyBridge)
    }
    if fm.fileExists(atPath: legacySample.path) {
        try? fm.removeItem(at: legacySample)
    }
}
```

Call `cleanupLegacyFiles()` from `init()` before `ensureBridgeSkillExists()`.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/SkillsDirectoryManager.swift` | Modify | Update bridge/sample placement to copy directories, add legacy cleanup |

#### Acceptance Criteria

- [ ] Bridge skill is placed as a directory (`bridge-skill/skill.json` + `bridge-skill/prompt.md`) on first launch
- [ ] Sample skill is placed as a directory on first launch
- [ ] Existing directories are not overwritten on subsequent launches
- [ ] Legacy flat `.json` files (`bridge-skill.json`, `sample-skill.json`) are cleaned up from the skills directory
- [ ] The bridge skill does NOT appear in the All Skills browser (still filtered by `system: true`)

---

### ✅ Task 3.5.5 — Update PopoverViewModel and Verify End-to-End

#### User Story

As the engineer, I need to verify that the `PopoverViewModel` skill references (starring, running, identity) all work correctly with the new directory-based `id` (which is now `directoryName` instead of `filePath`).

#### Implementation Steps

1. **Review `PopoverViewModel.swift`** — The `starredSkillIDs` Set uses `skill.id`. Since `id` changed from `filePath` (filename) to `directoryName` (directory name), verify that starring still works. No code change should be needed since both are strings, but the identity values change.

2. **Review `PopoverView.swift`** — `NavigationStack` uses `Skill` as a navigation destination. `Skill` is `Hashable` via `id`. Verify navigation still works.

3. **Review `SkillDetailView.swift`** — Uses `skill.name`, `skill.description`, `skill.prompt` (via `assemblePrompt()`). No changes needed since `prompt` is still a String property.

4. **Build and run the app.** Verify:
   - Popover opens and shows starred skills section
   - "All Skills" shows discovered skills from directory format
   - Tapping a skill navigates to detail view
   - Running a skill streams output
   - Star toggle works

5. **Manual test — drop a new skill directory:**
   - Create `~/Library/Application Support/MenuBot/skills/test-skill/`
   - Add `skill.json`: `{"name": "Test", "description": "A test skill", "icon": "star"}`
   - Add `prompt.md`: `Say hello! {extra_instructions}`
   - Verify it appears in the UI

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/PopoverViewModel.swift` | Review (likely no changes) | Verify skill identity works with directoryName |
| `MenuBarCompanion/UI/PopoverView.swift` | Review (likely no changes) | Verify NavigationStack works |
| `MenuBarCompanion/UI/SkillDetailView.swift` | Review (likely no changes) | Verify prompt display and execution |
| `MenuBarCompanion/UI/SkillsListView.swift` | Review (likely no changes) | Verify skill list rendering |

#### Acceptance Criteria

- [ ] App builds with zero errors
- [ ] Starred skills section renders correctly
- [ ] All Skills browser shows skills from directory format
- [ ] Skill detail view shows correct name, description, and prompt-derived output
- [ ] Running a skill executes the prompt from `prompt.md`
- [ ] Dropping a new skill directory into the skills folder triggers discovery
- [ ] Old flat `.json` files in the skills root are silently ignored
- [ ] Bridge skill is auto-placed as a directory and hidden from the browser
- [ ] No regressions to raw command input/output

---

## 5. Integration Points

- **`CommandRunner` (Phase 1):** No changes. Receives assembled prompt string as before.
- **`EventParser` (Phase 2):** No changes. Parses `[MENUBOT_EVENT]` lines from output as before.
- **`PopoverViewModel` (Phase 3):** Minor impact — `skill.id` values change from filename to directory name. Starring set keys change but behavior is identical.
- **Filesystem:** Same directory `~/Library/Application Support/MenuBot/skills/`. Now reads subdirectories instead of flat files.
- **Bundle resources:** Skill directories must be added as folder references in Xcode "Copy Bundle Resources" build phase.
- **Phase 4 dependency:** Phase 4's preinstalled skills and first-run seeding will use the new directory format. Phase 4's template substitution operates on the `prompt` string which is now read from `prompt.md`.

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

| Test File | Tests |
|-----------|-------|
| `Tests/SkillParsingTests.swift` | Update existing tests: valid directory loading, missing prompt.md, missing skill.json, malformed skill.json, prompt substitution still works |
| `Tests/SkillsDirectoryTests.swift` | Update existing tests: scanning subdirectories, ignoring flat files, system skill filtering with new format |

### During Implementation: Build Against Tests

- Update `Skill.load(from:)` tests to use temp directories with `skill.json` + `prompt.md`
- Verify `assemblePrompt()` tests still pass (no changes to substitution logic)
- Verify directory scanning tests use subdirectories instead of flat files

### Phase End: Polish Tests

- Edge cases: empty `prompt.md`, very long prompt, special characters, directory with only `skill.json` (no prompt), directory with only `prompt.md` (no metadata)
- Remove any Phase 3 tests that reference the old flat JSON format
- Ensure all tests pass with `xcodebuild test`

---

## 7. Definition of Done

- [ ] `Skill` model loads metadata from `skill.json` and prompt from `prompt.md`
- [ ] `SkillsDirectoryManager` scans subdirectories, not flat files
- [ ] Bundled resources are directory format (`bridge-skill/`, `sample-skill/`)
- [ ] Bridge skill is placed as a directory on first launch
- [ ] Legacy flat `.json` files are cleaned up from the skills directory
- [ ] All existing UI behavior unchanged (browse, star, run)
- [ ] Unit tests updated and passing
- [ ] No regressions to raw command input/output
- [ ] App builds and runs without warnings or errors

### Backward Compatibility

No external backward compatibility concerns — Phase 3 had no public users. The only migration is cleaning up the legacy flat `.json` files from the user's skills directory (placed by Phase 3's first-launch logic). This is handled by `cleanupLegacyFiles()`.

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Phase 4 until all items below are verified.**

- [ ] **Build verification:** `xcodebuild build` succeeds with no errors
- [ ] **Test verification:** `xcodebuild test` — all unit tests pass
- [ ] **Manual test — skill discovery:** Create a skill directory in `~/Library/Application Support/MenuBot/skills/test-skill/` with `skill.json` + `prompt.md`. Open popover → tap "All Skills" → verify the skill appears.
- [ ] **Manual test — starring:** Star a skill → verify it appears in the popover's Starred Skills section. Unstar → verify it disappears.
- [ ] **Manual test — skill execution:** Open a skill → add extra instructions → tap Run → verify output streams in popover using the prompt from `prompt.md`.
- [ ] **Manual test — malformed directory:** Create a directory with only `skill.json` (no `prompt.md`) → verify it is skipped (no crash, other skills still load).
- [ ] **Manual test — flat JSON ignored:** Drop a flat `.json` file into the skills root → verify it is NOT loaded as a skill.
- [ ] **Manual test — bridge skill:** Verify `bridge-skill/` directory exists in `~/Library/Application Support/MenuBot/skills/` after first launch with both `skill.json` and `prompt.md`. Verify it does NOT appear in the All Skills browser.
- [ ] **Manual test — legacy cleanup:** If `bridge-skill.json` exists in the skills directory from Phase 3, verify it is removed after launching the updated app.
- [ ] **Manual test — raw command:** Type a raw command in the input field → Run → verify output streams as before (no regression).
- [ ] **Signoff:** All Phase 3 acceptance criteria still pass with the new format.

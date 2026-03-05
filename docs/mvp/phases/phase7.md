# Phase 7 — System Integration & Polish

- **Phase Number:** 7
- **Phase Name:** System Integration & Polish
- **Source:** docs/mvp/phases/overviews/objective7PhaseOverview.md

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

- **What this phase accomplishes:** Wires Objectives 4-6 together into a cohesive system — extends bootstrap for new directories/skills/CLI tools, implements ordered startup sequence, adds Login Item support, consolidates permissions, and validates all end-to-end acceptance criteria.
- **What already exists:** `OrchestrationBootstrap.swift` creates `~/Library/Application Support/MenuBot/` with `skills/`, `doer-logs/`, seeds 3 default skills (`browse-web`, `create-skill`, `summarize-clipboard`), installs Playwright MCP. `AppDelegate.swift` calls `OrchestrationBootstrap.install()` then sets up the menu bar popover. `Skill.swift` and `SkillIndexEntry` handle skill loading from `skills-index.json` + `.md` files.
- **What future phases depend on this:** Nothing — this is the final objective. Everything must work end-to-end after this phase.

---

## 0. Mental Model (Required)

**Problem:** Objectives 4-6 each introduce independent subsystems (persistent sessions, memory, background jobs, credentials, screen vision, input control). Without explicit integration work, these subsystems won't start in the correct order, won't share permissions cleanly, and won't have their supporting files bootstrapped. The app needs to feel like one cohesive product, not a collection of features bolted together.

**Where it fits:** This is the final "glue" phase. It runs after all feature work (Obj 4-6) is complete. It doesn't introduce new capabilities — it ensures existing capabilities compose correctly and the app is production-ready.

**How data flows:**
1. App launches → `OrchestrationBootstrap.install()` creates all directories, seeds all 6 skills, installs CLI tools to `bin/`
2. `StartupSequence` executes 6 ordered steps: bootstrap → persistent session → job verification → memory load → credential check → emergency stop registration
3. When a feature needs a permission (Screen Recording, Accessibility), `PermissionsManager` shows a friendly explanation then triggers the system prompt
4. Login Item registration via `SMAppService` ensures the app starts on login

**Core entities:**
- `OrchestrationBootstrap` — extended with new directories, skills, CLI tool installation
- `StartupSequence` — new coordinator for ordered 6-step startup
- `PermissionsManager` — new centralizer for Screen Recording + Accessibility permissions
- `SettingsView` — new view with Login Item toggle
- `menubot-creds` — CLI tool for Keychain credential CRUD
- `menubot-input` — CLI tool for mouse/keyboard control via CGEvent

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Extend the bootstrap to provision all Objective 4-6 files and tools, implement an ordered startup sequence with Login Item support, consolidate permissions into a unified lazy-request flow, and validate all 8 end-to-end acceptance criteria.

### Prerequisites

- Objectives 4-6 subsystems implemented (or stubbed with protocol interfaces)
- `OrchestrationBootstrap.swift` exists and seeds 3 default skills
- `AppDelegate.swift` calls `OrchestrationBootstrap.install()` on launch
- `Skill.swift` with `SkillIndexEntry` Codable model exists
- `skills-index.json` with 3 entries exists in `Resources/skills/`
- macOS 13.0+ target (required for `SMAppService`)
- Sandbox disabled (required for Process execution and CLI tools)

### Key Deliverables

- Extended `OrchestrationBootstrap` with 7 new directories and 3 new skills
- `menubot-creds` CLI tool (Xcode command-line target)
- `menubot-input` CLI tool (Xcode command-line target)
- CLI tool installation logic in bootstrap
- `StartupSequence` coordinator with 6 ordered steps
- Login Item registration via `SMAppService.mainApp`
- `SettingsView` with "Start MenuBot at login" toggle
- `PermissionsManager` with lazy permission requests and friendly explanations
- All 8 end-to-end acceptance criteria validated

### System-Level Acceptance Criteria

- Bootstrap is idempotent — running multiple times never duplicates or corrupts data
- User-created skills survive bootstrap (merge logic preserves non-default entries)
- CLI tools are overwritten on every launch so app updates propagate
- Startup sequence failures are isolated — one failed step doesn't block others
- Permissions are requested lazily (first use), never at launch
- Permission denial is handled gracefully with no repeated prompts
- Accessibility permission is requested once and covers both screen metadata and input control
- Login Item defaults to enabled; toggle reflects real system state

---

## 2. Execution Order

### Blocking Tasks (Sequential)

1. **7A.1** — Create new directories in bootstrap
2. **7A.2** — Create 3 new skill `.md` resource files
3. **7A.3** — Update `skills-index.json` with all 6 skills
4. **7A.4** — Update `seedDefaultSkills()` to include new skill files
5. **7A.5** — Create `menubot-creds` CLI tool target
6. **7A.6** — Create `menubot-input` CLI tool target
7. **7A.7** — Add CLI tool installation logic to bootstrap
8. **7A.8** — Verify skill seeding preserves user-created skills
9. **7B.1-7B.2** — Implement StartupSequence coordinator
10. **7B.3-7B.4** — Login Item registration and toggle
11. **7B.5** — Settings view

### Parallel Tasks

- 7A.5 (`menubot-creds`) and 7A.6 (`menubot-input`) can be built in parallel
- 7C.1 (`PermissionsManager`) can begin once 7B is complete
- 7C.3 (permission explanation UI) and 7C.4 (denial handling) can be parallel

### Final Integration

- 7C.5 — End-to-end validation of all 8 acceptance criteria
- 7C.6 — Fix integration gaps discovered during E2E
- 7C.7 — UX principle review

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| CLI tool packaging | (A) Separate Xcode targets (B) Script-built Swift executables (C) Embedded in app bundle | A — Separate Xcode targets | Xcode manages compilation, signing, and bundling automatically; aligns with standard macOS practices | Project file complexity; must add new targets to `.xcodeproj` |
| Startup sequence pattern | (A) Sequential in AppDelegate (B) Dedicated coordinator class (C) Async/await task group | B — Dedicated `StartupSequence` class | Keeps AppDelegate clean; each step is testable independently; failures isolated per step | Slight over-abstraction for 6 steps, but worth it for testability |
| Permission management | (A) Per-feature inline checks (B) Centralized `PermissionsManager` | B — Centralized manager | Single source of truth for permission state; prevents duplicate prompts; consistent UX | Must wire into multiple feature code paths |
| Login Item API | (A) `SMAppService.mainApp` (B) `LSSharedFileList` (deprecated) (C) LaunchAgent plist | A — `SMAppService.mainApp` | Modern API for macOS 13+; our minimum target; no deprecation risk | Can silently fail; need graceful fallback |

---

## 4. Subtasks

### Task 7A.1 — Create New Directories in Bootstrap

#### User Story

As the app, I need to create all required subdirectories under `~/Library/Application Support/MenuBot/` so that Objectives 4-6 features have their expected file system structure on first launch.

#### Implementation Steps

1. Open `MenuBarCompanion/Core/OrchestrationBootstrap.swift`
2. In `install()`, after the existing directory creation block (lines 20-24), add creation of 7 new directories:

```swift
// New directories for Objectives 4-6
try? fm.createDirectory(at: menubotDir.appendingPathComponent("jobs", isDirectory: true), withIntermediateDirectories: true)
try? fm.createDirectory(at: menubotDir.appendingPathComponent("jobs/logs", isDirectory: true), withIntermediateDirectories: true)
try? fm.createDirectory(at: menubotDir.appendingPathComponent("memory", isDirectory: true), withIntermediateDirectories: true)
try? fm.createDirectory(at: menubotDir.appendingPathComponent("credentials", isDirectory: true), withIntermediateDirectories: true)
try? fm.createDirectory(at: menubotDir.appendingPathComponent("cache", isDirectory: true), withIntermediateDirectories: true)
try? fm.createDirectory(at: menubotDir.appendingPathComponent("cache/screenshots", isDirectory: true), withIntermediateDirectories: true)
try? fm.createDirectory(at: menubotDir.appendingPathComponent("bin", isDirectory: true), withIntermediateDirectories: true)
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modified | Add 7 new directory creation calls in `install()` |

#### Acceptance Criteria

- [ ] After app launch, `~/Library/Application Support/MenuBot/jobs/` exists
- [ ] After app launch, `~/Library/Application Support/MenuBot/jobs/logs/` exists
- [ ] After app launch, `~/Library/Application Support/MenuBot/memory/` exists
- [ ] After app launch, `~/Library/Application Support/MenuBot/credentials/` exists
- [ ] After app launch, `~/Library/Application Support/MenuBot/cache/` exists
- [ ] After app launch, `~/Library/Application Support/MenuBot/cache/screenshots/` exists
- [ ] After app launch, `~/Library/Application Support/MenuBot/bin/` exists
- [ ] Pre-existing directories (`skills/`, `doer-logs/`) are unaffected

---

### Task 7A.2 — Create New Skill Markdown Resource Files

#### User Story

As the orchestrator, I need 3 new skill prompt files bundled in the app so they can be seeded to the user's skills directory, enabling background job creation, computer control, and credential management features.

#### Implementation Steps

1. Create `MenuBarCompanion/Resources/skills/create-background-job.md` with a skill prompt that guides conversational background job creation. The prompt should:
   - Ask what the job should do
   - Ask about schedule (daily/weekly/hourly, what time)
   - Ask about delivery method (toast notification, clipboard, file)
   - Check if credentials are needed
   - Create the job via the job registry
   - Confirm success

2. Create `MenuBarCompanion/Resources/skills/computer-control.md` with a skill prompt for the vision-action loop:
   - Capture current screen state
   - Identify target UI elements
   - Plan actions (click, type, scroll)
   - Request user confirmation before executing
   - Execute actions via `menubot-input`
   - Verify result by re-capturing screen

3. Create `MenuBarCompanion/Resources/skills/manage-credentials.md` with a skill prompt for credential management:
   - List existing credentials
   - Guide user through adding new credentials (name, description, value)
   - Store via `menubot-creds` CLI
   - Delete credentials
   - Never display credential values in chat

4. Add all 3 files to the Xcode project under the `Resources/skills` group and ensure they're included in the app target's "Copy Bundle Resources" build phase.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/create-background-job.md` | Created | Skill prompt for guided background job creation |
| `MenuBarCompanion/Resources/skills/computer-control.md` | Created | Skill prompt for vision-action loop |
| `MenuBarCompanion/Resources/skills/manage-credentials.md` | Created | Skill prompt for credential CRUD |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add 3 new files to project and Copy Bundle Resources phase |

#### Acceptance Criteria

- [ ] `create-background-job.md` exists in `Resources/skills/` and is included in the bundle
- [ ] `computer-control.md` exists in `Resources/skills/` and is included in the bundle
- [ ] `manage-credentials.md` exists in `Resources/skills/` and is included in the bundle
- [ ] Each prompt is well-structured with clear instructions for the orchestrator

---

### Task 7A.3 — Update skills-index.json With All 6 Default Skills

#### User Story

As the bootstrap system, I need the bundled `skills-index.json` to include entries for all 6 default skills so that new installations get the complete skill set.

#### Implementation Steps

1. Open `MenuBarCompanion/Resources/skills/skills-index.json`
2. Add 3 new entries after the existing 3:

```json
[
  {
    "id": "browse-web",
    "name": "Browse Web",
    "description": "Use Playwright to browse websites, scrape data, fill forms, and interact with web pages.",
    "icon": "globe",
    "category": "Tools",
    "file": "browse-web.md"
  },
  {
    "id": "create-skill",
    "name": "Create New Skill",
    "description": "Create a new MenuBot skill by writing its markdown instructions and registering it in the skills index.",
    "icon": "plus.square",
    "category": "System",
    "file": "create-skill.md"
  },
  {
    "id": "summarize-clipboard",
    "name": "Summarize Clipboard",
    "description": "Summarize whatever text is currently on the clipboard.",
    "icon": "doc.on.clipboard",
    "category": "Productivity",
    "file": "summarize-clipboard.md"
  },
  {
    "id": "create-background-job",
    "name": "Create Background Job",
    "description": "Set up a new scheduled background job through a guided conversation — choose what it does, when it runs, and how it delivers results.",
    "icon": "clock.arrow.2.circlepath",
    "category": "Automation",
    "file": "create-background-job.md"
  },
  {
    "id": "computer-control",
    "name": "Computer Control",
    "description": "Control your mouse and keyboard to interact with any app on screen. Takes a screenshot, identifies UI elements, and performs actions with your confirmation.",
    "icon": "cursorarrow.click.2",
    "category": "Tools",
    "file": "computer-control.md"
  },
  {
    "id": "manage-credentials",
    "name": "Manage Credentials",
    "description": "Securely store, view, and manage API keys and service credentials in your macOS Keychain.",
    "icon": "key.fill",
    "category": "System",
    "file": "manage-credentials.md"
  }
]
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/skills-index.json` | Modified | Add 3 new skill entries (total: 6) |

#### Acceptance Criteria

- [ ] `skills-index.json` contains exactly 6 entries
- [ ] Each new entry has valid `id`, `name`, `description`, `icon`, `category`, and `file` fields
- [ ] The `file` values match the filenames created in Task 7A.2

---

### Task 7A.4 — Update seedDefaultSkills() for New Skill Files

#### User Story

As the bootstrap system, I need to copy the 3 new skill `.md` files to disk alongside the existing ones so users have all 6 default skills available.

#### Implementation Steps

1. Open `MenuBarCompanion/Core/OrchestrationBootstrap.swift`
2. In `seedDefaultSkills(to:)`, update the `defaultSkillFiles` array (line 58):

```swift
let defaultSkillFiles = [
    "browse-web", "create-skill", "summarize-clipboard",
    "create-background-job", "computer-control", "manage-credentials"
]
```

No other changes needed — the existing loop and merge logic handle the rest.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modified | Add 3 new skill names to `defaultSkillFiles` array |

#### Acceptance Criteria

- [ ] After bootstrap, all 6 `.md` skill files exist in `~/Library/Application Support/MenuBot/skills/`
- [ ] `skills-index.json` on disk contains all 6 default entries
- [ ] Existing user-created skills are preserved (not overwritten or removed)

---

### Task 7A.5 — Create menubot-creds CLI Tool

#### User Story

As a doer executing background jobs, I need a CLI tool to securely store and retrieve credentials from the macOS Keychain so that jobs can authenticate with external services without user interaction.

#### Implementation Steps

1. Create a new **Command Line Tool** target in Xcode named `menubot-creds`
   - Language: Swift
   - Framework: Foundation + Security
   - Product name: `menubot-creds`

2. Create `menubot-creds/main.swift` with the following commands:
   - `get <id>` — Retrieve credential value from Keychain, print to stdout
   - `set <id> --name "..." --description "..."` — Read value from stdin, store in Keychain, update `credentials-index.json`
   - `list` — Print all credentials from `credentials-index.json` (names/descriptions only, never values)
   - `delete <id>` — Remove from Keychain and `credentials-index.json`

3. Keychain operations:
   - Service prefix: `com.menubot.credential.<id>`
   - Use `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`
   - Account: `menubot`

4. Metadata storage:
   - Read/write `~/Library/Application Support/MenuBot/credentials/credentials-index.json`
   - Structure: `[{"id": "...", "name": "...", "description": "...", "createdAt": "..."}]`
   - Never store credential values in this file

5. Error handling:
   - Exit code 0 on success, 1 on failure
   - Print errors to stderr
   - Print results to stdout (JSON for `list`, plain text for `get`)

```swift
// Example Keychain write
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.menubot.credential.\(id)",
    kSecAttrAccount as String: "menubot",
    kSecValueData as String: value.data(using: .utf8)!
]
let status = SecItemAdd(query as CFDictionary, nil)
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `menubot-creds/main.swift` | Created | CLI entry point with get/set/list/delete commands |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add `menubot-creds` command-line tool target |

#### Acceptance Criteria

- [ ] `menubot-creds set test-cred --name "Test" --description "A test credential"` stores a value (read from stdin) in Keychain
- [ ] `menubot-creds get test-cred` retrieves and prints the stored value
- [ ] `menubot-creds list` prints JSON array of credential metadata (no values)
- [ ] `menubot-creds delete test-cred` removes from Keychain and index
- [ ] `menubot-creds get nonexistent` exits with code 1 and prints error to stderr
- [ ] Credentials persist across app restarts (stored in Keychain, not memory)

---

### Task 7A.6 — Create menubot-input CLI Tool

#### User Story

As a doer performing computer control actions, I need a CLI tool to move the mouse, click, type text, and press keyboard shortcuts so the orchestrator can automate GUI interactions.

#### Implementation Steps

1. Create a new **Command Line Tool** target in Xcode named `menubot-input`
   - Language: Swift
   - Framework: Foundation + CoreGraphics + ApplicationServices
   - Product name: `menubot-input`

2. Create `menubot-input/main.swift` with the following commands:
   - `mouse_move --x N --y N` — Move cursor to absolute coordinates
   - `mouse_click --x N --y N [--button left|right] [--count N]` — Click at coordinates (default: left, single)
   - `mouse_drag --x1 N --y1 N --x2 N --y2 N` — Click-drag from point to point
   - `key_type --text "..."` — Type text string character by character
   - `key_press --key K [--modifiers cmd,shift,ctrl,alt]` — Press a key with optional modifiers
   - `scroll --x N --y N --dx N --dy N` — Scroll at position by delta

3. Implementation using `CGEvent` APIs:

```swift
// Example mouse click
func mouseClick(x: Double, y: Double, button: CGMouseButton = .left, count: Int = 1) {
    let point = CGPoint(x: x, y: y)
    let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
    let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp

    for i in 0..<count {
        let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button)
        down?.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button)
        up?.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
        up?.post(tap: .cghidEventTap)
    }
}
```

4. Error handling:
   - Exit code 0 on success, 1 on failure
   - Print errors to stderr
   - Print confirmation to stdout (e.g., `{"action":"mouse_click","x":100,"y":200,"status":"ok"}`)

5. Note: Requires Accessibility permission. If not granted, CGEvent posts will silently fail. The app-level `PermissionsManager` (Task 7C.1) handles requesting this permission before first use.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `menubot-input/main.swift` | Created | CLI entry point with mouse/keyboard control commands |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add `menubot-input` command-line tool target |

#### Acceptance Criteria

- [ ] `menubot-input mouse_move --x 500 --y 500` moves the cursor
- [ ] `menubot-input mouse_click --x 500 --y 500` performs a left click
- [ ] `menubot-input mouse_click --x 500 --y 500 --button right` performs a right click
- [ ] `menubot-input mouse_click --x 500 --y 500 --count 2` performs a double click
- [ ] `menubot-input key_type --text "hello world"` types the text
- [ ] `menubot-input key_press --key a --modifiers cmd` triggers Cmd+A
- [ ] `menubot-input scroll --x 500 --y 500 --dx 0 --dy -3` scrolls down
- [ ] `menubot-input mouse_drag --x1 100 --y1 100 --x2 300 --y2 300` drags between points
- [ ] All commands output JSON status to stdout
- [ ] Invalid arguments exit with code 1 and print usage to stderr

---

### Task 7A.7 — Add CLI Tool Installation Logic to Bootstrap

#### User Story

As the bootstrap system, I need to copy the compiled CLI tools from the app bundle to `~/Library/Application Support/MenuBot/bin/` on every launch so that doers can invoke them and app updates propagate new versions.

#### Implementation Steps

1. Open `MenuBarCompanion/Core/OrchestrationBootstrap.swift`
2. Add a new private method `installCLITools()`:

```swift
private static func installCLITools() {
    let fm = FileManager.default
    let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let binDir = appSupport.appendingPathComponent("MenuBot/bin", isDirectory: true)

    let tools = ["menubot-creds", "menubot-input"]
    for tool in tools {
        guard let bundledURL = Bundle.main.url(forAuxiliaryExecutable: tool) else {
            print("[OrchestrationBootstrap] CLI tool not found in bundle: \(tool)")
            continue
        }
        let destURL = binDir.appendingPathComponent(tool)
        do {
            // Always overwrite so app updates propagate
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: bundledURL, to: destURL)
            // Ensure executable permission
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)
            print("[OrchestrationBootstrap] Installed CLI tool: \(tool)")
        } catch {
            print("[OrchestrationBootstrap] Failed to install \(tool): \(error)")
        }
    }
}
```

3. Call `installCLITools()` in `install()` after directory creation and skill seeding.

4. Ensure both CLI tool targets have their products included in the main app target's "Copy Files" build phase (destination: Executables) so `Bundle.main.url(forAuxiliaryExecutable:)` finds them.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modified | Add `installCLITools()` method and call it from `install()` |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add CLI tool products to main target's Copy Files phase |

#### Acceptance Criteria

- [ ] After app launch, `~/Library/Application Support/MenuBot/bin/menubot-creds` exists and is executable
- [ ] After app launch, `~/Library/Application Support/MenuBot/bin/menubot-input` exists and is executable
- [ ] Running the installed tools from terminal produces expected output
- [ ] Relaunching the app overwrites old versions with current bundle versions
- [ ] Missing CLI tools in bundle are logged but don't crash the app

---

### Task 7A.8 — Verify Skill Seeding Preserves User-Created Skills

#### User Story

As a user who has created custom skills, I need them to survive app restarts and bootstrap re-runs so my work isn't lost.

#### Implementation Steps

1. This is a verification task — no new code needed (the merge logic in `seedDefaultSkills()` already filters by `defaultIDs`).
2. Manual test procedure:
   - Launch app (seeds 6 default skills)
   - Manually add a custom skill entry to `~/Library/Application Support/MenuBot/skills/skills-index.json`:
     ```json
     {
       "id": "my-custom-skill",
       "name": "My Custom Skill",
       "description": "A user-created skill",
       "icon": "star",
       "category": "Custom",
       "file": "my-custom-skill.md"
     }
     ```
   - Create `my-custom-skill.md` in the skills directory
   - Relaunch app
   - Verify `skills-index.json` contains all 6 defaults + the custom skill
   - Verify `my-custom-skill.md` still exists

3. Review the merge logic in `seedDefaultSkills()` (lines 64-75) to confirm:
   - `defaultIDs` is built from the bundled index entries
   - User entries are filtered as those NOT in `defaultIDs`
   - Merged result is `defaultEntries + userEntries`

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | — | Verification only |

#### Acceptance Criteria

- [ ] A user-created skill entry in `skills-index.json` survives app relaunch
- [ ] A user-created `.md` prompt file is not overwritten or deleted
- [ ] Default skills are updated to latest bundle versions on relaunch
- [ ] The merged index contains both default and user entries

---

### Task 7B.1 — Refactor AppDelegate Into Ordered Startup Sequence

#### User Story

As the app, I need to execute 6 startup steps in a specific order on every launch so that all subsystems initialize correctly with proper dependencies.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/StartupSequence.swift`:

```swift
import Foundation

/// Executes the ordered 6-step startup sequence.
/// Each step is isolated — a failure logs an error but doesn't block subsequent steps.
enum StartupSequence {

    struct StepResult {
        let name: String
        let success: Bool
        let error: String?
    }

    static func execute() -> [StepResult] {
        var results: [StepResult] = []

        // Step 1: Bootstrap orchestration files, skills, CLI tools
        results.append(runStep("Bootstrap") {
            OrchestrationBootstrap.install()
        })

        // Step 2: Start persistent orchestrator session (Obj 4)
        results.append(runStep("Persistent Session") {
            // TODO: Call into session manager when Obj 4 is implemented
            print("[StartupSequence] Step 2: Persistent session — not yet implemented, skipping")
        })

        // Step 3: Verify/repair background job LaunchAgents (Obj 5)
        results.append(runStep("Job Verification") {
            // TODO: Call into job registry when Obj 5 is implemented
            print("[StartupSequence] Step 3: Job verification — not yet implemented, skipping")
        })

        // Step 4: Load orchestrator memory files (Obj 4)
        results.append(runStep("Memory Load") {
            // TODO: Call into memory system when Obj 4 is implemented
            print("[StartupSequence] Step 4: Memory load — not yet implemented, skipping")
        })

        // Step 5: Verify required credentials for enabled jobs (Obj 5)
        results.append(runStep("Credential Check") {
            // TODO: Call into credential/job system when Obj 5 is implemented
            print("[StartupSequence] Step 5: Credential check — not yet implemented, skipping")
        })

        // Step 6: Register global emergency stop shortcut (Obj 6)
        results.append(runStep("Emergency Stop") {
            // TODO: Register NSEvent global monitor when Obj 6 is implemented
            print("[StartupSequence] Step 6: Emergency stop — not yet implemented, skipping")
        })

        let successCount = results.filter(\.success).count
        print("[StartupSequence] Complete: \(successCount)/\(results.count) steps succeeded")
        return results
    }

    private static func runStep(_ name: String, action: () throws -> Void) -> StepResult {
        do {
            try action()
            print("[StartupSequence] ✓ \(name)")
            return StepResult(name: name, success: true, error: nil)
        } catch {
            print("[StartupSequence] ✗ \(name): \(error.localizedDescription)")
            return StepResult(name: name, success: false, error: error.localizedDescription)
        }
    }
}
```

2. Add the file to the Xcode project under `Core/` group.

3. Update `AppDelegate.applicationDidFinishLaunching` to replace the direct `OrchestrationBootstrap.install()` call:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // Execute ordered startup sequence (Step 1 includes bootstrap)
    let _ = StartupSequence.execute()

    // Hide dock icon (menu bar only)
    NSApp.setActivationPolicy(.accessory)
    // ... rest unchanged
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/StartupSequence.swift` | Created | 6-step ordered startup coordinator |
| `MenuBarCompanion/App/AppDelegate.swift` | Modified | Replace `OrchestrationBootstrap.install()` with `StartupSequence.execute()` |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add `StartupSequence.swift` to project |

#### Acceptance Criteria

- [ ] App launch executes all 6 steps in order (visible in console logs)
- [ ] Each step logs success or failure with step name
- [ ] A thrown error in any step doesn't crash the app or block subsequent steps
- [ ] Step 1 (Bootstrap) creates all directories and seeds all skills
- [ ] Steps 2-6 log "not yet implemented, skipping" until their Objectives are built
- [ ] Overall summary logs how many steps succeeded

---

### Task 7B.3 — Implement Login Item Registration

#### User Story

As a user, I want MenuBot to start automatically when I log in so I always have it available without manually launching it.

#### Implementation Steps

1. In `AppDelegate.swift`, import `ServiceManagement`

2. Add Login Item registration after the startup sequence:

```swift
import ServiceManagement

// In applicationDidFinishLaunching, after StartupSequence.execute():
do {
    try SMAppService.mainApp.register()
    print("[AppDelegate] Registered as Login Item")
} catch {
    print("[AppDelegate] Failed to register as Login Item: \(error)")
}
```

3. The registration is idempotent — calling `register()` when already registered is a no-op.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/App/AppDelegate.swift` | Modified | Add `SMAppService.mainApp.register()` call |

#### Acceptance Criteria

- [ ] After first launch, MenuBot appears in System Settings > General > Login Items
- [ ] Subsequent launches don't produce errors from duplicate registration
- [ ] If registration fails, the error is logged but the app continues normally

---

### Task 7B.4 — Add Settings View With Login Item Toggle

#### User Story

As a user, I want a "Start MenuBot at login" toggle in settings so I can control whether the app launches automatically.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/SettingsView.swift`:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Start MenuBot at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("[SettingsView] Login item toggle failed: \(error)")
                            // Revert the toggle to reflect actual state
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
```

2. Add a "Settings" option to the hamburger menu in `PopoverView.swift` that navigates to this view.

3. Add the file to the Xcode project under `UI/` group.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/SettingsView.swift` | Created | Settings view with Login Item toggle |
| `MenuBarCompanion/UI/PopoverView.swift` | Modified | Add "Settings" navigation option to hamburger menu |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add `SettingsView.swift` to project |

#### Acceptance Criteria

- [ ] Settings view is accessible from the hamburger menu
- [ ] "Start MenuBot at login" toggle defaults to on
- [ ] Toggling off removes MenuBot from Login Items (verified in System Settings)
- [ ] Toggling on re-adds MenuBot to Login Items
- [ ] Toggle reflects actual system state on view appear
- [ ] Failed toggle reverts to actual state rather than showing incorrect value

---

### Task 7C.1 — Create PermissionsManager

#### User Story

As the app, I need a centralized way to check and request macOS permissions (Screen Recording, Accessibility) so that each permission is requested at the right time with a consistent user experience.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/PermissionsManager.swift`:

```swift
import Foundation
import AppKit

/// Centralized permission state and request flow for Screen Recording and Accessibility.
@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var screenRecordingGranted: Bool = false
    @Published var accessibilityGranted: Bool = false

    // Track whether we've shown our in-app explanation (to avoid nagging)
    private var screenRecordingExplained = false
    private var accessibilityExplained = false

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
        accessibilityGranted = AXIsProcessTrusted()
    }

    // MARK: - Screen Recording

    /// Check and optionally request Screen Recording permission.
    /// Returns true if granted, false if denied.
    /// The `reason` closure is called to show an in-app explanation before triggering the system prompt.
    func requestScreenRecording(showExplanation: @escaping (@escaping () -> Void) -> Void) -> Bool {
        refreshStatus()
        if screenRecordingGranted { return true }

        if !screenRecordingExplained {
            screenRecordingExplained = true
            showExplanation {
                CGRequestScreenCaptureAccess()
            }
        }

        refreshStatus()
        return screenRecordingGranted
    }

    // MARK: - Accessibility

    /// Check and optionally request Accessibility permission.
    /// Returns true if granted, false if denied.
    func requestAccessibility(showExplanation: @escaping (@escaping () -> Void) -> Void) -> Bool {
        refreshStatus()
        if accessibilityGranted { return true }

        if !accessibilityExplained {
            accessibilityExplained = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            showExplanation {
                AXIsProcessTrustedWithOptions(options)
            }
        }

        refreshStatus()
        return accessibilityGranted
    }

    // MARK: - Denial Messages

    var screenRecordingDenialMessage: String {
        "I can't see your screen without Screen Recording permission. You can enable it in System Settings > Privacy & Security > Screen Recording."
    }

    var accessibilityDenialMessage: String {
        "I need Accessibility permission to read screen elements and control your mouse/keyboard. You can enable it in System Settings > Privacy & Security > Accessibility."
    }
}
```

2. Add the file to the Xcode project under `Core/` group.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/PermissionsManager.swift` | Created | Centralized permission check/request manager |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add `PermissionsManager.swift` to project |

#### Acceptance Criteria

- [ ] `PermissionsManager.shared` provides current permission state
- [ ] `refreshStatus()` re-reads actual system permission state
- [ ] `requestScreenRecording()` calls explanation closure before system prompt
- [ ] `requestAccessibility()` calls explanation closure before system prompt
- [ ] Neither method re-prompts after first explanation (no nagging)
- [ ] Denial messages provide clear instructions to the user

---

### Task 7C.2 — Wire Lazy Permission Requests Into Feature Code Paths

#### User Story

As a user, I should only be asked for permissions when I first try to use a feature that needs them, not on app launch.

#### Implementation Steps

1. Identify the code paths where permissions are needed:
   - **Screen Recording:** The screenshot capture function (Obj 6.1) — before calling `CGWindowListCreateImage` or `SCScreenshotManager`
   - **Accessibility:** The accessibility metadata reader (Obj 6.3) and `menubot-input` invocation (Obj 6.5) — before calling AX APIs or the input CLI tool

2. At each entry point, call the appropriate `PermissionsManager` method:

```swift
// Example: before capturing a screenshot
let granted = PermissionsManager.shared.requestScreenRecording { triggerSystemPrompt in
    // Show in-app explanation, then call triggerSystemPrompt()
}
if !granted {
    // Return denial message to the orchestrator
    return PermissionsManager.shared.screenRecordingDenialMessage
}
```

3. For the Accessibility permission, ensure a single grant covers both screen metadata (AX API calls) and input control (`menubot-input` CLI). Both should check `PermissionsManager.shared.accessibilityGranted` and request via `requestAccessibility()` if not granted.

4. This task depends on Objectives 4-6 feature code existing. If stubs are in place, wire the permission checks into the stubs so they're ready when the real code lands.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (Obj 6 screenshot capture file) | Modified | Add `PermissionsManager` check before screen capture |
| (Obj 6 accessibility metadata file) | Modified | Add `PermissionsManager` check before AX API calls |
| (Obj 6 input control file) | Modified | Add `PermissionsManager` check before `menubot-input` invocation |

#### Acceptance Criteria

- [ ] No permission dialogs appear on app launch
- [ ] First screenshot attempt triggers Screen Recording permission request
- [ ] First accessibility metadata or input control attempt triggers Accessibility permission request
- [ ] Accessibility permission is requested once — not separately for metadata and input
- [ ] Subsequent uses of the same feature don't re-trigger permission requests

---

### Task 7C.3 — Create Friendly Permission Explanation UI

#### User Story

As a non-technical user, I want a clear, friendly explanation of why a permission is needed before the system dialog appears, so I understand what I'm granting and feel confident.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/PermissionExplanationView.swift`:

```swift
import SwiftUI

struct PermissionExplanationView: View {
    let title: String
    let explanation: String
    let icon: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline)

            Text(explanation)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Not Now") { onSkip() }
                    .buttonStyle(.plain)

                Button("Continue") { onContinue() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
    }
}
```

2. Define explanation content for each permission:
   - **Screen Recording:** "To see your screen, MenuBot needs Screen Recording permission. This lets me take screenshots when you ask me to look at something on screen."
   - **Accessibility:** "To read what's on screen and control your mouse and keyboard, MenuBot needs Accessibility permission. This lets me identify buttons, text fields, and other elements, and interact with them when you ask."

3. Show this view inline in the chat (as a special message bubble) or as a sheet before triggering the system prompt.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/PermissionExplanationView.swift` | Created | Friendly in-app permission explanation component |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modified | Add `PermissionExplanationView.swift` to project |

#### Acceptance Criteria

- [ ] Permission explanation appears before the macOS system prompt
- [ ] Language is non-technical and friendly
- [ ] User can choose "Not Now" to skip (denial path)
- [ ] User can choose "Continue" to trigger the system permission prompt
- [ ] Each permission type has distinct, accurate explanation text

---

### Task 7C.4 — Handle Permission Denial Gracefully

#### User Story

As a user who denied a permission, I want a clear message about what I can't do and how to fix it, without being nagged repeatedly.

#### Implementation Steps

1. When a permission check returns false after the explanation has been shown:
   - Return the appropriate denial message from `PermissionsManager` to the chat
   - The message should be displayed as an assistant message in the chat UI
   - Do NOT re-trigger the permission explanation or system prompt

2. On subsequent feature attempts (e.g., user asks "what's on my screen" again):
   - Re-check the actual permission state via `refreshStatus()`
   - If now granted (user went to System Settings and enabled it), proceed normally
   - If still denied, show a brief reminder: "Screen Recording permission is still needed for this. You can enable it in System Settings > Privacy & Security."

3. Ensure the Accessibility permission covers both use cases:
   - If granted for screen metadata, it also works for input control — no second prompt
   - `PermissionsManager.accessibilityGranted` is the single check for both

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/PermissionsManager.swift` | Modified | Add re-check logic for subsequent attempts |
| (Chat response handling code) | Modified | Route denial messages to chat UI |

#### Acceptance Criteria

- [ ] Denied permission produces a clear fallback message in chat
- [ ] No repeated system prompts after denial
- [ ] If user grants permission via System Settings, next attempt works without relaunch
- [ ] Accessibility grant covers both screen metadata and input control
- [ ] Denial messages include specific System Settings path for manual enablement

---

### Task 7C.5 — End-to-End Validation of All 8 Acceptance Criteria

#### User Story

As the development team, we need to validate that all Objective 4-6 features compose correctly by testing 8 end-to-end scenarios that prove the complete system works.

#### Implementation Steps

1. **Scenario 1 — Concurrent tasks:**
   - Send "find flights from SLC to Dublin next week"
   - While that's running, send "what's the weather today?"
   - Verify both tasks execute concurrently and return independently
   - Expected: Two doers spawned, results arrive as each completes

2. **Scenario 2 — Job creation flow:**
   - Send "set up a morning newsletter for me"
   - Verify orchestrator asks about content, schedule, delivery method
   - Verify credential setup is offered if needed
   - Verify job is created in `jobs/jobs-registry.json`
   - Verify LaunchAgent plist is written

3. **Scenario 3 — Restart persistence:**
   - With a job from Scenario 2 in place, restart the app
   - Verify `StartupSequence` Step 3 verifies the job's LaunchAgent
   - Verify the job fires at its scheduled time

4. **Scenario 4 — Screen reading:**
   - Open a terminal with a visible error message
   - Ask "what's this error?"
   - Verify Screen Recording permission is requested (first time)
   - Verify screenshot is captured and error is explained

5. **Scenario 5 — Input control:**
   - Open a page with a Submit button
   - Say "click the Submit button"
   - Verify Accessibility permission is requested (first time)
   - Verify screenshot + element identification
   - Verify confirmation prompt before action
   - Verify click is executed and result is verified

6. **Scenario 6 — Multi-turn conversation:**
   - "Find Italian restaurants nearby"
   - "Which ones have outdoor seating?"
   - "Book the second one for Friday at 7pm"
   - Verify context is maintained across all turns

7. **Scenario 7 — Memory persistence:**
   - Say "remember that I prefer window seats on flights"
   - Verify it's stored in `memory/`
   - Restart app
   - Ask about flights
   - Verify the preference is recalled

8. **Scenario 8 — Credential retrieval:**
   - Set up a credential via `menubot-creds`
   - Create a job that uses it
   - Verify the job retrieves the credential without user interaction

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none — manual testing) | — | All scenarios are manual E2E tests |

#### Acceptance Criteria

- [ ] Scenario 1: Concurrent tasks execute and return independently
- [ ] Scenario 2: Full job creation flow completes with guided setup
- [ ] Scenario 3: Job persists across restart and fires on schedule
- [ ] Scenario 4: Screen reading works with permission flow
- [ ] Scenario 5: Input control works with confirmation and verification
- [ ] Scenario 6: Multi-turn context is maintained
- [ ] Scenario 7: Memory persists across restarts
- [ ] Scenario 8: Background job uses stored credentials automatically

---

### Task 7C.6 — Fix Integration Gaps

#### User Story

As the glue phase, I expect to discover edge cases where Objective 4-6 features don't compose cleanly, and I need to fix them.

#### Implementation Steps

1. Track all issues discovered during E2E validation (Task 7C.5) in a list
2. Prioritize by severity:
   - P0: Feature completely broken (blocks E2E scenario)
   - P1: Feature works but UX is poor (confusing messages, wrong order)
   - P2: Minor polish (timing, wording, visual alignment)
3. Fix P0 issues first, then P1, then P2
4. Re-run affected E2E scenarios after each fix

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (varies) | Modified | Bug fixes discovered during E2E validation |

#### Acceptance Criteria

- [ ] All P0 issues are resolved
- [ ] All P1 issues are resolved
- [ ] P2 issues are documented if not resolved
- [ ] All 8 E2E scenarios pass after fixes

---

### Task 7C.7 — UX Principle Validation

#### User Story

As the product, every feature must feel magical to a non-technical user — no exposed internals, guided setup flows, silent retries, glanceable status, and an app that feels alive.

#### Implementation Steps

1. Review each feature against these principles:
   - **No exposed internals:** User never sees doer IDs, log file paths, cron syntax, session IDs, or technical error traces
   - **Guided setup:** Job creation, credential setup, and skill creation are conversational, not form-based
   - **Silent retries:** Failed operations are retried before surfacing errors; when surfaced, include what was tried and what the user can do
   - **Glanceable status:** Progress indicators are ambient (e.g., typing indicator, toast notifications), not verbose logs
   - **Always alive:** App never shows "loading..." or freezes; operations are async with immediate feedback

2. For each violation found, create a fix or file it as a P2 issue.

3. Specific checks:
   - [ ] Chat messages from the orchestrator don't reference file paths or internal IDs
   - [ ] Error messages suggest user actions, not technical details
   - [ ] Background job status is shown as simple text ("Your morning newsletter ran at 7:00 AM"), not raw log output
   - [ ] Permission requests use friendly language
   - [ ] Skill descriptions are user-friendly, not developer-oriented

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (varies) | Modified | UX fixes for principle violations |

#### Acceptance Criteria

- [ ] No feature exposes internal complexity to the user
- [ ] All setup flows are guided and conversational
- [ ] Error messages are user-actionable
- [ ] Status is glanceable and ambient
- [ ] App feels responsive and alive at all times

---

## 5. Integration Points

- **OrchestrationBootstrap** ← Extended with new directories, skills, CLI tool installation
- **AppDelegate** ← Replaced direct bootstrap call with `StartupSequence.execute()`
- **StartupSequence** → Calls into Obj 4 session manager, Obj 5 job registry, Obj 4 memory system, Obj 5 credential system, Obj 6 emergency stop
- **PermissionsManager** → Called by Obj 6 screenshot capture, Obj 6 AX metadata reader, Obj 6 input control invoker
- **SMAppService** ← Login Item registration (macOS system integration)
- **Keychain** ← `menubot-creds` reads/writes via Security framework
- **CGEvent** ← `menubot-input` posts mouse/keyboard events via CoreGraphics
- **PopoverView** ← Settings navigation added to hamburger menu
- **SettingsView** ← New view for Login Item toggle (future: more settings from Obj 4-6)

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

- **OrchestrationBootstrap tests:** Verify all directories created, all 6 skills seeded, CLI tools installed, user skills preserved
- **StartupSequence tests:** Verify 6 steps execute in order, failures don't cascade, logging is correct
- **PermissionsManager tests:** Verify lazy request behavior, no re-prompting after denial, status refresh
- **SettingsView tests:** Verify toggle reflects system state, toggle changes registration
- **menubot-creds tests:** Verify get/set/list/delete operations, Keychain integration, error handling
- **menubot-input tests:** Verify argument parsing, command dispatch, error output

### During Implementation: Build Against Tests

- Implement bootstrap extensions and verify directory/skill creation tests pass
- Implement CLI tools and verify command tests pass
- Implement StartupSequence and verify ordering/isolation tests pass
- Implement PermissionsManager and verify lazy-request tests pass

### Phase End: Polish Tests

- Add integration tests that verify the full bootstrap → startup → feature flow
- Add edge case tests: corrupt `skills-index.json`, missing bundle resources, Keychain access denied
- Verify all 8 E2E scenarios pass as manual acceptance tests
- Remove any stub tests that are no longer needed

---

## 7. Definition of Done

- [ ] All 7 new directories created by bootstrap
- [ ] All 6 default skills seeded (index + `.md` files)
- [ ] Both CLI tools (`menubot-creds`, `menubot-input`) compiled, installed, and executable
- [ ] User-created skills preserved across bootstrap runs
- [ ] 6-step startup sequence executes in order with isolated failure handling
- [ ] Login Item registered via `SMAppService.mainApp`
- [ ] "Start MenuBot at login" toggle works in Settings view
- [ ] `PermissionsManager` centralizes Screen Recording and Accessibility permission flows
- [ ] Permissions requested lazily (first use), not at launch
- [ ] Permission denial handled gracefully with no repeated prompts
- [ ] All 8 end-to-end acceptance criteria pass
- [ ] No feature exposes internal complexity to the user
- [ ] All tests passing (unit + integration)
- [ ] No regressions in existing functionality

### Backward Compatibility

Backward compatibility is required for:
- **Existing skills:** User-created skills must survive bootstrap. The merge logic (filter by `defaultIDs`) already handles this.
- **Existing directories:** `skills/` and `doer-logs/` must not be affected by the new directory creation.
- **Existing chat history:** No changes to chat persistence.
- **Existing AppDelegate behavior:** Menu bar icon, popover, and notification manager must work identically.

No breaking changes are expected — this phase only adds new capabilities and wires existing ones together.

### End-of-Phase Checklist (Hard Gate)

**STOP — Do not mark this phase complete until ALL of the following are verified:**

- [ ] **Build:** App compiles with zero errors and zero warnings related to Phase 7 code
- [ ] **Bootstrap verification:** Launch app, verify all directories exist:
  ```bash
  ls -la ~/Library/Application\ Support/MenuBot/
  ls -la ~/Library/Application\ Support/MenuBot/jobs/
  ls -la ~/Library/Application\ Support/MenuBot/jobs/logs/
  ls -la ~/Library/Application\ Support/MenuBot/memory/
  ls -la ~/Library/Application\ Support/MenuBot/credentials/
  ls -la ~/Library/Application\ Support/MenuBot/cache/screenshots/
  ls -la ~/Library/Application\ Support/MenuBot/bin/
  ```
- [ ] **Skills verification:** Verify 6 skills in index:
  ```bash
  cat ~/Library/Application\ Support/MenuBot/skills/skills-index.json | python3 -m json.tool
  ls ~/Library/Application\ Support/MenuBot/skills/*.md
  ```
- [ ] **CLI tools verification:**
  ```bash
  ~/Library/Application\ Support/MenuBot/bin/menubot-creds list
  ~/Library/Application\ Support/MenuBot/bin/menubot-input --help
  ```
- [ ] **Startup sequence:** Console logs show all 6 steps executed in order
- [ ] **Login Item:** MenuBot appears in System Settings > General > Login Items
- [ ] **Settings toggle:** Toggle off removes from Login Items, toggle on re-adds
- [ ] **User skill preservation:** Add custom skill, relaunch, confirm it survives
- [ ] **E2E scenarios:** All 8 acceptance criteria pass (manual verification)
- [ ] **Signoff:** Phase 7 is complete and ready for production

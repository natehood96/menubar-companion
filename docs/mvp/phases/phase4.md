# Phase 4 — Context, Defaults & Scheduling

- **Phase Number:** 4
- **Phase Name:** Context Injection, Preinstalled Skills & Scheduling
- **Source:** docs/mvp/phases/overviews/objective4PhaseOverview.md

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

- **What this phase accomplishes:** Adds structured context injection to every CLI run, seeds the app with preinstalled skills on first launch, and enables recurring skill scheduling with notification delivery.
- **What already exists from previous phases:** Menu bar app with popover (Phase 1), event protocol with toast rendering (Phase 2), skills directory with directory-per-skill format (`skill.json` metadata + `prompt.md` template), browse/star/run UI, and skill execution via CommandRunner (Phase 3 + 3.5). **Chat-based UI** replaces the old input/output split — the home screen is now a persistent chat thread (`ChatViewModel` + `ChatView`), with skills and other views accessible via a navigation menu.
- **What future phases depend on this:** Phase 5 (activity log will track scheduled runs; safety confirmations apply to context-sensitive operations).

---

## 0. Mental Model (Required)

**Problem:** Without context, every skill run starts from zero — the user must manually describe their situation. Without preinstalled skills, a new user sees an empty skills browser. Without scheduling, the user must manually trigger every run.

**System lifecycle position:** Phase 4 sits between the skills execution system (Phase 3) and the polish/safety layer (Phase 5). It makes the app *useful by default* — a fresh install immediately has working skills that leverage automatic context and can run on a schedule.

**Data flow:**
1. **Context injection:** On every skill or free-form run, `ContextProvider` collects default context (time, active app) plus any enabled optional context (clipboard, screenshot). This is serialized into a `ContextPayload` and appended to the CLI prompt before `CommandRunner` executes it.
2. **Preinstalled skills:** On first launch, bundled skill directories (each containing `skill.json` + `prompt.md`) are copied from the app bundle into `~/Library/Application Support/MenuBot/skills/`. The `prompt.md` files use template variables (`{context.time}`, `{context.active_app}`, etc.) that get substituted at execution time.
3. **Scheduling:** `ScheduleManager` persists schedule configs and runs an internal timer. When a schedule fires, the skill executes via `CommandRunner` in the background and delivers results via macOS notification.

**Core entities:** `ContextProvider`, `ContextPayload`, template variable substitution, `ScheduleManager`, `UNUserNotificationCenter` integration.

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Every skill run includes structured context, the app ships with useful preinstalled skills, and users can schedule skills to run automatically with notification delivery.

### Prerequisites

- Phase 1 complete: menu bar app, popover, CommandRunner, CLI execution
- Phase 2 complete: event protocol, EventParser, toast rendering
- Phase 3 + 3.5 complete: skills directory (`~/Library/Application Support/MenuBot/skills/`) using directory-per-skill format (`skill.json` metadata + `prompt.md` template), `Skill` model with `SkillMetadata` Codable, `SkillsDirectoryManager` scanning subdirectories, browse/star/run UI, skill execution via `ChatViewModel`
- App sandbox disabled (required for process execution and file system access)

### Key Deliverables

- `ContextProvider` service collecting default and optional context
- `ContextPayload` struct with serialization to structured text
- Context toggle UI in the skill run screen
- macOS permission handling for Screen Recording and Accessibility
- 3+ preinstalled skill files (Morning Brief, Create New Skill, Find File)
- First-run seeding logic
- Template variable substitution at execution time
- `ScheduleManager` with persistent schedule storage
- Schedule UI on skill detail view
- Internal timer-based scheduling engine
- Background skill execution without popover
- macOS notification delivery for scheduled run results
- Launch at Login preference

### System-Level Acceptance Criteria

- Default context (time, active app) is always included — no way to disable it
- Optional context (clipboard, screenshot) requires explicit user toggle — never sent without consent
- Permission denials degrade gracefully — the run proceeds without that context type
- First-run seeding never overwrites user-modified files on subsequent launches
- Scheduled execution is idempotent — if a schedule fires while a previous run is still active, it queues or skips (no overlapping runs of the same skill)
- Schedule settings persist across app restarts
- Notifications respect macOS notification permissions — request permission before first scheduled delivery

---

## 2. Execution Order

### Blocking Tasks

1. **Task 4.1** — `ContextProvider` and `ContextPayload` (everything downstream depends on the context data model)
2. **Task 4.2** — Optional context collectors (screenshot, clipboard) — extends ContextProvider
3. **Task 4.3** — Wire context into CLI execution path
4. **Task 4.4** — Template variable substitution (skills need context values injected)
5. **Task 4.5** — Preinstalled skill files (need template substitution working to validate them)
6. **Task 4.6** — First-run seeding logic
7. **Task 4.7** — `ScheduleManager` foundation (requires skills to exist to schedule them)
8. **Task 4.8** — Scheduling engine (timer + execution)
9. **Task 4.9** — Background execution + notification delivery

### Parallel Tasks

- **Task 4.2** (optional context collectors) and **Task 4.5** (writing skill files) can proceed in parallel once Task 4.1 is complete
- **Task 4.10** (context toggle UI) can be built in parallel with Task 4.3 (wiring)
- **Task 4.11** (schedule UI) can be built in parallel with Task 4.8 (scheduling engine)
- **Task 4.12** (Launch at Login) can be built in parallel with any scheduling task

### Final Integration

- End-to-end: run Morning Brief from starred skills → verify context is injected → verify output renders
- End-to-end: schedule Morning Brief → wait for timer to fire → verify notification delivered
- Verify fresh install flow: first launch → skills seeded → appear in browser → can star and run

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Screenshot capture API | CGWindowListCreateImage vs ScreenCaptureKit | CGWindowListCreateImage | Available on macOS 13+ (our target); ScreenCaptureKit requires macOS 14+ for full API | Deprecated eventually, but sufficient for v1 |
| Scheduling engine | Internal Timer vs LaunchAgent plist | Internal Timer + Login Items | Simpler implementation; no plist generation; app is already a menu bar agent that should always run | Missed schedules if user quits app; mitigated by Launch at Login |
| Schedule persistence | UserDefaults vs JSON file | JSON file at `~/Library/Application Support/MenuBot/schedules.json` | Structured data with multiple schedules; easier to inspect and debug | File corruption risk; mitigated by atomic writes |
| Context serialization | JSON block vs structured text | Structured text block | More readable in Claude Code prompts; JSON nesting adds noise | Parsing is one-way (CLI input only), so readability wins |

---

## 4. Subtasks

### Task 4.1 — ContextProvider & ContextPayload

#### User Story

As the system, I collect default context (current time, active application name) on every skill or free-form run so that Claude Code always has situational awareness without the user needing to describe it.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/ContextProvider.swift`:
   - Define `ContextPayload` struct:
     ```swift
     struct ContextPayload {
         let currentTime: String       // ISO 8601 or human-readable
         let activeAppName: String?    // from NSWorkspace
         var clipboardText: String?    // optional
         var screenshotData: Data?     // optional, PNG
         var selectedText: String?     // optional, experimental
     }
     ```
   - Implement `ContextProvider` class:
     ```swift
     class ContextProvider {
         func collectDefaultContext() -> ContextPayload
         func collectFullContext(includeClipboard: Bool, includeScreenshot: Bool) -> ContextPayload
     }
     ```
   - `collectDefaultContext()`: get current time via `Date()` formatted with `ISO8601DateFormatter`, get active app via `NSWorkspace.shared.frontmostApplication?.localizedName`
2. Add a `serialize()` method to `ContextPayload` that produces a structured text block:
   ```
   --- CONTEXT ---
   Time: 2026-03-04T09:30:00-07:00
   Active Application: Safari
   Clipboard: <contents if enabled>
   Screenshot: <attached as base64 if enabled>
   --- END CONTEXT ---
   ```
3. Write unit tests for `ContextProvider`:
   - Default context always includes time (non-empty string)
   - Active app name returns nil gracefully if no frontmost app
   - Serialization format is consistent

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ContextProvider.swift` | Create | ContextProvider service and ContextPayload model |
| `MenuBarCompanionTests/ContextProviderTests.swift` | Create | Unit tests for context collection and serialization |

#### Acceptance Criteria

- [ ] `ContextPayload` struct exists with all defined fields
- [ ] `collectDefaultContext()` returns current time and active app name
- [ ] `serialize()` produces the structured text block format
- [ ] Unit tests pass for default context collection and serialization

---

### Task 4.2 — Optional Context Collectors

#### User Story

As a user, I can optionally attach my clipboard contents or a screenshot to a skill run so Claude Code has richer context for its response.

#### Implementation Steps

1. Extend `ContextProvider` with clipboard collection:
   - Read `NSPasteboard.general.string(forType: .string)` for text clipboard
   - Truncate to a reasonable limit (e.g., 10,000 characters) to avoid prompt bloat
2. Extend `ContextProvider` with screenshot capture:
   - Use `CGWindowListCreateImage(.infinite, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)` for full screen capture
   - Convert `CGImage` to PNG `Data` via `NSBitmapImageRep`
   - Encode as base64 string for inclusion in the prompt (or save to temp file and reference path)
3. Add permission detection:
   - Screenshot: call `CGPreflightScreenCaptureAccess()` to check; call `CGRequestScreenCaptureAccess()` to prompt
   - If permission denied, set `screenshotData` to nil and log a warning
4. Selected text collection (experimental, can defer):
   - Via Accessibility API (`AXUIElementCopyAttributeValue` for `kAXSelectedTextAttribute`)
   - Mark as experimental; skip if Accessibility permission not granted
5. Write tests for optional collectors:
   - Clipboard returns nil when pasteboard is empty
   - Screenshot returns nil when permission denied (mock `CGPreflightScreenCaptureAccess`)
   - Truncation works at boundary

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ContextProvider.swift` | Modify | Add clipboard, screenshot, and selected text collectors |
| `MenuBarCompanionTests/ContextProviderTests.swift` | Modify | Add tests for optional context collectors |

#### Acceptance Criteria

- [ ] Clipboard text is captured when enabled and pasteboard has string content
- [ ] Clipboard is truncated at the configured limit
- [ ] Screenshot capture works when Screen Recording permission is granted
- [ ] Screenshot capture returns nil gracefully when permission is denied
- [ ] `CGPreflightScreenCaptureAccess()` is checked before attempting capture
- [ ] Selected text is marked experimental and degrades gracefully

---

### Task 4.3 — Wire Context into CLI Execution

#### User Story

As the system, I append the serialized context payload to every CLI invocation so Claude Code receives structured context automatically.

#### Implementation Steps

1. Modify `ChatViewModel` to instantiate `ContextProvider` (or inject as dependency)
2. Before calling `CommandRunner`, collect context:
   ```swift
   let context = contextProvider.collectFullContext(
       includeClipboard: userSettings.clipboardEnabled,
       includeScreenshot: userSettings.screenshotEnabled
   )
   let contextBlock = context.serialize()
   ```
3. Append `contextBlock` to the prompt/command string passed to `CommandRunner`:
   - For free-form commands: `"\(userInput)\n\n\(contextBlock)"`
   - For skill runs: inject after template substitution (Task 4.4)
4. Add a simple `UserSettings` model (or extend existing) to track toggle states for optional context:
   ```swift
   class UserSettings: ObservableObject {
       @Published var clipboardEnabled: Bool = false
       @Published var screenshotEnabled: Bool = false
   }
   ```
   Store in `UserDefaults` for persistence.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Integrate ContextProvider into run flow |
| `MenuBarCompanion/Core/UserSettings.swift` | Create | User settings model for context toggles |
| `MenuBarCompanion/Core/CommandRunner.swift` | Modify | Accept context-augmented prompt (if interface change needed) |

#### Acceptance Criteria

- [ ] Every free-form command includes the context block in the CLI invocation
- [ ] Context toggle states are read from UserSettings
- [ ] Default context (time, active app) is always appended — no toggle to disable
- [ ] Optional context is only appended when the corresponding toggle is enabled
- [ ] Toggle states persist across app restarts via UserDefaults

---

### Task 4.4 — Template Variable Substitution

#### User Story

As the system, I replace template variables in skill prompts (`{context.time}`, `{context.active_app}`, `{context.clipboard}`, `{context.screenshot}`, `{extra_instructions}`) with actual values at execution time.

#### Implementation Steps

1. Create a `TemplateEngine` (or a method on `ContextPayload`) that performs string replacement:
   ```swift
   func substituteTemplateVariables(
       in template: String,
       context: ContextPayload,
       extraInstructions: String?
   ) -> String
   ```
2. Define the variable mapping:
   - `{context.time}` → `context.currentTime`
   - `{context.active_app}` → `context.activeAppName ?? "unknown"`
   - `{context.clipboard}` → `context.clipboardText ?? ""`
   - `{context.screenshot}` → base64 string or `"[screenshot not available]"`
   - `{extra_instructions}` → user-provided text or `""`
3. Strip any remaining unsubstituted `{context.*}` variables (defensive cleanup)
4. Wire into skill execution path in `ChatViewModel.runSkill()`:
   - Collect context → substitute variables → append remaining context block → execute
5. Write unit tests:
   - All variables substituted correctly
   - Missing optional context results in empty string or placeholder
   - Unrecognized variables are stripped
   - Template with no variables passes through unchanged

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/TemplateEngine.swift` | Create | Template variable substitution logic |
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Wire template substitution into skill execution |
| `MenuBarCompanionTests/TemplateEngineTests.swift` | Create | Unit tests for template substitution |

#### Acceptance Criteria

- [ ] All defined template variables are replaced with actual values
- [ ] Optional context variables degrade to empty string or placeholder when unavailable
- [ ] Unrecognized `{context.*}` variables are stripped from the final prompt
- [ ] Extra instructions are injected into the `{extra_instructions}` placeholder
- [ ] Unit tests cover all variable types and edge cases

---

### Task 4.5 — Preinstalled Skill Files

#### User Story

As a new user, I install Menu-Bot and immediately see useful skills (Morning Brief, Create New Skill, Find File) in the skills browser without any manual setup.

#### Implementation Steps

1. Create the skill directories in the app bundle under `MenuBarCompanion/Resources/PreinstalledSkills/`. Each skill is a directory containing `skill.json` (metadata) and `prompt.md` (prompt template):

   - **`morning-brief/skill.json`**:
     ```json
     {
       "name": "Morning Brief",
       "description": "Daily briefing with top news, weather, and your schedule summary.",
       "icon": "sun.rise",
       "category": "Productivity",
       "suggested_schedule": "daily"
     }
     ```

   - **`morning-brief/prompt.md`**:
     ```markdown
     You are generating a morning briefing for the user. Current time: {context.time}. The user is currently using {context.active_app}.

     Provide a concise morning brief including:
     1. A friendly greeting based on the time of day
     2. Key things to be aware of today
     3. A motivational thought

     Keep it concise and actionable.

     {extra_instructions}
     ```

   - **`create-new-skill/skill.json`**:
     ```json
     {
       "name": "Create New Skill",
       "description": "Generate a new Menu-Bot skill and save it to your skills folder.",
       "icon": "plus.square",
       "category": "Utilities"
     }
     ```

   - **`create-new-skill/prompt.md`**:
     ```markdown
     The user wants to create a new Menu-Bot skill. Help them define it.

     A Menu-Bot skill is a directory containing two files:
     - `skill.json` — metadata with these fields:
       - name (required): Display name
       - description (required): What the skill does
       - icon (optional): SF Symbol name
       - category (optional): Category for grouping
       - suggested_schedule (optional): "daily", "weekly", etc.
     - `prompt.md` — the prompt template (this file, written in markdown)

     Available template variables for prompt.md:
     - {context.time} — current time
     - {context.active_app} — active application name
     - {context.clipboard} — clipboard contents
     - {context.screenshot} — screenshot data
     - {extra_instructions} — user-provided instructions at run time

     The skill directory should be placed in: ~/Library/Application Support/MenuBot/skills/

     Ask the user what they want the skill to do, then generate both files.

     {extra_instructions}
     ```

   - **`find-file/skill.json`**:
     ```json
     {
       "name": "Find File",
       "description": "Search for files on your Mac by name, type, or content.",
       "icon": "doc.text.magnifyingglass",
       "category": "Utilities"
     }
     ```

   - **`find-file/prompt.md`**:
     ```markdown
     Help the user find a file on their Mac. Use the "find" or "mdfind" command to search.

     Current time: {context.time}
     Active app: {context.active_app}

     The user is looking for: {extra_instructions}

     Search smartly — use Spotlight (mdfind) for content searches and find for name/path searches. Present results clearly with full paths.
     ```

2. Optionally create `clean-downloads/` and `work-mode/` showcase skill directories
3. Add all skill directories to the Xcode project target as folder references so they're included in the app bundle

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/PreinstalledSkills/morning-brief/skill.json` | Create | Morning Brief metadata |
| `MenuBarCompanion/Resources/PreinstalledSkills/morning-brief/prompt.md` | Create | Morning Brief prompt template |
| `MenuBarCompanion/Resources/PreinstalledSkills/create-new-skill/skill.json` | Create | Create New Skill metadata |
| `MenuBarCompanion/Resources/PreinstalledSkills/create-new-skill/prompt.md` | Create | Create New Skill prompt template |
| `MenuBarCompanion/Resources/PreinstalledSkills/find-file/skill.json` | Create | Find File metadata |
| `MenuBarCompanion/Resources/PreinstalledSkills/find-file/prompt.md` | Create | Find File prompt template |
| `MenuBarCompanion/Resources/PreinstalledSkills/clean-downloads/` | Create | (Optional) Clean Downloads skill directory |
| `MenuBarCompanion/Resources/PreinstalledSkills/work-mode/` | Create | (Optional) Work Mode skill directory |

#### Acceptance Criteria

- [ ] At least 3 skill directories exist: morning-brief, create-new-skill, find-file
- [ ] Each skill directory contains a valid `skill.json` matching the `SkillMetadata` model and a `prompt.md`
- [ ] Prompt templates in `prompt.md` use template variables (`{context.time}`, `{context.active_app}`, `{extra_instructions}`)
- [ ] Skill directories are included in the Xcode target as folder references and accessible from the app bundle at runtime

---

### Task 4.6 — First-Run Seeding Logic

#### User Story

As the system, I copy bundled preinstalled skills into the user's skills directory on first launch so the skills browser is populated immediately.

#### Implementation Steps

1. Add seeding logic to `SkillsDirectoryManager` (or create a `SkillSeeder`):
   ```swift
   func seedPreinstalledSkillsIfNeeded() {
       let seededVersion = UserDefaults.standard.string(forKey: "seededSkillsVersion")
       let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

       if seededVersion == nil {
           // First run — copy all bundled skill directories
           copyBundledSkills()
           UserDefaults.standard.set(currentVersion, forKey: "seededSkillsVersion")
       } else if seededVersion != currentVersion {
           // App updated — seed new skills only (don't overwrite existing)
           copyBundledSkills(overwrite: false)
           UserDefaults.standard.set(currentVersion, forKey: "seededSkillsVersion")
       }
   }
   ```
2. `copyBundledSkills(overwrite:)`:
   - Locate the `PreinstalledSkills` subdirectory in the app bundle
   - Enumerate subdirectories (each is a skill directory containing `skill.json` + `prompt.md`)
   - Copy each skill directory to `~/Library/Application Support/MenuBot/skills/`
   - If `overwrite: false`, skip skill directories that already exist at the destination
   ```swift
   private func copyBundledSkills(overwrite: Bool = true) {
       guard let bundledSkillsURL = Bundle.main.url(
           forResource: "PreinstalledSkills",
           withExtension: nil
       ) else { return }

       let fm = FileManager.default
       guard let skillDirs = try? fm.contentsOfDirectory(
           at: bundledSkillsURL,
           includingPropertiesForKeys: [.isDirectoryKey],
           options: [.skipsHiddenFiles]
       ) else { return }

       for sourceDir in skillDirs {
           var isDir: ObjCBool = false
           guard fm.fileExists(atPath: sourceDir.path, isDirectory: &isDir),
                 isDir.boolValue else { continue }

           let destDir = SkillsDirectoryManager.skillsDirectoryURL
               .appendingPathComponent(sourceDir.lastPathComponent)

           if fm.fileExists(atPath: destDir.path) {
               guard overwrite else { continue }
               try? fm.removeItem(at: destDir)
           }

           try? fm.copyItem(at: sourceDir, to: destDir)
       }
   }
   ```
3. Call `seedPreinstalledSkillsIfNeeded()` during app launch (in `AppDelegate` or `SkillsDirectoryManager.initialize()`)
4. Write tests:
   - First run copies all skill directories
   - Subsequent launch with same version does not re-copy
   - Version bump copies only new skill directories (existing directories untouched)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/SkillSeeder.swift` | Create | First-run seeding logic |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Call seeding on launch |
| `MenuBarCompanionTests/SkillSeederTests.swift` | Create | Unit tests for seeding logic |

#### Acceptance Criteria

- [ ] First launch copies all bundled skill directories to the skills directory
- [ ] Subsequent launches with the same version do not re-copy or overwrite
- [ ] App version bump seeds only new skill directories without overwriting existing ones
- [ ] Seeded version is tracked in UserDefaults
- [ ] User-modified skill directories are never overwritten

---

### Task 4.7 — Context Toggle UI

#### User Story

As a user, I can enable or disable optional context (clipboard, screenshot) before running a skill so I control what information is shared with Claude Code.

#### Implementation Steps

1. Add context attachment icons to the chat input bar (like attaching a photo in iMessage):
   ```swift
   // In the chat input bar (PopoverView.swift inputBar section)
   HStack(spacing: 4) {
       Button { viewModel.clipboardEnabled.toggle() } label: {
           Image(systemName: viewModel.clipboardEnabled ? "doc.on.clipboard.fill" : "doc.on.clipboard")
               .foregroundStyle(viewModel.clipboardEnabled ? .accentColor : .secondary)
       }
       Button { viewModel.screenshotEnabled.toggle() } label: {
           Image(systemName: viewModel.screenshotEnabled ? "camera.fill" : "camera")
               .foregroundStyle(viewModel.screenshotEnabled ? .accentColor : .secondary)
       }
   }
   ```
2. Bind toggles to `UserSettings` via the view model
3. Show a permission status indicator next to screenshot toggle:
   - Green checkmark if Screen Recording permission granted
   - Warning icon with "Permission required" if not granted
   - Tapping opens System Settings to the Privacy pane
4. Context toggles are global (apply to both free-form chat messages and skill runs) since they live on the chat input bar

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ContextToggleView.swift` | Create | Reusable context toggle component (attachment-style icons) |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Embed context attachment icons in chat input bar |

#### Acceptance Criteria

- [ ] Context attachment icons appear in the chat input bar
- [ ] Clipboard and screenshot toggles are independently controllable
- [ ] Default context (time, active app) is always included — no toggle needed
- [ ] Permission status is visible next to screenshot toggle
- [ ] Toggle states persist via UserSettings/UserDefaults

---

### Task 4.8 — Permission Handling

#### User Story

As the system, I detect and request macOS permissions for Screen Recording and Accessibility, and degrade gracefully when permissions are denied.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/PermissionManager.swift`:
   ```swift
   class PermissionManager {
       static func screenCapturePermissionGranted() -> Bool {
           return CGPreflightScreenCaptureAccess()
       }

       static func requestScreenCapturePermission() {
           CGRequestScreenCaptureAccess()
       }

       static func openScreenCaptureSettings() {
           // Open System Settings > Privacy > Screen Recording
           NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
       }
   }
   ```
2. Check permission before screenshot capture in `ContextProvider`:
   - If not granted, return nil for screenshot and log
3. Wire permission check into toggle UI:
   - When user enables screenshot toggle, check permission
   - If not granted, prompt or direct to System Settings
4. For Accessibility (selected text — experimental):
   - Check via `AXIsProcessTrusted()`
   - If not trusted, skip selected text silently

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/PermissionManager.swift` | Create | macOS permission detection and request logic |
| `MenuBarCompanion/Core/ContextProvider.swift` | Modify | Check permissions before capturing |
| `MenuBarCompanion/UI/ContextToggleView.swift` | Modify | Wire permission status indicators |

#### Acceptance Criteria

- [ ] Screen Recording permission is checked before screenshot capture
- [ ] Permission denied results in nil screenshot, not a crash
- [ ] User is directed to System Settings when permission is needed
- [ ] Accessibility permission is checked before selected text capture
- [ ] All permission failures degrade gracefully with appropriate logging

---

### Task 4.9 — ScheduleManager Foundation

#### User Story

As the system, I persist schedule configurations (which skills run at what time) so users can set up recurring skill execution.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/ScheduleManager.swift`:
   - Define `ScheduleEntry` model:
     ```swift
     struct ScheduleEntry: Codable, Identifiable {
         let id: UUID
         let skillFilePath: String
         let skillName: String
         var enabled: Bool
         var timeOfDay: DateComponents  // hour + minute
         var interval: ScheduleInterval // .daily, .weekly, etc.
         var lastRunDate: Date?
     }

     enum ScheduleInterval: String, Codable {
         case daily, weekly
     }
     ```
   - Implement persistence to `~/Library/Application Support/MenuBot/schedules.json`:
     ```swift
     class ScheduleManager: ObservableObject {
         @Published var schedules: [ScheduleEntry] = []

         func addSchedule(for skill: Skill, at time: DateComponents, interval: ScheduleInterval)
         func removeSchedule(id: UUID)
         func updateSchedule(_ entry: ScheduleEntry)
         func save()
         func load()
     }
     ```
   - Use atomic writes (`Data.write(to:options:.atomic)`) for file safety
2. Load schedules on app launch, save on every mutation
3. Write unit tests:
   - Add/remove/update schedules
   - Persistence round-trip (save → load → compare)
   - Graceful handling of corrupted JSON file

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScheduleManager.swift` | Create | Schedule persistence and management |
| `MenuBarCompanionTests/ScheduleManagerTests.swift` | Create | Unit tests for schedule CRUD and persistence |

#### Acceptance Criteria

- [ ] `ScheduleEntry` model captures skill, time, interval, and enabled state
- [ ] Schedules persist to JSON file and survive app restarts
- [ ] Add, remove, and update operations work correctly
- [ ] Corrupted JSON file is handled gracefully (reset to empty, log error)
- [ ] Atomic file writes prevent corruption

---

### Task 4.10 — Scheduling Engine

#### User Story

As the system, I check for pending schedules on a timer and execute skills when their scheduled time arrives.

#### Implementation Steps

1. Add a timer-based scheduler to `ScheduleManager`:
   ```swift
   private var checkTimer: Timer?

   func startScheduler() {
       checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
           self?.checkPendingSchedules()
       }
   }

   private func checkPendingSchedules() {
       let now = Date()
       for var schedule in schedules where schedule.enabled {
           if shouldFire(schedule: schedule, at: now) {
               fireSchedule(&schedule)
           }
       }
   }
   ```
2. Implement `shouldFire()`:
   - Compare current hour/minute with schedule's `timeOfDay`
   - Check that `lastRunDate` is not today (for daily) or this week (for weekly)
   - Allow a window (e.g., ±2 minutes) to handle slight timer drift
3. Implement `fireSchedule()`:
   - Mark `lastRunDate = Date()` and save
   - Trigger skill execution (delegate to `ChatViewModel` or a shared `SkillExecutor`)
4. Handle wake-from-sleep:
   - Subscribe to `NSWorkspace.willSleepNotification` / `didWakeNotification`
   - On wake, immediately run `checkPendingSchedules()` to catch missed schedules
5. Start scheduler in `AppDelegate.applicationDidFinishLaunching`

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScheduleManager.swift` | Modify | Add timer-based scheduling engine |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Start scheduler on launch |
| `MenuBarCompanionTests/ScheduleManagerTests.swift` | Modify | Add tests for schedule firing logic |

#### Acceptance Criteria

- [ ] Timer checks for pending schedules every 60 seconds
- [ ] Schedule fires when current time matches scheduled time and hasn't already run today
- [ ] `lastRunDate` is updated to prevent duplicate firing
- [ ] Missed schedules (sleep/wake) are caught and executed on wake
- [ ] Scheduler starts automatically on app launch

---

### Task 4.11 — Background Execution & Notification Delivery

#### User Story

As a user, I receive a macOS notification when a scheduled skill finishes running, even if the popover isn't open.

#### Implementation Steps

1. Create a skill execution method that doesn't require the popover:
   - Extract execution logic from `ChatViewModel` into a shared `SkillExecutor` (or call into existing `CommandRunner` directly)
   - Collect context via `ContextProvider`, substitute template variables, invoke CLI
   - Capture the final output/result text
2. Set up `UNUserNotificationCenter`:
   ```swift
   import UserNotifications

   class NotificationManager {
       static func requestPermission() {
           UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
               // Log result
           }
       }

       static func deliverScheduledResult(skillName: String, summary: String) {
           let content = UNMutableNotificationContent()
           content.title = "Menu-Bot: \(skillName)"
           content.body = summary
           content.sound = .default

           let request = UNNotificationRequest(
               identifier: UUID().uuidString,
               content: content,
               trigger: nil  // deliver immediately
           )
           UNUserNotificationCenter.current().add(request)
       }
   }
   ```
3. Wire `ScheduleManager.fireSchedule()` to:
   - Execute the skill via `SkillExecutor`
   - On completion, extract a summary (first ~200 chars of output or a parsed event)
   - Call `NotificationManager.deliverScheduledResult()`
4. Request notification permission during first-run or when user enables first schedule
5. Handle overlapping runs: if a skill is already running from a schedule, skip the duplicate fire

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/SkillExecutor.swift` | Create | Shared skill execution logic (decoupled from popover) |
| `MenuBarCompanion/Core/NotificationManager.swift` | Create | macOS notification delivery |
| `MenuBarCompanion/Core/ScheduleManager.swift` | Modify | Wire fire → execute → notify pipeline |

#### Acceptance Criteria

- [ ] Scheduled skills execute without the popover being open
- [ ] Scheduled skill results are appended to the chat history as assistant messages (so the user sees them when they next open the popover)
- [ ] macOS notification is delivered with skill name and result summary (secondary notification in case popover is closed)
- [ ] Notification permission is requested before first delivery
- [ ] Overlapping scheduled runs of the same skill are prevented
- [ ] Execution uses the same context injection and template substitution as manual runs

---

### Task 4.12 — Schedule UI

#### User Story

As a user, I can schedule a skill from its detail view by choosing a time and enabling the schedule.

#### Implementation Steps

1. Add a "Schedule" section to `SkillDetailView`:
   ```swift
   Section("Schedule") {
       if skill.suggestedSchedule != nil {
           Toggle("Enable Schedule", isOn: $scheduleEnabled)
           if scheduleEnabled {
               DatePicker("Run at", selection: $scheduledTime, displayedComponents: .hourAndMinute)
               Picker("Repeat", selection: $scheduleInterval) {
                   Text("Daily").tag(ScheduleInterval.daily)
                   Text("Weekly").tag(ScheduleInterval.weekly)
               }
           }
       } else {
           Text("This skill does not have a suggested schedule.")
               .foregroundColor(.secondary)
       }
   }
   ```
2. Wire toggle/picker changes to `ScheduleManager`:
   - Enable → create `ScheduleEntry`
   - Disable → remove or set `enabled = false`
   - Time/interval change → update entry
3. Add a "Schedules" view accessible from the navigation menu (hamburger menu in chat header):
   ```swift
   ForEach(scheduleManager.schedules.filter(\.enabled)) { entry in
       HStack {
           Text(entry.skillName)
           Spacer()
           Text(entry.timeOfDay.formatted())
           Text(entry.interval.rawValue)
       }
   }
   ```
4. Show next run time for each schedule

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/SkillDetailView.swift` | Modify | Add schedule section with time picker |
| `MenuBarCompanion/UI/SchedulesOverviewView.swift` | Create | Active schedules list view |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add "Schedules" menu item to navigation menu in chat header |

#### Acceptance Criteria

- [ ] Skills with `suggested_schedule` show a schedule section in detail view
- [ ] User can enable/disable schedule and pick time and interval
- [ ] Schedule changes are persisted immediately via ScheduleManager
- [ ] Active schedules are visible in an overview list
- [ ] Next run time is displayed for each active schedule

---

### Task 4.13 — Launch at Login

#### User Story

As a user, I can enable "Launch at Login" so the app starts automatically and my scheduled skills don't miss their times.

#### Implementation Steps

1. Use `SMAppService` (macOS 13+) for Login Items:
   ```swift
   import ServiceManagement

   class LaunchAtLoginManager {
       static var isEnabled: Bool {
           SMAppService.mainApp.status == .enabled
       }

       static func toggle() throws {
           if isEnabled {
               try SMAppService.mainApp.unregister()
           } else {
               try SMAppService.mainApp.register()
           }
       }
   }
   ```
2. Add a toggle in settings or the popover:
   ```swift
   Toggle("Launch at Login", isOn: Binding(
       get: { LaunchAtLoginManager.isEnabled },
       set: { _ in try? LaunchAtLoginManager.toggle() }
   ))
   ```
3. When user enables their first schedule, suggest enabling Launch at Login if not already enabled

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/LaunchAtLoginManager.swift` | Create | SMAppService wrapper for Login Items |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add Launch at Login toggle |

#### Acceptance Criteria

- [ ] Launch at Login toggle works via SMAppService
- [ ] App appears in System Settings > Login Items when enabled
- [ ] User is prompted to enable Launch at Login when first schedule is created
- [ ] Toggle reflects actual system state

---

## 5. Integration Points

- **CommandRunner (Phase 1):** Context-augmented prompts are passed through the existing CommandRunner execution path. No protocol changes needed — just longer prompt strings.
- **EventParser (Phase 2):** Scheduled skill output is routed through EventParser for toast events. Toasts may not render if popover is closed — notifications serve as the fallback.
- **SkillsDirectoryManager (Phase 3 + 3.5):** First-run seeding writes skill directories to the same skills directory that SkillsDirectoryManager watches. The file watcher will pick up seeded directories automatically.
- **Skill model (Phase 3 + 3.5):** Preinstalled skills use the directory format from Phase 3.5 — each skill is a directory with `skill.json` (conforming to `SkillMetadata` Codable) and `prompt.md`. `suggested_schedule` is a new optional field in `skill.json`.
- **UserDefaults:** Used for seeding version tracking, context toggle persistence, and Launch at Login state.
- **macOS APIs:** NSWorkspace (active app, sleep/wake), NSPasteboard (clipboard), CGWindowListCreateImage (screenshot), UNUserNotificationCenter (notifications), SMAppService (Login Items), CGPreflightScreenCaptureAccess (permissions).

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

- `ContextProviderTests`: default context returns time and app name; serialization format matches spec
- `TemplateEngineTests`: all variable types substituted; missing vars produce placeholders; unrecognized vars stripped
- `SkillSeederTests`: first-run copies skill directories; re-run skips existing; version bump adds new only
- `ScheduleManagerTests`: CRUD operations; persistence round-trip; `shouldFire` logic with various dates

### During Implementation: Build Against Tests

- Implement `ContextProvider` → green tests for context collection
- Implement `TemplateEngine` → green tests for substitution
- Implement `SkillSeeder` → green tests for seeding logic
- Implement `ScheduleManager` → green tests for scheduling logic
- Integration test: seed skills → run Morning Brief → verify context injected in CLI call

### Phase End: Polish Tests

- Edge cases: empty clipboard, nil active app, corrupted schedule file, permission denied mid-run
- Integration: scheduled run fires → executes → notification delivered (may require manual verification)
- Remove any placeholder tests; ensure all tests pass cleanly

---

## 7. Definition of Done

- [ ] Features complete: context injection, preinstalled skills, template substitution, scheduling, notifications
- [ ] Tests passing (unit + integration) for ContextProvider, TemplateEngine, SkillSeeder, ScheduleManager
- [ ] Manual verification of end-to-end flows
- [ ] No regressions to Phase 1/2/3 functionality
- [ ] Data correctness: schedules persist, seeding is idempotent, context is accurate

### Backward Compatibility

No backward compatibility concerns — this phase adds new systems (context, seeding, scheduling) without modifying existing Phase 1-3 interfaces. The Skill model gains an optional `suggested_schedule` field which is additive and backward-compatible with existing Codable parsing.

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Phase 5 until all items are verified:**

- [ ] **Build verification:** Project compiles with zero errors and zero warnings related to Phase 4 code
- [ ] **Context test:** Send a chat message → verify the CLI invocation includes `--- CONTEXT ---` block with current time and active app
- [ ] **Optional context test:** Tap clipboard attachment icon in chat input bar → copy text → send message → verify clipboard appears in context block
- [ ] **Seeding test:** Delete `~/Library/Application Support/MenuBot/skills/` → relaunch app → verify 3+ skill directories appear (each with `skill.json` + `prompt.md`)
- [ ] **Template test:** Run Morning Brief → verify `{context.time}` and `{context.active_app}` are replaced with actual values from the `prompt.md` template in the CLI call
- [ ] **Schedule test:** Schedule Morning Brief for 1 minute from now → wait → verify it executes, result appears as a chat message, and macOS notification appears
- [ ] **Permission test:** Revoke Screen Recording permission → enable screenshot toggle → run skill → verify graceful degradation (no crash, screenshot not included)
- [ ] **Persistence test:** Set schedules and toggles → quit and relaunch → verify all settings preserved
- [ ] **Launch at Login test:** Enable toggle → verify app appears in System Settings > Login Items

**Signoff:** ______________________ Date: __________

# Phase 3 — Skills Library & Management

- **Phase Number:** 3
- **Phase Name:** Skills Library & Management
- **Source:** docs/mvp/phases/overviews/objective3PhaseOverview.md

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
>
> If you need any prisma commands run (e.g. `npx prisma migrate dev`), let the user know and they will run them.

---

## 📋 Task Tracking Instructions

- Each task heading includes a checkbox placeholder. Mark the task title with a ✅ emoji AFTER completing the work.
- Update this document as you go — it is the source of truth for phase progress.
- This phase cannot advance to Phase 4 until all task checkboxes are checked.
- If execution stops mid-phase, the checkmarks indicate exactly where progress was interrupted.

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Builds the entire skills system — a local skills directory with runtime file discovery, a JSON skill file format with metadata and prompt templates, a browse/star/run UI, skill execution wired through the existing `CommandRunner`, and a bridge skill file that connects Menu-Bot to Claude Code.
- **What already exists from previous phases:** `AppDelegate.swift` creates the menu bar icon and popover. `PopoverView.swift` renders a command input area and output area. `PopoverViewModel.swift` orchestrates execution via `CommandRunner.swift`. `EventParser.swift` detects `[MENUBOT_EVENT]` JSON payloads and parses them. The app builds and runs as a menu-bar-only app with sandbox disabled.
- **What future phases depend on:** Phase 4 adds context injection (`{context.screenshot}`, `{context.clipboard}`, `{context.active_app}`), preinstalled skills, and scheduling. Phase 5 adds persistence of starred skills to UserDefaults, safety confirmations, stop/cancel flows, and activity logging.

---

## 0. Mental Model (Required)

**Problem:** Users currently must type raw commands into the popover every time. There is no way to save, browse, or reuse pre-written prompts. The app needs a skills system so users can drop skill files into a folder and immediately browse, star, and execute them from the UI.

**Where it fits:** Phase 3 is the core product differentiator. Phases 1–2 established the shell and event protocol. Phase 3 builds the library of reusable prompts on top of that foundation. Phases 4–5 extend the skills system with context injection, scheduling, persistence, and safety.

**Data flow:**
1. User drops a `.json` skill file into `~/Library/Application Support/MenuBot/skills/`
2. `SkillsDirectoryManager` detects the new file via filesystem watcher, parses it into a `Skill` model
3. The skill appears in `SkillsListView` (All Skills browser)
4. User stars a skill → it appears in the main popover's Starred Skills section
5. User taps a skill → `SkillDetailView` shows description + extra instructions input
6. User taps "Run" → `PopoverViewModel` assembles the prompt (template + extra instructions), passes it to `CommandRunner`
7. Output streams back through `EventParser` and displays in the popover output area

**Core entities:**
- **`Skill`** — Codable struct representing a skill file (name, description, prompt template, optional metadata)
- **`SkillsDirectoryManager`** — watches the skills directory, emits `[Skill]` updates
- **`SkillsListView`** — SwiftUI view listing all discovered skills
- **`SkillDetailView`** — SwiftUI view for running a single skill
- **Bridge skill** — a special skill file that instructs Claude Code about the Menu-Bot skills system

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Enable users to drop JSON skill files into a local directory and immediately browse, star, and run them from the popover without rebuilding the app.

### Prerequisites

- Xcode project builds and runs successfully
- `AppDelegate.swift`, `PopoverView.swift`, `PopoverViewModel.swift`, `CommandRunner.swift`, `EventParser.swift` all exist and function
- `CommandRunner` can execute arbitrary processes and stream output
- `EventParser` can detect and parse `[MENUBOT_EVENT]` lines

### Key Deliverables

- `Skill` model and JSON file parser (`Core/Skill.swift`)
- `SkillsDirectoryManager` with filesystem watching (`Core/SkillsDirectoryManager.swift`)
- "All Skills" browser view (`UI/SkillsListView.swift`)
- "Run Skill" detail view (`UI/SkillDetailView.swift`)
- Updated `PopoverView.swift` with starred skills section and "All Skills" navigation
- Updated `PopoverViewModel.swift` with starring state and skill execution
- Bridge skill file (`Resources/bridge-skill.json`)
- Unit tests for skill parsing and directory scanning

### System-Level Acceptance Criteria

- Adding/removing/modifying a `.json` file in the skills directory updates the UI without app restart
- Malformed skill files are silently skipped (logged to console) — they do not crash the app
- Skill prompt templates correctly substitute `{extra_instructions}` — unused `{context.*}` variables are stripped for now
- Starring is in-memory only (no persistence requirement until Phase 5)
- Skill execution reuses the existing `CommandRunner` pipeline — no new execution path
- The bridge skill file is automatically placed in the skills directory on first launch

---

## 2. Execution Order

### Blocking Tasks (Sequential Critical Path)

1. **Task 3.1** — Skill File Format & `Skill` Model (everything depends on this type)
2. **Task 3.2** — Skills Directory Manager (UI needs a data source)
3. **Task 3.3** — Skills Browse & Star UI (needs model + data source)
4. **Task 3.4** — Skill Execution Wiring (needs UI + model)
5. **Task 3.5** — Bridge Skill (needs directory manager + execution)

### Parallel Tasks

- Tasks 3.3 and 3.4 can be partially parallelized: the UI can be built with stub data while execution wiring happens, but they share `PopoverViewModel` so final integration is sequential.
- Unit tests for 3.1 and 3.2 can be written alongside their respective tasks.

### Final Integration

- Verify end-to-end: drop a skill file → appears in UI → star it → appears in popover → run it → output streams
- Verify bridge skill is placed on first launch and is runnable
- Verify malformed files are skipped gracefully

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Skill file format | JSON vs YAML | JSON (`.json` extension) | No YAML dependency needed. `Codable` handles JSON natively. | Low — JSON is slightly less human-friendly, but sufficient for v1. |
| File watching mechanism | `DispatchSource` (kqueue) vs `FSEvents` vs polling | `DispatchSource` + periodic re-scan fallback | Lightweight, no dependencies. Kqueue can miss nested changes, so re-scan on popover open as fallback. | Medium — kqueue may miss rapid successive changes. Mitigated by re-scan. |
| Template variable syntax | `{var}` vs `{{var}}` vs `$var` | `{var}` simple string replacement | Simplest approach. No template engine needed for v1. | Low — may conflict with JSON braces in prompt text. Acceptable for v1. |
| Navigation within popover | `NavigationStack` vs sheet | `NavigationStack` inside popover | Keeps transitions within popover bounds. Sheet would feel disconnected. | Low — popover size may feel tight. Can adjust dimensions. |
| Star storage (v1) | In-memory `Set<String>` vs UserDefaults | In-memory `Set<String>` keyed by filename | Phase 5 adds persistence. Keep v1 simple. | None — expected limitation. |
| Skill identity | File path vs UUID vs filename | Filename (without extension) | Simple, human-readable, stable across app launches. File path changes if directory moves. | Low — duplicate filenames would conflict. Acceptable for v1. |

---

## 4. Subtasks

### Task 3.1 — Skill File Format & Data Model

#### User Story

As a developer extending Menu-Bot, I need a well-defined skill file format and a Swift model so that skill files can be parsed reliably and the rest of the system has a concrete type to work with.

#### Implementation Steps

1. **Create `Core/Skill.swift`** with the following:

```swift
import Foundation

struct Skill: Codable, Identifiable, Equatable {
    // Required fields
    let name: String
    let description: String
    let prompt: String

    // Optional fields
    let category: String?
    let tags: [String]?
    let icon: String?               // SF Symbol name or emoji
    let suggestedSchedule: String?
    let requiredPermissions: [String]?
    let system: Bool?               // true for bridge skill (hidden from UI)

    // Runtime properties (not from file)
    var id: String { filePath ?? name }
    var filePath: String?
    var isStarred: Bool = false

    enum CodingKeys: String, CodingKey {
        case name, description, prompt, category, tags, icon
        case suggestedSchedule = "suggested_schedule"
        case requiredPermissions = "required_permissions"
        case system
    }
}
```

2. **Add prompt template substitution** as an extension on `Skill`:

```swift
extension Skill {
    func assemblePrompt(extraInstructions: String? = nil) -> String {
        var result = prompt
        if let extra = extraInstructions, !extra.isEmpty {
            result = result.replacingOccurrences(of: "{extra_instructions}", with: extra)
        } else {
            result = result.replacingOccurrences(of: "{extra_instructions}", with: "")
        }
        // Strip unused context variables (Phase 4 will populate these)
        result = result.replacingOccurrences(of: "{context.screenshot}", with: "")
        result = result.replacingOccurrences(of: "{context.clipboard}", with: "")
        result = result.replacingOccurrences(of: "{context.active_app}", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

3. **Add a static parser method** for loading from a file path:

```swift
extension Skill {
    static func load(from url: URL) throws -> Skill {
        let data = try Data(contentsOf: url)
        var skill = try JSONDecoder().decode(Skill.self, from: data)
        skill.filePath = url.lastPathComponent
        return skill
    }
}
```

4. **Create a sample skill file** for manual testing at `Resources/sample-skill.json`:

```json
{
    "name": "Summarize Clipboard",
    "description": "Summarize whatever is currently on the clipboard.",
    "prompt": "Summarize the following content concisely: {context.clipboard} {extra_instructions}",
    "category": "Productivity",
    "tags": ["clipboard", "summary"],
    "icon": "doc.on.clipboard"
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/Skill.swift` | Create | Skill model, Codable, prompt template substitution, file loader |
| `Resources/sample-skill.json` | Create | Sample skill file for manual testing |

#### Acceptance Criteria

- [ ] `Skill` struct compiles and conforms to `Codable`, `Identifiable`, `Equatable`
- [ ] Valid JSON skill files decode without error
- [ ] Missing optional fields decode to `nil` (no crash)
- [ ] Malformed JSON throws a decodable error (does not crash)
- [ ] `assemblePrompt()` substitutes `{extra_instructions}` correctly
- [ ] `assemblePrompt()` strips unused `{context.*}` variables
- [ ] Unit tests pass for all parsing scenarios

---

### Task 3.2 — Skills Directory & Runtime Discovery

#### User Story

As a user, I want to drop skill files into a folder and have them appear in Menu-Bot automatically, so I don't have to rebuild or restart the app.

#### Implementation Steps

1. **Create `Core/SkillsDirectoryManager.swift`**:

```swift
import Foundation
import Combine

@MainActor
class SkillsDirectoryManager: ObservableObject {
    @Published var skills: [Skill] = []

    static let skillsDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MenuBot/skills", isDirectory: true)
    }()

    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1

    init() {
        ensureDirectoryExists()
        scan()
        startWatching()
    }

    deinit {
        stopWatching()
    }
}
```

2. **Implement directory creation**:

```swift
private func ensureDirectoryExists() {
    let fm = FileManager.default
    if !fm.fileExists(atPath: Self.skillsDirectoryURL.path) {
        try? fm.createDirectory(at: Self.skillsDirectoryURL, withIntermediateDirectories: true)
    }
}
```

3. **Implement scanning**:

```swift
func scan() {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(at: Self.skillsDirectoryURL,
                                                   includingPropertiesForKeys: nil,
                                                   options: [.skipsHiddenFiles]) else {
        skills = []
        return
    }

    let parsed = files
        .filter { $0.pathExtension == "json" }
        .compactMap { url -> Skill? in
            do {
                return try Skill.load(from: url)
            } catch {
                print("[SkillsDirectoryManager] Failed to parse \(url.lastPathComponent): \(error)")
                return nil
            }
        }
        .filter { $0.system != true }  // Hide system skills from browse UI
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    self.skills = parsed
}
```

4. **Implement file watching** using `DispatchSource`:

```swift
private func startWatching() {
    let path = Self.skillsDirectoryURL.path
    directoryFD = open(path, O_EVTONLY)
    guard directoryFD >= 0 else { return }

    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: directoryFD,
        eventMask: [.write, .rename, .delete],
        queue: .main
    )
    source.setEventHandler { [weak self] in
        self?.scan()
    }
    source.setCancelHandler { [weak self] in
        if let fd = self?.directoryFD, fd >= 0 {
            close(fd)
        }
    }
    source.resume()
    directorySource = source
}

private func stopWatching() {
    directorySource?.cancel()
    directorySource = nil
}
```

5. **Add a re-scan trigger** for when the popover opens (fallback for missed kqueue events):

```swift
func rescanIfNeeded() {
    scan()
}
```

6. **Place the bridge skill on first launch** (called from `ensureDirectoryExists` or a separate method):

```swift
func ensureBridgeSkillExists() {
    let bridgeURL = Self.skillsDirectoryURL.appendingPathComponent("bridge-skill.json")
    guard !FileManager.default.fileExists(atPath: bridgeURL.path) else { return }
    if let bundledURL = Bundle.main.url(forResource: "bridge-skill", withExtension: "json") {
        try? FileManager.default.copyItem(at: bundledURL, to: bridgeURL)
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/SkillsDirectoryManager.swift` | Create | Directory creation, scanning, file watching, bridge skill placement |

#### Acceptance Criteria

- [ ] Skills directory is created at `~/Library/Application Support/MenuBot/skills/` on first launch
- [ ] All `.json` files in the directory are parsed and available via `skills` published property
- [ ] Malformed files are skipped with a console warning (no crash)
- [ ] Adding a new `.json` file to the directory triggers a re-scan and updates `skills`
- [ ] Removing a `.json` file triggers a re-scan and removes it from `skills`
- [ ] System skills (`"system": true`) are filtered out of the browseable list
- [ ] Bridge skill is copied from the app bundle to the skills directory on first launch if not already present
- [ ] Unit tests pass for directory scanning logic

---

### Task 3.3 — Skills Browse & Star UI

#### User Story

As a user, I want to browse all my skills in a list, star my favorites so they appear in the main popover, and tap a skill to see its details and run it.

#### Implementation Steps

1. **Create `UI/SkillsListView.swift`** — the All Skills browser:

```swift
import SwiftUI

struct SkillsListView: View {
    @EnvironmentObject var viewModel: PopoverViewModel

    var body: some View {
        List {
            ForEach(viewModel.allSkills) { skill in
                NavigationLink(value: skill) {
                    SkillRowView(skill: skill, isStarred: viewModel.isStarred(skill)) {
                        viewModel.toggleStar(skill)
                    }
                }
            }
        }
        .navigationTitle("All Skills")
        .overlay {
            if viewModel.allSkills.isEmpty {
                ContentUnavailableView(
                    "No Skills Found",
                    systemImage: "folder",
                    description: Text("Add .json skill files to\n~/Library/Application Support/MenuBot/skills/")
                )
            }
        }
    }
}
```

2. **Create `SkillRowView`** (inline in `SkillsListView.swift` or separate):

```swift
struct SkillRowView: View {
    let skill: Skill
    let isStarred: Bool
    let onToggleStar: () -> Void

    var body: some View {
        HStack {
            if let icon = skill.icon {
                Image(systemName: icon)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.headline)
                Text(skill.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button(action: onToggleStar) {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .foregroundStyle(isStarred ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
```

3. **Create `UI/SkillDetailView.swift`** — the Run Skill screen:

```swift
import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @EnvironmentObject var viewModel: PopoverViewModel
    @State private var extraInstructions: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Skill info
            if let icon = skill.icon {
                Image(systemName: icon).font(.largeTitle)
            }
            Text(skill.name).font(.title2).bold()
            Text(skill.description).foregroundStyle(.secondary)

            if let category = skill.category {
                Text(category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Divider()

            // Extra instructions input
            Text("Extra Instructions (optional)").font(.subheadline).bold()
            TextField("Add context or instructions...", text: $extraInstructions, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            // Run button
            Button(action: {
                viewModel.runSkill(skill, extraInstructions: extraInstructions)
            }) {
                Label("Run Skill", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)

            Spacer()
        }
        .padding()
        .navigationTitle(skill.name)
    }
}
```

4. **Update `UI/PopoverView.swift`** to add:
   - A "Starred Skills" section above the command input area
   - An "All Skills" button that navigates to `SkillsListView`
   - Wrap the popover content in a `NavigationStack`

Key changes to `PopoverView.swift`:
   - Wrap existing content in `NavigationStack`
   - Add starred skills section: list of starred skills with tap-to-run
   - Add "All Skills" `NavigationLink` or button
   - Add `.navigationDestination(for: Skill.self)` to route to `SkillDetailView`

5. **Update `UI/PopoverViewModel.swift`** to add:

```swift
// New properties
@Published var allSkills: [Skill] = []
@Published var starredSkillIDs: Set<String> = []

private var skillsManager: SkillsDirectoryManager?
private var cancellables = Set<AnyCancellable>()

// Starring
func isStarred(_ skill: Skill) -> Bool {
    starredSkillIDs.contains(skill.id)
}

func toggleStar(_ skill: Skill) {
    if starredSkillIDs.contains(skill.id) {
        starredSkillIDs.remove(skill.id)
    } else {
        starredSkillIDs.insert(skill.id)
    }
}

var starredSkills: [Skill] {
    allSkills.filter { starredSkillIDs.contains($0.id) }
}
```

Wire the `SkillsDirectoryManager` into the view model:

```swift
func setupSkillsManager() {
    let manager = SkillsDirectoryManager()
    self.skillsManager = manager
    manager.$skills
        .receive(on: RunLoop.main)
        .assign(to: &$allSkills)
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/SkillsListView.swift` | Create | All Skills browser view with rows and star toggle |
| `MenuBarCompanion/UI/SkillDetailView.swift` | Create | Skill detail view with extra instructions and Run button |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add NavigationStack, starred skills section, All Skills navigation |
| `MenuBarCompanion/UI/PopoverViewModel.swift` | Modify | Add allSkills, starredSkillIDs, starring logic, skills manager wiring |

#### Acceptance Criteria

- [ ] Tapping "All Skills" in the popover navigates to `SkillsListView`
- [ ] `SkillsListView` displays all discovered skills with name, description, and optional icon
- [ ] Tapping the star icon on a skill toggles its starred state
- [ ] Starred skills appear in the main popover's "Starred Skills" section
- [ ] Tapping a skill row navigates to `SkillDetailView`
- [ ] `SkillDetailView` shows skill name, description, category, extra instructions input, and Run button
- [ ] Empty state is shown when no skills exist in the directory
- [ ] Back navigation works within the popover

---

### Task 3.4 — Skill Execution

#### User Story

As a user, I want to run a skill from the UI and see its output streamed in the popover, using the same experience as the raw command input.

#### Implementation Steps

1. **Add `runSkill` method to `PopoverViewModel`**:

```swift
func runSkill(_ skill: Skill, extraInstructions: String? = nil) {
    let assembledPrompt = skill.assemblePrompt(extraInstructions: extraInstructions)
    // Use the assembled prompt as the command input
    inputText = assembledPrompt
    run()
}
```

This reuses the existing `run()` method and `CommandRunner` pipeline. The skill's assembled prompt is treated as if the user typed it.

2. **Handle skill execution from starred skills section** in the popover:
   - Tapping a starred skill in the main popover navigates to `SkillDetailView` (same as from All Skills)
   - User can add extra instructions and tap "Run"
   - Alternatively, provide a quick-run action (e.g., long press or secondary tap) that runs with no extra instructions

3. **Ensure the output area is visible** when a skill starts running:
   - If the user is on the `SkillDetailView` or `SkillsListView`, navigate back to the main popover view so output is visible
   - Or: show output inline in `SkillDetailView` — depends on popover space constraints. Recommend navigating back for v1.

4. **Add navigation-back-on-run logic**:
   - In `SkillDetailView`, after calling `viewModel.runSkill(...)`, pop back to the root view so the user sees the streaming output in the main popover area.
   - Use `@Environment(\.dismiss)` or a binding to the `NavigationStack` path.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/PopoverViewModel.swift` | Modify | Add `runSkill(_:extraInstructions:)` method |
| `MenuBarCompanion/UI/SkillDetailView.swift` | Modify | Wire Run button to `runSkill`, add dismiss-on-run |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Ensure navigation path resets on skill run if needed |

#### Acceptance Criteria

- [ ] Running a skill from `SkillDetailView` invokes `CommandRunner` with the assembled prompt
- [ ] `{extra_instructions}` is substituted into the prompt correctly
- [ ] Unused `{context.*}` variables are stripped from the prompt
- [ ] Output streams in the popover output area, same as raw command execution
- [ ] User is returned to the main popover view when a skill starts running
- [ ] Running indicator shows while skill is executing
- [ ] Cancel button works to terminate a running skill

---

### Task 3.5 — Bridge Skill

#### User Story

As a user, I want a pre-installed bridge skill that instructs Claude Code to interact with Menu-Bot's skills system, so Claude Code can discover and report on available skills.

#### Implementation Steps

1. **Create `Resources/bridge-skill.json`**:

```json
{
    "name": "Menu-Bot Bridge",
    "description": "Connects Claude Code to the Menu-Bot skills system. Instructs Claude Code to scan the skills directory and communicate results back via the event protocol.",
    "prompt": "You are interacting with Menu-Bot, a macOS menu bar companion app. Menu-Bot has a skills directory at ~/Library/Application Support/MenuBot/skills/ containing JSON skill files. Each skill file has a name, description, and prompt template.\n\nYour task:\n1. Scan the skills directory and list all available skills\n2. For each skill, report its name and description\n3. Use the [MENUBOT_EVENT] protocol to communicate results back to Menu-Bot\n\nTo send an event, output a line in this exact format:\n[MENUBOT_EVENT]{\"type\":\"toast\",\"payload\":{\"title\":\"Skills Found\",\"message\":\"Found N skills in the directory\"}}\n\n{extra_instructions}",
    "category": "System",
    "tags": ["bridge", "system"],
    "icon": "link",
    "system": true
}
```

2. **Add `bridge-skill.json` to the Xcode project** as a bundle resource:
   - In Xcode, add the file to the project under a `Resources` group
   - Ensure it is included in the "Copy Bundle Resources" build phase

3. **Wire bridge skill placement** in `SkillsDirectoryManager`:
   - The `ensureBridgeSkillExists()` method (from Task 3.2) copies the bridge skill from the app bundle to the skills directory on first launch
   - Call `ensureBridgeSkillExists()` from `init()` after `ensureDirectoryExists()` and before `scan()`

4. **Verify the bridge skill is hidden from the browse UI** because `"system": true` is set, and `scan()` filters these out.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/bridge-skill.json` | Create | Bridge skill file bundled with the app |
| `MenuBarCompanion/Core/SkillsDirectoryManager.swift` | Modify | Call `ensureBridgeSkillExists()` in init |

#### Acceptance Criteria

- [ ] `bridge-skill.json` exists in the app bundle
- [ ] On first launch, the bridge skill is copied to the skills directory
- [ ] On subsequent launches, the bridge skill is not overwritten if already present
- [ ] The bridge skill does NOT appear in the All Skills browser (filtered by `system: true`)
- [ ] Running the bridge skill (e.g., via direct file reference or removing the system flag) produces expected output via Claude Code
- [ ] The bridge skill's prompt references the correct skills directory path and event protocol format

---

## 5. Integration Points

- **`CommandRunner` (existing):** Skill execution flows through the same `CommandRunner.start()` pipeline used for raw commands. No new execution path.
- **`EventParser` (existing):** Skill output (especially from the bridge skill) may contain `[MENUBOT_EVENT]` lines. These are handled by the existing parser.
- **`PopoverViewModel` (existing):** Extended with skills manager, starring state, and `runSkill()` method. Must not break existing raw command input/output flow.
- **`AppDelegate` / `PopoverView` (existing):** Popover now wraps content in `NavigationStack`. Must preserve existing popover sizing, toggle behavior, and appearance.
- **Filesystem:** Reads/writes to `~/Library/Application Support/MenuBot/skills/`. App sandbox is already disabled. No additional entitlements needed.
- **Bundle resources:** Bridge skill JSON must be added to "Copy Bundle Resources" in Xcode build phases.

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

Create test targets/files before implementation:

| Test File | Tests |
|-----------|-------|
| `Tests/SkillParsingTests.swift` | Valid JSON decoding, missing optional fields, malformed JSON, prompt substitution, context variable stripping |
| `Tests/SkillsDirectoryTests.swift` | Directory creation, scanning with valid/invalid/empty files, system skill filtering |

### During Implementation: Build Against Tests

- **`Skill` parsing tests:** Write first, then implement `Skill.swift` until all tests pass
- **Prompt assembly tests:** Verify `{extra_instructions}` substitution and `{context.*}` stripping
- **Directory scanning tests:** Use a temporary directory with test fixture JSON files. Verify correct count, ordering, and error handling.

### Phase End: Polish Tests

- Add edge case tests: empty prompt, very long prompt, special characters in JSON, duplicate filenames
- Add integration test: drop file → scan → verify skill appears in `allSkills`
- Verify all tests pass with `xcodebuild test`
- Remove any placeholder stubs

---

## 7. Definition of Done

- [ ] `Skill` model parses valid JSON skill files correctly
- [ ] `SkillsDirectoryManager` creates the skills directory on first launch
- [ ] `SkillsDirectoryManager` detects file changes and updates the skill list
- [ ] `SkillsListView` displays all discovered skills
- [ ] Star toggle works and starred skills appear in the main popover
- [ ] `SkillDetailView` shows skill details with extra instructions input
- [ ] Running a skill streams output through existing `CommandRunner` pipeline
- [ ] Bridge skill is auto-placed and hidden from browse UI
- [ ] Unit tests pass for skill parsing and directory scanning
- [ ] No regressions to existing raw command input/output functionality
- [ ] App builds and runs without warnings or errors

### Backward Compatibility

No backward compatibility concerns. This phase adds entirely new functionality. The existing raw command input/output flow must continue to work unchanged — skill execution is additive, not a replacement.

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Phase 4 until all items below are verified.**

- [ ] **Build verification:** `xcodebuild build` succeeds with no errors
- [ ] **Test verification:** `xcodebuild test` — all unit tests pass
- [ ] **Manual test — skill discovery:** Drop a `.json` skill file into `~/Library/Application Support/MenuBot/skills/`. Open popover → tap "All Skills" → verify the skill appears.
- [ ] **Manual test — starring:** Star a skill → verify it appears in the popover's Starred Skills section. Unstar → verify it disappears.
- [ ] **Manual test — skill execution:** Open a skill → add extra instructions → tap Run → verify output streams in popover.
- [ ] **Manual test — malformed file:** Drop an invalid JSON file into the skills directory → verify it is skipped (no crash, other skills still load).
- [ ] **Manual test — bridge skill:** Verify `bridge-skill.json` exists in `~/Library/Application Support/MenuBot/skills/` after first launch. Verify it does NOT appear in the All Skills browser.
- [ ] **Manual test — raw command:** Type a raw command in the input field → Run → verify output streams as before (no regression).
- [ ] **Signoff:** All acceptance criteria from Objective 3 are met:
  - [ ] User can open the popover and view starred skills
  - [ ] User can open the popover and open the skills browser
  - [ ] User can add a new skill file to the skills folder and it appears in the UI without rebuilding

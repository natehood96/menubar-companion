# Phase 5 — Safety, Persistence & Polish

- **Phase Number:** 5
- **Phase Name:** Safety, Persistence & Polish
- **Source:** docs/mvp/phases/overviews/objective5PhaseOverview.md

---

## AI Agent Execution Instructions

> **READ THIS ENTIRE DOCUMENT BEFORE STARTING ANY WORK.**
>
> Once you have read and understood the full document:
>
> 1. Execute each task in order
> 2. After completing a task, come back to this document and add a checkmark emoji to that task's title
> 3. If you are interrupted or stop mid-execution, the checkmarks show exactly where you left off
> 4. Do NOT check off a task until the work is fully complete
> 5. If you need to reference another doc, b/c the doc you're currently referencing doesn't have the right info you need to fill out the task, check neighboring docs in the same folder to see if you can find the information you're looking for there.
>
> If you need any prisma commands run (e.g. `npx prisma migrate dev`), let the user know and they will run them.

---

## Task Tracking Instructions

- Each task heading includes a checkbox placeholder. Mark the task title with a checkmark emoji AFTER completing the work.
- Update this document as you go — it is the source of truth for phase progress.
- This phase cannot advance until all task checkboxes are checked.
- If execution stops mid-phase, the checkmarks indicate exactly where progress was interrupted.

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Adds safety guardrails (confirmation dialogs, stop/cancel), a persistence layer for all user state, an activity log of recent skill runs, and icon customization from presets. This is the final objective — after this the MVP is complete.
- **What already exists from previous phases:** A working menu bar app shell (Phase 1), event protocol with toast rendering (Phase 2), skills directory with browse/star/run UI (Phase 3), context injection, preinstalled skills, and scheduling (Phase 4). **The home screen is a chat-based UI** (`ChatViewModel` + `ChatView` + `ChatBubbleView`) with persistent message history. Skills browser and other views are accessible via a navigation menu. All command output streams into chat message bubbles. Scheduled skill results also appear as chat messages.
- **What future phases depend on this:** None — this is the final objective. After this phase, the MVP is feature-complete.

---

## 0. Mental Model (Required)

**Problem:** The app currently runs skills without safety checks — a skill that deletes files or sends emails executes immediately on click. Users have no way to cancel a running skill, no visibility into what ran previously, no persistence of their preferences across restarts, and no way to personalize the menu bar icon.

**Where it fits:** This is the final layer of the MVP. Phases 1–4 built the execution engine, event protocol, skills system, and context/scheduling. Phase 5 wraps everything with safety, observability, persistence, and personalization. It transforms the app from a functional prototype into something safe and polished enough to ship.

**Data flow:**
1. User clicks a skill → `ChatViewModel` checks skill metadata for `safe_to_auto_run` → if false, presents `ConfirmationView` → user confirms or cancels
2. Skill executes → `CommandRunner` runs process → Stop button can send SIGTERM/SIGKILL to terminate early
3. On completion (success/failure/cancel), a `RunRecord` is written to `PersistenceManager` → stored as JSON in `~/Library/Application Support/MenuBot/`
4. Activity log reads from `PersistenceManager` and displays recent runs
5. Icon preference, starred skills, ordering, and schedule settings are all read/written through `PersistenceManager` using UserDefaults and JSON files

**Core entities:**
- **ConfirmationView** — SwiftUI overlay that gates dangerous skill execution
- **CommandRunner.stop()** — process termination method (SIGTERM → SIGKILL fallback)
- **PersistenceManager** — centralized local storage (UserDefaults + JSON files)
- **RunRecord** — model for a single skill execution (name, timestamp, duration, outcome)
- **ActivityLogView** — SwiftUI list of recent skill runs
- **IconPickerView** — settings view for choosing menu bar icon presets

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Make the app safe (confirmation dialogs, stop button), observable (activity log), persistent (all user state survives restarts), and customizable (icon presets).

### Prerequisites

- Phases 1–4 are complete and functional
- Skills directory exists at `~/Library/Application Support/MenuBot/skills/`
- Skill metadata spec supports name, description, and tags
- `CommandRunner` can execute processes and stream output
- `ChatViewModel` orchestrates skill execution
- `AppDelegate` manages the `NSStatusItem` and popover
- Starring UI exists from Phase 3 (but is in-memory only)
- Scheduling settings exist from Phase 4 (but are in-memory only)

### Key Deliverables

- Confirmation dialog for unsafe skills
- Stop/Cancel button for running skills
- `PersistenceManager` centralizing all local storage
- Activity log view showing recent skill runs
- Icon picker in a settings/preferences view
- Full persistence: stars, ordering, schedules, history, icon preference

### System-Level Acceptance Criteria

- Skills without `safe_to_auto_run: true` always show a confirmation dialog before executing
- The Stop button terminates the running process and the UI reflects cancellation
- All user state (stars, ordering, schedules, history, icon) persists across app restarts
- Activity log displays up to 100 recent runs with correct outcomes
- Icon changes apply immediately and persist across restarts

---

## 2. Execution Order

### Blocking Tasks

1. **5A.1–5A.5** — Safety & Control (confirmation flow + stop button) — must ship first so cancellation outcomes exist for the activity log
2. **5B.1** — `PersistenceManager` — must exist before activity log or icon persistence
3. **5B.2–5B.5** — `RunRecord` model, `ActivityLogView`, lifecycle hooks, navigation
4. **5B.6** — Retrofit existing features (stars, ordering, schedules) to use `PersistenceManager`

### Parallel Tasks

- **5B.7** (history pruning) can be built alongside 5B.3–5B.5
- **5C.1** (icon assets) can be sourced while 5B tasks are in progress

### Final Integration

- **5C.2–5C.6** — Icon picker wired to `PersistenceManager` and `AppDelegate`
- **5A.6 / 5B.8 / 5C.6** — Manual testing across all three sub-phases
- Verify no regressions to existing skill run flow, starring, scheduling

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Persistence storage | (a) UserDefaults only (b) JSON files only (c) UserDefaults + JSON files (d) CoreData/SQLite | UserDefaults + JSON files | UserDefaults is ideal for small atomic values (icon pref, starred skill IDs, schedule settings). JSON files are better for larger ordered data (run history) with atomic write support. | UserDefaults can lose data on crash for complex values; mitigated by using it only for simple types |
| Process termination | (a) SIGTERM only (b) SIGTERM + SIGKILL fallback (c) Process group kill | SIGTERM + SIGKILL fallback with process group kill | Skills may spawn subprocesses (e.g., Claude Code). Process group kill ensures children are terminated too. | `killpg` may not cover all edge cases; acceptable for MVP |
| Icon assets | (a) Bundled PNGs (b) SF Symbols (c) Mix | SF Symbols (primary) with bundled PNG fallback | SF Symbols auto-adapt to light/dark mode and are resolution-independent. Fallback PNGs for any custom icons not available as SF Symbols. | Limited icon variety from SF Symbols alone; mitigated by choosing expressive symbols |

---

## 4. Subtasks

### Task 5A.1 — Add `safe_to_auto_run` Field to Skill Metadata

#### User Story

As a skill author, I want to mark my skill as safe to auto-run so that users aren't prompted with a confirmation dialog for non-destructive skills.

#### Implementation Steps

1. Open the skill metadata model (wherever skill metadata is parsed — likely in a `Skill` model or struct)
2. Add an optional `safe_to_auto_run: Bool` field, defaulting to `false`
3. Update the skill metadata parser to read this field from the skill file's frontmatter or JSON metadata
4. Update preinstalled skills to include this field where appropriate:
   - Morning Brief → `safe_to_auto_run: true` (read-only)
   - Find File → `safe_to_auto_run: true` (read-only)
   - Create New Skill → `safe_to_auto_run: false` (writes files)
   - Clean Downloads → `safe_to_auto_run: false` (moves/deletes files)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/Skill.swift` (or equivalent model) | Modify | Add `safeToAutoRun: Bool` property with default `false` |
| `MenuBarCompanion/Core/SkillParser.swift` (or equivalent) | Modify | Parse `safe_to_auto_run` from skill metadata |
| `~/Library/Application Support/MenuBot/skills/*.md` | Modify | Add `safe_to_auto_run` to preinstalled skill frontmatter |

#### Acceptance Criteria

- [ ] `Skill` model has a `safeToAutoRun` property defaulting to `false`
- [ ] Skill parser correctly reads `safe_to_auto_run` from skill files
- [ ] Existing skills without the field default to `false` (safe behavior)

---

### Task 5A.2 — Build ConfirmationView

#### User Story

As a user, I want to see a clear confirmation dialog before a potentially dangerous skill runs, showing me what it's about to do so I can cancel if needed.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/ConfirmationView.swift`
2. Build a SwiftUI view as a sheet or overlay containing:
   - Skill name as the title
   - Human-readable description of what the skill does
   - A warning icon or visual indicator
   - "Cancel" button (dismisses, does not run)
   - "Confirm & Run" button (dismisses and triggers execution)
3. The view should accept closures for onConfirm and onCancel actions
4. Style consistently with the existing popover UI

```swift
struct ConfirmationView: View {
    let skillName: String
    let skillDescription: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Run \(skillName)?")
                .font(.headline)

            Text(skillDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Confirm & Run", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ConfirmationView.swift` | Create | SwiftUI confirmation dialog for unsafe skills |

#### Acceptance Criteria

- [ ] `ConfirmationView` renders skill name, description, warning icon, Cancel, and Confirm & Run buttons
- [ ] Cancel dismisses without triggering execution
- [ ] Confirm & Run dismisses and calls the onConfirm closure
- [ ] Keyboard shortcuts work (Escape = cancel, Return = confirm)

---

### Task 5A.3 — Wire Confirmation into Skill Run Flow

#### User Story

As a user, when I click to run a skill that could have side effects, I should see a confirmation dialog. Skills marked as safe should execute immediately without interruption.

#### Implementation Steps

1. In `ChatViewModel`, locate the method that initiates skill execution (e.g., `runSkill(_:)`)
2. Before calling `CommandRunner`, check the skill's `safeToAutoRun` property
3. If `safeToAutoRun == true`, execute immediately
4. If `safeToAutoRun == false` (or not set), set a `@Published` state to present the `ConfirmationView`
5. Add `@Published var showConfirmation = false` and `@Published var pendingSkill: Skill?` to `ChatViewModel`
6. In `PopoverView`, attach `.sheet(isPresented: $viewModel.showConfirmation)` presenting the `ConfirmationView` (or render it inline as a system message in the chat with Confirm/Cancel buttons)
7. On confirm, call the actual execution method; on cancel, clear `pendingSkill`

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Add confirmation gating logic, `showConfirmation` and `pendingSkill` state |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Attach `.sheet` for `ConfirmationView` |

#### Acceptance Criteria

- [ ] Skills with `safeToAutoRun: true` execute immediately on click
- [ ] Skills with `safeToAutoRun: false` (or missing) show the confirmation dialog
- [ ] Confirming the dialog starts skill execution
- [ ] Canceling the dialog does not execute the skill
- [ ] No regressions to existing skill execution flow

---

### Task 5A.4 — Add Stop Button to Running-Skill UI

#### User Story

As a user, I want to stop a running skill that is taking too long or that I triggered by mistake, and I want the UI to clearly show the skill was cancelled.

#### Implementation Steps

1. In the chat input bar (within `PopoverView`), the Stop button already replaces the Send button while a skill is running. Ensure it is clearly visible and styled as a red stop icon
2. Add `@Published var isRunning = false` to `ChatViewModel` if not already present
3. The Stop button calls `viewModel.stopCurrentSkill()`
4. `stopCurrentSkill()` calls `commandRunner.stop()` (implemented in 5A.5)
5. After stopping, update the UI to show a "Cancelled" state indicator
6. Add `@Published var lastRunOutcome: RunOutcome?` enum with cases: `.success`, `.failure`, `.cancelled`

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add Stop button in the running-skill area |
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Add `stopCurrentSkill()`, `isRunning`, `lastRunOutcome` |

#### Acceptance Criteria

- [ ] Stop button is visible only while a skill is running
- [ ] Clicking Stop terminates the running process
- [ ] UI displays "Cancelled" state after stopping
- [ ] Stop button is hidden when no skill is running

---

### Task 5A.5 — Add `stop()` Method to CommandRunner

#### User Story

As the system, I need to cleanly terminate a running process when the user clicks Stop, including any child processes spawned by the skill.

#### Implementation Steps

1. Open `MenuBarCompanion/Core/CommandRunner.swift`
2. Add a `stop()` method:
   - Send `SIGTERM` to the process
   - Start a 3-second timeout
   - If the process hasn't exited after the timeout, send `SIGKILL`
   - Use process group kill to catch child processes

```swift
func stop() {
    guard process.isRunning else { return }

    // Kill the entire process group
    let pgid = process.processIdentifier
    kill(-pgid, SIGTERM)

    // Fallback to SIGKILL after timeout
    DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
        guard let self = self, self.process.isRunning else { return }
        kill(-pgid, SIGKILL)
    }
}
```

3. Ensure the process is launched with its own process group (set `process.qualityOfService` or use `setpgid` equivalent if needed)
4. After termination, ensure readability handlers are cleaned up and completion callbacks fire with a cancelled/terminated status

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/CommandRunner.swift` | Modify | Add `stop()` method with SIGTERM → SIGKILL fallback and process group kill |

#### Acceptance Criteria

- [ ] `stop()` sends SIGTERM to the process group
- [ ] If process doesn't exit within 3 seconds, SIGKILL is sent
- [ ] Child processes spawned by the skill are also terminated
- [ ] Readability handlers are cleaned up after termination
- [ ] No zombie processes are left behind

---

### Task 5A.6 — Manual Testing: Safety & Control

#### User Story

As a developer, I need to verify the entire safety flow works end-to-end before moving on to persistence.

#### Implementation Steps

1. Build and run the app
2. Test confirmation flow:
   - Run a skill marked `safe_to_auto_run: false` → confirm dialog appears
   - Click Cancel → skill does not run
   - Run the same skill again → click Confirm & Run → skill executes
   - Run a skill marked `safe_to_auto_run: true` → runs immediately, no dialog
3. Test stop/cancel:
   - Run a long-running skill (or create a test skill that sleeps)
   - Click the Stop button while it's running → process terminates
   - UI shows "Cancelled" state
4. Verify no regressions:
   - Run a normal skill end-to-end → output streams correctly
   - Event protocol still works (toasts, status updates)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | — | Manual testing only |

#### Acceptance Criteria

- [ ] Unsafe skills show confirmation dialog; safe skills bypass it
- [ ] Canceling the confirmation dialog prevents execution
- [ ] Stop button terminates a running skill
- [ ] UI correctly reflects cancelled state
- [ ] No regressions in existing skill execution, event protocol, or streaming output

---

### Task 5B.1 — Design and Implement PersistenceManager

#### User Story

As the system, I need a centralized persistence layer so that all user preferences and data survive app restarts without requiring a database.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/PersistenceManager.swift`
2. Implement as a singleton or environment-injected object (`@MainActor` class)
3. Define storage locations:
   - **UserDefaults** for simple atomic values:
     - Starred skill IDs (`[String]`)
     - Selected icon preference (`String`)
     - Scheduling settings (encoded as `Data` via `Codable`)
   - **JSON file** for ordered/complex data:
     - Run history → `~/Library/Application Support/MenuBot/history.json`
     - Skill ordering/groups → `~/Library/Application Support/MenuBot/skill_ordering.json`
4. Create the Application Support directory on first access if it doesn't exist
5. Implement atomic writes for JSON files (write to temp file, then rename)
6. Provide typed read/write methods:

```swift
@MainActor
class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults = UserDefaults.standard
    private let appSupportURL: URL

    init() {
        appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MenuBot")
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
    }

    // MARK: - Starred Skills
    var starredSkillIDs: [String] {
        get { defaults.stringArray(forKey: "starredSkillIDs") ?? [] }
        set { defaults.set(newValue, forKey: "starredSkillIDs") }
    }

    // MARK: - Icon Preference
    var selectedIcon: String {
        get { defaults.string(forKey: "selectedIcon") ?? "robot" }
        set { defaults.set(newValue, forKey: "selectedIcon") }
    }

    // MARK: - Run History (JSON file)
    func loadRunHistory() -> [RunRecord] { ... }
    func saveRunHistory(_ records: [RunRecord]) { ... }

    // MARK: - Skill Ordering (JSON file)
    func loadSkillOrdering() -> [String] { ... }
    func saveSkillOrdering(_ ordering: [String]) { ... }
}
```

7. Use `JSONEncoder`/`JSONDecoder` with atomic write pattern for all file operations

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/PersistenceManager.swift` | Create | Centralized persistence layer using UserDefaults + JSON files |

#### Acceptance Criteria

- [ ] `PersistenceManager` provides typed accessors for all persistent data
- [ ] Application Support directory is created automatically if missing
- [ ] JSON file writes are atomic (temp file + rename)
- [ ] UserDefaults keys are used for simple values; JSON files for complex/ordered data
- [ ] All read methods return sensible defaults when no data exists

---

### Task 5B.2 — Define RunRecord Model

#### User Story

As the system, I need a data model representing a single skill execution to store in the activity log.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/RunRecord.swift`
2. Define the model:

```swift
struct RunRecord: Codable, Identifiable {
    let id: UUID
    let skillName: String
    let timestamp: Date
    let duration: TimeInterval
    let outcome: RunOutcome
    let summary: String?

    init(skillName: String, timestamp: Date = Date(), duration: TimeInterval, outcome: RunOutcome, summary: String? = nil) {
        self.id = UUID()
        self.skillName = skillName
        self.timestamp = timestamp
        self.duration = duration
        self.outcome = outcome
        self.summary = summary
    }
}

enum RunOutcome: String, Codable {
    case success
    case failure
    case cancelled
}
```

3. Ensure `RunOutcome` is also used by `ChatViewModel` (from 5A.4) for UI state

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/RunRecord.swift` | Create | `RunRecord` and `RunOutcome` models |

#### Acceptance Criteria

- [ ] `RunRecord` is `Codable` and `Identifiable`
- [ ] `RunOutcome` has cases for success, failure, and cancelled
- [ ] Model includes skill name, timestamp, duration, outcome, and optional summary
- [ ] Encodes/decodes correctly to/from JSON

---

### Task 5B.3 — Build ActivityLogView

#### User Story

As a user, I want to see a list of recent skill runs so I can verify what happened and when.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/ActivityLogView.swift`
2. Build a SwiftUI list view:
   - Each row displays: skill name, relative timestamp ("2 min ago"), outcome badge
   - Outcome badge: green checkmark for success, red X for failure, yellow circle for cancelled
   - Tapping a row navigates to a detail view with full run info (duration, summary, exact timestamp)
3. Source data from `PersistenceManager.shared.loadRunHistory()`
4. Sort by timestamp descending (newest first)
5. Create a simple `RunRecordDetailView` for the detail view

```swift
struct ActivityLogView: View {
    @State private var records: [RunRecord] = []

    var body: some View {
        List(records) { record in
            NavigationLink(destination: RunRecordDetailView(record: record)) {
                HStack {
                    outcomeIcon(record.outcome)
                    VStack(alignment: .leading) {
                        Text(record.skillName).font(.headline)
                        Text(record.timestamp.relativeFormatted).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear { records = PersistenceManager.shared.loadRunHistory() }
    }
}
```

6. Add a helper extension on `Date` for relative time formatting ("just now", "2 min ago", "1 hr ago", "yesterday", etc.)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ActivityLogView.swift` | Create | SwiftUI list view for recent skill runs |
| `MenuBarCompanion/UI/RunRecordDetailView.swift` | Create | Detail view for a single run record |

#### Acceptance Criteria

- [ ] Activity log displays recent runs sorted newest-first
- [ ] Each row shows skill name, relative timestamp, and outcome badge
- [ ] Tapping a row shows full detail (duration, summary, exact timestamp)
- [ ] Empty state is handled gracefully (e.g., "No recent runs")

---

### Task 5B.4 — Hook Activity Log into Skill Execution Lifecycle

#### User Story

As the system, I need to automatically record every skill execution in the activity log, whether it succeeds, fails, or is cancelled.

#### Implementation Steps

1. In `ChatViewModel`, at the point where skill execution completes:
   - Capture the start time when execution begins
   - On completion, calculate duration
   - Determine outcome (success/failure from exit code, cancelled from stop action)
   - Create a `RunRecord` and save via `PersistenceManager`
2. Wire into success path:
   ```swift
   let record = RunRecord(skillName: skill.name, duration: elapsed, outcome: .success)
   PersistenceManager.shared.appendRunRecord(record)
   ```
3. Wire into failure path (non-zero exit code or error):
   ```swift
   let record = RunRecord(skillName: skill.name, duration: elapsed, outcome: .failure, summary: errorMessage)
   PersistenceManager.shared.appendRunRecord(record)
   ```
4. Wire into cancellation path (from 5A.4 stop action):
   ```swift
   let record = RunRecord(skillName: skill.name, duration: elapsed, outcome: .cancelled)
   PersistenceManager.shared.appendRunRecord(record)
   ```
5. Add `appendRunRecord(_:)` convenience method to `PersistenceManager` that loads existing history, appends, and saves

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Record `RunRecord` on every skill completion |
| `MenuBarCompanion/Core/PersistenceManager.swift` | Modify | Add `appendRunRecord(_:)` convenience method |

#### Acceptance Criteria

- [ ] Every successful skill run creates a `RunRecord` with `.success` outcome
- [ ] Every failed skill run creates a `RunRecord` with `.failure` outcome and error summary
- [ ] Every cancelled skill run creates a `RunRecord` with `.cancelled` outcome
- [ ] Records are persisted to disk immediately after creation

---

### Task 5B.5 — Add Activity Log Navigation

#### User Story

As a user, I want to easily access the activity log from the main popover.

#### Implementation Steps

1. Add an "Activity Log" item to the navigation menu (hamburger menu in chat header of `PopoverView`):
   ```swift
   Button {
       navigationPath.append("activityLog")
   } label: {
       Label("Activity Log", systemImage: "clock.arrow.circlepath")
   }
   ```
2. Add a `.navigationDestination(for:)` case for `"activityLog"` that presents `ActivityLogView`
3. Note: The chat history itself serves as a natural activity log (the user can scroll up to see past runs), but the dedicated `ActivityLogView` provides a filtered, structured view of skill runs with outcome badges and durations

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add "Activity Log" to navigation menu in chat header |

#### Acceptance Criteria

- [ ] User can reach the activity log from the navigation menu with one tap
- [ ] Navigation is discoverable and consistent with the chat-based UI style

---

### Task 5B.6 — Retrofit Existing Features to Use PersistenceManager

#### User Story

As a user, I want my starred skills, skill ordering, and scheduling settings to persist across app restarts.

#### Implementation Steps

1. **Starred skills:** Find where starred skill state is managed (likely in the skills browse/list view model). Replace in-memory storage with `PersistenceManager.shared.starredSkillIDs` read/write.
2. **Skill ordering:** Find where skill order/grouping is managed. Replace with `PersistenceManager.shared.loadSkillOrdering()` / `saveSkillOrdering(_:)`.
3. **Scheduling settings:** Find where schedule configuration is stored. Replace with `PersistenceManager`-backed storage. Encode schedule settings as `Codable` and store in UserDefaults.
4. On app launch (`AppDelegate` or app initialization), load all persisted state and populate the relevant view models.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` (or skills view model) | Modify | Read/write starred skills via `PersistenceManager` |
| `MenuBarCompanion/UI/ChatViewModel.swift` (or skills view model) | Modify | Read/write skill ordering via `PersistenceManager` |
| `MenuBarCompanion/UI/ChatViewModel.swift` (or scheduling view model) | Modify | Read/write scheduling settings via `PersistenceManager` |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Load persisted state on launch |

#### Acceptance Criteria

- [ ] Starred skills persist across app restarts
- [ ] Skill ordering persists across app restarts
- [ ] Scheduling settings persist across app restarts
- [ ] First launch with no existing data uses sensible defaults

---

### Task 5B.7 — Add History Pruning

#### User Story

As the system, I need to prevent the activity log and chat history from growing unbounded by capping them at a reasonable size.

#### Implementation Steps

1. In `PersistenceManager`, add pruning logic to `appendRunRecord(_:)` or `saveRunHistory(_:)`:
   - After appending, if history count exceeds 100, remove the oldest records
2. Optionally, also prune on app launch as a safety net
3. The cap of 100 records is sufficient for MVP

```swift
func appendRunRecord(_ record: RunRecord) {
    var history = loadRunHistory()
    history.insert(record, at: 0)
    if history.count > 100 {
        history = Array(history.prefix(100))
    }
    saveRunHistory(history)
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/PersistenceManager.swift` | Modify | Add pruning logic capping history at 100 records |

#### Acceptance Criteria

- [ ] Run history never exceeds 100 records
- [ ] Chat message history is capped at 200 messages (already implemented in `ChatStore.save()`)
- [ ] Oldest records are pruned first
- [ ] Pruning happens automatically on append/save

---

### Task 5B.8 — Manual Testing: Activity Log & Persistence

#### User Story

As a developer, I need to verify the activity log and persistence layer work end-to-end.

#### Implementation Steps

1. Build and run the app
2. Test activity log:
   - Run several skills (mix of success, failure, cancellation)
   - Open the activity log → all runs appear with correct outcomes and timestamps
   - Tap a run → detail view shows full info
3. Test persistence:
   - Star some skills → restart app → stars are preserved
   - Reorder skills → restart app → ordering is preserved
   - Set a schedule → restart app → schedule settings are preserved
   - Check that run history survives restart
4. Test pruning:
   - If feasible, generate more than 100 run records → verify oldest are pruned

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | — | Manual testing only |

#### Acceptance Criteria

- [ ] Activity log shows all recent runs with correct data
- [ ] Starred skills survive app restart
- [ ] Skill ordering survives app restart
- [ ] Scheduling settings survive app restart
- [ ] Run history survives app restart
- [ ] History pruning works correctly at the 100-record cap

---

### Task 5C.1 — Create or Source Preset Icon Assets

#### User Story

As a user, I want to choose from a set of fun, personality-filled menu bar icons to make the app feel like mine.

#### Implementation Steps

1. Select SF Symbols that work well as menu bar template images (monochrome, clear at small size):
   - `"face.smiling"` — Robot/Default
   - `"ghost"` — Ghost (available in SF Symbols 3+, macOS 13+)
   - `"cat"` — Cat (available as `"cat.fill"` in SF Symbols 4+, macOS 14+)
   - `"star.fill"` — Star
   - `"circle.fill"` — Blob (simple circle as a minimal option)
2. For any symbols not available on macOS 13 (the deployment target), create bundled PNG template images:
   - 18x18pt @1x, 36x36pt @2x
   - Monochrome, transparent background
   - Set as template images in the asset catalog
3. Add any bundled PNGs to `MenuBarCompanion/Assets.xcassets/`
4. Define an `IconPreset` model:

```swift
struct IconPreset: Identifiable, Hashable {
    let id: String
    let displayName: String
    let sfSymbolName: String?
    let assetName: String?  // fallback bundled image

    static let presets: [IconPreset] = [
        IconPreset(id: "robot", displayName: "Robot", sfSymbolName: "face.smiling", assetName: nil),
        IconPreset(id: "ghost", displayName: "Ghost", sfSymbolName: "ghost", assetName: "ghost-icon"),
        IconPreset(id: "cat", displayName: "Cat", sfSymbolName: "cat.fill", assetName: "cat-icon"),
        IconPreset(id: "star", displayName: "Star", sfSymbolName: "star.fill", assetName: nil),
        IconPreset(id: "blob", displayName: "Blob", sfSymbolName: "circle.fill", assetName: nil),
    ]
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/IconPreset.swift` | Create | `IconPreset` model with preset definitions |
| `MenuBarCompanion/Assets.xcassets/` | Modify | Add any bundled PNG fallback icon assets |

#### Acceptance Criteria

- [ ] At least 4 icon presets are defined
- [ ] Each preset has a display name and either an SF Symbol or bundled asset
- [ ] Icons render clearly at menu bar size in both light and dark mode

---

### Task 5C.2 — Build IconPickerView

#### User Story

As a user, I want a settings screen where I can see all available icons and pick the one I want for my menu bar.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/IconPickerView.swift`
2. Build a grid or horizontal list of icon previews:
   - Show each `IconPreset` as a tappable icon with its display name below
   - Highlight the currently selected icon (border or background color)
   - On tap, immediately update the selection
3. Preview updates the menu bar icon live (via a binding or callback)

```swift
struct IconPickerView: View {
    @Binding var selectedIconID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Icon").font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                ForEach(IconPreset.presets) { preset in
                    VStack {
                        iconImage(for: preset)
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .background(selectedIconID == preset.id ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIconID == preset.id ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture { selectedIconID = preset.id }
                        Text(preset.displayName).font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}
```

4. Integrate `IconPickerView` into a Settings/Preferences screen (create one if it doesn't exist)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/IconPickerView.swift` | Create | Icon picker grid view |
| `MenuBarCompanion/UI/SettingsView.swift` | Create (if needed) | Settings/preferences container view |

#### Acceptance Criteria

- [ ] All icon presets are displayed in a grid with labels
- [ ] Currently selected icon is visually highlighted
- [ ] Tapping an icon selects it immediately
- [ ] View is accessible from the popover (settings/preferences)

---

### Task 5C.3 — Wire Icon Selection to PersistenceManager

#### User Story

As the system, I need to save the user's icon choice so it persists across app restarts.

#### Implementation Steps

1. In the view model managing settings (or `ChatViewModel`), when the icon selection changes:
   ```swift
   PersistenceManager.shared.selectedIcon = newIconID
   ```
2. On settings view appear, read the current selection:
   ```swift
   selectedIconID = PersistenceManager.shared.selectedIcon
   ```
3. Ensure the binding in `IconPickerView` writes through to `PersistenceManager`

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` (or settings view model) | Modify | Read/write icon preference via `PersistenceManager` |

#### Acceptance Criteria

- [ ] Icon selection is saved to UserDefaults via `PersistenceManager`
- [ ] Selection is read from `PersistenceManager` when settings view opens

---

### Task 5C.4 — Apply Icon on App Launch

#### User Story

As a user, I want the menu bar to show my chosen icon every time I launch the app.

#### Implementation Steps

1. In `AppDelegate`, after creating the `NSStatusItem`, read the persisted icon preference:
   ```swift
   let iconID = PersistenceManager.shared.selectedIcon
   let preset = IconPreset.presets.first { $0.id == iconID } ?? IconPreset.presets[0]
   ```
2. Apply the icon:
   ```swift
   if let sfSymbol = preset.sfSymbolName {
       statusBarItem.button?.image = NSImage(systemSymbolName: sfSymbol, accessibilityDescription: preset.displayName)
   } else if let assetName = preset.assetName {
       let image = NSImage(named: assetName)
       image?.isTemplate = true
       statusBarItem.button?.image = image
   }
   ```
3. Also expose a method on `AppDelegate` (or use NotificationCenter / a callback) so the `IconPickerView` can trigger a live icon update without restarting

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Load and apply persisted icon on launch; expose method for live updates |

#### Acceptance Criteria

- [ ] On launch, the persisted icon preference is loaded and applied to the menu bar
- [ ] If no preference exists, the default icon is used
- [ ] Icon changes from settings are reflected in the menu bar immediately (live)

---

### Task 5C.5 — Handle First Launch Default

#### User Story

As a first-time user, I want to see a friendly default icon without having to configure anything.

#### Implementation Steps

1. Verify that `PersistenceManager.selectedIcon` returns `"robot"` (the default) when no value has been saved
2. Verify that `IconPreset.presets[0]` is the robot/default preset
3. No additional code should be needed if the getter default is correctly implemented in 5B.1
4. Test by deleting the UserDefaults key and launching the app

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | — | Verification only; default already implemented in PersistenceManager |

#### Acceptance Criteria

- [ ] First launch (no saved preference) shows the default robot icon
- [ ] Deleting the UserDefaults key reverts to the default icon

---

### Task 5C.6 — Manual Testing: Icon Customization

#### User Story

As a developer, I need to verify icon customization works end-to-end.

#### Implementation Steps

1. Build and run the app
2. Open settings/preferences → icon picker is visible with at least 4 presets
3. Tap a different icon → menu bar icon updates immediately
4. Restart the app → the chosen icon persists
5. Delete UserDefaults (or clear app data) → restart → default icon appears
6. Test in both light and dark mode → icons adapt correctly

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | — | Manual testing only |

#### Acceptance Criteria

- [ ] Icon picker shows at least 4 presets
- [ ] Selecting an icon updates the menu bar immediately
- [ ] Selected icon persists across app restart
- [ ] Default icon is used on fresh install
- [ ] Icons render correctly in both light and dark mode

---

## 5. Integration Points

- **CommandRunner** — process termination (`stop()`) integrates with the existing process execution lifecycle
- **EventParser** — no changes needed; events still flow through the same pipeline
- **Skills directory** (`~/Library/Application Support/MenuBot/skills/`) — skill metadata now includes `safe_to_auto_run`
- **Application Support directory** (`~/Library/Application Support/MenuBot/`) — now also stores `history.json` and `skill_ordering.json`
- **UserDefaults** — stores starred skill IDs, icon preference, and scheduling settings
- **NSStatusItem** (`AppDelegate`) — icon image is now dynamically set based on user preference
- **macOS light/dark mode** — icon assets must be template images or SF Symbols to auto-adapt

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

- `RunRecord` encoding/decoding tests
- `PersistenceManager` read/write/pruning tests (using a temporary directory)
- `IconPreset` validation (all presets have valid SF Symbol names or asset names)
- `CommandRunner.stop()` termination tests (mock process or use a known long-running command)
- Confirmation flow logic tests (safe vs. unsafe skill branching)

### During Implementation: Build Against Tests

- Implement `RunRecord` → tests pass for Codable round-trips
- Implement `PersistenceManager` → tests pass for read/write/prune/atomic-write
- Implement `CommandRunner.stop()` → tests pass for termination behavior
- Build UI components (`ConfirmationView`, `ActivityLogView`, `IconPickerView`) → verify in previews and manual testing

### Phase End: Polish Tests

- Integration test: run a skill → verify `RunRecord` is created with correct outcome
- Integration test: star a skill, restart, verify persistence
- Edge case: attempt to stop a process that already exited → no crash
- Edge case: corrupted JSON history file → graceful fallback to empty history
- Edge case: 101 records → verify pruning to 100
- Remove any placeholder/stub tests

---

## 7. Definition of Done

- [ ] Confirmation dialog blocks unsafe skills; safe skills bypass it
- [ ] Stop button terminates running skills and UI reflects cancellation
- [ ] Activity log shows recent runs with outcome badges
- [ ] PersistenceManager handles all user state (stars, ordering, schedules, history, icon)
- [ ] All persisted data survives app restart
- [ ] Icon picker offers at least 4 presets with live preview
- [ ] Selected icon persists and applies on launch
- [ ] Tests passing (unit + integration)
- [ ] Manual verification complete
- [ ] No regressions in Phases 1–4 functionality

### Backward Compatibility

Backward compatibility is not a concern for this phase. This is the final MVP objective, there are no existing consumers of the persistence layer (it's being created here), and no existing API contracts are being modified. The `safe_to_auto_run` field defaults to `false` for existing skills, which is the safe behavior.

### End-of-Phase Checklist (Hard Gate)

**STOP — Do not consider this phase complete until every item below is verified:**

- [ ] **Build verification:** App builds with zero errors and zero warnings related to Phase 5 code
- [ ] **Safety flow:** Run an unsafe skill → confirmation dialog appears → Cancel works → Confirm runs the skill
- [ ] **Safe skill bypass:** Run a safe skill → executes immediately, no dialog
- [ ] **Stop button:** Run a long skill → click Stop (red stop icon in chat input bar) → process terminates → assistant message shows "[cancelled]"
- [ ] **Activity log:** Open activity log from navigation menu → shows recent runs with correct outcomes (success/failure/cancelled)
- [ ] **Chat history:** Run several commands → close and reopen popover → chat messages are preserved
- [ ] **Persistence — stars:** Star skills → restart app → stars preserved
- [ ] **Persistence — ordering:** Reorder skills → restart app → ordering preserved
- [ ] **Persistence — schedules:** Set schedule → restart app → schedule preserved
- [ ] **Persistence — history:** Run skills → restart app → activity log and chat history preserved
- [ ] **Persistence — icon:** Change icon → restart app → icon preserved
- [ ] **Icon picker:** Open settings → at least 4 icon presets → select one → menu bar updates live
- [ ] **First launch:** Delete all persisted data → launch app → default icon, empty chat, no stars, no schedules
- [ ] **Light/dark mode:** Icons render correctly in both appearances
- [ ] **No regressions:** Chat UI, skills browse, star, run, event protocol, toasts, streaming output in chat bubbles, context injection, scheduling all work as before
- [ ] **History pruning:** Verify history caps at 100 records

**Signoff:** _______________  Date: _______________

# Phase 5 — Scheduled Automation

- **Phase Number:** 5
- **Phase Name:** Scheduled Automation (Credentials, Jobs Engine, Job Creation Skill, UI & Health)
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

- Tasks use checkboxes
- Engineer checks off each task title with a checkmark emoji AFTER completing the work
- Engineer updates as they go
- Phase cannot advance until checklist complete
- If execution stops, checkmarks indicate progress

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Adds secure credential storage (macOS Keychain), a background jobs engine (LaunchAgents), a conversational job creation skill, and full UI for managing both credentials and jobs.
- **What already exists:** Menu bar app with chat UI (`ChatViewModel`, `PopoverView`), skills system (`Skill.swift`, `SkillsDirectoryManager`, `skills-index.json`), orchestration bootstrap (`OrchestrationBootstrap.swift`), `CommandRunner` for process execution, `NotificationManager` for toasts, Claude Code integration with `[SAY]` filtering.
- **What future phases depend on this:** Objective 7 (startup sequence, bootstrap seeding, Xcode target for CLI) will build on the job infrastructure and credential system.

---

## 0. Mental Model (Required)

**Problem:** Users want MenuBot to do things automatically on a schedule — "send me a tech news summary in Slack every morning at 9am." This requires three capabilities that don't exist yet: (1) securely storing API keys/tokens, (2) scheduling and executing background tasks that survive app restarts, and (3) a conversational flow to set all this up.

**Where it fits:** This is the automation layer on top of the existing chat + skills system. The chat UI and orchestrator/doer pattern from Phases 1-3.5 handle one-off tasks. Phase 5 makes tasks repeatable and autonomous.

**Data flow:**
1. User asks to create a recurring job via chat
2. The `create-background-job` skill gathers requirements (what, when, where, credentials)
3. Credentials are stored in macOS Keychain via `menubot-creds` CLI; metadata tracked in `credentials-index.json`
4. Job definition is written to `jobs-registry.json`
5. A LaunchAgent plist is generated and loaded via `launchctl`
6. On schedule, macOS fires the LaunchAgent, which invokes the job runner
7. Job runner verifies credentials, launches a Claude Code session (or shell command), streams output to a log file, updates registry, and sends a toast notification

**Core entities:**
- **Credential** — value in Keychain, metadata in `credentials-index.json` (id, name, description, timestamps)
- **BackgroundJob** — definition in `jobs-registry.json` (id, name, schedule, task_prompt, required_credentials, enabled)
- **LaunchAgent plist** — macOS scheduling mechanism at `~/Library/LaunchAgents/com.menubot.job.<id>.plist`
- **Job log** — execution output at `~/Library/Application Support/MenuBot/jobs/logs/<job-id>-<timestamp>.log`

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Users can create, schedule, and manage recurring background jobs through natural conversation, with secure credential storage and full UI controls, all surviving app restarts via macOS LaunchAgents.

### Prerequisites

- Phases 1-3.5 complete: menu bar app, chat UI, skills system, orchestration bootstrap
- `CommandRunner.swift` for process execution
- `NotificationManager.swift` for toast notifications
- `OrchestrationBootstrap.swift` for app-launch file installation
- `SkillsDirectoryManager.swift` and `skills-index.json` for skill registration
- Claude Code CLI detected and functional

### Key Deliverables

- `menubot-creds` CLI tool (Swift command-line executable) for Keychain CRUD
- `credentials-index.json` metadata tracking
- `manage-credentials` skill for conversational credential setup
- `BackgroundJob` model and `JobsRegistryManager`
- `LaunchAgentManager` for plist generation/install/unload
- Job runner/execution engine
- `create-background-job` skill for conversational job creation
- Credentials settings UI
- Jobs list view and job detail view
- Job health monitoring (log cleanup, failure notifications, repair)

### System-Level Acceptance Criteria

- Credential values are ONLY stored in macOS Keychain — never in JSON, logs, chat history, or memory files
- `menubot-creds` operations are idempotent (set overwrites, delete is safe if missing)
- LaunchAgent plists are validated before writing
- App startup reconciles registry state with actual LaunchAgent state
- Jobs with missing credentials are skipped (not crashed) with user notification
- Log files older than 30 days are cleaned up on launch
- 3+ consecutive job failures surface a notification

---

## 2. Execution Order

### Blocking Tasks

1. **5A.1** — `menubot-creds` CLI tool (everything else depends on credential storage)
2. **5A.2** — Credentials index infrastructure
3. **5A.3** — Binary installation in OrchestrationBootstrap
4. **5A.4** — `manage-credentials` skill
5. **5B.1** — Jobs registry infrastructure
6. **5B.2** — LaunchAgent plist management
7. **5B.3** — App-startup job verification
8. **5B.4** — Job runner/execution engine
9. **5C.1-5C.4** — Job creation skill

### Parallel Tasks

- **5A.4** (manage-credentials skill) can be written in parallel with **5A.3** (binary installation)
- **5D.1** (credentials UI) can start after 5A completes, in parallel with 5B work
- **5D.2** (jobs list UI) can start after 5B.1 completes

### Final Integration

- End-to-end test: create a job via the skill, verify LaunchAgent fires, verify credential retrieval, verify log output, verify toast notification
- UI verification: credentials and jobs visible and controllable
- Restart test: kill app, relaunch, verify all LaunchAgents are reconciled

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Credential storage | Keychain vs encrypted file vs env vars | macOS Keychain | OS-level encryption, no custom crypto needed, survives app deletion | Keychain access prompts on first use if codesigning doesn't match |
| Job scheduling | cron daemon vs LaunchAgents vs in-app timer | LaunchAgents | Survives app restarts, native macOS, fires even if app isn't running | `StartCalendarInterval` less expressive than cron; plist format is verbose |
| CLI tool language | Swift CLI vs shell script vs Node.js | Swift CLI | Same language as app, direct Security.framework access, single binary | Must be compiled and distributed alongside the app |
| Job runner entry point | App with `--run-job` flag vs standalone script | App with `--run-job` argument | Reuses existing code, single binary, access to all managers | App must handle being launched in "headless" mode |

---

## 4. Subtasks

### Task 5A.1 — menubot-creds CLI Tool

#### User Story

As a developer (and later the orchestrator/doer), I need a command-line tool that can store, retrieve, list, and delete credentials in macOS Keychain so that sensitive values like API tokens are encrypted at rest and never appear in plain-text files.

#### Implementation Steps

1. Create a new directory for the CLI source: `MenuBarCompanion/Core/CredentialsCLI/`

2. Create `MenuBarCompanion/Core/CredentialsCLI/main.swift` — a standalone Swift script that will be compiled into the `menubot-creds` binary:

```swift
// Usage:
//   menubot-creds set <id> --name "..." --description "..."   (reads value from stdin)
//   menubot-creds get <id>                                     (prints value to stdout)
//   menubot-creds list                                         (prints index as JSON)
//   menubot-creds delete <id>                                  (removes from Keychain + index)
```

3. Implement Keychain operations using Security.framework:
   - **set**: `SecItemAdd` with service = `com.menubot.credential.<id>`, account = `menubot`, value from stdin. If exists, use `SecItemUpdate`.
   - **get**: `SecItemCopyMatching` with `kSecReturnData`, print raw value to stdout.
   - **list**: Read `credentials-index.json`, print to stdout (no values).
   - **delete**: `SecItemDelete` by service name, remove entry from index.

4. Create `MenuBarCompanion/Core/CredentialsCLI/KeychainHelper.swift` with focused Keychain functions:

```swift
import Foundation
import Security

enum KeychainHelper {
    static let servicePrefix = "com.menubot.credential."

    static func set(id: String, value: Data) throws { ... }
    static func get(id: String) throws -> Data { ... }
    static func delete(id: String) throws { ... }
}
```

5. Create `MenuBarCompanion/Core/CredentialsCLI/CredentialsIndex.swift` for reading/writing the index file:

```swift
struct CredentialMetadata: Codable {
    let id: String
    let name: String
    let description: String
    let created_at: String
    var last_used: String?
    var used_by_jobs: [String]
}
```

6. Add a new **command-line tool target** in the Xcode project:
   - Target name: `menubot-creds`
   - Source files: `main.swift`, `KeychainHelper.swift`, `CredentialsIndex.swift`
   - Link against `Security.framework`
   - Build product: `menubot-creds` (command-line tool)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/CredentialsCLI/main.swift` | Create | CLI entry point with argument parsing |
| `MenuBarCompanion/Core/CredentialsCLI/KeychainHelper.swift` | Create | Security.framework Keychain CRUD |
| `MenuBarCompanion/Core/CredentialsCLI/CredentialsIndex.swift` | Create | Index file read/write model |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add `menubot-creds` command-line tool target |

#### Acceptance Criteria

- [ ] `menubot-creds set test-cred --name "Test" --description "A test credential"` reads value from stdin, stores in Keychain
- [ ] `menubot-creds get test-cred` prints the stored value to stdout
- [ ] `menubot-creds list` prints JSON array of credential metadata (no values)
- [ ] `menubot-creds delete test-cred` removes from Keychain and index
- [ ] Keychain entry visible in Keychain Access.app under service `com.menubot.credential.test-cred`
- [ ] Re-running `set` for an existing id overwrites the value
- [ ] `delete` on a non-existent id exits cleanly (no crash)
- [ ] `get` on a non-existent id prints an error to stderr and exits with code 1

---

### Task 5A.2 — Credentials Index Infrastructure

#### User Story

As the system, I need a JSON metadata index that tracks credential names, descriptions, and usage without storing actual secret values, so the UI and skills can enumerate credentials without touching Keychain.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/CredentialsIndexManager.swift`:

```swift
import Foundation

struct CredentialMetadata: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let created_at: String
    var last_used: String?
    var used_by_jobs: [String]
}

@MainActor
class CredentialsIndexManager: ObservableObject {
    @Published var credentials: [CredentialMetadata] = []

    static let directoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MenuBot/credentials", isDirectory: true)
    }()

    static var indexFileURL: URL {
        directoryURL.appendingPathComponent("credentials-index.json")
    }

    func load() { ... }
    func add(_ metadata: CredentialMetadata) { ... }
    func remove(id: String) { ... }
    func updateLastUsed(id: String) { ... }
    func updateUsedByJobs(id: String, jobs: [String]) { ... }
}
```

2. Ensure directory creation in `OrchestrationBootstrap.install()`:

```swift
let credentialsDir = menubotDir.appendingPathComponent("credentials", isDirectory: true)
try? fm.createDirectory(at: credentialsDir, withIntermediateDirectories: true)
```

3. Create empty index file on first use if missing.

4. Share the `CredentialMetadata` struct between the CLI tool and the app. Since they're separate targets, duplicate the struct in both (keep in sync) or extract to a shared framework target. Simplest: duplicate in both, they're small.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/CredentialsIndexManager.swift` | Create | App-side index manager (ObservableObject) |
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add credentials directory creation |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file to main target |

#### Acceptance Criteria

- [ ] `~/Library/Application Support/MenuBot/credentials/` directory created on app launch
- [ ] `credentials-index.json` created as empty array `[]` if missing
- [ ] `CredentialsIndexManager` can add, remove, and list credential metadata
- [ ] No credential values appear in the index file

---

### Task 5A.3 — Binary Installation via OrchestrationBootstrap

#### User Story

As the app, I need to automatically install the `menubot-creds` binary to a known location so the orchestrator/doer and job runner can invoke it without knowing the build path.

#### Implementation Steps

1. In `OrchestrationBootstrap.install()`, add a step to copy the built `menubot-creds` binary:

```swift
// Install menubot-creds binary
let binDir = menubotDir.appendingPathComponent("bin", isDirectory: true)
try? fm.createDirectory(at: binDir, withIntermediateDirectories: true)
let credsBinaryDest = binDir.appendingPathComponent("menubot-creds")
installBinary(named: "menubot-creds", to: credsBinaryDest)
```

2. Add a helper to `OrchestrationBootstrap`:

```swift
private static func installBinary(named name: String, to destination: URL) {
    guard let sourceURL = Bundle.main.url(forResource: name, withExtension: nil) else {
        print("[OrchestrationBootstrap] Missing bundled binary: \(name)")
        return
    }
    let fm = FileManager.default
    // Always overwrite to get latest version
    try? fm.removeItem(at: destination)
    do {
        try fm.copyItem(at: sourceURL, to: destination)
        // Ensure executable
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
    } catch {
        print("[OrchestrationBootstrap] Failed to install \(name): \(error)")
    }
}
```

3. In the Xcode project, add a **Copy Files** build phase to the main app target that copies the `menubot-creds` product into the app bundle's `Resources/` so `Bundle.main.url(forResource:)` can find it.

4. Alternatively, if using a build phase is simpler: add a Run Script build phase that copies `$(BUILT_PRODUCTS_DIR)/menubot-creds` into the app bundle.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add binary installation logic |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add Copy Files build phase for menubot-creds binary |

#### Acceptance Criteria

- [ ] After app launch, `~/Library/Application Support/MenuBot/bin/menubot-creds` exists and is executable
- [ ] Running `~/Library/Application Support/MenuBot/bin/menubot-creds list` from Terminal works
- [ ] Binary is updated on each app launch (overwritten from bundle)

---

### Task 5A.4 — manage-credentials Skill

#### User Story

As a user, I want to say "set up my Slack token" and have MenuBot guide me through storing it securely, so I don't have to use the terminal or understand Keychain.

#### Implementation Steps

1. Create `MenuBarCompanion/Resources/skills/manage-credentials.md`:

```markdown
# Manage Credentials

You are helping the user manage their stored credentials for MenuBot background jobs.

## Available Commands
Use the `menubot-creds` CLI at `~/Library/Application Support/MenuBot/bin/menubot-creds`.

- **List credentials:** `menubot-creds list`
- **Store a credential:** `echo "<value>" | menubot-creds set <id> --name "<name>" --description "<desc>"`
- **Delete a credential:** `menubot-creds delete <id>`
- **Retrieve (for verification only):** `menubot-creds get <id>`

## Service-Specific Setup Guides

### Slack Bot Token
- ID: `slack-bot-token`
- Instructions: Go to api.slack.com/apps > Your App > OAuth & Permissions > Bot User OAuth Token
- Starts with `xoxb-`
- Verify: `curl -s -H "Authorization: Bearer <token>" https://slack.com/api/auth.test | jq .ok`

### GitHub Personal Access Token
- ID: `github-pat`
- Instructions: GitHub > Settings > Developer settings > Personal access tokens > Fine-grained tokens
- Verify: `curl -s -H "Authorization: Bearer <token>" https://api.github.com/user | jq .login`

### Generic API Key
- ID: user-chosen
- Ask user for the service name, key format, and any verification endpoint

## Rules
- NEVER display, log, or echo a credential value after storage
- NEVER include credential values in [SAY] output
- Always verify the credential works after storing it
- If verification fails, offer to re-enter
```

2. Add entry to `MenuBarCompanion/Resources/skills/skills-index.json`:

```json
{
    "id": "manage-credentials",
    "name": "Manage Credentials",
    "description": "Securely store, list, and delete API keys and tokens",
    "icon": "key.fill",
    "category": "system",
    "file": "manage-credentials.md"
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/manage-credentials.md` | Create | Credential management skill prompt |
| `MenuBarCompanion/Resources/skills/skills-index.json` | Modify | Add manage-credentials entry |
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add `manage-credentials` to default skill seeding list |

#### Acceptance Criteria

- [ ] `manage-credentials` skill appears in the skills list
- [ ] Invoking the skill guides user through credential setup conversationally
- [ ] Credential values are stored in Keychain via `menubot-creds set`
- [ ] Skill instructs doer to verify credential after storage
- [ ] No credential values appear in chat history or logs

---

### Task 5A.5 — Credential System End-to-End Test

#### User Story

As a developer, I need to verify the entire credential pipeline works — CLI, index, Keychain, skill — before building the jobs engine on top of it.

#### Implementation Steps

1. Manual test sequence from Terminal:

```bash
# Store
echo "test-value-123" | ~/Library/Application\ Support/MenuBot/bin/menubot-creds set test-cred --name "Test Credential" --description "For testing"

# List
~/Library/Application\ Support/MenuBot/bin/menubot-creds list
# Should show: [{"id":"test-cred","name":"Test Credential",...}]

# Get
~/Library/Application\ Support/MenuBot/bin/menubot-creds get test-cred
# Should print: test-value-123

# Delete
~/Library/Application\ Support/MenuBot/bin/menubot-creds delete test-cred

# Verify gone
~/Library/Application\ Support/MenuBot/bin/menubot-creds get test-cred
# Should exit 1
```

2. Open Keychain Access.app, search for `com.menubot.credential` — verify entries appear and disappear correctly.

3. Test the skill via chat: type a message that triggers `manage-credentials`, walk through Slack token setup (use a dummy value).

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|

(No files — this is a manual verification task)

#### Acceptance Criteria

- [ ] All four CLI operations work from Terminal
- [ ] Keychain entries visible in Keychain Access.app
- [ ] Index file updated correctly after each operation
- [ ] Skill flow works end-to-end via chat
- [ ] No credential values in any log files under `~/Library/Application Support/MenuBot/`

---

### Task 5B.1 — Jobs Registry Infrastructure

#### User Story

As the system, I need a persistent registry of background jobs with their schedules, prompts, credential requirements, and run status so the job runner and UI can operate on a shared source of truth.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/BackgroundJob.swift`:

```swift
import Foundation

struct BackgroundJob: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let schedule: JobSchedule
    let created_at: String
    var last_run: String?
    var last_status: JobStatus?
    var enabled: Bool
    let task_prompt: String
    let uses_claude_code: Bool
    var required_credentials: [String]
    var launchd_label: String
}

struct JobSchedule: Codable {
    let cron: String
    let human_readable: String
    let timezone: String
}

enum JobStatus: String, Codable {
    case success
    case failure
    case running
    case skipped
}
```

2. Create `MenuBarCompanion/Core/JobsRegistryManager.swift`:

```swift
import Foundation

@MainActor
class JobsRegistryManager: ObservableObject {
    @Published var jobs: [BackgroundJob] = []

    static let jobsDirectoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MenuBot/jobs", isDirectory: true)
    }()

    static let logsDirectoryURL: URL = {
        jobsDirectoryURL.appendingPathComponent("logs", isDirectory: true)
    }()

    static var registryFileURL: URL {
        jobsDirectoryURL.appendingPathComponent("jobs-registry.json")
    }

    func load() { ... }
    func save() { ... }
    func add(_ job: BackgroundJob) { ... }
    func remove(id: String) { ... }
    func update(id: String, _ transform: (inout BackgroundJob) -> Void) { ... }
    func job(byId id: String) -> BackgroundJob? { ... }
}
```

3. Add directory creation in `OrchestrationBootstrap.install()`:

```swift
let jobsDir = menubotDir.appendingPathComponent("jobs", isDirectory: true)
let jobsLogsDir = jobsDir.appendingPathComponent("logs", isDirectory: true)
try? fm.createDirectory(at: jobsDir, withIntermediateDirectories: true)
try? fm.createDirectory(at: jobsLogsDir, withIntermediateDirectories: true)
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/BackgroundJob.swift` | Create | Job model and schedule/status types |
| `MenuBarCompanion/Core/JobsRegistryManager.swift` | Create | Registry CRUD with JSON persistence |
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add jobs + logs directory creation |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source files to main target |

#### Acceptance Criteria

- [ ] `~/Library/Application Support/MenuBot/jobs/` and `jobs/logs/` created on app launch
- [ ] `jobs-registry.json` created as empty array if missing
- [ ] `JobsRegistryManager` can add, remove, update, and list jobs
- [ ] Registry persists across app restarts
- [ ] `BackgroundJob` round-trips through JSON encode/decode

---

### Task 5B.2 — LaunchAgent Plist Management

#### User Story

As the system, I need to generate, install, and unload macOS LaunchAgent plists so that jobs fire on schedule even when the app isn't in the foreground.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/LaunchAgentManager.swift`:

```swift
import Foundation

enum LaunchAgentManager {
    static let labelPrefix = "com.menubot.job."

    static let launchAgentsDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }()

    /// Generate and install a LaunchAgent plist for a job.
    static func install(job: BackgroundJob, appPath: String) throws { ... }

    /// Unload and remove the plist for a job.
    static func unload(job: BackgroundJob) throws { ... }

    /// Check if a plist exists and is loaded for a job.
    static func isInstalled(job: BackgroundJob) -> Bool { ... }

    /// Generate the plist XML for a job.
    static func generatePlist(job: BackgroundJob, appPath: String) -> String { ... }
}
```

2. Plist generation — convert cron to `StartCalendarInterval`:

```swift
/// Convert "0 9 * * *" (daily at 9am) to:
/// <key>StartCalendarInterval</key>
/// <dict>
///   <key>Hour</key><integer>9</integer>
///   <key>Minute</key><integer>0</integer>
/// </dict>
```

Support common patterns:
- `M H * * *` — daily at H:M
- `M H * * D` — weekly on day D at H:M
- `M H D * *` — monthly on day D at H:M
- `*/N * * * *` — every N minutes (use `StartInterval` = N*60 instead)

3. The plist's `ProgramArguments` should invoke the app binary with `--run-job <job-id>`:

```xml
<key>ProgramArguments</key>
<array>
    <string>/path/to/MenuBarCompanion.app/Contents/MacOS/MenuBarCompanion</string>
    <string>--run-job</string>
    <string>JOB_ID</string>
</array>
```

4. Install: write plist file, run `launchctl load <path>`.
5. Unload: run `launchctl unload <path>`, delete plist file.
6. Validate plist XML before writing (basic checks: well-formed, required keys present).

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/LaunchAgentManager.swift` | Create | Plist generation, install, unload, validation |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file |

#### Acceptance Criteria

- [ ] `install()` writes a valid plist to `~/Library/LaunchAgents/com.menubot.job.<id>.plist`
- [ ] `launchctl list` shows the job after installation
- [ ] `unload()` removes the job from launchctl and deletes the plist
- [ ] Cron expressions `0 9 * * *`, `0 9 * * 1`, `*/15 * * * *` all produce correct plists
- [ ] Invalid cron expressions throw a descriptive error

---

### Task 5B.3 — App-Startup Job Verification

#### User Story

As the system, I need to verify on every app launch that all enabled jobs have their LaunchAgent plists installed and loaded, recreating any that are missing, so jobs survive system updates and plist deletions.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/JobHealthManager.swift` (will be extended in 5D.5):

```swift
import Foundation

enum JobHealthManager {
    /// Verify all enabled jobs have loaded LaunchAgents. Recreate missing ones.
    static func verifyOnStartup(registry: JobsRegistryManager) {
        let jobs = registry.jobs.filter { $0.enabled }
        let appPath = Bundle.main.bundlePath + "/Contents/MacOS/MenuBarCompanion"

        for job in jobs {
            if !LaunchAgentManager.isInstalled(job: job) {
                print("[JobHealth] Reinstalling LaunchAgent for job: \(job.name)")
                try? LaunchAgentManager.install(job: job, appPath: appPath)
            }
        }
    }
}
```

2. Call from `AppDelegate.applicationDidFinishLaunching()` after `OrchestrationBootstrap.install()`:

```swift
let registry = JobsRegistryManager()
registry.load()
JobHealthManager.verifyOnStartup(registry: registry)
```

3. Log any discrepancies to console (reinstated plists, orphaned plists).

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/JobHealthManager.swift` | Create | Startup verification logic |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Call verification on launch |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file |

#### Acceptance Criteria

- [ ] On app launch, missing LaunchAgent plists are recreated for enabled jobs
- [ ] Disabled jobs' plists are NOT reinstalled
- [ ] Console logs indicate which plists were reinstated
- [ ] No crash if `jobs-registry.json` is empty or missing

---

### Task 5B.4 — Job Runner / Execution Engine

#### User Story

As the system, I need a job execution engine that is invoked by LaunchAgents, verifies credentials, runs the job (via Claude Code or shell), logs output, updates the registry, and sends a toast notification on completion.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/JobRunner.swift`:

```swift
import Foundation

enum JobRunner {
    /// Execute a job by ID. Called when app is launched with --run-job <id>.
    static func run(jobId: String) {
        let registry = JobsRegistryManager()
        registry.load()

        guard var job = registry.job(byId: jobId) else {
            print("[JobRunner] Job not found: \(jobId)")
            exit(1)
        }

        // Pre-flight: verify credentials
        let credsBinary = credsBinaryPath()
        for credId in job.required_credentials {
            if !credentialExists(credId, binary: credsBinary) {
                print("[JobRunner] Missing credential: \(credId)")
                // Update registry
                registry.update(id: jobId) { $0.last_status = .skipped }
                registry.save()
                sendNotification(title: "Job Skipped: \(job.name)", body: "Missing credential: \(credId)")
                exit(1)
            }
        }

        // Update status to running
        registry.update(id: jobId) { $0.last_status = .running }
        registry.save()

        // Execute
        let logURL = createLogFile(jobId: jobId)
        let exitCode: Int32

        if job.uses_claude_code {
            exitCode = runClaudeCodeSession(prompt: job.task_prompt, logURL: logURL)
        } else {
            exitCode = runShellCommand(command: job.task_prompt, logURL: logURL)
        }

        // Update registry
        let status: JobStatus = exitCode == 0 ? .success : .failure
        let now = ISO8601DateFormatter().string(from: Date())
        registry.update(id: jobId) {
            $0.last_run = now
            $0.last_status = status
        }
        registry.save()

        // Notify
        let body = exitCode == 0 ? "Completed successfully" : "Failed (exit code \(exitCode))"
        sendNotification(title: "Job: \(job.name)", body: body)
    }
}
```

2. Add `--run-job` argument handling in `AppDelegate` or the app's `@main` entry point:

```swift
// In MenuBarCompanionApp.swift or AppDelegate
if let jobIdx = CommandLine.arguments.firstIndex(of: "--run-job"),
   jobIdx + 1 < CommandLine.arguments.count {
    let jobId = CommandLine.arguments[jobIdx + 1]
    JobRunner.run(jobId: jobId)
    exit(0) // Don't start the UI
}
```

3. Implement `runClaudeCodeSession()` — find claude binary (same logic as `ClaudeDetector`), run with `--dangerously-skip-permissions -p <prompt>`, stream to log file.

4. Implement `runShellCommand()` — run via `/bin/sh -c <command>`, stream to log file.

5. Log files go to `~/Library/Application Support/MenuBot/jobs/logs/<job-id>-<ISO8601 timestamp>.log`.

6. Toast notification via `NSUserNotification` or `UNUserNotificationCenter` (since the app may not be in the foreground, use system notifications rather than the toast window).

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/JobRunner.swift` | Create | Job execution engine |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Handle `--run-job` argument to run headlessly |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file |

#### Acceptance Criteria

- [ ] `MenuBarCompanion.app --run-job <id>` executes the job and exits
- [ ] Claude Code sessions are launched for `uses_claude_code: true` jobs
- [ ] Shell commands are executed for `uses_claude_code: false` jobs
- [ ] Output is streamed to a timestamped log file
- [ ] `last_run` and `last_status` updated in registry after execution
- [ ] Missing credentials cause the job to be skipped (not crashed) with notification
- [ ] A system notification appears on job completion/failure
- [ ] The app does NOT show its UI when launched with `--run-job`

---

### Task 5B.5 — Jobs Engine End-to-End Test

#### User Story

As a developer, I need to verify the full jobs pipeline works before building the creation skill on top of it.

#### Implementation Steps

1. Manually create a test job in `jobs-registry.json`:

```json
[{
    "id": "test-job-001",
    "name": "Echo Test",
    "description": "Simple test job",
    "schedule": {"cron": "*/2 * * * *", "human_readable": "Every 2 minutes", "timezone": "America/Chicago"},
    "created_at": "2026-03-05T00:00:00Z",
    "last_run": null,
    "last_status": null,
    "enabled": true,
    "task_prompt": "echo 'Hello from MenuBot job runner'",
    "uses_claude_code": false,
    "required_credentials": [],
    "launchd_label": "com.menubot.job.test-job-001"
}]
```

2. Install the LaunchAgent: launch the app (or call `LaunchAgentManager.install` programmatically).

3. Wait for the LaunchAgent to fire (within 2 minutes).

4. Verify: log file created, registry updated, notification appeared.

5. Clean up: remove test job and its LaunchAgent.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|

(No files — this is a manual verification task)

#### Acceptance Criteria

- [ ] Test job fires on schedule via LaunchAgent
- [ ] Log file appears in `jobs/logs/`
- [ ] Registry shows updated `last_run` and `last_status: success`
- [ ] System notification appeared
- [ ] App startup reinstalls the plist if manually deleted

---

### Task 5C.1 — create-background-job Skill File

#### User Story

As a user, I want to say "send me a tech news summary in Slack every morning at 9am" and have MenuBot handle the entire setup through conversation.

#### Implementation Steps

1. Create `MenuBarCompanion/Resources/skills/create-background-job.md`:

```markdown
# Create Background Job

You are helping the user create a recurring background job for MenuBot.

## Gathering Requirements

Walk through these steps conversationally:

### 1. What should the job do?
Ask the user to describe the task in natural language.
Compose a self-contained `task_prompt` that works without conversational context.

### 2. When should it run?
Translate natural language to a cron expression:
- "every morning at 9" -> "0 9 * * *"
- "every Monday at 8am" -> "0 8 * * 1"
- "every hour" -> "0 * * * *"
- "twice a day at 9am and 5pm" -> two separate jobs

Include timezone (default: system timezone from `date +%Z`).
Show the user the schedule in human-readable format for confirmation.

### 3. Where should results go?
Options: Slack DM, system notification, email, file, or just log.
If Slack or email: check if required credentials exist.

### 4. Credentials
Run `~/Library/Application Support/MenuBot/bin/menubot-creds list` to check existing credentials.
If the task or delivery method requires credentials that don't exist:
- Guide the user through credential setup inline (follow the manage-credentials skill pattern)
- Do NOT switch to a separate skill — handle it within this flow
- Once credential is stored, continue with job creation

## Job Composition

After gathering all info:

1. Compose the `task_prompt` — a complete, self-contained prompt that includes:
   - What to do
   - How to deliver results (including credential retrieval via `menubot-creds get <id>`)
   - Any formatting instructions

2. Determine `uses_claude_code`: true for anything requiring reasoning/web/tools, false for simple shell commands

3. Write the job to the registry using the `jobs-registry.json` file at:
   `~/Library/Application Support/MenuBot/jobs/jobs-registry.json`

4. Create and load the LaunchAgent plist by writing to:
   `~/Library/LaunchAgents/com.menubot.job.<job-id>.plist`
   Then run: `launchctl load ~/Library/LaunchAgents/com.menubot.job.<job-id>.plist`

5. Confirm to the user:
   - Job name
   - Schedule (human-readable)
   - Delivery method
   - Next expected run time
   - How to manage it (mention the Jobs view in the hamburger menu)

## Rules
- Generate a UUID for the job ID (use `uuidgen` command)
- Always confirm the schedule with the user before creating
- task_prompt must be self-contained — no references to "the conversation" or "earlier"
- NEVER include credential values in the task_prompt — always use `menubot-creds get <id>` at runtime
```

2. Add entry to `skills-index.json` and update `OrchestrationBootstrap` seeding list.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/create-background-job.md` | Create | Job creation skill prompt |
| `MenuBarCompanion/Resources/skills/skills-index.json` | Modify | Add create-background-job entry |
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add to default skill seeding list |

#### Acceptance Criteria

- [ ] `create-background-job` skill appears in the skills list
- [ ] Skill conversationally gathers what/when/where/credentials
- [ ] Missing credentials trigger inline setup without losing context
- [ ] Job is written to registry with correct fields
- [ ] LaunchAgent plist is created and loaded
- [ ] User receives a confirmation summary with schedule and next run time

---

### Task 5C.2 — Job Creation Skill End-to-End Test

#### User Story

As a developer, I need to verify the full conversational job creation flow works before building the UI.

#### Implementation Steps

1. In the chat UI, invoke the create-background-job skill.
2. Walk through: "Send me a summary of Hacker News top stories in a system notification every day at 9am."
3. Verify:
   - Conversational flow asks clarifying questions
   - No credential setup needed (system notification delivery)
   - Job appears in `jobs-registry.json`
   - LaunchAgent plist exists and is loaded
   - Confirmation message shows schedule
4. Test with Slack delivery to exercise credential flow:
   - "Send me a tech news summary in Slack every morning at 9am"
   - Should detect missing Slack credential and guide through setup

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|

(No files — this is a manual verification task)

#### Acceptance Criteria

- [ ] Simple job (no credentials) created end-to-end via conversation
- [ ] Credential-requiring job triggers inline credential setup
- [ ] Created jobs appear in registry and have loaded LaunchAgents

---

### Task 5D.1 — Credentials Settings UI

#### User Story

As a user, I want to see my stored credentials in a settings/preferences view so I can manage them without using the terminal.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/CredentialsSettingsView.swift`:

```swift
import SwiftUI

struct CredentialsSettingsView: View {
    @StateObject private var indexManager = CredentialsIndexManager()
    @EnvironmentObject var chatViewModel: ChatViewModel

    var body: some View {
        List {
            if indexManager.credentials.isEmpty {
                Text("No credentials stored")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(indexManager.credentials) { cred in
                    credentialRow(cred)
                }
            }
        }
        .navigationTitle("Credentials")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    // Navigate back and invoke manage-credentials skill
                } label: {
                    Label("Add Credential", systemImage: "plus")
                }
            }
        }
        .onAppear { indexManager.load() }
    }

    private func credentialRow(_ cred: CredentialMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "key.fill")
                Text(cred.name).font(.headline)
                Spacer()
                Button(role: .destructive) {
                    deleteCred(cred.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            Text(cred.description).font(.caption).foregroundStyle(.secondary)
            if let lastUsed = cred.last_used {
                Text("Last used: \(lastUsed)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func deleteCred(_ id: String) {
        // Run menubot-creds delete <id>
        // Refresh index
    }
}
```

2. Add navigation destination in `PopoverView`:

```swift
.navigationDestination(for: String.self) { destination in
    if destination == "allSkills" {
        SkillsListView().environmentObject(viewModel)
    } else if destination == "credentials" {
        CredentialsSettingsView().environmentObject(viewModel)
    } else if destination == "jobs" {
        JobsListView().environmentObject(viewModel)
    }
}
```

3. Add menu entry in the hamburger menu:

```swift
Button {
    navigationPath.append("credentials")
} label: {
    Label("Credentials", systemImage: "key.fill")
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/CredentialsSettingsView.swift` | Create | Credentials list UI |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add navigation destination and menu entry |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file |

#### Acceptance Criteria

- [ ] "Credentials" entry visible in hamburger menu
- [ ] Credentials list shows name, description, last-used (no values)
- [ ] "Add Credential" button navigates to chat and invokes the manage-credentials skill
- [ ] "Delete" removes the credential (with confirmation) from Keychain and index
- [ ] Empty state shown when no credentials exist

---

### Task 5D.2 — Jobs List View

#### User Story

As a user, I want to see all my background jobs in a dedicated view with their schedules, statuses, and controls so I can manage automation at a glance.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/JobsListView.swift`:

```swift
import SwiftUI

struct JobsListView: View {
    @StateObject private var registry = JobsRegistryManager()
    @EnvironmentObject var chatViewModel: ChatViewModel

    var body: some View {
        List {
            if registry.jobs.isEmpty {
                emptyState
            } else {
                ForEach(registry.jobs) { job in
                    NavigationLink(value: job) {
                        jobRow(job)
                    }
                }
            }
        }
        .navigationTitle("Jobs")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    // Navigate to chat and invoke create-background-job skill
                } label: {
                    Label("New Job", systemImage: "plus")
                }
            }
        }
        .onAppear { registry.load() }
    }

    private func jobRow(_ job: BackgroundJob) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.name).font(.headline)
                Spacer()
                statusIndicator(job.last_status)
                Toggle("", isOn: enabledBinding(for: job))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Text(job.schedule.human_readable).font(.caption).foregroundStyle(.secondary)
            if let lastRun = job.last_run {
                Text("Last run: \(lastRun)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
```

2. Add `NavigationLink` for `BackgroundJob` in `PopoverView`:

```swift
.navigationDestination(for: BackgroundJob.self) { job in
    JobDetailView(job: job).environmentObject(viewModel)
}
```

3. Add "Jobs" entry in the hamburger menu, before "All Skills".

4. Make `BackgroundJob` conform to `Hashable` for NavigationStack.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/JobsListView.swift` | Create | Jobs browser view |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add Jobs menu entry and navigation destination |
| `MenuBarCompanion/Core/BackgroundJob.swift` | Modify | Add Hashable conformance |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file |

#### Acceptance Criteria

- [ ] "Jobs" entry visible in hamburger menu
- [ ] Jobs list shows name, schedule, last run time, status indicator
- [ ] Enable/disable toggle works (loads/unloads LaunchAgent)
- [ ] Tapping a job navigates to detail view
- [ ] "New Job" button navigates to chat and invokes the creation skill
- [ ] Empty state shown when no jobs exist
- [ ] Visual design consistent with Skills list

---

### Task 5D.3 — Job Detail View

#### User Story

As a user, I want to see full details about a job including its run history, and be able to run it immediately, edit it, or delete it.

#### Implementation Steps

1. Create `MenuBarCompanion/UI/JobDetailView.swift`:

```swift
import SwiftUI

struct JobDetailView: View {
    let job: BackgroundJob
    @StateObject private var registry = JobsRegistryManager()
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Schedule
                scheduleSection

                Divider()

                // Actions
                actionsSection

                Divider()

                // Run History
                runHistorySection
            }
            .padding()
        }
        .navigationTitle(job.name)
    }

    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button("Run Now") { runNow() }
            Button("Edit") { editJob() }
            Button("Delete", role: .destructive) { deleteJob() }
        }
    }

    private var runHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run History").font(.headline)
            // Load last 10 log files for this job
            ForEach(recentLogs(), id: \.self) { logURL in
                logRow(logURL)
            }
        }
    }
}
```

2. `runNow()` — launch `JobRunner.run(jobId:)` in a background task.

3. `editJob()` — navigate to chat with a pre-filled prompt to edit the job.

4. `deleteJob()` — confirmation dialog, then: remove from registry, unload LaunchAgent, delete plist, dismiss view.

5. `recentLogs()` — scan `jobs/logs/` for files matching `<job-id>-*.log`, sort by date, take last 10.

6. `logRow()` — show timestamp, status, and a truncated preview of the log content.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/JobDetailView.swift` | Create | Job detail + run history + actions |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add new source file |

#### Acceptance Criteria

- [ ] Detail view shows job name, description, schedule, and credentials
- [ ] "Run Now" triggers immediate execution
- [ ] "Edit" opens a chat flow for editing the job
- [ ] "Delete" removes job, unloads LaunchAgent, and navigates back (with confirmation)
- [ ] Run history shows last 10 runs with timestamps, status, and log preview
- [ ] Empty run history shows "No runs yet"

---

### Task 5D.4 — Enable/Disable Toggle

#### User Story

As a user, I want to pause and resume jobs without deleting them.

#### Implementation Steps

1. In `JobsListView`, the toggle binding should:
   - **Disable (toggle off):** `launchctl unload <plist>`, set `enabled: false` in registry
   - **Enable (toggle on):** recreate plist if needed, `launchctl load <plist>`, set `enabled: true` in registry

2. Add a method to `JobsRegistryManager`:

```swift
func toggleEnabled(id: String) {
    guard var job = job(byId: id) else { return }
    if job.enabled {
        try? LaunchAgentManager.unload(job: job)
        update(id: id) { $0.enabled = false }
    } else {
        let appPath = Bundle.main.bundlePath + "/Contents/MacOS/MenuBarCompanion"
        try? LaunchAgentManager.install(job: job, appPath: appPath)
        update(id: id) { $0.enabled = true }
    }
    save()
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/JobsRegistryManager.swift` | Modify | Add `toggleEnabled` method |
| `MenuBarCompanion/UI/JobsListView.swift` | Modify | Wire toggle to `toggleEnabled` |

#### Acceptance Criteria

- [ ] Toggling off unloads the LaunchAgent and sets `enabled: false`
- [ ] Toggling on reinstalls the LaunchAgent and sets `enabled: true`
- [ ] Toggle state persists across app restarts
- [ ] `launchctl list` confirms load/unload state

---

### Task 5D.5 — Job Health Monitoring

#### User Story

As a user, I want to be notified if my jobs are failing and have old logs cleaned up automatically, so the system stays healthy without manual maintenance.

#### Implementation Steps

1. Extend `JobHealthManager` with log cleanup:

```swift
/// Delete log files older than 30 days.
static func cleanupOldLogs() {
    let logsDir = JobsRegistryManager.logsDirectoryURL
    let fm = FileManager.default
    let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)

    guard let files = try? fm.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey]) else { return }
    for file in files {
        if let attrs = try? fm.attributesOfItem(atPath: file.path),
           let created = attrs[.creationDate] as? Date,
           created < cutoff {
            try? fm.removeItem(at: file)
        }
    }
}
```

2. Add failure detection:

```swift
/// Check for jobs with 3+ consecutive failures and notify the user.
static func checkForRepeatedFailures(registry: JobsRegistryManager) {
    for job in registry.jobs where job.enabled {
        let logs = recentLogs(for: job.id, limit: 3)
        let allFailed = logs.count >= 3 && logs.allSatisfy { $0.contains("[FAILED]") }
        if allFailed {
            sendNotification(
                title: "\(job.name) is failing",
                body: "This job has failed 3 times in a row. Want me to take a look?"
            )
        }
    }
}
```

3. Add "Repair All Jobs" action:

```swift
/// Re-verify and re-install all LaunchAgent plists for enabled jobs.
static func repairAllJobs(registry: JobsRegistryManager) {
    let appPath = Bundle.main.bundlePath + "/Contents/MacOS/MenuBarCompanion"
    for job in registry.jobs where job.enabled {
        try? LaunchAgentManager.unload(job: job)
        try? LaunchAgentManager.install(job: job, appPath: appPath)
    }
}
```

4. Call `cleanupOldLogs()` and `checkForRepeatedFailures()` from `AppDelegate.applicationDidFinishLaunching()`.

5. Wire "Repair All Jobs" to a button in the Jobs list view toolbar or a menu action.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/JobHealthManager.swift` | Modify | Add log cleanup, failure detection, repair |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Call cleanup and failure check on launch |
| `MenuBarCompanion/UI/JobsListView.swift` | Modify | Add "Repair All Jobs" toolbar button |

#### Acceptance Criteria

- [ ] Log files older than 30 days are deleted on app launch
- [ ] Jobs with 3+ consecutive failures trigger a system notification
- [ ] "Repair All Jobs" unloads and reinstalls all enabled LaunchAgent plists
- [ ] Cleanup and failure check run on every app launch without blocking UI

---

### Task 5D.6 — Credential Usage Tracking

#### User Story

As the system, I need to track which jobs use which credentials and when credentials were last used, so the UI can show this information and prevent deleting credentials that are in use.

#### Implementation Steps

1. In `JobRunner`, after successfully retrieving a credential during execution, call:

```swift
CredentialsIndexManager.updateLastUsed(id: credentialId)
```

2. When creating a job (in the skill or programmatically), update `used_by_jobs` in the credentials index:

```swift
for credId in job.required_credentials {
    CredentialsIndexManager.addJobReference(credentialId: credId, jobId: job.id)
}
```

3. When deleting a job, remove job references:

```swift
for credId in job.required_credentials {
    CredentialsIndexManager.removeJobReference(credentialId: credId, jobId: job.id)
}
```

4. In `CredentialsSettingsView`, show `used_by_jobs` count and warn before deleting a credential that's in use.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/CredentialsIndexManager.swift` | Modify | Add `updateLastUsed`, `addJobReference`, `removeJobReference` |
| `MenuBarCompanion/Core/JobRunner.swift` | Modify | Call `updateLastUsed` after credential retrieval |
| `MenuBarCompanion/UI/CredentialsSettingsView.swift` | Modify | Show usage info, warn on delete if in use |

#### Acceptance Criteria

- [ ] `last_used` timestamp updates when a job retrieves a credential
- [ ] `used_by_jobs` array updates when jobs are created/deleted
- [ ] Credentials UI shows "Used by N jobs" indicator
- [ ] Deleting a credential in use shows a warning with job names

---

## 5. Integration Points

- **macOS Keychain** — Security.framework for credential CRUD via `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete`
- **macOS LaunchAgents** — `launchctl load/unload` for job scheduling; plists in `~/Library/LaunchAgents/`
- **Claude Code CLI** — Job runner launches Claude Code sessions with `--dangerously-skip-permissions` for job execution
- **NotificationManager / UNUserNotificationCenter** — Toast notifications for job completion; system notifications for background execution
- **OrchestrationBootstrap** — Extended to create credential/job directories and install the `menubot-creds` binary
- **SkillsDirectoryManager / skills-index.json** — Two new skills registered (`manage-credentials`, `create-background-job`)
- **NavigationStack in PopoverView** — Extended with new destinations for Credentials and Jobs views

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

- **KeychainHelper tests:** set/get/delete round-trip, overwrite behavior, missing key returns error
- **CredentialsIndex tests:** add/remove/list, JSON round-trip, `used_by_jobs` tracking
- **BackgroundJob model tests:** JSON encode/decode round-trip, all fields preserved
- **JobsRegistryManager tests:** add/remove/update/list, persistence to file
- **LaunchAgentManager tests:** plist generation for common cron patterns, cron-to-StartCalendarInterval conversion
- **CronParser tests:** "0 9 * * *" -> daily at 9, "0 8 * * 1" -> Monday at 8, "*/15 * * * *" -> every 15 min
- **JobHealthManager tests:** log cleanup with mock dates, failure detection with mock registry

### During Implementation: Build Against Tests

- Run tests after each subtask completion
- Credential tests may require Keychain entitlements in the test target
- LaunchAgent tests should validate plist XML without actually calling `launchctl`

### Phase End: Polish Tests

- Integration test: create credential -> create job -> simulate execution -> verify registry + logs
- UI snapshot tests for credentials list and jobs list (if feasible)
- Edge cases: empty registry, malformed JSON, concurrent access, very long job prompts

---

## 7. Definition of Done

- [ ] `menubot-creds` CLI works for get/set/list/delete from Terminal
- [ ] Credential values stored only in Keychain, never in files/logs/chat
- [ ] `manage-credentials` skill guides users through credential setup
- [ ] Background jobs persist in `jobs-registry.json` and fire via LaunchAgents
- [ ] App startup reconciles registry with LaunchAgent state
- [ ] Job runner executes Claude Code sessions and shell commands, logs output
- [ ] `create-background-job` skill creates jobs through conversation
- [ ] Credentials UI in settings with add/delete
- [ ] Jobs UI with list, detail, enable/disable, Run Now, Delete
- [ ] Log files older than 30 days cleaned on launch
- [ ] 3+ consecutive failures trigger notification
- [ ] "Repair All Jobs" reinstalls all LaunchAgent plists
- [ ] All tests passing
- [ ] No regressions in existing chat, skills, or orchestration functionality

### Backward Compatibility

No backward compatibility concerns. This phase adds entirely new subsystems (credentials, jobs, new UI views) with no changes to existing data formats. The `skills-index.json` gains new entries but the format is unchanged. The `OrchestrationBootstrap` seeding logic already handles merging defaults with user additions.

### End-of-Phase Checklist (Hard Gate)

Before marking Phase 5 complete, verify ALL of the following:

- [ ] **Build:** `xcodebuild -scheme MenuBarCompanion build` succeeds with no errors
- [ ] **Build:** `xcodebuild -scheme menubot-creds build` succeeds with no errors
- [ ] **CLI:** `menubot-creds set/get/list/delete` all work from Terminal
- [ ] **Keychain:** Credentials visible in Keychain Access.app
- [ ] **Skills:** Both new skills appear in the skills list and are invocable
- [ ] **LaunchAgent:** A test job fires on schedule via `launchctl`
- [ ] **Job Runner:** `--run-job` flag executes a job headlessly and exits
- [ ] **Logs:** Job execution produces a log file
- [ ] **Notifications:** Toast/system notification appears on job completion
- [ ] **Startup:** App launch recreates missing LaunchAgent plists
- [ ] **Cleanup:** Log files older than 30 days are deleted on launch
- [ ] **UI — Credentials:** List, add, delete all functional
- [ ] **UI — Jobs:** List, detail, toggle, Run Now, Delete all functional
- [ ] **Repair:** "Repair All Jobs" reinstalls all plists
- [ ] **No regressions:** Chat, skills browser, orchestrator/doer all still work

**Signoff:** _______________________ Date: _______

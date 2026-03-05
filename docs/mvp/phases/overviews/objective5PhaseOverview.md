# Objective 5: Scheduled Automation — Phased Implementation Plan

> **Objective:** [Objective 5](../../objectives/Objective_5.md)
> **Depends on:** Objective 4 (persistent session, proactive toasts)
> **Feeds into:** Objective 7 (startup sequence, bootstrap seeding, Xcode target for CLI)

---

## Reference Documents
- `docs/mvp/objectives/Objective_5.md` — Full objective spec (5.1–5.6)

## Scope Summary

- **Credential storage** in macOS Keychain with a CLI tool (`menubot-creds`) for get/set/list/delete
- **Credential metadata index** at `~/Library/Application Support/MenuBot/credentials/credentials-index.json`
- **Credential management skill** (`manage-credentials.md`) with service-specific templates (Slack, GitHub, Email, generic)
- **Credentials UI** in settings (list, add, delete — never reveal values)
- **Background jobs registry** (`jobs-registry.json`) with full job metadata
- **LaunchAgent scheduling** — each enabled job backed by a `~/Library/LaunchAgents/` plist, verified on app startup
- **Job execution engine** — launches Claude Code sessions (or direct shell) with job prompts, streams to log files, updates registry, sends toast notifications
- **Credential integration** — jobs declare required credentials; missing credentials trigger setup flow; pre-execution verification
- **Job creation skill** (`create-background-job.md`) — conversational flow covering what/when/where/credentials/confirmation
- **Jobs UI** — dedicated view with list, detail, run history, enable/disable toggle, Run Now, Edit, Delete
- **Job health** — 30-day log cleanup, 3+ failure notifications, Repair All Jobs action

**End state:** A user says "send me a tech news summary in Slack every morning at 9am" and MenuBot handles everything — credential setup, scheduling, execution, delivery — all surviving restarts.

---

## Phasing Option Selected: Option C — Layered Verticals

---

## Detailed Phase Plan

### Phase 5A — Credential System

**Goal:** Users can securely store, retrieve, and manage service credentials through Keychain, a CLI tool, and a conversational skill.

**Tasks:**

- [ ] **5A.1** Create the `menubot-creds` CLI tool (Swift command-line executable):
  - `menubot-creds set <id> --name "..." --description "..."` — reads value from stdin, stores in Keychain via `SecItemAdd`, updates index
  - `menubot-creds get <id>` — retrieves value from Keychain via `SecItemCopyMatching`, prints to stdout
  - `menubot-creds list` — reads index file, prints credential IDs and names (no values)
  - `menubot-creds delete <id>` — removes from Keychain via `SecItemDelete`, updates index
  - All Keychain entries use service name prefix `com.menubot.credential.<id>`
- [ ] **5A.2** Create the credentials metadata index infrastructure:
  - Directory: `~/Library/Application Support/MenuBot/credentials/`
  - File: `credentials-index.json` — array of `{id, name, description, created_at, last_used, used_by_jobs}`
  - Create directory and empty index on first use if missing
- [ ] **5A.3** Place the `menubot-creds` binary at `~/Library/Application Support/MenuBot/bin/menubot-creds`
  - App should copy/install the binary on launch if missing or outdated
  - Ensure the binary is executable (`chmod +x`)
- [ ] **5A.4** Create the `manage-credentials` skill:
  - Skill file: `manage-credentials.md` in the skills directory
  - Add entry to `skills-index.json`
  - Skill prompt instructs the orchestrator/doer to:
    - Guide users conversationally through credential setup
    - Provide service-specific instructions for: Slack (Bot Token), GitHub (PAT), Email/SMTP (app password), Generic API key
    - Store via `menubot-creds set` (value goes straight to Keychain)
    - Verify credential works (e.g., test API call)
    - Never display, log, or echo credential values after storage
- [ ] **5A.5** Test end-to-end: store a credential via CLI, retrieve it, list it, delete it. Verify Keychain entries appear in Keychain Access.app.

**Definition of Done:**
- `menubot-creds get/set/list/delete` all work from the terminal
- Credential values are in Keychain (verifiable via Keychain Access.app)
- Index file tracks metadata without storing values
- `manage-credentials` skill exists and can be invoked through the chat flow
- No credential values appear in any log, memory, or chat history files

---

### Phase 5B — Jobs Engine

**Goal:** Background jobs can be registered, scheduled via LaunchAgents, and executed automatically — including launching Claude Code sessions and integrating with stored credentials.

**Tasks:**

- [ ] **5B.1** Create the jobs registry infrastructure:
  - Directory: `~/Library/Application Support/MenuBot/jobs/`
  - Logs directory: `~/Library/Application Support/MenuBot/jobs/logs/`
  - Registry file: `jobs-registry.json` — array of job objects with fields: `id`, `name`, `description`, `schedule` (cron + human_readable + timezone), `created_at`, `last_run`, `last_status`, `enabled`, `task_prompt`, `uses_claude_code`, `required_credentials`, `launchd_label`
  - Swift model: `BackgroundJob` (Codable struct)
  - `JobsRegistryManager` to read/write/update registry
- [ ] **5B.2** Implement LaunchAgent plist generation and management:
  - Generate plist files at `~/Library/LaunchAgents/com.menubot.job.<job-id>.plist`
  - Plist invokes a runner script (or MenuBot app with `--run-job <job-id>` argument)
  - `StartCalendarInterval` derived from the job's cron expression
  - Methods to: install (write + `launchctl load`), unload (`launchctl unload`), remove plist
- [ ] **5B.3** Implement app-startup job verification:
  - On launch, read `jobs-registry.json`
  - For each enabled job, check that the corresponding LaunchAgent plist exists and is loaded
  - Recreate and load any missing plists
  - Log discrepancies to activity log
- [ ] **5B.4** Implement the job runner / execution engine:
  - Entry point: invoked by LaunchAgent with job ID
  - Reads job from registry
  - **Pre-flight:** verify all `required_credentials` exist via `menubot-creds list`; if missing, notify user and skip execution
  - If `uses_claude_code: true`: launch a Claude Code session with the job's `task_prompt` and the doer skill
  - If `uses_claude_code: false`: execute `task_prompt` as a shell command
  - Stream output to `jobs/logs/<job-id>-<timestamp>.log`
  - Update `last_run` and `last_status` in the registry
  - Send a toast/notification with result summary via `NotificationManager`
- [ ] **5B.5** Test end-to-end: manually create a job entry in the registry, install its LaunchAgent, verify it fires on schedule, check log output and registry updates.

**Definition of Done:**
- A job entry in `jobs-registry.json` with an installed LaunchAgent fires on schedule
- Job execution launches a Claude Code session (or shell command) and logs output
- Missing credentials are detected before execution and the user is notified
- App startup recreates missing LaunchAgent plists for enabled jobs
- Toast notification appears when a job completes

---

### Phase 5C — Job Creation Skill

**Goal:** Users can create background jobs through natural conversation — the skill handles requirements gathering, cron translation, credential detection, and full setup.

**Tasks:**

- [ ] **5C.1** Create the `create-background-job` skill:
  - Skill file: `create-background-job.md` in the skills directory
  - Add entry to `skills-index.json`
- [ ] **5C.2** Skill prompt must instruct the orchestrator/doer to conversationally gather:
  - **What** the job should do (natural language description)
  - **When** it should run (translate "every morning at 9" → cron `0 9 * * *` with timezone)
  - **Where** results should be delivered (Slack DM, notification, email, file, etc.)
  - **Credentials needed** — detect if the delivery method or task requires credentials
- [ ] **5C.3** Credential integration within the flow:
  - Check existing credentials via `menubot-creds list`
  - If required credentials are missing, seamlessly switch to credential setup (inline, not a separate skill invocation)
  - Return to job creation once credential is stored
- [ ] **5C.4** Job composition and installation:
  - Compose a complete, self-contained `task_prompt` that works without conversational context
  - Determine `uses_claude_code` (default true for non-trivial tasks)
  - Write the job entry to `jobs-registry.json`
  - Create and load the LaunchAgent plist
  - Confirm to user with summary: name, schedule, delivery method, next run time
- [ ] **5C.5** Test end-to-end: invoke the skill via chat, walk through the conversational flow, verify job appears in registry with a loaded LaunchAgent.

**Definition of Done:**
- User can say "send me a tech news summary in Slack every morning at 9am" and the skill handles the entire flow
- Missing credentials trigger inline setup without losing job creation context
- Job is written to registry with a loaded LaunchAgent
- User receives a confirmation summary

---

### Phase 5D — UI & Health

**Goal:** Full UI for managing credentials and jobs, plus health monitoring and maintenance features.

**Tasks:**

- [ ] **5D.1** Credentials settings UI:
  - New **Credentials** section in settings/preferences
  - List view: shows each credential's name, description, last-used timestamp
  - "Add Credential" button — starts the `manage-credentials` skill flow in chat
  - "Delete" action per credential (with confirmation dialog) — calls `menubot-creds delete`
  - No "reveal value" option
- [ ] **5D.2** Jobs list view:
  - New **Jobs** entry in the hamburger menu (alongside Skills)
  - List shows: job name, description, schedule (human-readable), last run time + status indicator, enabled/disabled toggle, next scheduled run time
  - Visual design matches the existing Skills list for consistency
- [ ] **5D.3** Job detail view:
  - Full description and schedule display
  - Run history: last 10 runs with status and log preview
  - "Run Now" button — triggers immediate job execution
  - "Edit" action — opens conversational edit flow in chat
  - "Delete" action — with confirmation, removes job + unloads LaunchAgent + deletes plist
- [ ] **5D.4** Enable/disable toggle:
  - Toggling off: unloads LaunchAgent, sets `enabled: false` in registry
  - Toggling on: creates/loads LaunchAgent, sets `enabled: true`
- [ ] **5D.5** Job health monitoring:
  - On app launch, delete log files older than 30 days from `jobs/logs/`
  - If a job has 3+ consecutive failures, surface a notification: "Your [Job Name] job has failed 3 times in a row. Want me to take a look?"
  - "Repair All Jobs" action in settings — re-verifies and re-installs all LaunchAgent plists for enabled jobs
- [ ] **5D.6** Wire credentials index `used_by_jobs` and `last_used` updates:
  - When a job executes and retrieves a credential, update `last_used` timestamp in the index
  - When a job is created/deleted, update `used_by_jobs` arrays in the credentials index

**Definition of Done:**
- Credentials section in settings lists stored credentials with add/delete
- Jobs view shows all registered jobs with schedule, status, and controls
- Jobs can be enabled/disabled, run manually, and deleted from the UI
- Job detail shows run history with log previews
- Log files older than 30 days are cleaned up on launch
- 3+ consecutive failures trigger a user notification
- "Repair All Jobs" re-installs all LaunchAgent plists

---

## File Map (Expected New/Modified Files)

| File | Phase | Description |
|---|---|---|
| `MenuBarCompanion/Core/CredentialsCLI/` (or separate target) | 5A | `menubot-creds` CLI source |
| `MenuBarCompanion/Core/CredentialsIndexManager.swift` | 5A | Read/write credentials index JSON |
| `Resources/skills/manage-credentials.md` | 5A | Credential management skill |
| `MenuBarCompanion/Core/BackgroundJob.swift` | 5B | Job model (Codable struct) |
| `MenuBarCompanion/Core/JobsRegistryManager.swift` | 5B | Read/write/update jobs registry |
| `MenuBarCompanion/Core/LaunchAgentManager.swift` | 5B | Plist generation, install/unload/remove |
| `MenuBarCompanion/Core/JobRunner.swift` | 5B | Job execution engine |
| `Resources/skills/create-background-job.md` | 5C | Job creation skill |
| `MenuBarCompanion/UI/CredentialsSettingsView.swift` | 5D | Credentials settings UI |
| `MenuBarCompanion/UI/JobsListView.swift` | 5D | Jobs browser view |
| `MenuBarCompanion/UI/JobDetailView.swift` | 5D | Job detail + run history |
| `MenuBarCompanion/Core/JobHealthManager.swift` | 5D | Log cleanup, failure detection, repair |

---

## Phase Dependency Chain

```
5A (Credential System)
 |
 v
5B (Jobs Engine) -------> 5C (Job Creation Skill)
                              |
                              v
                           5D (UI & Health)
```

- **5A must complete before 5B** — jobs need credential verification at execution time
- **5B must complete before 5C** — the creation skill writes to the registry and installs LaunchAgents
- **5C must complete before 5D** — the UI's "Add" buttons invoke the skills from 5A and 5C
- **5D could partially parallelize with 5C** — the credentials UI (5D.1) only depends on 5A, and the jobs list UI (5D.2) only depends on 5B. However, the job detail view and health features depend on 5B being fully functional, and the "Add" flows depend on 5C. Keeping 5D last is simpler.

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| **Keychain access prompts** — macOS may prompt the user to allow Keychain access for the CLI tool, especially if codesigning doesn't match | Ensure `menubot-creds` is signed with the same team ID as the main app. Test on a clean Keychain. Document expected first-use prompt. |
| **LaunchAgent reliability** — plists can silently fail to load if malformed, or `launchctl` behavior differs across macOS versions | Validate plist XML before writing. Test on macOS 13+. App-startup verification catches drift. |
| **Cron-to-StartCalendarInterval translation** — cron expressions are more expressive than `StartCalendarInterval` (no "every 15 minutes" without multiple entries) | Support common patterns (daily, weekly, hourly) and document limitations. Fall back to `StartInterval` (seconds) for simple repeating intervals. |
| **Claude Code session lifecycle in background** — jobs fire when the app may not be in the foreground; Claude Code session management must work headlessly | The runner script must be self-contained. Test execution from `launchctl` directly (no TTY, no foreground app). |
| **Credential value leakage** — a doer could accidentally echo a credential value in chat or logs | Skill prompts explicitly instruct against echoing. Consider post-processing log files to redact known credential patterns. |
| **Large Phase 5B** — the jobs engine phase has the most moving parts | Break implementation within 5B into sub-PRs: registry first, then LaunchAgent management, then runner. Each is independently testable. |

---

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| **5A complete** | User can store a Slack token via the `manage-credentials` skill, retrieve it via CLI, and see it listed (name only) in the credentials index |
| **5B complete** | A manually-created job fires on schedule via LaunchAgent, executes a Claude Code session, logs output, updates the registry, and sends a toast notification |
| **5C complete** | User says "send me a tech news summary in Slack every morning at 9am" and the full job is set up — including credential prompting if needed — with a loaded LaunchAgent |
| **5D complete** | All jobs and credentials are visible and manageable through dedicated UI views. Failed jobs surface notifications. Repair All re-installs all plists. Old logs are cleaned up. |

---

## Acceptance Criteria Mapping

| Criterion (from Objective 5) | Phase |
|---|---|
| Credentials stored in macOS Keychain, encrypted at rest | 5A |
| `menubot-creds` CLI can get, set, list, and delete | 5A |
| Doers retrieve credentials via `menubot-creds get` | 5A |
| Credential values never in logs/memory/chat | 5A |
| `manage-credentials` skill guides setup conversationally | 5A |
| Credentials UI in settings with add/delete | 5D |
| Credentials index tracks metadata without values | 5A |
| Jobs persist across restarts via LaunchAgents | 5B |
| On startup, enabled jobs verified and missing LaunchAgents recreated | 5B |
| Jobs using Claude Code launch session, execute, deliver | 5B |
| Toast notification on job completion | 5B |
| Job creation integrates with credential setup | 5C |
| User creates job through natural conversation | 5C |
| Job creation skill guides through setup including credentials and delivery | 5C |
| Jobs UI with schedule, status, controls | 5D |
| Enable/disable, run manually, edit, delete from UI | 5D |
| Log cleanup on launch (30 days) | 5D |
| 3+ failures surface notification | 5D |
| Repair All Jobs action in settings | 5D |

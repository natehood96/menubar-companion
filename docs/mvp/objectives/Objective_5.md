# Objective 5: Scheduled Automation

## Overview

Give Menu-Bot the ability to store credentials securely and run recurring background jobs on a schedule. This objective bundles credentials and background jobs together because in practice, useful scheduled tasks (morning newsletters via Slack, daily reports via email) require service credentials to deliver results. The job creation flow explicitly includes credential setup as part of its conversational UX — separating them would produce a half-working feature. By the end of this objective, a user can say "send me a tech news summary in Slack every morning at 9am" and MenuBot will guide them through the entire setup: what to send, where to send it, credential configuration, scheduling, and ongoing execution — all surviving machine restarts.

---

## Objectives

### 5.1 Credential Storage Infrastructure

#### Problem

Many tasks require credentials (API tokens, account passwords, OAuth tokens). Users need a way to give Menu-Bot access to their accounts, and Menu-Bot needs a consistent, secure-as-possible way to store and retrieve them.

#### Requirements

##### 5.1.1 Credential Store

- Credentials are stored in macOS **Keychain** using the Security framework (`SecItemAdd`, `SecItemCopyMatching`, etc.).
- This is the most secure local storage option on macOS — credentials are encrypted at rest and protected by the user's login keychain.
- All Menu-Bot credentials use a consistent service name prefix: `com.menubot.credential.<credential-id>`
- A metadata index file tracks what credentials exist (but NOT the values):
  `~/Library/Application Support/MenuBot/credentials/credentials-index.json`

```json
[
  {
    "id": "slack-token",
    "name": "Slack Bot Token",
    "description": "OAuth token for sending Slack messages",
    "created_at": "2026-03-04T10:00:00Z",
    "last_used": "2026-03-04T09:00:00Z",
    "used_by_jobs": ["morning-newsletter"]
  }
]
```

##### 5.1.2 Credential CLI Tool

- A small command-line tool (`menubot-creds`) bundled with MenuBot:
  `~/Library/Application Support/MenuBot/bin/menubot-creds`
- Operations:

| Command | Description |
|---|---|
| `menubot-creds get <id>` | Retrieve a credential value from Keychain, print to stdout |
| `menubot-creds set <id> --name "..." --description "..."` | Prompt for value via stdin, store in Keychain + update index |
| `menubot-creds list` | List all credential IDs and names (no values) |
| `menubot-creds delete <id>` | Remove from Keychain and index |

- This lets doers retrieve credentials from their Bash tool: `TOKEN=$(menubot-creds get slack-token)`
- **Credential values are never written to log files, skill files, or memory files.** The CLI tool prints to stdout only, and doers should use them inline without echoing.

#### Acceptance Criteria

- [ ] Credentials are stored in macOS Keychain, encrypted at rest
- [ ] `menubot-creds` CLI tool can get, set, list, and delete credentials
- [ ] Doers can retrieve credential values via `menubot-creds get <id>` in their Bash tool
- [ ] Credential values never appear in log files, memory files, or chat history

---

### 5.2 Credential Management Skill & UI

#### Requirements

##### 5.2.1 Credential Management Skill

- A new skill in the skills directory and index:
  - **ID:** `manage-credentials`
  - **File:** `manage-credentials.md`
- The skill instructs the orchestrator/doer to:
  1. **Guide the user through credential setup conversationally:**
     - "To send Slack messages, I need a Slack Bot Token. Here's how to get one:"
     - Step-by-step instructions specific to the service
     - "Paste your token here and I'll store it securely."
  2. **Store via `menubot-creds set`** — the value goes straight into Keychain
  3. **Never display, log, or echo credential values** after storage
  4. **Verify the credential works** — e.g., make a test API call with the stored token
- Common credential templates should be included in the skill for popular services:
  - Slack (Bot Token + instructions for creating a Slack app)
  - GitHub (Personal Access Token)
  - Email/SMTP (app password)
  - Generic API key (any service)

##### 5.2.2 Credential UI

- A **Credentials** section in settings/preferences:
  - List of stored credentials (name + description, never the value)
  - "Add Credential" button that starts the conversational setup flow in chat
  - "Delete" action per credential (with confirmation)
  - "Last used" timestamp for each credential
- No "reveal value" option — once stored, values are only accessible via `menubot-creds get` (keeps the security posture clean).

#### Acceptance Criteria

- [ ] A `manage-credentials` skill guides users through setup conversationally with service-specific instructions
- [ ] Credentials UI in settings shows stored credentials (names only) with add/delete actions
- [ ] Credentials index tracks metadata (name, description, usage) without storing values

---

### 5.3 Background Jobs Registry & Scheduling

#### Problem

Users want recurring automated tasks (e.g., daily morning newsletter, weekly report) but currently have no way to create, view, or manage scheduled jobs. The system can also lose track of schedules if the machine restarts.

#### Requirements

##### 5.3.1 Background Jobs Registry

- All background jobs are stored in a dedicated registry file:
  `~/Library/Application Support/MenuBot/jobs/jobs-registry.json`
- Each job entry contains:

```json
{
  "id": "uuid",
  "name": "Morning Newsletter",
  "description": "Search tech news and send a summary to my Slack DMs at 9am daily",
  "schedule": {
    "cron": "0 9 * * *",
    "human_readable": "Every day at 9:00 AM",
    "timezone": "America/Denver"
  },
  "created_at": "2026-03-04T10:00:00Z",
  "last_run": "2026-03-04T09:00:00Z",
  "last_status": "success",
  "enabled": true,
  "task_prompt": "Search for top tech news today, compile a 5-bullet summary, and send it to my Slack DMs using my Slack token.",
  "uses_claude_code": true,
  "required_credentials": ["slack-token"],
  "launchd_label": "com.menubot.job.morning-newsletter"
}
```

##### 5.3.2 Scheduling Mechanism

- Each enabled job must be backed by a macOS `launchd` plist (LaunchAgent) installed at `~/Library/LaunchAgents/`.
- The plist should invoke a lightweight runner script or the MenuBot app itself with arguments identifying the job to execute.
- **On app startup**, MenuBot must:
  1. Read `jobs-registry.json`
  2. For each enabled job, verify the corresponding LaunchAgent plist exists and is loaded
  3. Recreate and load any missing plists
  4. Report discrepancies in the activity log
- This ensures jobs survive machine restarts, sleep/wake cycles, and app updates.

#### Acceptance Criteria

- [ ] Jobs persist across app restarts and machine reboots via LaunchAgents
- [ ] On app startup, all enabled jobs are verified and missing LaunchAgents are recreated

---

### 5.4 Job Execution & Delivery

#### Requirements

##### 5.4.1 Job Execution

- When a job fires, it should:
  1. Launch a Claude Code session (if `uses_claude_code: true`) with the job's `task_prompt` and the doer skill
  2. Stream output to a job-specific log: `~/Library/Application Support/MenuBot/jobs/logs/<job-id>-<timestamp>.log`
  3. Update `last_run` and `last_status` in the registry
  4. Send a toast/notification to the user with the result summary
- Jobs that don't need Claude Code (simple shell commands) should execute directly.
- **Jobs should assume Claude Code is the right tool unless the task is trivially simple.** Most interesting recurring tasks (news aggregation, data compilation, report generation) benefit from Claude Code's reasoning and tool use.

##### 5.4.2 Integration with Credentials

- When creating a background job (via the job creation skill), if the job requires credentials that don't exist yet, the job creation flow should:
  1. Detect the missing credential
  2. Seamlessly switch to the credential setup flow
  3. Return to job creation once the credential is stored
- The job's `required_credentials` array in `jobs-registry.json` tracks which credentials it needs.
- Before executing a job, verify all required credentials exist. If any are missing, notify the user instead of running (and failing).

#### Acceptance Criteria

- [ ] Jobs that use Claude Code successfully launch a session, execute, and deliver results
- [ ] User receives a toast/notification when a scheduled job completes
- [ ] Background job creation integrates with credential setup when credentials are needed

---

### 5.5 Job Creation Skill

#### Requirements

- A new skill must be added to the skills directory and `skills-index.json`:
  - **ID:** `create-background-job`
  - **File:** `create-background-job.md`
- This skill instructs the doer/orchestrator to:
  1. **Conversationally gather requirements from the user:**
     - What should the job do? (natural language)
     - How often? (translate natural language like "every morning at 9" into cron)
     - Does it need any credentials or accounts? (prompt for setup — see 5.1/5.2)
     - How should results be delivered? (Slack DM, notification, email, file, etc.)
  2. **Determine if the job needs Claude Code** (most non-trivial jobs will)
  3. **Compose the `task_prompt`** — a complete, self-contained prompt that will work without conversational context
  4. **Write the job entry** to `jobs-registry.json`
  5. **Create and load the LaunchAgent plist**
  6. **Confirm to the user** with a summary: "Got it — I'll send you a tech news summary in Slack every morning at 9am. You can manage this anytime from the Jobs section."

- **The skill should be smart about delivery.** If the user says "send me a morning newsletter," the skill should:
  - Ask where they want it (Slack, email, notification, etc.)
  - Help them set up credentials if needed (e.g., "To send Slack DMs, I'll need a Slack token. You can get one from [guided instructions].")
  - Compose a task prompt that includes the full delivery pipeline (search the web -> compile data -> send via Slack)
  - The user should never have to think about *how* it works — they describe what they want and it gets set up.

#### Acceptance Criteria

- [ ] User can create a background job through natural conversation with the orchestrator
- [ ] Job creation skill guides the user conversationally through setup including credential needs and delivery method

---

### 5.6 Jobs UI & Health

#### Requirements

##### 5.6.1 Jobs UI

- A dedicated **Jobs** view accessible from the hamburger menu (alongside Skills).
- The Jobs list shows:
  - Job name and description
  - Schedule (human-readable, e.g., "Every day at 9:00 AM")
  - Last run time and status (success/failure indicator)
  - Enabled/disabled toggle
  - Next scheduled run time
- Tapping a job opens a detail view with:
  - Full description and schedule
  - Run history (last 10 runs with status and log preview)
  - "Run Now" button for manual trigger
  - "Edit" and "Delete" actions
- Visual design should match the existing Skills list for consistency.

##### 5.6.2 Job Health

- On app launch, clean up log files older than 30 days.
- If a job has failed 3+ consecutive times, surface a notification: "Your Morning Newsletter job has failed 3 times in a row. Want me to take a look?"
- Provide a "Repair All Jobs" action in settings that re-verifies and re-installs all LaunchAgent plists.

#### Acceptance Criteria

- [ ] Jobs appear in a dedicated Jobs UI view with schedule, status, and controls
- [ ] Jobs can be enabled/disabled, run manually, edited, and deleted from the UI
- [ ] Log files older than 30 days are cleaned up on launch
- [ ] 3+ consecutive failures surface a notification to the user
- [ ] "Repair All Jobs" action exists in settings

---

## Scope Boundary

This objective does NOT include:

- Persistent orchestrator session, stdin piping, or session lifecycle (Objective 4)
- Non-blocking concurrent chat or multiple CommandRunner instances (Objective 4)
- Proactive toast notifications or menu bar unread badges (Objective 4)
- Orchestrator memory system (Objective 4)
- Screenshot capture, screen recording, or accessibility metadata (Objective 6)
- Mouse/keyboard control, the `menubot-input` CLI, or the vision-action loop (Objective 6)
- Login item registration or startup sequence ordering (Objective 7 — though startup verification of jobs is defined here, the overall ordered startup sequence is in Objective 7)

---

## Dependencies

- **Depends on:** Objective 4 (persistent session for conversational job creation flow; proactive toasts for job completion notifications)
- **Feeds into:** Objective 7 (startup sequence includes job verification and credential checks; `OrchestrationBootstrap` must seed `create-background-job.md` and `manage-credentials.md` skills; `menubot-creds` CLI must be built as an Xcode target)

# Menu-Bot (macOS) — MVP Business Requirements v2

> Builds on MVP_BIZ_REQ.md. Assumes Phase 1-3 foundations are in place (menu bar app, chat UI, skills system, orchestrator/doer architecture, event protocol).

---

## Summary

Evolve Menu-Bot from a single-request chat assistant into a persistent, multi-tasking AI companion that maintains conversational context, runs background jobs on a schedule, sees and controls the user's screen, manages credentials securely, and never blocks the user while working. The overarching principle: **optimize for a great user experience** — the user should feel like they have a capable, always-available assistant that just works.

---

## Design Principle: User Experience First

Every feature in this document must be evaluated against a single question: **"Does this feel magical to a non-technical user?"**

- The user should never need to understand internals (doers, log files, cron syntax, session IDs).
- Setup flows should be guided and conversational ("What's your Slack workspace? Here's how to get a token...").
- Failures should be retried silently before surfacing — and when surfaced, should include what was tried and what the user can do.
- Status should be glanceable. Progress should be ambient, not noisy.
- The app should feel alive — always ready, never frozen, never "loading...".

---

## Existing Architecture Reference

| Component | Location | Role |
|---|---|---|
| Orchestrator skill | `~/.claude/skills/menubot-orchestrator/SKILL.md` | User-facing intelligence, delegates to doers |
| Doer skill | `~/.claude/skills/menubot-doer/SKILL.md` | Task-focused worker, reports via protocol |
| Protocol | `~/Library/Application Support/MenuBot/protocol.md` | `[DONE]`, `[ERROR]`, `[PROGRESS]`, `[ASK_USER]` messages |
| Skills index | `~/Library/Application Support/MenuBot/skills/skills-index.json` | Registry of available skills |
| Skills directory | `~/Library/Application Support/MenuBot/skills/` | Markdown skill files |
| Doer logs | `~/Library/Application Support/MenuBot/doer-logs/` | Per-doer stdout/stderr capture |
| Chat history | `~/Library/Application Support/MenuBot/chat_history.json` | Persisted chat messages (capped at 200) |
| ChatViewModel | `MenuBarCompanion/UI/ChatViewModel.swift` | Manages chat state, invokes CommandRunner |
| CommandRunner | `MenuBarCompanion/Core/CommandRunner.swift` | Process wrapper with streaming output |

---

## Feature 1: Non-Blocking Chat (Always-Available Orchestrator)

### Problem

Currently, `ChatViewModel` tracks a single `CommandRunner` and sets `isRunning = true`, which blocks the input field (`guard !isRunning` in `sendMessage()`). The user cannot send new messages while a task is in progress. The orchestrator uses `sleep` + timer patterns for doer polling that can hang the session.

### Requirements

#### 1.1 Concurrent Message Processing

- The user must be able to send new messages at any time, even while previous tasks are actively running.
- The input field must never be disabled. Remove the `guard !isRunning` gate from `sendMessage()`.
- Each user message that triggers a Claude Code session should be managed independently.

#### 1.2 Multiple Simultaneous Processes

- `ChatViewModel` must support multiple active `CommandRunner` instances, not just one.
- Each running process should be associated with the assistant message bubble it's streaming into.
- A data structure (e.g., dictionary keyed by message ID) should track active runners so completions route to the correct message bubble.

#### 1.3 Orchestrator Session Awareness

- The orchestrator must remain responsive while doers are running. It already uses `run_in_background` for check-ins — this pattern must be preserved and enforced.
- When a doer completes and the orchestrator receives its result, the orchestrator must correctly associate the result with the original request context, even if the user has sent additional messages since.
- The orchestrator must never "forget" to poll a running doer. If a check-in reveals the doer is still running, another check-in must be scheduled. This chain must not break.

#### 1.4 UI Indicators

- Each in-progress task should show a subtle activity indicator (spinner or pulsing dot) on its message bubble.
- The menu bar icon should indicate when any background work is active (e.g., subtle animation or badge).
- A "Stop" action should be available per-task (per message bubble), not just globally.

### Acceptance Criteria

- [ ] User can send a message while a previous task is still running
- [ ] Two or more doer processes can run simultaneously without cross-talk
- [ ] Orchestrator correctly routes doer results to the right conversation context
- [ ] Each active task has its own cancel/stop control
- [ ] Menu bar icon reflects active background work

---

## Feature 2: Background Jobs (Scheduled Tasks)

### Problem

Users want recurring automated tasks (e.g., daily morning newsletter, weekly report) but currently have no way to create, view, or manage scheduled jobs. The system can also lose track of schedules if the machine restarts.

### Requirements

#### 2.1 Background Jobs Registry

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

#### 2.2 Scheduling Mechanism

- Each enabled job must be backed by a macOS `launchd` plist (LaunchAgent) installed at `~/Library/LaunchAgents/`.
- The plist should invoke a lightweight runner script or the MenuBot app itself with arguments identifying the job to execute.
- **On app startup**, MenuBot must:
  1. Read `jobs-registry.json`
  2. For each enabled job, verify the corresponding LaunchAgent plist exists and is loaded
  3. Recreate and load any missing plists
  4. Report discrepancies in the activity log
- This ensures jobs survive machine restarts, sleep/wake cycles, and app updates.

#### 2.3 Job Execution

- When a job fires, it should:
  1. Launch a Claude Code session (if `uses_claude_code: true`) with the job's `task_prompt` and the doer skill
  2. Stream output to a job-specific log: `~/Library/Application Support/MenuBot/jobs/logs/<job-id>-<timestamp>.log`
  3. Update `last_run` and `last_status` in the registry
  4. Send a toast/notification to the user with the result summary
- Jobs that don't need Claude Code (simple shell commands) should execute directly.
- **Jobs should assume Claude Code is the right tool unless the task is trivially simple.** Most interesting recurring tasks (news aggregation, data compilation, report generation) benefit from Claude Code's reasoning and tool use.

#### 2.4 Jobs UI

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

#### 2.5 Job Creation Skill

- A new skill must be added to the skills directory and `skills-index.json`:
  - **ID:** `create-background-job`
  - **File:** `create-background-job.md`
- This skill instructs the doer/orchestrator to:
  1. **Conversationally gather requirements from the user:**
     - What should the job do? (natural language)
     - How often? (translate natural language like "every morning at 9" into cron)
     - Does it need any credentials or accounts? (prompt for setup — see Feature 6)
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

#### 2.6 Job Cleanup and Health

- On app launch, clean up log files older than 30 days.
- If a job has failed 3+ consecutive times, surface a notification: "Your Morning Newsletter job has failed 3 times in a row. Want me to take a look?"
- Provide a "Repair All Jobs" action in settings that re-verifies and re-installs all LaunchAgent plists.

### Acceptance Criteria

- [ ] User can create a background job through natural conversation with the orchestrator
- [ ] Jobs appear in a dedicated Jobs UI view with schedule, status, and controls
- [ ] Jobs persist across app restarts and machine reboots via LaunchAgents
- [ ] On app startup, all enabled jobs are verified and missing LaunchAgents are recreated
- [ ] Jobs that use Claude Code successfully launch a session, execute, and deliver results
- [ ] User receives a toast/notification when a scheduled job completes
- [ ] Jobs can be enabled/disabled, run manually, edited, and deleted from the UI
- [ ] Job creation skill guides the user conversationally through setup including credential needs and delivery method

---

## Feature 3: Screen Vision (See the Current Screen)

### Problem

Users want to ask Menu-Bot about what's currently on their screen ("What's this error?", "Can you read this table?", "What app is this?"). Menu-Bot needs native screen capture capabilities.

### Requirements

#### 3.1 Screenshot Capture (Primary Method)

- Menu-Bot must be able to capture the screen using macOS native APIs:
  - **Full screen** capture via `CGWindowListCreateImage` or `ScreenCaptureKit` (macOS 13+)
  - **Active window** capture by identifying the frontmost window and capturing just that region
  - **User-selected region** (stretch goal for v2 — not required for initial implementation)
- Screenshots should be captured as PNG, stored temporarily in a transient cache directory:
  `~/Library/Application Support/MenuBot/cache/screenshots/`
- Cache should be cleaned on app quit or after 1 hour, whichever comes first.

#### 3.2 macOS Permissions

- Screen capture requires the **Screen Recording** permission (`CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`).
- On first use, MenuBot must:
  1. Check if permission is granted
  2. If not, show a friendly in-app explanation: "To see your screen, I need Screen Recording permission. macOS will ask you to grant it — this lets me take screenshots when you ask me to look at something."
  3. Trigger the system permission prompt
  4. Handle the case where the user denies (graceful fallback message, don't nag)
- Permission status should be cached and re-checked only when a screen-related action is requested.

#### 3.3 Accessibility Tree / Window Info (Supplementary Native Method)

- In addition to screenshots, Menu-Bot should gather structured metadata about what's on screen via the **Accessibility API** (`AXUIElement`):
  - Active application name and bundle identifier
  - Frontmost window title
  - Focused UI element (text field contents, selected text, button labels)
  - Window hierarchy (list of visible windows with titles and app names)
- This provides machine-readable context that complements the visual screenshot. For example:
  - Screenshot shows a webpage — Accessibility API tells us it's Safari showing "GitHub - anthropics/claude-code"
  - Screenshot shows an error dialog — Accessibility API gives us the exact error text without OCR
- Accessibility API requires the **Accessibility** permission (System Settings > Privacy & Security > Accessibility).
- Same permission flow as Screen Recording: check, explain, request, handle denial gracefully.

#### 3.4 Context Assembly

- When the user asks about their screen (detected via intent or explicit phrases like "look at my screen", "what's this", "what am I looking at"), Menu-Bot should:
  1. Capture a screenshot of the active window (default) or full screen
  2. Gather accessibility metadata (window title, focused element, selected text)
  3. Bundle both into the prompt sent to Claude Code
- The screenshot should be passed to Claude Code as a file path reference. The orchestrator should instruct the doer to read the image file.
- Accessibility metadata should be included as structured text in the prompt.

#### 3.5 Context Toggle in UI

- The chat input area should have a small, unobtrusive toggle or attachment button for screen context:
  - An "eye" icon or similar that, when active, means "include my screen with this message"
  - Can be toggled on per-message or set as a default in preferences
- When screen context is attached, show a subtle indicator on the message bubble (e.g., a small screen icon).

#### 3.6 Performance

- Screenshot capture must complete in under 500ms.
- The screenshot file should be compressed (JPEG at 80% quality is acceptable for analysis) to keep prompt sizes reasonable.
- Accessibility API queries should timeout after 2 seconds to avoid hanging on unresponsive apps.

### Acceptance Criteria

- [ ] Menu-Bot can capture a screenshot of the active window on demand
- [ ] Menu-Bot can capture a full-screen screenshot
- [ ] Screen Recording permission is requested with a user-friendly explanation
- [ ] Accessibility metadata (app name, window title, focused element) is gathered alongside screenshots
- [ ] Accessibility permission is requested with a user-friendly explanation
- [ ] Screenshots and metadata are bundled into the Claude Code prompt
- [ ] The orchestrator/doer can analyze the screenshot and answer questions about what's on screen
- [ ] A toggle in the chat UI lets the user attach screen context to a message
- [ ] Screenshots are cached transiently and cleaned up automatically

---

## Feature 4: Mouse and Keyboard Control

### Problem

Users want Menu-Bot to perform actions on their computer — click buttons, fill forms, navigate UIs, type text. This requires programmatic control of the mouse and keyboard.

### Requirements

#### 4.1 Input Control via Accessibility API

- Menu-Bot must be able to programmatically control the mouse and keyboard using macOS native APIs:
  - **Mouse control:** `CGEvent` for mouse move, click (left/right), double-click, drag, and scroll
  - **Keyboard control:** `CGEvent` for key press, key release, and modifier keys (Cmd, Shift, Option, Control)
  - **Text input:** Direct text insertion via `CGEvent` key sequences or Accessibility API `AXUIElementSetAttributeValue` for focused text fields
- All input control requires the **Accessibility** permission (same as Feature 3.3 — shared permission).

#### 4.2 Action Primitives

Expose a set of action primitives that the orchestrator/doer can invoke. These should be implemented as a Swift helper that the doer calls via a shell command or small CLI tool bundled with MenuBot:

| Primitive | Parameters | Description |
|---|---|---|
| `mouse_move` | x, y | Move cursor to screen coordinates |
| `mouse_click` | x, y, button (left/right), count (1/2) | Click at coordinates |
| `mouse_drag` | x1, y1, x2, y2 | Drag from point to point |
| `key_type` | text | Type a string of text |
| `key_press` | key, modifiers[] | Press a key combo (e.g., Cmd+C) |
| `scroll` | x, y, dx, dy | Scroll at coordinates |

- These primitives should be packaged as a small command-line tool (`menubot-input`) installed alongside MenuBot:
  `~/Library/Application Support/MenuBot/bin/menubot-input`
- Usage: `menubot-input mouse_click --x 500 --y 300 --button left`
- This lets doers invoke input control from their Claude Code Bash tool without needing Swift interop.

#### 4.3 Screen-Action Loop (Vision + Control)

- The most powerful use case combines Feature 3 (Screen Vision) and Feature 4 (Mouse/Keyboard Control) into a vision-action loop:
  1. Capture screenshot + accessibility metadata
  2. Analyze what's on screen (identify UI elements, buttons, text fields)
  3. Determine the next action (click this button, type in this field)
  4. Execute the action
  5. Wait briefly (200-500ms) for the UI to update
  6. Repeat from step 1 until the task is complete
- A dedicated skill should be created for this pattern:
  - **ID:** `computer-control`
  - **File:** `computer-control.md`
  - The skill instructs the doer to use the screenshot + `menubot-input` tool in a loop, with guardrails (max iterations, confirmation prompts for destructive actions).

#### 4.4 Safety and Transparency

- **This is the highest-risk feature and must have strong guardrails.**
- Before executing any mouse/keyboard action, the doer must describe what it's about to do in its output stream (so the orchestrator and user can see it).
- **Confirmation required by default.** Before the first action in a control sequence, the orchestrator must ask the user: "I'm going to [description of actions]. Should I go ahead?"
  - The user can approve the full sequence or ask to approve step-by-step.
  - Skills/jobs can be marked `"auto_approve_input_control": true` only by explicit user action in the Jobs/Skills UI (not by the AI itself).
- **Emergency stop:** A global keyboard shortcut (e.g., `Cmd+Shift+Escape` or similar) must immediately halt all input control actions. This should be registered via `NSEvent.addGlobalMonitorForEvents`.
- **Visual indicator:** While MenuBot is controlling the mouse/keyboard, show a persistent, unmistakable overlay or menu bar badge (e.g., a red recording-style dot) so the user always knows automation is active.
- **Scope limits (v1):**
  - No control actions while the screen is locked
  - No control actions targeting System Settings / Security & Privacy panes
  - Maximum 100 actions per sequence before requiring re-confirmation

#### 4.5 Common Use Case Patterns

The `computer-control` skill should include guidance for common patterns:

- **Fill out a form:** Screenshot -> identify fields -> click each field -> type values -> click submit
- **Navigate a UI:** Screenshot -> find target button/link -> click -> wait for navigation -> verify
- **Copy content:** Screenshot -> identify text -> select (click + drag or Cmd+A) -> Cmd+C -> read clipboard
- **App switching:** Use Cmd+Tab or `open -a "AppName"` for reliable app switching rather than clicking the dock

### Acceptance Criteria

- [ ] `menubot-input` CLI tool is bundled and can perform mouse clicks, moves, drags, typing, and key combos
- [ ] Doers can invoke `menubot-input` from their Bash tool
- [ ] A vision-action loop (screenshot -> analyze -> act -> repeat) works end-to-end
- [ ] `computer-control` skill is available in the skills index
- [ ] User is prompted for confirmation before input control actions begin
- [ ] A global emergency stop shortcut halts all input control immediately
- [ ] A visual indicator shows when automation is actively controlling the screen
- [ ] Accessibility permission is requested with a clear, friendly explanation
- [ ] Safety limits are enforced (max actions per sequence, blocked targets)

---

## Feature 5: Persistent Conversational Context

### Problem

Currently, every user message launches a new Claude Code session (`-p "..."` flag), meaning the orchestrator has no memory of previous messages. The user can't have a back-and-forth conversation — every message is a one-off request with no context of what came before.

### Requirements

#### 5.1 Single Persistent Session

- Instead of launching a new Claude Code process per message, MenuBot must maintain a **single long-running Claude Code session** for the orchestrator.
- The session should be started when the app launches (or on first user message) and kept alive.
- User messages should be fed into the running session's stdin (using `--input-format stream-json` or equivalent interactive mode).
- If the session dies unexpectedly, MenuBot must automatically restart it and restore context from memory (see 5.3).

#### 5.2 Session Lifecycle Management

- **Startup:** Launch the orchestrator Claude Code session with the orchestrator skill loaded.
- **Message input:** Pipe user messages into the running session rather than spawning new processes.
- **Context window management:** Claude Code has built-in context compression. The orchestrator skill should instruct Claude to:
  - Summarize and condense older conversation context as the window fills
  - Prioritize retaining: user preferences, active task states, recent decisions, and key facts
  - Write important context to memory files (see 5.3) before it falls out of the window
- **Session restart:** If the process exits (crash, context exhaustion, or manual reset):
  1. Save current conversation summary to memory
  2. Restart a new session
  3. Load the orchestrator skill (mandatory — see 5.5)
  4. Load memory files so the new session has continuity
  5. The user should experience this as a brief "thinking..." pause, not a visible restart

#### 5.3 Orchestrator Memory System

- The orchestrator must have a persistent memory directory:
  `~/Library/Application Support/MenuBot/memory/`
- Memory files are markdown documents organized by topic:
  - `user-profile.md` — Name, preferences, communication style, accounts, common requests
  - `conversation-context.md` — Rolling summary of recent conversations and decisions
  - `task-history.md` — What tasks have been completed, what approaches worked/failed
  - `learned-facts.md` — Things the user has told the orchestrator to remember
- **The orchestrator skill must instruct Claude to:**
  - Read memory files on startup (and after session restart)
  - Update memory files proactively when it learns something worth retaining
  - Use memory to provide continuity (e.g., "Last time you asked me to find flights, you preferred Delta. Want me to check Delta first?")
- **Memory search:** For efficient recall, the orchestrator should use `grep` or a simple keyword search against memory files when it needs to recall something specific, rather than loading all files into context every time.

#### 5.4 Memory Lifecycle

- Memory files should be kept concise. The orchestrator skill should instruct Claude to:
  - Cap `conversation-context.md` at ~200 lines, rotating old content out
  - Cap `task-history.md` at ~100 entries, keeping only the most recent and most relevant
  - Keep `user-profile.md` as a living document that's updated, not appended to
  - Keep `learned-facts.md` as a clean reference (remove outdated facts, update changed ones)
- Provide a "Forget everything" option in settings that clears all memory files (with confirmation).

#### 5.5 Mandatory Skill Loading

- **Every message must force-load the orchestrator skill.** The orchestrator must never lose sight of its purpose, communication style, or operational rules.
- Implementation: When piping a user message into the session, prepend or wrap it with an instruction to re-read the orchestrator skill:
  - Option A: Use the `/menubot-orchestrator` slash command prefix on every message
  - Option B: Include a system-level instruction that references the skill file path, and the orchestrator re-reads it periodically
- The goal: even deep in a long conversation, the orchestrator behaves consistently and never drifts from its defined personality and rules.

### Acceptance Criteria

- [ ] The orchestrator runs as a single persistent Claude Code session, not one-per-message
- [ ] User messages are piped into the running session (no new process per message)
- [ ] Conversation context is maintained across messages within a session
- [ ] When context gets full, Claude compresses/summarizes and key info is preserved in memory files
- [ ] Session restarts are automatic and seamless — the user doesn't lose continuity
- [ ] Memory files exist at `~/Library/Application Support/MenuBot/memory/` and are read on startup
- [ ] The orchestrator updates memory proactively as it learns about the user
- [ ] The orchestrator skill is loaded with every message to maintain consistent behavior
- [ ] A "Forget everything" option exists in settings

---

## Feature 6: Credential Storage and Retrieval

### Problem

Many tasks require credentials (API tokens, account passwords, OAuth tokens). Users need a way to give Menu-Bot access to their accounts, and Menu-Bot needs a consistent, secure-as-possible way to store and retrieve them.

### Requirements

#### 6.1 Credential Store

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

#### 6.2 Credential CLI Tool

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

#### 6.3 Credential Management Skill

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

#### 6.4 Credential UI

- A **Credentials** section in settings/preferences:
  - List of stored credentials (name + description, never the value)
  - "Add Credential" button that starts the conversational setup flow in chat
  - "Delete" action per credential (with confirmation)
  - "Last used" timestamp for each credential
- No "reveal value" option — once stored, values are only accessible via `menubot-creds get` (keeps the security posture clean).

#### 6.5 Integration with Background Jobs

- When creating a background job (Feature 2), if the job requires credentials that don't exist yet, the job creation flow should:
  1. Detect the missing credential
  2. Seamlessly switch to the credential setup flow
  3. Return to job creation once the credential is stored
- The job's `required_credentials` array in `jobs-registry.json` tracks which credentials it needs.
- Before executing a job, verify all required credentials exist. If any are missing, notify the user instead of running (and failing).

### Acceptance Criteria

- [ ] Credentials are stored in macOS Keychain, encrypted at rest
- [ ] `menubot-creds` CLI tool can get, set, list, and delete credentials
- [ ] Doers can retrieve credential values via `menubot-creds get <id>` in their Bash tool
- [ ] Credential values never appear in log files, memory files, or chat history
- [ ] A `manage-credentials` skill guides users through setup conversationally with service-specific instructions
- [ ] Credentials UI in settings shows stored credentials (names only) with add/delete actions
- [ ] Background job creation integrates with credential setup when credentials are needed
- [ ] Credentials index tracks metadata (name, description, usage) without storing values

---

## Feature 7: Proactive Toast Notifications (Ambient Awareness)

### Problem

When the orchestrator finishes a task or has an update for the user, and the popover (`NSPopover`) is closed, the user has no idea anything happened. Updates silently land in chat history that no one is looking at.

### Current Infrastructure

- **`ToastWindow`** (`ToastWindow.swift`) — An `NSPanel` (`.nonactivatingPanel`, `.statusBar` level) that renders a speech-bubble toast anchored below the `NSStatusItem`. It has an upward-pointing arrow (`BubbleArrow` shape), uses `.ultraThinMaterial` for a frosted glass look, and auto-dismisses after 4 seconds. Positioned via `statusItem.button.window.convertToScreen()`.
- **`ToastView`** (`ToastView.swift`) — SwiftUI view displaying `title` + `message` with tap-to-dismiss.
- **`NotificationManager`** (`NotificationManager.swift`) — Receives `MenuBotEvent` cases (`.toast`, `.result`, `.error`) and calls `toastWindow.show()` for toast events. Currently only triggers on explicit `[MENUBOT_EVENT]` protocol messages from doers.
- **`NSPopover`** (`AppDelegate.swift`) — The main chat UI. `popover.isShown` indicates whether the user is actively viewing the chat. Behavior is `.transient` (closes when clicking outside).

### Requirements

#### 7.1 Auto-Toast When Popover Is Closed

- Whenever the orchestrator produces a new assistant message (or updates an existing one with meaningful content) **and** the popover is not shown (`popover.isShown == false`), MenuBot must automatically display a `ToastWindow` notification anchored to the menu bar icon.
- This applies to:
  - Task completion messages (doer finishes and orchestrator summarizes the result)
  - Progress updates that the orchestrator relays to the user
  - `[ASK_USER]` questions that need the user's attention
  - Any new assistant message content streamed into the chat
- This does **not** require explicit `[MENUBOT_EVENT]` protocol messages — the trigger is simply "new assistant content appeared while the popover is closed."

#### 7.2 Toast Content

- The toast should show a concise preview of the assistant's message:
  - **Title:** "MenuBot" (or the task context if available, e.g., "Flight Search")
  - **Message:** First 2-3 lines or ~120 characters of the assistant message, truncated with "..." if longer
- For `[ASK_USER]` events, the title should indicate attention is needed: "MenuBot needs your input"

#### 7.3 Toast Interaction

- **Tap the toast** -> Opens the popover and scrolls to the relevant message. The toast dismisses.
- **Toast auto-dismisses** after 4 seconds (existing behavior) if not tapped.
- If multiple updates arrive while the popover is closed, toasts should queue (not overlap). Show them sequentially with a brief gap, or show the most recent one with a badge count (e.g., "3 new messages").

#### 7.4 Menu Bar Icon Badge

- When there are unread assistant messages (messages that arrived while the popover was closed and haven't been seen yet), the menu bar icon should show a subtle indicator:
  - A small dot badge (similar to notification badges on iOS app icons)
  - Or a count badge if multiple unread messages exist
- The badge clears when the popover is opened.

#### 7.5 Implementation Notes

- `ChatViewModel` needs awareness of whether the popover is visible. Options:
  - Pass a binding or closure from `AppDelegate` that checks `popover.isShown`
  - Use `NotificationCenter` to broadcast popover open/close events
  - Have `NotificationManager` check popover state before deciding whether to toast
- The `appendToAssistantMessage()` and `finishRun()` methods in `ChatViewModel` are the natural trigger points — after updating the message, check popover visibility and fire a toast if closed.
- `NotificationManager` already has the `ToastWindow` and `statusItem` references needed. It just needs a new method like `showAutoToast(preview:)` that `ChatViewModel` can call.

### Acceptance Criteria

- [ ] When the popover is closed and the orchestrator produces a new message, a toast appears anchored to the menu bar icon
- [ ] The toast shows a concise preview of the message content
- [ ] Tapping the toast opens the popover
- [ ] Multiple rapid updates queue or consolidate rather than overlapping
- [ ] The menu bar icon shows an unread indicator when messages arrived while the popover was closed
- [ ] The unread indicator clears when the popover is opened
- [ ] When the popover is already open, no toast is shown (content is visible in chat)

---

## Cross-Cutting Concerns

### Startup Sequence

On app launch, MenuBot must (in order):

1. Bootstrap orchestration files (existing: `OrchestrationBootstrap.swift`)
2. Start the persistent orchestrator session (Feature 5)
3. Verify and repair background job LaunchAgents (Feature 2)
4. Load orchestrator memory files (Feature 5)
5. Verify required credentials exist for enabled jobs (Feature 6)
6. Register global emergency stop shortcut (Feature 4)

### Login Item

- MenuBot must register itself as a **Login Item** so it starts automatically when the user logs in.
- Use `SMAppService.mainApp` (macOS 13+) for modern login item registration.
- Provide a toggle in settings: "Start MenuBot at login" (default: on).

### New Skills to Ship

| Skill ID | File | Feature | Description |
|---|---|---|---|
| `create-background-job` | `create-background-job.md` | 2 | Conversationally create scheduled background jobs |
| `computer-control` | `computer-control.md` | 4 | Vision-action loop for mouse/keyboard automation |
| `manage-credentials` | `manage-credentials.md` | 6 | Store and manage service credentials |

These must be seeded by `OrchestrationBootstrap` on first run (same pattern as existing default skills).

### New CLI Tools to Bundle

| Tool | Location | Feature | Description |
|---|---|---|---|
| `menubot-input` | `~/Library/Application Support/MenuBot/bin/menubot-input` | 4 | Mouse and keyboard control primitives |
| `menubot-creds` | `~/Library/Application Support/MenuBot/bin/menubot-creds` | 6 | Keychain credential storage and retrieval |

Both should be compiled Swift executables, built as part of the Xcode project (separate targets or embedded command-line tools).

### Permissions Summary

| Permission | Features | When Requested |
|---|---|---|
| Screen Recording | 3 (Screen Vision) | First time user asks about their screen |
| Accessibility | 3 (Accessibility metadata), 4 (Mouse/Keyboard) | First time screen metadata or input control is needed |
| Keychain access | 6 (Credentials) | Automatic (app's own keychain items) |

### Updated File Structure

```
~/Library/Application Support/MenuBot/
  skills/
    skills-index.json
    *.md (skill files)
  jobs/
    jobs-registry.json
    logs/
      <job-id>-<timestamp>.log
  memory/
    user-profile.md
    conversation-context.md
    task-history.md
    learned-facts.md
  credentials/
    credentials-index.json
  doer-logs/
    doer-<task>-<timestamp>.log
  cache/
    screenshots/
  bin/
    menubot-input
    menubot-creds
  protocol.md
  output-rules.md
```

---

## Acceptance Criteria (End-to-End)

These validate the features working together as a cohesive experience:

- [ ] User opens MenuBot, sends "find me flights from SLC to Dublin next week", and while that's running, sends "what's the weather today?" — both tasks execute concurrently and results arrive independently
- [ ] User says "set up a morning newsletter for me" and the orchestrator guides them through the full setup: what content, what schedule, what delivery method, credential setup, and creates a working background job
- [ ] User restarts their Mac, logs in, and the morning newsletter job fires at the scheduled time without any manual intervention
- [ ] User asks "what's this error?" while looking at a terminal error — MenuBot captures the screen, reads the error, and explains it
- [ ] User says "click the Submit button on this page" — MenuBot captures the screen, identifies the button, asks for confirmation, clicks it, and verifies the result
- [ ] User has a multi-turn conversation: "Find Italian restaurants nearby" -> "Which ones have outdoor seating?" -> "Book the second one for Friday at 7pm" — the orchestrator maintains context across all messages
- [ ] User says "remember that I prefer window seats on flights" — this is stored in memory and recalled in future flight-related tasks, even across app restarts
- [ ] A background job needs a Slack token that was set up weeks ago — it retrieves it from Keychain and uses it successfully without any user interaction

---

## Future Enhancements (Post-MVP v2)

- OAuth flows for credential setup (instead of manual token pasting)
- User-selected screen region capture
- Multi-monitor support for screen vision
- Job templates / skill-to-job conversion ("run this skill on a schedule")
- Shared/community skill and job libraries
- Voice input (microphone -> speech-to-text -> chat)
- File drop zone (drag files onto the popover to provide context)

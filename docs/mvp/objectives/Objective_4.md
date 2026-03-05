# Objective 4: Always-Available Companion

## Overview

Transform Menu-Bot from a single-request-at-a-time chat assistant into a persistent, always-responsive AI companion. This objective bundles three tightly coupled changes: rewriting the orchestrator to run as a single long-lived Claude Code session with persistent memory, refactoring the chat system to support multiple concurrent tasks, and adding proactive toast notifications so the user never misses an update. Together, these deliver the single biggest UX leap — the user goes from "one message at a time, no memory" to "always-on conversational assistant that remembers me and keeps me informed."

---

## Objectives

### 4.1 Persistent Orchestrator Session

#### Problem

Currently, every user message launches a new Claude Code session (`-p "..."` flag), meaning the orchestrator has no memory of previous messages. The user can't have a back-and-forth conversation — every message is a one-off request with no context of what came before.

#### Requirements

##### 4.1.1 Single Persistent Session

- Instead of launching a new Claude Code process per message, MenuBot must maintain a **single long-running Claude Code session** for the orchestrator.
- The session should be started when the app launches (or on first user message) and kept alive.
- User messages should be fed into the running session's stdin (using `--input-format stream-json` or equivalent interactive mode).
- If the session dies unexpectedly, MenuBot must automatically restart it and restore context from memory (see 4.2).

##### 4.1.2 Session Lifecycle Management

- **Startup:** Launch the orchestrator Claude Code session with the orchestrator skill loaded.
- **Message input:** Pipe user messages into the running session rather than spawning new processes.
- **Context window management:** Claude Code has built-in context compression. The orchestrator skill should instruct Claude to:
  - Summarize and condense older conversation context as the window fills
  - Prioritize retaining: user preferences, active task states, recent decisions, and key facts
  - Write important context to memory files (see 4.2) before it falls out of the window
- **Session restart:** If the process exits (crash, context exhaustion, or manual reset):
  1. Save current conversation summary to memory
  2. Restart a new session
  3. Load the orchestrator skill (mandatory — see 4.1.3)
  4. Load memory files so the new session has continuity
  5. The user should experience this as a brief "thinking..." pause, not a visible restart

##### 4.1.3 Mandatory Skill Loading

- **Every message must force-load the orchestrator skill.** The orchestrator must never lose sight of its purpose, communication style, or operational rules.
- Implementation: When piping a user message into the session, prepend or wrap it with an instruction to re-read the orchestrator skill:
  - Option A: Use the `/menubot-orchestrator` slash command prefix on every message
  - Option B: Include a system-level instruction that references the skill file path, and the orchestrator re-reads it periodically
- The goal: even deep in a long conversation, the orchestrator behaves consistently and never drifts from its defined personality and rules.

#### Acceptance Criteria

- [ ] The orchestrator runs as a single persistent Claude Code session, not one-per-message
- [ ] User messages are piped into the running session (no new process per message)
- [ ] Conversation context is maintained across messages within a session
- [ ] Session restarts are automatic and seamless — the user doesn't lose continuity
- [ ] The orchestrator skill is loaded with every message to maintain consistent behavior

---

### 4.2 Orchestrator Memory System

#### Requirements

##### 4.2.1 Memory Directory & Files

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

##### 4.2.2 Memory Lifecycle

- Memory files should be kept concise. The orchestrator skill should instruct Claude to:
  - Cap `conversation-context.md` at ~200 lines, rotating old content out
  - Cap `task-history.md` at ~100 entries, keeping only the most recent and most relevant
  - Keep `user-profile.md` as a living document that's updated, not appended to
  - Keep `learned-facts.md` as a clean reference (remove outdated facts, update changed ones)
- Provide a "Forget everything" option in settings that clears all memory files (with confirmation).

#### Acceptance Criteria

- [ ] Memory files exist at `~/Library/Application Support/MenuBot/memory/` and are read on startup
- [ ] When context gets full, Claude compresses/summarizes and key info is preserved in memory files
- [ ] The orchestrator updates memory proactively as it learns about the user
- [ ] A "Forget everything" option exists in settings

---

### 4.3 Non-Blocking Concurrent Chat

#### Problem

Currently, `ChatViewModel` tracks a single `CommandRunner` and sets `isRunning = true`, which blocks the input field (`guard !isRunning` in `sendMessage()`). The user cannot send new messages while a task is in progress. The orchestrator uses `sleep` + timer patterns for doer polling that can hang the session.

#### Requirements

##### 4.3.1 Concurrent Message Processing

- The user must be able to send new messages at any time, even while previous tasks are actively running.
- The input field must never be disabled. Remove the `guard !isRunning` gate from `sendMessage()`.
- Each user message that triggers a Claude Code session should be managed independently.

##### 4.3.2 Multiple Simultaneous Processes

- `ChatViewModel` must support multiple active `CommandRunner` instances, not just one.
- Each running process should be associated with the assistant message bubble it's streaming into.
- A data structure (e.g., dictionary keyed by message ID) should track active runners so completions route to the correct message bubble.

##### 4.3.3 Orchestrator Session Awareness

- The orchestrator must remain responsive while doers are running. It already uses `run_in_background` for check-ins — this pattern must be preserved and enforced.
- When a doer completes and the orchestrator receives its result, the orchestrator must correctly associate the result with the original request context, even if the user has sent additional messages since.
- The orchestrator must never "forget" to poll a running doer. If a check-in reveals the doer is still running, another check-in must be scheduled. This chain must not break.

#### Acceptance Criteria

- [ ] User can send a message while a previous task is still running
- [ ] Two or more doer processes can run simultaneously without cross-talk
- [ ] Orchestrator correctly routes doer results to the right conversation context

---

### 4.4 Per-Task UI Indicators

#### Requirements

- Each in-progress task should show a subtle activity indicator (spinner or pulsing dot) on its message bubble.
- The menu bar icon should indicate when any background work is active (e.g., subtle animation or badge).
- A "Stop" action should be available per-task (per message bubble), not just globally.

#### Acceptance Criteria

- [ ] Each active task has its own cancel/stop control
- [ ] Menu bar icon reflects active background work

---

### 4.5 Proactive Toast Notifications

#### Problem

When the orchestrator finishes a task or has an update for the user, and the popover (`NSPopover`) is closed, the user has no idea anything happened. Updates silently land in chat history that no one is looking at.

#### Current Infrastructure

- **`ToastWindow`** (`ToastWindow.swift`) — An `NSPanel` (`.nonactivatingPanel`, `.statusBar` level) that renders a speech-bubble toast anchored below the `NSStatusItem`. It has an upward-pointing arrow (`BubbleArrow` shape), uses `.ultraThinMaterial` for a frosted glass look, and auto-dismisses after 4 seconds. Positioned via `statusItem.button.window.convertToScreen()`.
- **`ToastView`** (`ToastView.swift`) — SwiftUI view displaying `title` + `message` with tap-to-dismiss.
- **`NotificationManager`** (`NotificationManager.swift`) — Receives `MenuBotEvent` cases (`.toast`, `.result`, `.error`) and calls `toastWindow.show()` for toast events. Currently only triggers on explicit `[MENUBOT_EVENT]` protocol messages from doers.
- **`NSPopover`** (`AppDelegate.swift`) — The main chat UI. `popover.isShown` indicates whether the user is actively viewing the chat. Behavior is `.transient` (closes when clicking outside).

#### Requirements

##### 4.5.1 Auto-Toast When Popover Is Closed

- Whenever the orchestrator produces a new assistant message (or updates an existing one with meaningful content) **and** the popover is not shown (`popover.isShown == false`), MenuBot must automatically display a `ToastWindow` notification anchored to the menu bar icon.
- This applies to:
  - Task completion messages (doer finishes and orchestrator summarizes the result)
  - Progress updates that the orchestrator relays to the user
  - `[ASK_USER]` questions that need the user's attention
  - Any new assistant message content streamed into the chat
- This does **not** require explicit `[MENUBOT_EVENT]` protocol messages — the trigger is simply "new assistant content appeared while the popover is closed."

##### 4.5.2 Toast Content

- The toast should show a concise preview of the assistant's message:
  - **Title:** "MenuBot" (or the task context if available, e.g., "Flight Search")
  - **Message:** First 2-3 lines or ~120 characters of the assistant message, truncated with "..." if longer
- For `[ASK_USER]` events, the title should indicate attention is needed: "MenuBot needs your input"

##### 4.5.3 Toast Interaction

- **Tap the toast** -> Opens the popover and scrolls to the relevant message. The toast dismisses.
- **Toast auto-dismisses** after 4 seconds (existing behavior) if not tapped.
- If multiple updates arrive while the popover is closed, toasts should queue (not overlap). Show them sequentially with a brief gap, or show the most recent one with a badge count (e.g., "3 new messages").

##### 4.5.4 Menu Bar Icon Badge

- When there are unread assistant messages (messages that arrived while the popover was closed and haven't been seen yet), the menu bar icon should show a subtle indicator:
  - A small dot badge (similar to notification badges on iOS app icons)
  - Or a count badge if multiple unread messages exist
- The badge clears when the popover is opened.

##### 4.5.5 Implementation Notes

- `ChatViewModel` needs awareness of whether the popover is visible. Options:
  - Pass a binding or closure from `AppDelegate` that checks `popover.isShown`
  - Use `NotificationCenter` to broadcast popover open/close events
  - Have `NotificationManager` check popover state before deciding whether to toast
- The `appendToAssistantMessage()` and `finishRun()` methods in `ChatViewModel` are the natural trigger points — after updating the message, check popover visibility and fire a toast if closed.
- `NotificationManager` already has the `ToastWindow` and `statusItem` references needed. It just needs a new method like `showAutoToast(preview:)` that `ChatViewModel` can call.

#### Acceptance Criteria

- [ ] When the popover is closed and the orchestrator produces a new message, a toast appears anchored to the menu bar icon
- [ ] The toast shows a concise preview of the message content
- [ ] Tapping the toast opens the popover
- [ ] Multiple rapid updates queue or consolidate rather than overlapping
- [ ] The menu bar icon shows an unread indicator when messages arrived while the popover was closed
- [ ] The unread indicator clears when the popover is opened
- [ ] When the popover is already open, no toast is shown (content is visible in chat)

---

## Scope Boundary

This objective does NOT include:

- Background jobs, job scheduling, or LaunchAgents (Objective 5)
- Credential storage, Keychain integration, or the `menubot-creds` CLI (Objective 5)
- Screenshot capture, screen recording permissions, or accessibility metadata (Objective 6)
- Mouse/keyboard control, the `menubot-input` CLI, or the vision-action loop (Objective 6)
- Login item registration, startup sequence ordering, or new skill bootstrapping (Objective 7)

---

## Dependencies

- **Depends on:** Objectives 1–3 (existing Phase 1-3 foundations: menu bar app, chat UI, skills system, orchestrator/doer architecture, event protocol)
- **Feeds into:** Objective 5 (persistent session enables background job result delivery), Objective 6 (non-blocking chat enables concurrent screen tasks), Objective 7 (startup sequence depends on persistent session and memory system)

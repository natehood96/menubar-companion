# Phase 4 — Persistent Orchestrator Session

- **Phase Number:** 4
- **Phase Name:** Persistent Orchestrator Session
- **Source:** docs/mvp/phases/overviews/objective4PhaseOverview.md

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

---

## Task Tracking Instructions

- Tasks use checkboxes
- Engineer checks off each task title with a checkmark emoji AFTER completing the work
- Engineer updates as they go
- Phase cannot advance until checklist complete
- If execution stops, checkmarks indicate progress

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Replaces the process-per-message model with a single persistent Claude Code session that accepts user messages via stdin, maintains conversation context across messages, and auto-restarts on crash or context exhaustion.
- **What already exists:** `CommandRunner` spawns a new `Process` per message. `ChatViewModel` creates a new `CommandRunner` for each `sendMessage()` call with `-p` one-shot prompt mode. `StreamJsonParser` handles NDJSON stream-json output. `[SAY]` filtering works per-run with `lineBuffer` and `currentLineIsUserFacing` state on the view model. `OrchestrationBootstrap` installs skill files and creates directories.
- **What future phases depend on this:** Phase 5 (Memory System) needs session restart hooks to reload memory files. Phase 6 (Concurrent Chat) adapts the persistent session's stdin model for concurrent message handling. Phase 7 (Toasts & Badge) hooks into the message routing from Phase 6.

---

## 0. Mental Model (Required)

**Problem:** Currently, every user message spawns an entirely new Claude Code process. This means:
1. No conversation context — each message is independent, the orchestrator can't reference earlier messages.
2. High latency — each spawn incurs process startup + model initialization overhead.
3. Skill loading overhead — the orchestrator skill must be loaded fresh every time.

**Where it fits:** This is the foundational architectural change for Objective 4. Every subsequent phase (memory, concurrency, notifications) builds on the persistent session model. Without this, the app cannot maintain conversational continuity.

**Data flow (after this phase):**
1. App launches (or user sends first message) -> `ChatViewModel` starts a single `CommandRunner` in long-running mode with `--input-format stream-json`.
2. User sends a message -> `ChatViewModel` pipes the message as a JSON object into the running process's stdin (instead of spawning a new process).
3. The running Claude Code session processes the message, streams NDJSON responses back via stdout.
4. `StreamJsonParser` + `[SAY]` filter process the output as before, appending to the current assistant message bubble.
5. If the process dies (crash, context exhaustion, exit) -> `ChatViewModel` detects via `terminationHandler`, restarts the session, and queues any pending message.

**Core entities:**
- **`CommandRunner`** — gains a `send(input:)` method to write to stdin; keeps process alive between messages.
- **`ChatViewModel`** — manages a single persistent `CommandRunner` instead of creating one per message; handles session lifecycle (start, restart, queue).
- **`StreamJsonParser`** — unchanged, continues parsing NDJSON lines.
- **`[SAY]` filter state** — must reset between messages within the same session (new assistant turn = fresh filter state).

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Replace the process-per-message model with a single long-running Claude Code session that maintains conversation context across messages, auto-restarts on failure, and queues messages during restarts.

### Prerequisites

- `CommandRunner` exists at `MenuBarCompanion/Core/CommandRunner.swift` with process spawning and streaming stdout/stderr.
- `ChatViewModel` exists at `MenuBarCompanion/UI/ChatViewModel.swift` with `sendMessage()`, `[SAY]` filtering, and `buildCommand()`.
- `StreamJsonParser` exists and handles NDJSON parsing.
- `OrchestrationBootstrap` installs orchestrator skill files to `~/.claude/skills/menubot-orchestrator/`.
- Claude Code CLI supports `--input-format stream-json` for accepting streamed JSON input on stdin.

### Key Deliverables

- `CommandRunner` refactored to support long-running mode with `send(input:)` stdin writing.
- `ChatViewModel` refactored to use a single persistent session instead of process-per-message.
- Session lifecycle management: auto-start, crash detection, auto-restart with queued messages.
- `buildCommand()` updated for persistent/interactive mode launch arguments.
- `[SAY]` filter state correctly resets between messages within one session.
- Message queuing during session restart.

### System-Level Acceptance Criteria

- The orchestrator runs as a single persistent process, not one-per-message.
- User messages are piped into the running session's stdin as JSON objects.
- Conversation context is maintained across messages (the orchestrator can reference earlier messages).
- If the process dies, it restarts automatically and the user sees only a brief "thinking..." indicator.
- The `[SAY]` filtering layer continues to work correctly across multiple messages in one session.
- The orchestrator skill is referenced with every message.
- If the user sends a message during restart, it is queued and sent once the session is live.
- If the claude binary is missing, fallback to the current process-per-message model gracefully.

---

## 2. Execution Order

### Blocking Tasks (sequential critical path)

1. **Task 4.1** — Refactor `CommandRunner` for long-running mode (foundation for everything else)
2. **Task 4.2** — Update `buildCommand()` for persistent mode launch arguments
3. **Task 4.3** — Refactor `ChatViewModel.sendMessage()` to pipe into running session
4. **Task 4.4** — Implement session lifecycle management (start, detect exit, restart)
5. **Task 4.5** — Reset `[SAY]` filter state between messages within a session
6. **Task 4.6** — Implement mandatory skill loading per message

### Parallel Tasks

- **Task 4.7** (message queuing during restart) can be built in parallel with Task 4.6 once Task 4.4 is complete.
- **Task 4.8** (edge case: claude binary missing fallback) can be built any time after Task 4.1.

### Final Integration

- **Task 4.9** — End-to-end integration test: send multiple messages in sequence, verify context is maintained, kill the process, verify restart and continuity.

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Stdin input format | (A) `--input-format stream-json` with JSON objects on stdin, (B) `--resume SESSION_ID` with new process per message | A: stream-json stdin | Lower latency, single process, true persistent session. Fall back to B if stdin piping doesn't work. | Claude Code stdin mode may have undocumented behavior — spike early in Task 4.1. |
| Session start timing | (A) Start on app launch, (B) Start on first user message | B: First message (lazy start) | Avoids wasting resources if user opens app but doesn't chat. Also avoids blocking app launch. | Slightly longer first-message latency. Acceptable trade-off. |
| Filter state reset | (A) Reset on each `send()`, (B) Reset when new assistant message bubble is created | B: Reset on new bubble creation | Aligns with the natural message boundary — new assistant bubble = new turn. | None significant. |

---

## 4. Subtasks

### Task 4.1 — Refactor CommandRunner for Long-Running Mode

#### User Story

As the app, I need `CommandRunner` to keep a process alive across multiple interactions, exposing a `send(input:)` method that writes to the process's stdin pipe, so that I can maintain a persistent Claude Code session.

#### Implementation Steps

1. Add a `stdinPipe` property to `CommandRunner`:
   ```swift
   private let stdinPipe = Pipe()
   ```

2. In `init`, attach `stdinPipe` to the process:
   ```swift
   process.standardInput = stdinPipe
   ```

3. Add a `send(input:)` method that writes data to stdin:
   ```swift
   func send(input: String) {
       guard process.isRunning else { return }
       let data = (input + "\n").data(using: .utf8)!
       stdinPipe.fileHandleForWriting.write(data)
   }
   ```

4. Add a `var isAlive: Bool` computed property:
   ```swift
   var isAlive: Bool { process.isRunning }
   ```

5. Ensure existing `start(onOutput:onComplete:)` still works — the process now stays alive after first output since we're not closing stdin.

6. Ensure `cancel()` closes the stdin pipe before terminating to avoid broken pipe errors:
   ```swift
   func cancel() {
       guard process.isRunning else { return }
       try? stdinPipe.fileHandleForWriting.close()
       process.terminate()
   }
   ```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/CommandRunner.swift` | Modified | Add `stdinPipe`, `send(input:)`, `isAlive`, update `cancel()` |

#### Acceptance Criteria

- [ ] `CommandRunner` has a `stdinPipe` connected to the process's `standardInput`
- [ ] `send(input:)` writes a string followed by newline to stdin
- [ ] `isAlive` returns `true` while the process is running
- [ ] `cancel()` closes stdin before terminating
- [ ] Existing `start(onOutput:onComplete:)` continues to work for the fallback shell mode

---

### Task 4.2 — Update buildCommand() for Persistent Mode

#### User Story

As the app, I need to launch Claude Code in persistent/interactive mode rather than one-shot `-p` mode, so the session stays alive and accepts streamed input.

#### Implementation Steps

1. Split `buildCommand()` into two methods — one for persistent mode, one for one-shot fallback:

   ```swift
   /// Build command for persistent interactive session (no -p flag, uses --input-format stream-json)
   private func buildPersistentCommand() -> (executable: String, arguments: [String])? {
       guard let claudePath else { return nil }
       return (claudePath, [
           "--dangerously-skip-permissions",
           "--permission-mode", "bypassPermissions",
           "--output-format", "stream-json",
           "--input-format", "stream-json",
           "--verbose"
       ])
   }
   ```

2. Keep the existing `buildCommand(for:)` as the one-shot fallback for when claude is not detected or for non-Claude shell commands.

3. The persistent command does NOT include `-p` — the prompt is sent via stdin after the process starts.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Add `buildPersistentCommand()`, keep existing `buildCommand(for:)` as fallback |

#### Acceptance Criteria

- [ ] `buildPersistentCommand()` returns a command without `-p` flag
- [ ] `buildPersistentCommand()` includes `--input-format stream-json`
- [ ] `buildPersistentCommand()` returns `nil` if `claudePath` is not set
- [ ] Existing `buildCommand(for:)` still works for fallback/shell mode

---

### Task 4.3 — Refactor ChatViewModel.sendMessage() for Persistent Session

#### User Story

As a user, I want my messages to be sent into an existing Claude Code session so the AI remembers our conversation context, rather than starting fresh every time.

#### Implementation Steps

1. Add session state properties to `ChatViewModel`:
   ```swift
   private var sessionRunner: CommandRunner?
   private var sessionStarting: Bool = false
   private var pendingMessages: [String] = []
   ```

2. Refactor `sendMessage()`:
   ```swift
   func sendMessage() {
       let trimmed = inputText.trimmingCharacters(in: .whitespaces)
       guard !trimmed.isEmpty else { return }
       // Remove the `guard !isRunning` gate — user can always send messages

       // Add user message bubble
       let userMessage = ChatMessage(role: .user, content: trimmed)
       messages.append(userMessage)
       inputText = ""

       // If Claude is not detected, use legacy one-shot mode
       guard claudePath != nil else {
           sendOneShot(trimmed)
           return
       }

       // Send via persistent session
       sendToSession(trimmed)
   }
   ```

3. Implement `sendToSession(_:)`:
   ```swift
   private func sendToSession(_ message: String) {
       // If session exists and is alive, pipe the message
       if let session = sessionRunner, session.isAlive {
           startNewAssistantBubble()
           let payload = buildStdinPayload(for: message)
           session.send(input: payload)
           return
       }

       // Session not alive — queue message and start/restart
       pendingMessages.append(message)
       if !sessionStarting {
           startSession()
       }
   }
   ```

4. Implement `buildStdinPayload(for:)` — format the message as the JSON object that `--input-format stream-json` expects:
   ```swift
   private func buildStdinPayload(for message: String) -> String {
       // Claude Code stream-json input expects: {"type":"user","content":"..."}
       let skillPrefix = "/menubot-orchestrator The claude binary is at: \(claudePath!). Use this full path when launching doers."
       let fullMessage = "\(skillPrefix) \(message)"
       let escaped = fullMessage
           .replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
           .replacingOccurrences(of: "\n", with: "\\n")
           .replacingOccurrences(of: "\t", with: "\\t")
       return "{\"type\":\"user\",\"content\":\"\(escaped)\"}"
   }
   ```
   > **Note:** The exact JSON schema for `--input-format stream-json` stdin must be validated during implementation. If Claude Code expects a different format (e.g., `{"prompt":"..."}` or a raw string), adjust accordingly. Check Claude Code docs or test empirically.

5. Extract the legacy one-shot flow into `sendOneShot(_:)` preserving current behavior:
   ```swift
   private func sendOneShot(_ message: String) {
       let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
       messages.append(assistantMessage)
       isRunning = true
       lineBuffer = ""
       currentLineIsUserFacing = false

       let command = buildCommand(for: message)
       runner = CommandRunner(command: command.executable, arguments: command.arguments)
       runner?.start(
           onOutput: { [weak self] line in
               Task { @MainActor in self?.handleOutputLine(line) }
           },
           onComplete: { [weak self] exitCode in
               Task { @MainActor in self?.finishRun(exitCode: exitCode) }
           }
       )
   }
   ```

6. Add helper `startNewAssistantBubble()`:
   ```swift
   private func startNewAssistantBubble() {
       let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
       messages.append(assistantMessage)
       isRunning = true
       // Reset [SAY] filter for new turn
       lineBuffer = ""
       currentLineIsUserFacing = false
   }
   ```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Add `sessionRunner`, `pendingMessages`, refactor `sendMessage()`, add `sendToSession()`, `sendOneShot()`, `buildStdinPayload()`, `startNewAssistantBubble()` |

#### Acceptance Criteria

- [ ] `sendMessage()` no longer spawns a new `CommandRunner` per message when Claude is detected
- [ ] Messages are piped into the existing session via `sessionRunner.send(input:)`
- [ ] A new assistant bubble is created for each user message
- [ ] The `guard !isRunning` gate is removed — users can always type (though messages may queue)
- [ ] Legacy one-shot mode still works when `claudePath` is nil
- [ ] The stdin JSON payload includes the skill prefix and the user's message

---

### Task 4.4 — Implement Session Lifecycle Management

#### User Story

As a user, I want the AI session to start automatically, survive crashes, and restart invisibly, so I never have to think about the underlying process.

#### Implementation Steps

1. Implement `startSession()`:
   ```swift
   private func startSession() {
       guard let command = buildPersistentCommand() else { return }
       sessionStarting = true

       sessionRunner = CommandRunner(command: command.executable, arguments: command.arguments)
       sessionRunner?.start(
           onOutput: { [weak self] line in
               Task { @MainActor in self?.handleOutputLine(line) }
           },
           onComplete: { [weak self] exitCode in
               Task { @MainActor in self?.handleSessionExit(exitCode: exitCode) }
           }
       )

       // Once the session is running, flush any pending messages
       // Give a brief delay for the process to initialize
       DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
           self?.sessionStarting = false
           self?.flushPendingMessages()
       }
   }
   ```

2. Implement `handleSessionExit(exitCode:)`:
   ```swift
   private func handleSessionExit(exitCode: Int32) {
       print("[ChatViewModel] Session exited with code \(exitCode)")
       sessionRunner = nil
       isRunning = false

       // Mark any streaming assistant message as done
       if !messages.isEmpty, messages[messages.count - 1].role == .assistant,
          messages[messages.count - 1].isStreaming {
           messages[messages.count - 1].isStreaming = false
           if messages[messages.count - 1].content.isEmpty {
               messages[messages.count - 1].content = "[session restarting...]"
           }
       }

       // Auto-restart after a brief delay
       DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
           guard let self else { return }
           // Add a system message indicating restart
           let systemMsg = ChatMessage(role: .system, content: "Session restarted — context may be limited.")
           self.messages.append(systemMsg)
           ChatStore.save(self.messages)

           // If there are pending messages or the session died mid-conversation, restart
           if !self.pendingMessages.isEmpty {
               self.startSession()
           }
           // Otherwise, session will restart lazily on next user message via sendToSession()
       }
   }
   ```

3. Implement `flushPendingMessages()`:
   ```swift
   private func flushPendingMessages() {
       guard let session = sessionRunner, session.isAlive else { return }
       while !pendingMessages.isEmpty {
           let message = pendingMessages.removeFirst()
           startNewAssistantBubble()
           let payload = buildStdinPayload(for: message)
           session.send(input: payload)
       }
   }
   ```

4. Handle the `finishRun` for persistent session differently — in persistent mode, a "result" event from stream-json signals end of a turn, not end of the process. Update `handleStreamJsonLine` to detect turn completion:
   ```swift
   case .done:
       // In persistent mode, this marks end of an assistant turn, not session end
       finishCurrentTurn()
   ```

5. Add `finishCurrentTurn()`:
   ```swift
   private func finishCurrentTurn() {
       isRunning = false
       lineBuffer = ""
       currentLineIsUserFacing = false

       if !messages.isEmpty, messages[messages.count - 1].role == .assistant {
           messages[messages.count - 1].isStreaming = false
           messages[messages.count - 1].content = messages[messages.count - 1].content
               .trimmingCharacters(in: .whitespacesAndNewlines)
           if messages[messages.count - 1].content.isEmpty {
               messages[messages.count - 1].content = "[done]"
           }
       }
       ChatStore.save(messages)
   }
   ```

6. Update the existing `finishRun(exitCode:)` to only be used for one-shot mode. Rename to `finishOneShotRun(exitCode:)` for clarity, or gate its behavior:
   ```swift
   private func finishRun(exitCode: Int32) {
       // Only applies to one-shot (non-persistent) runs
       // ... existing implementation unchanged ...
   }
   ```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Add `startSession()`, `handleSessionExit()`, `flushPendingMessages()`, `finishCurrentTurn()`, update `handleStreamJsonLine` done case |

#### Acceptance Criteria

- [ ] Session starts automatically when the first message is sent (lazy start)
- [ ] Session exit is detected via `onComplete` callback
- [ ] On exit, the session auto-restarts after a brief delay
- [ ] A system message is appended indicating the restart
- [ ] Pending messages are flushed after session (re)start
- [ ] Turn completion (`result` event) marks the assistant bubble as done without killing the process
- [ ] `isRunning` correctly reflects whether a turn is in progress (not whether the session exists)

---

### Task 4.5 — Reset [SAY] Filter State Between Messages

#### User Story

As a user, I want each AI response to start with a clean slate for the `[SAY]` filter, so that incomplete buffered content from a previous response doesn't leak into the next one.

#### Implementation Steps

1. The `[SAY]` filter state (`lineBuffer`, `currentLineIsUserFacing`) is already reset in `startNewAssistantBubble()` (added in Task 4.3). Verify this is sufficient.

2. Also reset in `finishCurrentTurn()` (added in Task 4.4) to ensure clean state after a turn completes.

3. Edge case: if the user sends a new message while the previous turn is still streaming, the new `startNewAssistantBubble()` call resets the filter. But the old turn's output is still arriving on stdout. Since we're in a single session, output from the old turn and new turn arrives on the same stdout stream. We need to handle the boundary.

4. The natural boundary is the `result` event from stream-json — it signals end of a turn. After `result`, the next `content_block_delta` or `assistant` event belongs to the new turn. Since we reset filter state when creating a new bubble (which happens before sending the new message), and the new message won't produce output until the previous turn finishes (Claude processes sequentially), this should be safe.

5. Add a guard: if `result` arrives and we still have buffered `[SAY]` content, flush it before resetting:
   ```swift
   private func finishCurrentTurn() {
       // Flush any remaining [SAY] content
       if currentLineIsUserFacing && !lineBuffer.isEmpty {
           // lineBuffer content was already streamed char-by-char, nothing to flush
       }
       isRunning = false
       lineBuffer = ""
       currentLineIsUserFacing = false
       // ... rest of finishCurrentTurn
   }
   ```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Verify and ensure filter state resets at turn boundaries |

#### Acceptance Criteria

- [ ] `lineBuffer` and `currentLineIsUserFacing` are reset when a new assistant bubble is created
- [ ] `lineBuffer` and `currentLineIsUserFacing` are reset when a turn completes
- [ ] No `[SAY]` content from a previous turn leaks into a new turn's assistant bubble
- [ ] If a turn ends mid-line (rare), the partial content is handled gracefully

---

### Task 4.6 — Implement Mandatory Skill Loading Per Message

#### User Story

As the app, I need to ensure the orchestrator skill is referenced with every user message, so the orchestrator never drifts from its defined behavior even within a long-running session.

#### Implementation Steps

1. The skill prefix is already included in `buildStdinPayload(for:)` (Task 4.3):
   ```swift
   let skillPrefix = "/menubot-orchestrator The claude binary is at: \(claudePath!). Use this full path when launching doers."
   ```

2. Verify that prepending `/menubot-orchestrator` to every message in a persistent session actually triggers skill re-loading in Claude Code. If Claude Code only loads skills on session start, this approach may need adjustment.

3. Alternative if per-message skill invocation doesn't work: load the skill as the first message when starting the session, and on subsequent messages just include the claude binary path context:
   ```swift
   private func buildStdinPayload(for message: String, isFirstMessage: Bool = false) -> String {
       let context = "The claude binary is at: \(claudePath!). Use this full path when launching doers."
       let fullMessage: String
       if isFirstMessage {
           fullMessage = "/menubot-orchestrator \(context) \(message)"
       } else {
           fullMessage = "\(context) \(message)"
       }
       // ... JSON encode
   }
   ```

4. Track whether this is the first message in the session:
   ```swift
   private var isFirstMessageInSession: Bool = true
   ```
   Reset to `true` in `startSession()`, set to `false` after first `send()`.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Add `isFirstMessageInSession` tracking, update `buildStdinPayload()` to conditionally include skill prefix |

#### Acceptance Criteria

- [ ] The orchestrator skill is loaded/referenced on the first message of every session
- [ ] The claude binary path context is included with every message
- [ ] After a session restart, the skill is re-loaded on the first message of the new session
- [ ] The orchestrator behaves consistently whether it's the 1st or 10th message in a session

---

### Task 4.7 — Message Queuing During Session Restart

#### User Story

As a user, I want to be able to type and send messages even if the AI session is restarting, so I never have to wait or worry about timing.

#### Implementation Steps

1. The queuing mechanism is already scaffolded in Tasks 4.3 and 4.4 via `pendingMessages`. Ensure it handles these scenarios:

2. **Scenario A: Session not yet started (first message).** `sendToSession()` adds to `pendingMessages`, calls `startSession()`. `startSession()` flushes after initialization delay.

3. **Scenario B: Session died, user sends message.** `sendToSession()` sees `sessionRunner` is nil or not alive, adds to `pendingMessages`, calls `startSession()`.

4. **Scenario C: Session is restarting (`sessionStarting == true`), user sends another message.** `sendToSession()` adds to `pendingMessages` but does NOT call `startSession()` again (guarded by `sessionStarting` flag).

5. **Scenario D: Multiple messages queued.** `flushPendingMessages()` sends them all sequentially. However, since the persistent session processes one at a time, sending multiple messages rapidly will result in them being processed in order. Each queued message should get its own assistant bubble.

6. Update `flushPendingMessages()` to handle multiple messages with a slight delay between sends to allow the session to process each:
   ```swift
   private func flushPendingMessages() {
       guard let session = sessionRunner, session.isAlive, !pendingMessages.isEmpty else { return }
       let message = pendingMessages.removeFirst()
       startNewAssistantBubble()
       let payload = buildStdinPayload(for: message, isFirstMessage: isFirstMessageInSession)
       isFirstMessageInSession = false
       session.send(input: payload)
       // Remaining pending messages will be sent after the current turn completes
       // (via finishCurrentTurn -> check for more pending)
   }
   ```

7. Update `finishCurrentTurn()` to check for and flush remaining pending messages:
   ```swift
   private func finishCurrentTurn() {
       // ... existing turn cleanup ...
       // Check for queued messages
       if !pendingMessages.isEmpty {
           flushPendingMessages()
       }
   }
   ```

8. Add a visual indicator when messages are queued: show a brief "queued..." label or keep the assistant bubble showing "..." while waiting.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Refine `flushPendingMessages()`, update `finishCurrentTurn()` to flush queue, handle multiple queued messages |

#### Acceptance Criteria

- [ ] Messages sent while the session is starting are queued and delivered once the session is live
- [ ] Messages sent while the session is restarting are queued and delivered after restart
- [ ] Multiple queued messages are processed sequentially (one turn at a time)
- [ ] Each queued message gets its own user bubble immediately and assistant bubble when processing starts
- [ ] No messages are lost during session transitions

---

### Task 4.8 — Fallback for Missing Claude Binary

#### User Story

As a user without the Claude CLI installed, I want the app to still work in a basic shell mode, so it degrades gracefully rather than breaking.

#### Implementation Steps

1. The fallback is already handled by the `guard claudePath != nil` check in `sendMessage()` (Task 4.3). If `claudePath` is nil, `sendOneShot()` is called which uses the existing `/bin/sh` fallback from `buildCommand(for:)`.

2. Ensure `startSession()` has a guard for `claudePath`:
   ```swift
   private func startSession() {
       guard let command = buildPersistentCommand() else {
           // Claude not available — one-shot mode only
           sessionStarting = false
           return
       }
       // ... rest of startSession
   }
   ```

3. If the session starts but immediately crashes (binary found but broken), `handleSessionExit` will fire. Add a retry limit to avoid infinite restart loops:
   ```swift
   private var sessionRestartCount: Int = 0
   private let maxSessionRestarts: Int = 3
   ```

4. In `handleSessionExit`:
   ```swift
   sessionRestartCount += 1
   if sessionRestartCount > maxSessionRestarts {
       print("[ChatViewModel] Max session restarts exceeded, falling back to one-shot mode")
       let systemMsg = ChatMessage(role: .system, content: "Session could not be maintained. Falling back to single-message mode.")
       messages.append(systemMsg)
       // Move pending messages to one-shot execution
       for msg in pendingMessages {
           sendOneShot(msg)
       }
       pendingMessages.removeAll()
       return
   }
   ```

5. Reset `sessionRestartCount` on successful turn completion (in `finishCurrentTurn()`):
   ```swift
   sessionRestartCount = 0  // Session is healthy
   ```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modified | Add `sessionRestartCount`, `maxSessionRestarts`, restart loop protection, reset on success |

#### Acceptance Criteria

- [ ] App works in shell mode when `claudePath` is nil
- [ ] Session restart loop is capped at 3 attempts
- [ ] After max restarts, pending messages are executed in one-shot mode
- [ ] Successful turns reset the restart counter
- [ ] User sees a system message explaining the fallback

---

### Task 4.9 — End-to-End Integration Validation

#### User Story

As the developer, I need to verify the entire persistent session flow works end-to-end: multi-message context, crash recovery, and message queuing.

#### Implementation Steps

1. **Test: Multi-message context.** Send "My name is Alice", then send "What is my name?". The orchestrator should respond with "Alice" in the second response, proving context is maintained.

2. **Test: Session restart.** While the session is running, manually kill the Claude Code process (`kill -9 <PID>`). Verify:
   - The streaming assistant bubble stops and shows content (not stuck in loading)
   - A system message appears: "Session restarted..."
   - The next user message triggers a new session start
   - The `[SAY]` filter works correctly after restart

3. **Test: Message queuing.** Send a message, and while the session is starting (before the first response arrives), send a second message. Verify both messages are processed and both get assistant responses.

4. **Test: Rapid messages.** Send 3 messages in quick succession. Verify all 3 get user bubbles immediately and assistant responses arrive sequentially.

5. **Test: Fallback mode.** Temporarily rename the claude binary. Send a message. Verify the app falls back to shell mode without crashing.

6. **Test: [SAY] filter across turns.** Send a message, wait for response. Send another message. Verify no `[SAY]` prefix text leaks into the displayed content and no output from the first turn appears in the second turn's bubble.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | Manual testing | Run app and verify scenarios manually |

#### Acceptance Criteria

- [ ] Multi-message context is maintained within a session
- [ ] Session auto-restarts after process death with visible system message
- [ ] Messages queued during restart are delivered after restart
- [ ] Rapid sequential messages all get responses
- [ ] Fallback to one-shot mode works when claude binary is unavailable
- [ ] `[SAY]` filtering works correctly across multiple turns in one session

---

## 5. Integration Points

- **Claude Code CLI:** Depends on `--input-format stream-json` for stdin-based message piping. If this flag doesn't exist or behaves differently, fall back to `--resume SESSION_ID` with process-per-message (preserves context via session resumption).
- **OrchestrationBootstrap:** No changes needed — skill files are already installed at `~/.claude/skills/menubot-orchestrator/`. The persistent session loads them once on start.
- **StreamJsonParser:** Unchanged — continues parsing NDJSON from stdout. Must handle the `result` event as a turn boundary (not session end).
- **NotificationManager / EventParser:** Unchanged — MenuBot events embedded in tool output are still detected and handled.
- **ChatStore:** Unchanged — messages are saved on turn completion and session exit.
- **AppDelegate:** No changes needed for this phase.

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

- **CommandRunner tests:** Verify `send(input:)` writes to stdin, `isAlive` returns correct state, `cancel()` closes stdin.
- **Stdin payload tests:** Verify `buildStdinPayload(for:)` correctly JSON-encodes messages with special characters (quotes, newlines, backslashes, unicode).
- **Session lifecycle tests:** Verify restart logic, queue flushing, restart counter behavior.
- **[SAY] filter reset tests:** Verify filter state is clean at turn boundaries.

### During Implementation: Build Against Tests

- Test `CommandRunner` with a simple long-running process (e.g., `cat` which echoes stdin to stdout) to verify stdin/stdout piping works.
- Test payload encoding with edge-case strings.
- Test session restart by spawning a process that exits after a delay.

### Phase End: Polish Tests

- Integration test with actual Claude Code binary (manual).
- Edge case: very long messages, messages with emoji/unicode, empty messages.
- Edge case: what happens if `send(input:)` is called on a process that just died (race condition).
- Remove placeholder tests, ensure all pass.

---

## 7. Definition of Done

- [ ] Persistent session launches and stays alive across multiple user messages
- [ ] Conversation context is maintained (orchestrator references earlier messages)
- [ ] Session auto-restarts on crash/exit with user-visible system message
- [ ] Messages queued during restart are delivered after restart
- [ ] `[SAY]` filter works correctly across turns
- [ ] Orchestrator skill is loaded on session start
- [ ] Fallback to one-shot mode works when Claude CLI is unavailable
- [ ] Restart loop protection prevents infinite crash-restart cycles
- [ ] No regressions in existing chat UI, skill execution, or event handling
- [ ] All tests passing

### Backward Compatibility

The one-shot fallback (`sendOneShot` / `buildCommand(for:)`) preserves the existing process-per-message behavior for non-Claude mode. No breaking changes for users without the Claude CLI. The `ChatMessage` model, `ChatStore`, and UI are unchanged.

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Phase 5 until all items are verified:**

- [ ] **Build:** `xcodebuild` compiles with zero errors and zero warnings related to this phase's changes.
- [ ] **Manual test — context:** Send "Remember the number 42", then send "What number did I mention?" — assistant responds with 42.
- [ ] **Manual test — restart:** Kill the Claude process via Activity Monitor. Verify restart system message appears and next message works.
- [ ] **Manual test — queue:** Send a message immediately after app launch (before session is ready). Verify it is delivered once the session starts.
- [ ] **Manual test — fallback:** With claude binary renamed/removed, verify shell mode still works.
- [ ] **Manual test — [SAY] filter:** Send 3 messages in a session. Verify no raw `[SAY]` prefixes appear in any assistant bubble.
- [ ] **Code review:** No unused properties, no debug print statements left in production paths, no force-unwraps without justification.

---

## Appendix

### Claude Code Stdin Format (to validate)

The exact JSON format for `--input-format stream-json` stdin needs empirical validation. Expected format based on Claude Code docs:

```json
{"type":"user","content":"Hello, how are you?"}
```

If the actual format differs, update `buildStdinPayload(for:)` accordingly. Run `claude --help` or check Claude Code source for the schema.

### Session State Machine

```
[App Launch]
     |
     v
  NO SESSION  ---(user sends message)---> STARTING
     ^                                        |
     |                                  (process running)
     |                                        |
     |                                        v
     |                                     ACTIVE  <--(turn completes)-- PROCESSING
     |                                        |              ^
     |                                  (user sends msg)     |
     |                                        |              |
     |                                        v              |
     |                                   PROCESSING ---------'
     |
     '----(process dies)---- RESTARTING ----(delay)----> STARTING
```

### Key Properties Summary

| Property | Type | Purpose |
|----------|------|---------|
| `sessionRunner` | `CommandRunner?` | The persistent session process |
| `sessionStarting` | `Bool` | Guards against duplicate `startSession()` calls |
| `pendingMessages` | `[String]` | Messages queued during session start/restart |
| `isFirstMessageInSession` | `Bool` | Controls skill loading on first message |
| `sessionRestartCount` | `Int` | Tracks consecutive restarts for loop protection |
| `runner` | `CommandRunner?` | Legacy one-shot runner (kept for fallback) |

# Objective 4: Always-Available Companion — Phased Implementation Plan

## Reference Documents
- `docs/mvp/objectives/Objective_4.md`

## Scope Summary
- Rewrite orchestrator from process-per-message to a single persistent Claude Code session with stdin message piping, session restart/recovery, and mandatory skill loading (4.1)
- Add a persistent memory system with topic-organized markdown files, lifecycle management, and a "forget everything" option (4.2)
- Refactor ChatViewModel to support non-blocking concurrent chat with multiple simultaneous CommandRunners keyed by message ID (4.3)
- Add per-task UI indicators: per-bubble spinners, per-task cancel, menu bar activity indicator (4.4)
- Add proactive toast notifications when the popover is closed, with unread badge, toast queuing, and tap-to-open (4.5)

End state: The user has a persistent, memory-equipped AI companion that handles multiple tasks concurrently, shows per-task progress, and proactively notifies them of updates even when the popover is closed.

## Phasing Strategy: Front-to-Back (Option A)

Build the persistent foundation first, then layer concurrent chat on top, then polish with UI feedback and notifications. Each phase builds on the last, delivering the most architecturally fundamental changes first.

---

## Detailed Phase Plan

### Phase 1 — Persistent Orchestrator Session
**Goal:** Replace the process-per-message model with a single long-running Claude Code session that accepts user messages via stdin and survives restarts.
**Duration Estimate:** 4-6 days

**Tasks:**

- [ ] **1.1** Refactor `CommandRunner` to support a long-running mode: keep the process alive, expose a `send(input:)` method that writes to the process's stdin pipe, and continue reading stdout/stderr via existing `readabilityHandler` callbacks.
- [ ] **1.2** Add `--input-format stream-json` (or equivalent) to the Claude Code launch arguments so the running session accepts streamed input rather than a single `-p` prompt.
- [ ] **1.3** Refactor `ChatViewModel.sendMessage()` to pipe user messages into the running session's stdin instead of spawning a new `CommandRunner` per message. The `[SAY]` filtering layer must continue to work — `lineBuffer` and `currentLineIsUserFacing` state carry across messages within a session.
- [ ] **1.4** Implement session lifecycle management in `ChatViewModel`:
  - Start the orchestrator session on app launch (or on first user message).
  - Detect process exit (crash, context exhaustion) via `onComplete` callback.
  - On exit: save a conversation summary, restart the session, re-load the orchestrator skill, and load memory files (Phase 2 will flesh out the memory part — for now, just restart cleanly).
  - The user should see a brief "thinking..." indicator during restart, not a visible error.
- [ ] **1.5** Implement mandatory skill loading: prepend `/menubot-orchestrator` (or an equivalent skill reference instruction) to every user message piped into the session, ensuring the orchestrator never drifts from its defined behavior.
- [ ] **1.6** Update `buildCommand()` to launch the orchestrator in persistent/interactive mode rather than one-shot `-p` mode. Preserve `--dangerously-skip-permissions`, `--permission-mode bypassPermissions`, `--output-format stream-json`, and `--verbose` flags.
- [ ] **1.7** Handle edge cases: what happens if the user sends a message while the session is restarting? Queue it. What if the session never starts (claude binary missing)? Fall back to the current process-per-message model gracefully.
- [ ] **1.8** Test: send multiple messages in sequence within one session and verify context is maintained (the orchestrator remembers what was said earlier in the conversation).

**Definition of Done:**
- The orchestrator runs as a single persistent Claude Code process, not one-per-message.
- User messages are piped into the running session's stdin.
- Conversation context is maintained across messages within a session (the orchestrator can reference earlier messages).
- If the process dies, it restarts automatically and the user sees only a brief pause.
- The `[SAY]` filtering layer continues to work correctly across multiple messages in one session.
- The orchestrator skill is loaded/referenced with every message.

---

### Phase 2 — Orchestrator Memory System
**Goal:** Give the orchestrator persistent memory that survives session restarts and context window exhaustion, so the user never has to repeat themselves.
**Duration Estimate:** 2-3 days

**Tasks:**

- [ ] **2.1** Create the memory directory structure at `~/Library/Application Support/MenuBot/memory/` during `OrchestrationBootstrap.install()`. Seed empty starter files: `user-profile.md`, `conversation-context.md`, `task-history.md`, `learned-facts.md`.
- [ ] **2.2** Update the orchestrator skill (`menubot-orchestrator-SKILL.md`) with memory instructions:
  - On startup (and after session restart): read all memory files from the memory directory.
  - Proactively update memory files when learning something worth retaining (user preferences, completed tasks, facts the user asks to remember).
  - Use `grep` or keyword search against memory files for efficient recall rather than loading everything into context.
  - Write important context to memory files before it falls out of the context window.
- [ ] **2.3** Add memory lifecycle rules to the orchestrator skill:
  - Cap `conversation-context.md` at ~200 lines, rotating old content out.
  - Cap `task-history.md` at ~100 entries.
  - Keep `user-profile.md` as a living document (update in place, don't append).
  - Keep `learned-facts.md` clean (remove outdated facts, update changed ones).
- [ ] **2.4** Update session restart logic (from Phase 1, task 1.4): after restarting the session, instruct the orchestrator to read memory files as its first action, restoring continuity.
- [ ] **2.5** Add a "Forget everything" option in the app's settings/menu that deletes all files in the memory directory (with a confirmation dialog). Wire this through `ChatViewModel` or a dedicated `MemoryManager`.
- [ ] **2.6** Migrate the existing `user-profile.md` from `~/Library/Application Support/MenuBot/user-profile.md` (if it exists from the current orchestrator skill's reference files) into the new memory directory. Update the orchestrator skill's reference files section to point to the new memory directory.

**Definition of Done:**
- Memory files exist at `~/Library/Application Support/MenuBot/memory/` and are created on app launch.
- The orchestrator reads memory files on startup and after session restarts.
- The orchestrator proactively writes to memory files during conversation (observable by checking file modification times/content after a conversation).
- Memory file sizes stay within defined caps over extended use.
- "Forget everything" clears all memory files.
- After a session restart, the orchestrator demonstrates continuity (e.g., remembers the user's name, recent tasks).

---

### Phase 3 — Non-Blocking Concurrent Chat + Per-Task UI
**Goal:** Let the user send messages at any time (even while tasks are running) and see per-task progress indicators with individual cancel controls.
**Duration Estimate:** 3-5 days

**Tasks:**

- [ ] **3.1** Remove the `guard !isRunning` gate from `ChatViewModel.sendMessage()`. The user must always be able to send messages.
- [ ] **3.2** Refactor `ChatViewModel` to support multiple active runners. Replace the single `runner: CommandRunner?` with a dictionary keyed by message ID (e.g., `activeRunners: [UUID: CommandRunner]`). Each runner streams output into its associated assistant message bubble.
- [ ] **3.3** Adapt the `[SAY]` filtering state to be per-runner. Currently `lineBuffer` and `currentLineIsUserFacing` are single properties on the view model. With multiple concurrent runners, each runner needs its own filter state. Create a small struct (e.g., `SAYFilterState`) that holds `lineBuffer` and `currentLineIsUserFacing`, stored alongside each runner.
- [ ] **3.4** Determine how concurrent messages interact with the persistent session (Phase 1):
  - **If using a single persistent session:** Messages are queued and processed sequentially by the orchestrator (Claude Code handles one message at a time). The UI is non-blocking (user can type), but the orchestrator processes in order. Doer processes still run concurrently.
  - **If the orchestrator is busy with a doer check-in loop:** The new message should still be piped in — the orchestrator should handle it as an interruption and acknowledge it.
- [ ] **3.5** Update `cancel()` to support per-task cancellation. Each assistant message bubble with an active runner gets its own stop button. Cancelling one task doesn't affect others.
- [ ] **3.6** Add per-bubble activity indicators: show a spinner or pulsing dot on assistant message bubbles that are actively streaming (`isStreaming == true`). Update `ChatBubbleView` to display this.
- [ ] **3.7** Add a menu bar activity indicator: when any runner is active (`activeRunners` is non-empty), show a subtle animation or badge on the `NSStatusItem` button. Clear it when all runners complete.
- [ ] **3.8** Update `finishRun()` to correctly clean up the specific runner that finished (remove from `activeRunners`), update only its associated message bubble, and leave other active runners untouched.
- [ ] **3.9** Update `isRunning` to be a computed property: `var isRunning: Bool { !activeRunners.isEmpty }`. This preserves any existing UI that checks `isRunning` (e.g., menu bar indicator) without breaking the concurrent model.

**Definition of Done:**
- User can send a message while a previous task is still running.
- Each active task has its own spinner/indicator on its message bubble.
- Each active task has its own cancel/stop control.
- Cancelling one task does not affect others.
- The menu bar icon reflects when any background work is active.
- The `[SAY]` filter works correctly for each concurrent stream without cross-contamination.
- `finishRun()` correctly routes completions to the right message bubble.

---

### Phase 4 — Proactive Toast Notifications & Unread Badge
**Goal:** Ensure the user never misses an update by showing toast notifications when the popover is closed, with an unread badge on the menu bar icon.
**Duration Estimate:** 2-3 days

**Tasks:**

- [ ] **4.1** Give `ChatViewModel` awareness of popover visibility. Options:
  - Inject a closure `() -> Bool` from `AppDelegate` that returns `popover.isShown`.
  - Or use `NotificationCenter` to broadcast popover open/close state changes from `AppDelegate`, with `ChatViewModel` tracking a `popoverIsVisible` property.
- [ ] **4.2** Add an auto-toast trigger: after new `[SAY]` content is appended to an assistant message (in `streamFilteredDelta` and `appendFilteredAssistantText`), check if the popover is closed. If so, fire a toast via `NotificationManager`.
  - Debounce: don't fire a toast on every streaming delta. Wait until a complete `[SAY]` line has been received (i.e., after a `\n` following user-facing content), or after a brief pause in streaming (~1 second).
- [ ] **4.3** Add `NotificationManager.showAutoToast(preview:)` method. Constructs a toast with:
  - **Title:** "MenuBot" (or task context if available).
  - **Message:** First ~120 characters of the assistant message content, truncated with "..." if longer.
  - For `[ASK_USER]` events: title "MenuBot needs your input".
- [ ] **4.4** Implement toast queuing: if multiple toasts arrive while the popover is closed, queue them and show sequentially with a brief gap (e.g., 1 second between dismissal and next toast). Or consolidate into a single toast with a count (e.g., "3 new messages").
- [ ] **4.5** Implement tap-to-open: when the user taps a toast, open the popover (call `AppDelegate`'s toggle method) and scroll to the relevant message. Dismiss the toast on tap.
- [ ] **4.6** Add unread message tracking to `ChatViewModel`: maintain an `unreadCount: Int` that increments when assistant content arrives while the popover is closed, and resets to 0 when the popover opens.
- [ ] **4.7** Add a badge to the `NSStatusItem` button: when `unreadCount > 0`, overlay a small dot (or count) on the menu bar icon. Clear it when `unreadCount` resets to 0. Use `NSStatusItem.button` layer or a custom drawn image.
- [ ] **4.8** Wire up popover-open event to clear the unread badge: when the popover opens (detected via `NSPopover` delegate or `NotificationCenter`), set `unreadCount = 0` and remove the badge.

**Definition of Done:**
- When the popover is closed and the orchestrator produces a new `[SAY]` message, a toast appears anchored to the menu bar icon.
- The toast shows a concise preview of the message content.
- Tapping the toast opens the popover.
- Multiple rapid updates queue or consolidate rather than overlapping.
- The menu bar icon shows an unread dot/badge when messages arrived while the popover was closed.
- The unread indicator clears when the popover is opened.
- When the popover is already open, no toast is shown.

---

## Phase Dependency Chain

```
Phase 1 (Persistent Session)
    |
    v
Phase 2 (Memory System)  -- depends on Phase 1 for session restart + skill loading
    |
    v
Phase 3 (Concurrent Chat + Per-Task UI)  -- depends on Phase 1 for persistent session stdin model
    |
    v
Phase 4 (Toasts & Badge)  -- depends on Phase 3 for per-task message routing
```

All phases are sequential. Phase 2 builds on Phase 1's session restart logic. Phase 3 adapts the persistent session from Phase 1 for concurrent use. Phase 4 hooks into the message routing from Phase 3.

## Risk Areas

| Risk | Mitigation |
|------|------------|
| Claude Code's interactive/stdin mode may not work as expected or may have undocumented behavior | Spike task 1.2 early. If stdin piping isn't viable, fall back to `--resume SESSION_ID` with a new process per message (preserves context via session resumption). |
| `[SAY]` filter state becomes complex with multiple concurrent runners (Phase 3) | Encapsulate filter state in a per-runner struct (task 3.3). Unit test the filter independently. |
| Persistent session context window fills up, causing degraded responses before auto-restart | Memory system (Phase 2) provides the safety net. Orchestrator skill instructions should proactively dump to memory before context is exhausted. |
| Session restart during active doer check-in loops could lose track of running doers | On restart, scan the doer-logs directory for recent logs and check PIDs to rediscover active doers. Add this to the orchestrator skill's restart instructions. |
| Toast notification spam if the orchestrator is chatty while popover is closed | Debounce toasts (task 4.2) — only fire on complete `[SAY]` lines, not every delta. Consolidate rapid-fire updates. |
| Menu bar badge/animation may conflict with macOS appearance modes or system styles | Use simple approaches (drawn dot overlay) rather than complex animations. Test in both light and dark mode. |

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Phase 1 complete | Orchestrator maintains conversation context across multiple user messages. Session restarts are invisible to the user. |
| Phase 2 complete | After restarting the app, the orchestrator remembers the user's name and recent tasks. "Forget everything" wipes all memory. |
| Phase 3 complete | User sends "find flights" then immediately sends "what's the weather" — both tasks run and complete independently with their own UI indicators. |
| Phase 4 complete | Close the popover, wait for a task to complete, see a toast appear. Tap it, popover opens. Menu bar shows unread dot that clears on open. |
| All phases complete | Full end-to-end: persistent session with memory, concurrent tasks with individual progress/cancel, proactive notifications when not looking. The user never waits, never loses context, never misses an update. |

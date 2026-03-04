# Objective 2: Event Protocol & Notifications — Phased Implementation Plan

## Reference Documents
- `docs/mvp/objectives/Objective_2.md`

## Scope Summary
- Claude Code emits `[MENUBOT_EVENT] {json}` lines in stdout that Menu-Bot parses into structured UI
- Three event types: `toast` (short-lived tooltip), `result` (summary + artifacts + action buttons), `error` (message + recovery guidance)
- Toasts are anchored near the menu bar icon as drop-down bubbles
- Action buttons on toasts/results can open files, folders, or URLs
- Non-event text in stdout must be ignored safely
- **End state:** Claude Code emits structured events and Menu-Bot renders them as toasts, result cards with action buttons, and error states — all anchored to the menu bar icon

## Existing Codebase
`EventParser.swift` already detects the `[MENUBOT_EVENT]` prefix and parses JSON payloads. `PopoverViewModel` routes output through EventParser. The primary work is defining the full event model (toast/result/error types with their payloads), enriching the parser, and building the notification UI layer.

## Phasing Options

### Option A — Protocol First, Then UI Layers (Selected)
Start by building the event parsing pipeline end-to-end with a minimal visual indicator, then layer on the full toast/tooltip UI, and finally add result/error display with action buttons. This validates parsing logic early with real Claude Code output before investing in UI polish.

### Option B — Vertical Slices by Event Type
Implement one event type fully (parse → render → actions) per phase: toast, then result, then error.

### Option C — Two-Phase: Parse Everything, Then Render Everything
Phase 1 builds the complete EventParser and event model for all three types wired to log output. Phase 2 builds all UI in one go.

---

## Detailed Phase Plan

### Phase 1 — Event Model & Minimal Toast

**Goal:** Expand the event protocol to support all three event types with typed Swift models, and display a basic toast notification anchored to the menu bar icon when a `toast` event is received.

**Duration Estimate:** 1–2 days

**Tasks:**
- [ ] **1.1** Define `MenuBotEvent` enum with associated payloads for `toast`, `result`, and `error` types
- [ ] **1.2** Define payload structs: `ToastPayload` (title, message, optional action), `ResultPayload` (summary, artifacts list), `ErrorPayload` (message, guidance)
- [ ] **1.3** Update `EventParser` to decode the JSON payload into the typed `MenuBotEvent` model
- [ ] **1.4** Add a `NotificationManager` (or similar) that receives parsed events and is responsible for presenting UI
- [ ] **1.5** Implement a minimal toast view — a small transient popover or panel anchored near the status item that shows title + message and auto-dismisses after a few seconds
- [ ] **1.6** Wire `PopoverViewModel` → `EventParser` → `NotificationManager` → toast view for the `toast` event type
- [ ] **1.7** Verify that non-event stdout lines are still displayed normally and do not trigger notifications

**Definition of Done:**
- A `[MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"World"}` line in stdout causes a tooltip-style bubble to appear near the menu bar icon and auto-dismiss
- Non-event output continues to render in the popover as before
- `result` and `error` events are parsed into typed models (logged but not yet rendered in UI)

---

### Phase 2 — Rich Toast UI with Actions

**Goal:** Upgrade the toast to support action buttons (e.g. "Open", "Copy") and polish the visual design so it feels like a native macOS notification anchored to the menu bar.

**Duration Estimate:** 1–2 days

**Tasks:**
- [ ] **2.1** Extend the toast view to render an optional action button from `ToastPayload.action`
- [ ] **2.2** Implement action handling: open a file path in Finder, open a URL in the default browser, or copy text to the clipboard
- [ ] **2.3** Add entry/exit animations (fade or slide from the menu bar) for the toast
- [ ] **2.4** Support stacking or queuing if multiple toasts arrive in quick succession
- [ ] **2.5** Allow clicking the toast body to dismiss it (in addition to auto-dismiss timer)

**Definition of Done:**
- A toast event with an action button renders the button; clicking it performs the action (opens file/URL or copies)
- Multiple rapid toast events queue and display sequentially without overlapping
- Toast appearance and dismissal are animated

---

### Phase 3 — Result & Error Display States

**Goal:** Implement the `result` and `error` event UI so that result summaries with artifact links/action buttons and error states with recovery guidance are rendered in the popover or as anchored panels.

**Duration Estimate:** 1–2 days

**Tasks:**
- [ ] **3.1** Design and implement a result card view: summary text, list of artifacts (file paths / URLs), and an action button per artifact (e.g. "Open", "Copy Path")
- [ ] **3.2** Wire `result` events from `NotificationManager` to render the result card (either in the popover or as a persistent panel)
- [ ] **3.3** Design and implement an error state view: error message, guidance text, and a visual error indicator
- [ ] **3.4** Wire `error` events from `NotificationManager` to render the error state
- [ ] **3.5** Ensure result and error displays can be dismissed and don't block further toast events

**Definition of Done:**
- A `result` event displays a summary with clickable artifact links and action buttons
- An `error` event displays the error message with recovery guidance
- All three event types (toast, result, error) work together without conflicts
- The acceptance criteria from Objective 2 is met: Claude Code can emit a `[MENUBOT_EVENT]` line and Menu-Bot displays a tooltip/toast anchored to the menu bar icon

---

## Phase Dependency Chain
- **Phase 1** → Phase 2 → Phase 3
- Phase 2 depends on Phase 1 (toast view must exist before enriching it with actions)
- Phase 3 depends on Phase 1 (event model and NotificationManager must exist) but could theoretically be parallelized with Phase 2 since result/error views are separate from toast UI

## Risk Areas

| Risk | Mitigation |
|------|------------|
| macOS doesn't have a native "toast anchored to status item" API — custom window positioning is needed | Use an NSPanel or secondary NSPopover positioned relative to the status item's button frame |
| Multiple toasts arriving rapidly could cause visual chaos | Implement a serial queue with configurable display duration in Phase 2 |
| Action handling (open file/URL) may require entitlement changes or sandbox exceptions | Sandbox is already disabled per project config; validate file/URL opening works in Phase 2 |
| The existing NSPopover for command output may conflict with toast/result panels | Use a separate NSWindow/NSPanel for notifications, independent of the main popover |

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Event parsing complete | All three event types decode from `[MENUBOT_EVENT]` JSON into typed Swift models |
| Basic toast working | A toast event produces a visible, auto-dismissing bubble near the menu bar icon |
| Actions functional | Toast action buttons successfully open files, URLs, or copy to clipboard |
| Full event UI | Result cards and error states render correctly with all payload fields |
| End-to-end verified | A real Claude Code session emitting events produces the expected notifications in Menu-Bot |

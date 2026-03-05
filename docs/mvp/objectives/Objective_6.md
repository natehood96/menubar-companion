# Objective 6: Eyes and Hands

## Overview

Give Menu-Bot the ability to see the user's screen and control their mouse and keyboard. This is the most self-contained and highest-risk objective — it depends on nothing from Objectives 4 or 5, and nothing depends on it. It introduces two new macOS permissions (Screen Recording, Accessibility), two new native capabilities (screenshot capture, input control), a new CLI tool (`menubot-input`), and a new skill (`computer-control`) that combines vision and action into an autonomous loop. Because this feature lets an AI control the user's computer, it requires the strongest safety guardrails of any objective: confirmation prompts, an emergency stop shortcut, visual indicators, and hard scope limits.

---

## Objectives

### 6.1 Screenshot Capture

#### Problem

Users want to ask Menu-Bot about what's currently on their screen ("What's this error?", "Can you read this table?", "What app is this?"). Menu-Bot needs native screen capture capabilities.

#### Requirements

##### 6.1.1 Screenshot Capture (Primary Method)

- Menu-Bot must be able to capture the screen using macOS native APIs:
  - **Full screen** capture via `CGWindowListCreateImage` or `ScreenCaptureKit` (macOS 13+)
  - **Active window** capture by identifying the frontmost window and capturing just that region
  - **User-selected region** (stretch goal for v2 — not required for initial implementation)
- Screenshots should be captured as PNG, stored temporarily in a transient cache directory:
  `~/Library/Application Support/MenuBot/cache/screenshots/`
- Cache should be cleaned on app quit or after 1 hour, whichever comes first.

##### 6.1.2 Performance

- Screenshot capture must complete in under 500ms.
- The screenshot file should be compressed (JPEG at 80% quality is acceptable for analysis) to keep prompt sizes reasonable.

#### Acceptance Criteria

- [ ] Menu-Bot can capture a screenshot of the active window on demand
- [ ] Menu-Bot can capture a full-screen screenshot
- [ ] Screenshots are cached transiently and cleaned up automatically

---

### 6.2 macOS Permissions Flow

#### Requirements

##### 6.2.1 Screen Recording Permission

- Screen capture requires the **Screen Recording** permission (`CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`).
- On first use, MenuBot must:
  1. Check if permission is granted
  2. If not, show a friendly in-app explanation: "To see your screen, I need Screen Recording permission. macOS will ask you to grant it — this lets me take screenshots when you ask me to look at something."
  3. Trigger the system permission prompt
  4. Handle the case where the user denies (graceful fallback message, don't nag)
- Permission status should be cached and re-checked only when a screen-related action is requested.

##### 6.2.2 Accessibility Permission

- Accessibility API requires the **Accessibility** permission (System Settings > Privacy & Security > Accessibility).
- Same permission flow as Screen Recording: check, explain, request, handle denial gracefully.
- This permission is shared between screen metadata gathering (6.3) and input control (6.5). A single grant covers both.

#### Acceptance Criteria

- [ ] Screen Recording permission is requested with a user-friendly explanation
- [ ] Accessibility permission is requested with a user-friendly explanation
- [ ] Denial is handled gracefully without nagging

---

### 6.3 Accessibility Metadata

#### Requirements

- In addition to screenshots, Menu-Bot should gather structured metadata about what's on screen via the **Accessibility API** (`AXUIElement`):
  - Active application name and bundle identifier
  - Frontmost window title
  - Focused UI element (text field contents, selected text, button labels)
  - Window hierarchy (list of visible windows with titles and app names)
- This provides machine-readable context that complements the visual screenshot. For example:
  - Screenshot shows a webpage — Accessibility API tells us it's Safari showing "GitHub - anthropics/claude-code"
  - Screenshot shows an error dialog — Accessibility API gives us the exact error text without OCR
- Accessibility API queries should timeout after 2 seconds to avoid hanging on unresponsive apps.

#### Acceptance Criteria

- [ ] Accessibility metadata (app name, window title, focused element) is gathered alongside screenshots

---

### 6.4 Context Assembly & UI Toggle

#### Requirements

##### 6.4.1 Context Assembly

- When the user asks about their screen (detected via intent or explicit phrases like "look at my screen", "what's this", "what am I looking at"), Menu-Bot should:
  1. Capture a screenshot of the active window (default) or full screen
  2. Gather accessibility metadata (window title, focused element, selected text)
  3. Bundle both into the prompt sent to Claude Code
- The screenshot should be passed to Claude Code as a file path reference. The orchestrator should instruct the doer to read the image file.
- Accessibility metadata should be included as structured text in the prompt.

##### 6.4.2 Context Toggle in UI

- The chat input area should have a small, unobtrusive toggle or attachment button for screen context:
  - An "eye" icon or similar that, when active, means "include my screen with this message"
  - Can be toggled on per-message or set as a default in preferences
- When screen context is attached, show a subtle indicator on the message bubble (e.g., a small screen icon).

#### Acceptance Criteria

- [ ] Screenshots and metadata are bundled into the Claude Code prompt
- [ ] The orchestrator/doer can analyze the screenshot and answer questions about what's on screen
- [ ] A toggle in the chat UI lets the user attach screen context to a message

---

### 6.5 Input Control CLI Tool

#### Problem

Users want Menu-Bot to perform actions on their computer — click buttons, fill forms, navigate UIs, type text. This requires programmatic control of the mouse and keyboard.

#### Requirements

##### 6.5.1 Input Control via Accessibility API

- Menu-Bot must be able to programmatically control the mouse and keyboard using macOS native APIs:
  - **Mouse control:** `CGEvent` for mouse move, click (left/right), double-click, drag, and scroll
  - **Keyboard control:** `CGEvent` for key press, key release, and modifier keys (Cmd, Shift, Option, Control)
  - **Text input:** Direct text insertion via `CGEvent` key sequences or Accessibility API `AXUIElementSetAttributeValue` for focused text fields
- All input control requires the **Accessibility** permission (same as 6.2.2 — shared permission).

##### 6.5.2 Action Primitives

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

#### Acceptance Criteria

- [ ] `menubot-input` CLI tool is bundled and can perform mouse clicks, moves, drags, typing, and key combos
- [ ] Doers can invoke `menubot-input` from their Bash tool

---

### 6.6 Vision-Action Loop & Computer Control Skill

#### Requirements

##### 6.6.1 Screen-Action Loop

- The most powerful use case combines screen vision and input control into a vision-action loop:
  1. Capture screenshot + accessibility metadata
  2. Analyze what's on screen (identify UI elements, buttons, text fields)
  3. Determine the next action (click this button, type in this field)
  4. Execute the action
  5. Wait briefly (200-500ms) for the UI to update
  6. Repeat from step 1 until the task is complete

##### 6.6.2 Computer Control Skill

- A dedicated skill should be created for this pattern:
  - **ID:** `computer-control`
  - **File:** `computer-control.md`
  - The skill instructs the doer to use the screenshot + `menubot-input` tool in a loop, with guardrails (max iterations, confirmation prompts for destructive actions).

##### 6.6.3 Common Use Case Patterns

The `computer-control` skill should include guidance for common patterns:

- **Fill out a form:** Screenshot -> identify fields -> click each field -> type values -> click submit
- **Navigate a UI:** Screenshot -> find target button/link -> click -> wait for navigation -> verify
- **Copy content:** Screenshot -> identify text -> select (click + drag or Cmd+A) -> Cmd+C -> read clipboard
- **App switching:** Use Cmd+Tab or `open -a "AppName"` for reliable app switching rather than clicking the dock

#### Acceptance Criteria

- [ ] A vision-action loop (screenshot -> analyze -> act -> repeat) works end-to-end
- [ ] `computer-control` skill is available in the skills index

---

### 6.7 Safety & Transparency System

#### Requirements

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

#### Acceptance Criteria

- [ ] User is prompted for confirmation before input control actions begin
- [ ] A global emergency stop shortcut halts all input control immediately
- [ ] A visual indicator shows when automation is actively controlling the screen
- [ ] Accessibility permission is requested with a clear, friendly explanation
- [ ] Safety limits are enforced (max actions per sequence, blocked targets)

---

## Scope Boundary

This objective does NOT include:

- Persistent orchestrator session, memory system, or session lifecycle (Objective 4)
- Non-blocking concurrent chat or multiple CommandRunner instances (Objective 4)
- Proactive toast notifications or menu bar unread badges (Objective 4)
- Credential storage, Keychain integration, or the `menubot-creds` CLI (Objective 5)
- Background jobs, job scheduling, LaunchAgents, or the Jobs UI (Objective 5)
- Login item registration, startup sequence ordering, or skill bootstrapping (Objective 7)
- User-selected screen region capture (future enhancement)
- Multi-monitor support (future enhancement)

---

## Dependencies

- **Depends on:** Objectives 1–3 (existing Phase 1-3 foundations: menu bar app, chat UI, skills system, orchestrator/doer architecture, event protocol)
- **Feeds into:** Objective 7 (startup sequence includes registering the global emergency stop shortcut; `OrchestrationBootstrap` must seed `computer-control.md` skill; `menubot-input` CLI must be built as an Xcode target; permissions flow should be consolidated across features)

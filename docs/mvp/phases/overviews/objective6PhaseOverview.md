# Objective 6: Eyes and Hands — Phased Implementation Plan

> **Objective:** [Objective 6](../../objectives/Objective_6.md)
> **Depends on:** Objectives 1-3 (menu bar app, event protocol, skills system, orchestrator/doer architecture)
> **Feeds into:** Objective 7 (startup sequence, skill seeding, CLI build target, permissions consolidation)

---

## Reference Documents
- `docs/mvp/objectives/Objective_6.md` — Full objective specification (sections 6.1-6.7)

## Scope Summary

- Native macOS screen capture (full screen + active window) with transient caching
- macOS permission flows for Screen Recording and Accessibility
- Accessibility API metadata gathering (app name, window title, focused element)
- Context assembly: bundle screenshots + metadata into Claude Code prompts
- UI toggle ("eye" icon) to attach screen context to chat messages
- `menubot-input` Swift CLI tool with mouse, keyboard, and scroll primitives
- Vision-action loop combining screenshot analysis with input control
- `computer-control` skill for autonomous screen interaction
- Safety system: confirmation prompts, emergency stop shortcut, visual indicator, scope limits

**End state:** Users can ask Menu-Bot about what's on their screen and have it autonomously interact with macOS applications — clicking, typing, navigating — with strong safety guardrails including confirmation prompts, an emergency stop shortcut, and visual indicators of active automation.

---

## Phasing Strategy: Capability-First (Vision -> Control -> Loop)

Each native capability is built as a complete vertical slice, then combined into the autonomous loop, with safety as the final hardening pass.

---

## Detailed Phase Plan

### Phase 6A — Screenshot Capture & Permissions

**Goal:** Menu-Bot can capture screenshots of the active window or full screen, with proper macOS permission handling and transient caching.

**Tasks:**

- [ ] **6A.1** Implement Screen Recording permission flow:
  - Check permission via `CGPreflightScreenCaptureAccess()`
  - Show in-app explanation dialog before triggering `CGRequestScreenCaptureAccess()`
  - Cache permission status; re-check only when a screen action is requested
  - Handle denial gracefully (informative message, no repeated nagging)
- [ ] **6A.2** Implement screenshot capture using `CGWindowListCreateImage`:
  - Full-screen capture mode
  - Active-window capture mode (identify frontmost window via `NSWorkspace.shared.frontmostApplication` + `CGWindowListCopyWindowInfo`, capture that region)
- [ ] **6A.3** Implement screenshot caching:
  - Store as JPEG (80% quality) in `~/Library/Application Support/MenuBot/cache/screenshots/`
  - Create cache directory on first use
  - Clean cache on app quit (via `applicationWillTerminate`)
  - Clean screenshots older than 1 hour via a periodic timer
- [ ] **6A.4** Verify capture completes in under 500ms (performance requirement)
- [ ] **6A.5** Create a `ScreenCaptureManager` (or similar) class that exposes:
  - `captureFullScreen() async throws -> URL` (returns path to cached screenshot)
  - `captureActiveWindow() async throws -> URL`
  - `checkPermission() -> PermissionStatus`
  - `requestPermission()`

**Key Decisions:**
- Use `CGWindowListCreateImage` over ScreenCaptureKit for broader macOS version support (macOS 13+). ScreenCaptureKit can be a future enhancement.
- JPEG at 80% quality balances file size with readability for Claude's vision capabilities.

**Definition of Done:**
- Running a test action in the app captures a screenshot of the active window and saves it to the cache directory
- The permission prompt appears on first use with a friendly explanation
- Denying permission shows a graceful fallback message
- Cache directory is cleaned on app quit

---

### Phase 6B — Accessibility Metadata & Context Assembly

**Goal:** Menu-Bot gathers structured metadata about the screen via the Accessibility API and bundles it with screenshots into Claude Code prompts. A UI toggle lets users attach screen context to messages.

**Tasks:**

- [ ] **6B.1** Implement Accessibility permission flow:
  - Check permission via `AXIsProcessTrusted()`
  - Show in-app explanation before directing user to System Settings > Privacy & Security > Accessibility
  - Handle denial gracefully
- [ ] **6B.2** Implement Accessibility metadata gathering via `AXUIElement`:
  - Active application name and bundle identifier (via `NSWorkspace`)
  - Frontmost window title (via `AXUIElementCopyAttributeValue` on the frontmost app's window)
  - Focused UI element: text field contents, selected text, button labels
  - Window hierarchy: list of visible windows with titles and app names
  - Timeout after 2 seconds to avoid hanging on unresponsive apps
- [ ] **6B.3** Create an `AccessibilityManager` (or similar) class that exposes:
  - `gatherMetadata() async throws -> ScreenMetadata` (struct with app name, window title, focused element, etc.)
  - `checkPermission() -> PermissionStatus`
- [ ] **6B.4** Implement context assembly in the orchestrator:
  - When user intent matches screen queries ("look at my screen", "what's this", "what am I looking at"), trigger capture
  - Call `ScreenCaptureManager.captureActiveWindow()` + `AccessibilityManager.gatherMetadata()`
  - Pass screenshot file path and structured metadata text into the Claude Code prompt for the doer
- [ ] **6B.5** Add screen context toggle to chat UI:
  - "Eye" icon button in the chat input area
  - When active, the current message will include screen context
  - Show a subtle screen icon indicator on message bubbles that included screen context
  - Optional: preference to set as default (can defer)

**Key Decisions:**
- Accessibility permission is shared between metadata (this phase) and input control (6C). A single grant covers both.
- Screenshot is passed as a file path reference in the prompt; the doer reads the image file via its tools.

**Definition of Done:**
- Sending a message with the eye toggle active captures a screenshot + metadata and includes both in the doer prompt
- The doer can answer questions about what's on screen (e.g., "What app is this?", "What does this error say?")
- Accessibility metadata includes at minimum: app name, window title, focused element text
- AX queries timeout after 2 seconds without crashing

---

### Phase 6C — Input Control CLI (`menubot-input`)

**Goal:** A Swift CLI tool bundled with MenuBot that provides mouse, keyboard, and scroll primitives callable from the doer's Bash tool.

**Tasks:**

- [ ] **6C.1** Create a new Swift CLI target `menubot-input` in the Xcode project
- [ ] **6C.2** Implement mouse control primitives via `CGEvent`:
  - `mouse_move --x <int> --y <int>` — move cursor to screen coordinates
  - `mouse_click --x <int> --y <int> --button <left|right> --count <1|2>` — click at coordinates
  - `mouse_drag --x1 <int> --y1 <int> --x2 <int> --y2 <int>` — drag from point to point
- [ ] **6C.3** Implement keyboard control primitives via `CGEvent`:
  - `key_type --text <string>` — type a string of text character by character
  - `key_press --key <key_name> --modifiers <comma-separated>` — press a key combo (e.g., `--key c --modifiers cmd`)
- [ ] **6C.4** Implement scroll primitive:
  - `scroll --x <int> --y <int> --dx <int> --dy <int>` — scroll at coordinates
- [ ] **6C.5** Implement argument parsing with clear error messages and `--help` output
- [ ] **6C.6** Install the built CLI to `~/Library/Application Support/MenuBot/bin/menubot-input`:
  - Copy binary on app launch if missing or outdated (compare build version)
  - Ensure the binary is executable
- [ ] **6C.7** Verify the doer can invoke `menubot-input` commands from its Bash tool

**Key Decisions:**
- Separate CLI target rather than embedding in the main app. This lets doers call it via shell without Swift interop.
- `CGEvent` for both mouse and keyboard — it's the standard low-level macOS input API.
- Key names follow macOS virtual key code conventions, with human-readable aliases for common keys (return, tab, escape, space, delete, arrow keys, etc.).

**Definition of Done:**
- `menubot-input mouse_click --x 500 --y 300 --button left` moves the cursor and clicks at (500, 300)
- `menubot-input key_type --text "hello world"` types the text into the currently focused field
- `menubot-input key_press --key c --modifiers cmd` performs Cmd+C
- The CLI is automatically installed to the MenuBot bin directory on app launch
- A doer session can invoke `menubot-input` commands successfully

---

### Phase 6D — Vision-Action Loop & Computer Control Skill

**Goal:** Combine screen vision (6A/6B) and input control (6C) into an autonomous loop, packaged as the `computer-control` skill.

**Tasks:**

- [ ] **6D.1** Create the `computer-control` skill file (`computer-control/skill.json` + `computer-control/prompt.md`):
  - Instructs the doer to use screenshots + `menubot-input` in a loop
  - Documents the vision-action cycle: capture -> analyze -> act -> wait -> repeat
  - Includes the `menubot-input` CLI path and usage reference
- [ ] **6D.2** Include guidance for common patterns in the skill prompt:
  - **Fill out a form:** screenshot -> identify fields -> click -> type -> submit
  - **Navigate a UI:** screenshot -> find target -> click -> wait -> verify
  - **Copy content:** screenshot -> identify text -> select -> Cmd+C -> read clipboard
  - **App switching:** use `open -a "AppName"` or Cmd+Tab
- [ ] **6D.3** Include loop control in the skill prompt:
  - Wait 200-500ms between action and next screenshot (UI update time)
  - Maximum iteration guidance (doer should stop and report after reasonable attempts)
  - Error recovery: if an action doesn't produce expected results, re-assess before retrying
- [ ] **6D.4** Register `computer-control` skill in the skills index (seed on first launch via `SkillsDirectoryManager`)
- [ ] **6D.5** End-to-end test: user asks Menu-Bot to perform a multi-step UI task (e.g., "open TextEdit and type 'hello'"), and the doer executes the full loop

**Key Decisions:**
- The skill is a prompt-based pattern, not new Swift code. The doer already has access to Bash (for `menubot-input`) and screenshot capture. The skill just teaches it the loop pattern.
- Wait times between actions are guidance in the prompt, not enforced in code.

**Definition of Done:**
- The `computer-control` skill appears in the skills browser
- A doer can execute a multi-step task: screenshot -> identify target -> click -> screenshot again -> verify
- The loop completes autonomously for simple tasks (e.g., open an app, click a button, type text)

---

### Phase 6E — Safety & Transparency System

**Goal:** Harden the computer control feature with confirmation prompts, emergency stop, visual indicators, and scope limits.

**Tasks:**

- [ ] **6E.1** Implement confirmation flow in the orchestrator:
  - Before the first input control action in a sequence, the orchestrator asks: "I'm going to [description]. Should I go ahead?"
  - User can approve the full sequence or request step-by-step approval
  - Skills/jobs can be marked `auto_approve_input_control: true` only via explicit user action in the UI (never by the AI)
- [ ] **6E.2** Implement emergency stop global shortcut:
  - Register a global keyboard shortcut (e.g., Cmd+Shift+Escape) via `NSEvent.addGlobalMonitorForEvents`
  - When triggered, immediately kill any running doer process that has input control active
  - Show a toast/notification confirming automation was stopped
- [ ] **6E.3** Implement visual indicator for active automation:
  - Show a persistent, unmistakable indicator when MenuBot is controlling mouse/keyboard
  - Options: red dot badge on the menu bar icon, a small floating overlay, or both
  - Indicator appears when input control starts, disappears when it ends or is stopped
- [ ] **6E.4** Implement scope limits:
  - No input control actions while the screen is locked (check via `CGSessionCopyCurrentDictionary`)
  - No input control actions targeting System Settings / Security & Privacy (check frontmost app bundle ID before each action)
  - Maximum 100 actions per sequence before requiring re-confirmation
  - Action counter resets on user re-confirmation
- [ ] **6E.5** Ensure doer describes each action in its output stream before executing it (enforced via skill prompt instructions + orchestrator validation)
- [ ] **6E.6** Update `menubot-input` CLI to support safety checks:
  - Accept a `--action-count` flag or read from a state file to enforce the 100-action limit
  - Check for blocked targets before executing (or have the orchestrator enforce this)

**Key Decisions:**
- Emergency stop kills the doer process entirely rather than trying to send a graceful signal. This is the safest approach — a runaway process should be terminated, not asked politely to stop.
- Scope limits are checked at the orchestrator level (before dispatching to doer) AND at the CLI level (defense in depth).

**Definition of Done:**
- User is prompted for confirmation before any input control actions begin
- Pressing the emergency stop shortcut immediately halts automation and shows confirmation
- A red indicator is visible in the menu bar whenever automation is active
- Automation is blocked when targeting System Settings or when the screen is locked
- After 100 actions, the user is prompted to re-confirm before continuing

---

## File Map (Expected New/Modified Files)

| File | Phase | Description |
|---|---|---|
| `Core/ScreenCaptureManager.swift` | 6A | Screenshot capture and permission management |
| `Core/AccessibilityManager.swift` | 6B | AX metadata gathering and permission management |
| `Core/ScreenContext.swift` | 6B | Context assembly (screenshot + metadata bundling) |
| `UI/ChatInputView.swift` (or equivalent) | 6B | Eye toggle for screen context attachment |
| `UI/ChatBubbleView.swift` | 6B | Screen context indicator on message bubbles |
| `menubot-input/` (new CLI target) | 6C | Swift CLI for mouse/keyboard/scroll control |
| `menubot-input/main.swift` | 6C | CLI entry point and argument parsing |
| `menubot-input/MouseControl.swift` | 6C | CGEvent mouse primitives |
| `menubot-input/KeyboardControl.swift` | 6C | CGEvent keyboard primitives |
| `Resources/computer-control/skill.json` | 6D | Computer control skill metadata |
| `Resources/computer-control/prompt.md` | 6D | Computer control skill prompt with loop pattern |
| `Core/SafetyManager.swift` | 6E | Confirmation flow, action counting, scope checks |
| `Core/EmergencyStop.swift` | 6E | Global shortcut registration and process termination |
| `UI/AutomationIndicator.swift` | 6E | Red dot / overlay for active automation |
| `App/AppDelegate.swift` | 6A, 6E | Cache cleanup on quit, emergency stop registration |

---

## Phase Dependency Chain

```
6A (Screenshot + Permissions)
 |
 v
6B (Accessibility Metadata + Context Assembly + UI Toggle)
 |
 v
6C (Input Control CLI) --- does NOT depend on 6A/6B, but ordered here for narrative flow
 |
 v
6D (Vision-Action Loop + Skill) --- depends on 6A + 6B + 6C
 |
 v
6E (Safety System) --- depends on 6C + 6D
```

**Parallelization notes:**
- 6A and 6C are independent and could be built in parallel (vision and control are separate capabilities)
- 6B depends on 6A (needs screenshot capture to bundle context)
- 6D depends on 6A + 6B + 6C (combines all capabilities)
- 6E depends on 6C + 6D (hardens the input control and loop features)

---

## Acceptance Criteria Mapping

| Criterion (from Objective 6) | Phase |
|---|---|
| Menu-Bot can capture a screenshot of the active window on demand | 6A |
| Menu-Bot can capture a full-screen screenshot | 6A |
| Screenshots are cached transiently and cleaned up automatically | 6A |
| Screen Recording permission is requested with a user-friendly explanation | 6A |
| Accessibility permission is requested with a user-friendly explanation | 6A, 6B |
| Denial is handled gracefully without nagging | 6A, 6B |
| Accessibility metadata is gathered alongside screenshots | 6B |
| Screenshots and metadata are bundled into the Claude Code prompt | 6B |
| The orchestrator/doer can analyze the screenshot and answer questions | 6B |
| A toggle in the chat UI lets the user attach screen context to a message | 6B |
| `menubot-input` CLI tool can perform mouse clicks, moves, drags, typing, and key combos | 6C |
| Doers can invoke `menubot-input` from their Bash tool | 6C |
| A vision-action loop works end-to-end | 6D |
| `computer-control` skill is available in the skills index | 6D |
| User is prompted for confirmation before input control actions begin | 6E |
| A global emergency stop shortcut halts all input control immediately | 6E |
| A visual indicator shows when automation is actively controlling the screen | 6E |
| Safety limits are enforced (max actions per sequence, blocked targets) | 6E |

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| **Screen Recording permission is app-restart-required on some macOS versions** | Document this in the permission flow UI; detect the need for restart and guide the user |
| **CGEvent input control may not work with all apps (e.g., sandboxed apps, games)** | Document known limitations; fall back to Accessibility API `AXUIElementPerformAction` for standard UI elements |
| **Vision-action loop may get stuck in infinite loops** | Enforce max iterations in skill prompt; add a hard timeout at the orchestrator level |
| **Safety system ships after input control is functional (phases 6C/6D before 6E)** | During development of 6C/6D, add temporary manual-only invocation guards; treat safety phase as mandatory before any release |
| **`menubot-input` CLI needs Accessibility permission from the main app's grant** | Verify that child processes inherit the parent app's Accessibility permission; if not, the CLI may need to be embedded differently |
| **Screenshot quality may be insufficient for Claude's vision analysis** | Test with JPEG 80% quality early; adjust quality or switch to PNG if analysis accuracy suffers |
| **Emergency stop shortcut may conflict with other apps' shortcuts** | Use an uncommon combo (Cmd+Shift+Escape); allow user customization in preferences |

---

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Screen Vision | User asks "what's on my screen?" and gets an accurate answer based on screenshot + metadata |
| Input Control | Doer can click a specific button on screen by invoking `menubot-input` |
| Autonomous Loop | User says "open Safari and go to example.com" and Menu-Bot completes the task autonomously |
| Safety | Emergency stop halts automation within 500ms; confirmation is always required before first action |
| Production Ready | All acceptance criteria pass, safety guardrails are active, and the feature is usable without developer supervision |

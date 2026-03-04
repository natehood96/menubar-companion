# Objective 1: Run a Command from the Menu Bar — Phased Implementation Plan

## Reference Documents
- `docs/mvp/objectives/Objective_1.md`

## Scope Summary
- macOS menu bar app with a friendly blob icon (monochrome template image, 18x18pt @1x / 36x36pt @2x)
- LSUIElement (no dock icon, menu bar only)
- Clicking the icon opens a lightweight popover with a command input, placeholder Starred Skills section, and placeholder All Skills button
- Free-form commands are executed via the Claude Code CLI with streaming output
- UI displays running, partial output, and completion states
- **End state:** User clicks the blob icon, types a command, sees streaming Claude Code output, and gets a clear completion state

## Existing Codebase
The app shell already exists: `MenuBarCompanionApp.swift`, `AppDelegate.swift` (NSStatusBar + NSPopover), `PopoverView.swift` (input + output UI), `PopoverViewModel.swift` (orchestrator, currently runs `/bin/sh -c` stub), `CommandRunner.swift` (Process wrapper with streaming callbacks), `EventParser.swift` (basic `[MENUBOT_EVENT]` parsing). The primary work is replacing the placeholder terminal icon with the real blob asset, refining the popover layout to match the spec, and swapping the shell stub for real Claude CLI invocation.

## Phasing Options

### Option A — Icon First, Then Wire It Up (Selected)
Start by replacing the placeholder terminal icon with the real blob character asset and locking down the menu bar presence, then move to the popover UI refinements, and finally wire up real Claude Code CLI execution with streaming output.

### Option B — End-to-End Thin Slice
Get Claude CLI execution working first, then refine the popover, then polish the icon.

### Option C — Two Big Phases
One phase for all visual work (icon + popover), one phase for all functional work (CLI execution).

---

## Detailed Phase Plan

### Phase 1 — Menu Bar Icon & App Shell Polish

**Goal:** Replace the placeholder terminal icon with the real blob character asset and confirm the app shell meets all Objective 1.1 requirements.

**Tasks:**
- [ ] **1.1** Design or source a friendly smiling blob character icon — approachable, companion-like, conveys "your pal that's always there for you"
- [ ] **1.2** Render the icon as a monochrome template image (so macOS auto-adapts to light/dark mode) at 18x18pt @1x and 36x36pt @2x
- [ ] **1.3** Add the icon assets to `Assets.xcassets` as a template image set
- [ ] **1.4** Update `AppDelegate.swift` to load the new blob icon via `statusBarItem.button?.image` instead of the current system terminal icon
- [ ] **1.5** Verify LSUIElement behavior — app shows no dock icon, only the menu bar icon
- [ ] **1.6** Verify the icon renders correctly in both light and dark mode

**Definition of Done:**
- App launches and shows a friendly blob icon in the menu bar (not the terminal icon)
- Icon adapts correctly to light and dark mode
- No dock icon appears
- Clicking the icon still opens the existing popover

---

### Phase 2 — Popover UI with Command Input

**Goal:** Refine the popover layout to match the Objective 1.2 spec — a clean command input with placeholder sections for future skills UI.

**Tasks:**
- [ ] **2.1** Ensure the command input field uses "Ask or command..." as placeholder text
- [ ] **2.2** Add a **Starred Skills** placeholder section below the input (empty state, e.g., "No starred skills yet" or a subtle placeholder — wired up in Objective 3)
- [ ] **2.3** Add an **All Skills** button/tab at the bottom of the popover (non-functional placeholder — wired up in Objective 3)
- [ ] **2.4** Review and clean up the popover layout — ensure the input, output area, starred skills section, and All Skills button are visually cohesive
- [ ] **2.5** Verify the popover opens and closes correctly on icon click, and the input field is focused on open

**Definition of Done:**
- Popover contains: command input ("Ask or command..."), Starred Skills placeholder section, All Skills button/tab
- Layout is clean and visually cohesive
- Input field receives focus when popover opens
- Placeholder sections are clearly non-functional but don't look broken

---

### Phase 3 — Claude Code CLI Execution & Streaming Output

**Goal:** Replace the `/bin/sh -c` stub in `PopoverViewModel` with real Claude Code CLI invocation and ensure streaming output, running state, and completion state all work correctly.

**Tasks:**
- [ ] **3.1** Determine the correct Claude Code CLI invocation — locate the `claude` binary, determine required arguments (e.g., `claude --output-format stream-json` or `claude -p "<prompt>"`)
- [ ] **3.2** Update `PopoverViewModel.swift` to build the correct `claude` CLI command instead of the current `/bin/sh -c` shell passthrough
- [ ] **3.3** Handle the case where Claude CLI is not installed — show a clear error message (the existing `claudeAvailable` check may need updating for the real binary path)
- [ ] **3.4** Ensure streaming output from Claude CLI is displayed line-by-line in the output area as it arrives (leveraging the existing `CommandRunner` streaming callbacks)
- [ ] **3.5** Display a clear "Running..." state while the command is in progress
- [ ] **3.6** Display a clear completion state when the command finishes (success or error)
- [ ] **3.7** Verify end-to-end: type a free-form command, see streaming output from Claude Code, see completion

**Definition of Done:**
- Typing a command and pressing Run invokes the real `claude` CLI (not `/bin/sh`)
- Streaming output appears in real time in the popover
- "Running..." state is visible while the command executes
- Completion state is clearly shown when done
- If Claude CLI is not installed, a helpful error message is displayed
- The existing Cancel button still terminates the running process

---

## Phase Dependency Chain

```
Phase 1 (Icon & Shell) ──→ Phase 2 (Popover UI) ──→ Phase 3 (CLI Execution)
```

- Phase 1 and Phase 2 are technically independent (no code dependencies between them) and could be parallelized
- Phase 3 depends on Phase 2 being complete (the popover layout should be finalized before wiring up execution)
- In practice, doing them sequentially is recommended since each phase is small

## Risk Areas

| Risk | Mitigation |
|------|------------|
| Claude CLI binary location varies across installs (homebrew, npm global, etc.) | Check common paths (`/usr/local/bin/claude`, `~/.npm/bin/claude`, etc.) and allow user override; surface clear error if not found |
| Claude CLI output format may differ from what CommandRunner expects | Test with real CLI output early in Phase 3; adjust parsing if needed |
| Blob icon design may not render well as a tiny monochrome template image | Test at actual menu bar size early; keep the design simple with clear silhouette |
| Streaming output from Claude CLI may use JSON streaming (not plain text lines) | Inspect actual CLI output format in Phase 3.1 before building the integration |

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Phase 1 complete | Blob icon visible in menu bar, adapts to light/dark mode, no dock icon |
| Phase 2 complete | Popover has command input, Starred Skills placeholder, All Skills button |
| Phase 3 complete | Free-form command runs via real Claude CLI with streaming output and completion state |
| Objective 1 complete | All three acceptance criteria from Objective_1.md pass: blob icon visible, popover works with free-form commands, Claude CLI executes successfully |

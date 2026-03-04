# Phase 5: Safety, Persistence & Polish — Implementation Overview

> **Objective:** [Objective 5](../objectives/Objective_5.md)
> **Depends on:** Phase 1 (CLI execution), Phase 2 (event protocol), Phase 3 (skills system), Phase 4 (context, defaults, scheduling)
> **Feeds into:** None (final objective)

---

## Reference Documents
- [Objective 5 — Safety, Persistence & Polish](../objectives/Objective_5.md)
- [Objective 3 — Skills Library & Management](../objectives/Objective_3.md) (starred skills, ordering context)
- [Objective 4 — Context, Defaults & Scheduling](../objectives/Objective_4.md) (scheduling settings context)

---

## Scope Summary

- Confirmation flows for skills that trigger external side effects, with opt-out for skills marked "safe to auto-run"
- Stop/Cancel button for in-progress skill execution
- Activity log showing recent skill runs
- Icon customization: user picks from preset menu bar icons, persisted and applied at runtime
- Full persistence layer covering: starred skills, skill ordering/groups, scheduling settings, recent run history, and selected icon preference
- Storage via UserDefaults and/or local JSON files — no CoreData/SQLite unless proven necessary

**End state:** The app is safe (users confirm before destructive actions), observable (activity log shows what happened), customizable (icon presets), and resilient (all user state persists across launches).

---

## Phasing Strategy: Vertical Slices

Each phase delivers a complete, user-visible feature. Persistence ships alongside the first feature that requires it (activity log), so every phase has immediate visible value.

---

## Detailed Phase Plan

### Phase 5A — Safety & Control

**Goal:** Prevent accidental destructive actions and give users control over running skills.

**Tasks:**

- [ ] **5A.1** Add a `safe` / `requires_confirmation` field to the skill metadata spec (e.g., `"safe_to_auto_run": true|false`, defaulting to `false`)
- [ ] **5A.2** Build a `ConfirmationView` SwiftUI sheet/overlay that displays:
  - Skill name
  - Human-readable description of what the skill is about to do
  - "Cancel" and "Confirm & Run" buttons
- [ ] **5A.3** Wire confirmation into the skill run flow in `PopoverViewModel`:
  - Before executing a skill, check `safe_to_auto_run`
  - If `false` (or absent), present `ConfirmationView` and wait for user response
  - If `true`, execute immediately
- [ ] **5A.4** Add a **Stop** button to the running-skill UI that:
  - Sends `SIGTERM` to the running `Process` via `CommandRunner`
  - Falls back to `SIGKILL` after a short timeout if the process hasn't exited
  - Updates the UI to show "Cancelled" state
- [ ] **5A.5** Add a `cancel()` or `stop()` method to `CommandRunner` that terminates the process cleanly
- [ ] **5A.6** Manual testing: run a skill marked unsafe → confirm dialog appears; run a skill marked safe → runs immediately; stop a running skill → process terminates and UI reflects cancellation

**Definition of Done:**
- Skills without `safe_to_auto_run: true` show a confirmation dialog before executing
- A visible Stop button appears while a skill is running and successfully terminates the process
- No regressions to existing skill run flow

---

### Phase 5B — Activity Log & Persistence Layer

**Goal:** Ship a recent-runs activity log and wire up the full persistence layer so all user state survives app restarts.

**Tasks:**

- [ ] **5B.1** Design and implement a `PersistenceManager` (or similar) that centralizes local storage:
  - Starred skills list → UserDefaults (simple array of skill IDs/names)
  - Skill ordering/groups → UserDefaults or JSON file
  - Scheduling settings → UserDefaults
  - Recent run history → JSON file in `~/Library/Application Support/MenuBot/`
  - Selected icon preference → UserDefaults
- [ ] **5B.2** Define a `RunRecord` model:
  - Skill name, timestamp, duration, outcome (success/failure/cancelled), optional short summary
- [ ] **5B.3** Build `ActivityLogView` — a SwiftUI list view showing recent runs:
  - Each row: skill name, relative timestamp ("2 min ago"), outcome badge (success/fail/cancelled)
  - Tapping a row shows a detail view with full run info
  - List sourced from `PersistenceManager`
- [ ] **5B.4** Hook into the skill execution lifecycle to write a `RunRecord` on every skill completion (success, failure, or cancellation from 5A)
- [ ] **5B.5** Add navigation to the activity log from the popover (e.g., a "Recent" tab or button)
- [ ] **5B.6** Retrofit existing features to use `PersistenceManager`:
  - Starred skills (from Objective 3 UI) now persist across launches
  - Skill ordering persists across launches
  - Scheduling settings (from Objective 4) persist across launches
- [ ] **5B.7** Add reasonable limits: cap history at ~100 records, prune on launch
- [ ] **5B.8** Manual testing: run several skills → activity log shows them; restart app → starred skills, ordering, schedule settings, and run history all survive; verify log prunes correctly

**Definition of Done:**
- Activity log view accessible from the popover, showing recent skill runs with outcome
- All user state (stars, ordering, schedules, history) persists across app restarts
- Storage is local, uses UserDefaults + JSON files, no external dependencies

---

### Phase 5C — Icon Customization

**Goal:** Let users personalize their menu bar icon from a set of presets.

**Tasks:**

- [ ] **5C.1** Create or source preset icon assets (SF Symbols or bundled PNGs, rendered as template images):
  - Robot (default)
  - Ghost
  - Cat
  - Star
  - Blob
  - At minimum 4-5 options
- [ ] **5C.2** Build an `IconPickerView` in a Settings/Preferences screen:
  - Grid or horizontal list of icon previews
  - Current selection highlighted
  - Tapping an icon selects it immediately (preview in the menu bar updates live)
- [ ] **5C.3** Wire icon selection to `PersistenceManager` (UserDefaults key for selected icon)
- [ ] **5C.4** On app launch, read the persisted icon preference and apply it to `statusBarItem.button?.image` in `AppDelegate`
- [ ] **5C.5** If no preference is saved (first launch), use the default icon
- [ ] **5C.6** Manual testing: open settings → pick a different icon → menu bar updates immediately; restart app → icon persists

**Definition of Done:**
- User can open a settings/preferences view and choose from at least 4 icon presets
- Selected icon appears in the menu bar immediately and persists across restarts
- Default icon is used when no preference has been set

---

## Phase Dependency Chain

```
Phase 5A (Safety & Control)
    ↓
Phase 5B (Activity Log & Persistence)  ← depends on 5A for cancelled-run records
    ↓
Phase 5C (Icon Customization)          ← depends on 5B for PersistenceManager
```

- **5A is fully independent** — no persistence or new data models needed
- **5B depends on 5A** only lightly (to record cancellation outcomes), but could technically start in parallel if cancellation records are stubbed
- **5C depends on 5B** for the `PersistenceManager` — this is a hard dependency
- **No phases can be fully parallelized** due to the dependency chain, but 5A and the data-modeling portion of 5B could overlap

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| `Process.terminate()` may not reliably kill all child processes (e.g., Claude Code spawns subprocesses) | Use process group kill (`killpg`) or `SIGKILL` fallback after timeout |
| UserDefaults can silently fail or lose data on crash | Keep UserDefaults for small atomic values; use JSON files with atomic writes (write-to-temp-then-rename) for history |
| Icon template images may render poorly in light/dark mode | Use SF Symbols where possible (auto-adapt); test both appearances for any bundled PNGs |
| Activity log could grow unbounded | Cap at ~100 records, prune oldest on launch |
| Confirmation flow may feel intrusive for power users | Default to requiring confirmation, but respect the `safe_to_auto_run` flag so skill authors can opt out |

---

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Safety shipped | Dangerous skills require explicit confirmation; safe skills bypass it; running skills can be stopped |
| Activity log working | Recent runs visible in the UI with outcome; history persists across restarts |
| Persistence complete | Stars, ordering, schedules, history, and icon pref all survive app restart |
| Icon customization live | User can pick from presets; selection persists and applies on launch |
| MVP-ready | All Objective 5 acceptance criteria pass; no regressions in Objectives 1-4 |

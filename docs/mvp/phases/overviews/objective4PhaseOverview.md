# Objective 4: Context, Defaults & Scheduling — Phased Implementation Plan

## Reference Documents
- `docs/mvp/objectives/Objective_4.md` (primary)
- `docs/mvp/MVP_BIZ_REQ.md` (overall requirements)
- `docs/mvp/objectives/Objective_1.md` (CLI execution dependency)
- `docs/mvp/objectives/Objective_2.md` (event protocol & toast dependency)
- `docs/mvp/objectives/Objective_3.md` (skills directory, format & run UI dependency)

## Scope Summary
- **Context Injection**: Default context (current time, active app name) always included on every run; optional toggles for screenshot capture, clipboard contents, and selected text; context appended in structured format to Claude Code CLI invocation
- **Preinstalled Skills**: First-run seeding of `~/Library/Application Support/MenuBot/skills/` with Morning Brief, Create New Skill, and Find File (plus optional Clean Downloads and Work Mode); skills use template variables referencing context
- **Scheduling**: Skill metadata field for recommended schedule; UI to schedule at least Morning Brief daily at a user-chosen time; execution via internal timer or macOS LaunchAgent; report-back via toast/notification when scheduled run completes
- **End state**: A new user installs Menu-Bot and immediately has working skills, automatic daily briefings, and rich context attached to every run

## Phasing Strategy: Two Phases — Foundation & Automation

Context injection and preinstalled skills are built together because skill templates directly reference context variables (`{context.active_app}`, `{context.clipboard}`, etc.). Scheduling is a fundamentally different system (timers, background execution, notification delivery without the popover) and is cleanly separable.

---

## Detailed Phase Plan

### Phase 1 — Context Injection & Preinstalled Skills
**Goal:** Every skill run attaches structured context, and the app ships with a set of useful preinstalled skills seeded on first launch.
**Duration Estimate:** 3–5 days

**Tasks:**

- [ ] **1.1** Build `ContextProvider` service that collects default context (current time via `Date()`, active app name via `NSWorkspace.shared.frontmostApplication`)
- [ ] **1.2** Add optional context collectors: clipboard (`NSPasteboard.general`), screenshot (CGWindowListCreateImage or ScreenCaptureKit), selected text (Accessibility API if feasible, else skip for v1)
- [ ] **1.3** Define a `ContextPayload` struct and a consistent serialization format (structured text block or JSON) that gets appended to the CLI prompt
- [ ] **1.4** Wire `ContextProvider` into `PopoverViewModel` / `CommandRunner` so every skill run and free-form command includes context in the CLI invocation
- [ ] **1.5** Add context toggle UI — a small disclosure section or toggles on the Run Skill screen allowing the user to enable/disable optional context (screenshot, clipboard) per run; default context (time, active app) is always on with no toggle
- [ ] **1.6** Handle macOS permission prompts: detect and request Screen Recording permission for screenshot, Accessibility for selected text; gracefully degrade if denied
- [ ] **1.7** Create the preinstalled skill files: `morning-brief.md`, `create-new-skill.md`, `find-file.md` using the skill format from Objective 3; each skill's prompt template references context variables where appropriate
- [ ] **1.8** Optionally create `clean-downloads.md` and `work-mode.md` showcase skills
- [ ] **1.9** Implement first-run seeding logic: on app launch, check if skills directory exists and is empty (or check a `seeded` flag in UserDefaults); if first run, copy bundled skill files into `~/Library/Application Support/MenuBot/skills/`
- [ ] **1.10** Wire template variable substitution into skill execution: when a skill is run, replace `{context.active_app}`, `{context.clipboard}`, `{context.screenshot}`, `{context.time}`, and `{extra_instructions}` with actual values from `ContextPayload` and user input

**Definition of Done:**
- Running any skill or free-form command includes current time and active app name in the CLI invocation
- Screenshot and clipboard context can be toggled on and are included when enabled
- Fresh app launch seeds the skills directory with at least 3 preinstalled skills
- Preinstalled skills appear in the All Skills browser and can be starred and run
- Morning Brief skill runs successfully and produces meaningful output using injected context
- Template variables in skill files are substituted with real values at execution time

---

### Phase 2 — Scheduling
**Goal:** Users can schedule skills to run automatically on a recurring basis, starting with Morning Brief as the flagship use case.
**Duration Estimate:** 2–4 days

**Tasks:**

- [ ] **2.1** Extend skill metadata schema to include an optional `schedule` field (e.g., `{ "recommended": "daily", "default_time": "08:00" }`)
- [ ] **2.2** Build `ScheduleManager` service responsible for persisting schedule settings (which skills are scheduled, at what time/interval) to a local JSON file or UserDefaults
- [ ] **2.3** Implement the scheduling engine — choose one approach:
  - **Option A (recommended for v1):** Internal timer via `Timer.scheduledTimer` or `DispatchSourceTimer` that checks pending schedules every minute while the app is running; combine with Login Items registration so the app launches at startup
  - **Option B:** Generate and install a macOS LaunchAgent plist that wakes the app at the scheduled time
- [ ] **2.4** Build schedule UI: a "Schedule" button or section on the Run Skill screen (visible when a skill has a `schedule` metadata field); allows the user to enable/disable the schedule and pick a time
- [ ] **2.5** Add a Schedules overview — a simple list in settings or a dedicated section showing all active schedules with their next run time
- [ ] **2.6** Implement background skill execution: when a schedule fires, run the skill via `CommandRunner` without requiring the popover to be open; the app must be running (menu bar agent)
- [ ] **2.7** Wire report-back: when a scheduled skill completes, deliver a macOS notification (`UNUserNotificationCenter`) and/or a toast anchored to the menu bar icon using the existing event protocol; notification should include the skill name and a summary
- [ ] **2.8** Handle edge cases: missed schedules (app was quit), overlapping runs, schedule persistence across app restarts
- [ ] **2.9** Ensure Login Items / "Launch at Login" preference is available so the scheduling system is reliable

**Definition of Done:**
- Morning Brief skill can be scheduled to run daily at a user-chosen time
- When the schedule fires, the skill executes automatically and the user receives a visible notification with the result
- Schedule settings persist across app restarts
- The app can register itself to launch at login so schedules aren't missed
- Scheduled runs appear in any existing activity tracking (if wired from Objective 5)

---

## Phase Dependency Chain

```
Phase 1: Context Injection & Preinstalled Skills
  ├── Depends on: Objective 1 (CLI execution), Objective 2 (event protocol), Objective 3 (skills directory & format)
  └── No internal sub-phase dependencies — context and skills are built together
        │
        ▼
Phase 2: Scheduling
  ├── Depends on: Phase 1 (needs preinstalled skills to schedule, needs context injection for meaningful output)
  └── Depends on: Objective 2 (toast/notification for report-back)
```

Phases are strictly sequential — Phase 2 requires Phase 1's preinstalled skills and context system to have something worth scheduling.

## Risk Areas

| Risk | Mitigation |
|------|------------|
| macOS Screen Recording permission blocks screenshot context silently | Detect permission status via `CGPreflightScreenCaptureAccess()`; show a clear prompt directing users to System Settings; degrade gracefully with a "screenshot unavailable" message |
| Accessibility API for selected text is unreliable across apps | Mark selected text as "experimental" or skip for v1; clipboard is a more reliable alternative |
| App not running when schedule fires (user quit it) | Implement Launch at Login preference; document that scheduling requires the app to be running; consider LaunchAgent as a fallback |
| First-run seeding overwrites user-modified skills on update | Use a `seeded_version` flag in UserDefaults; only seed new skills on app version bump, never overwrite existing files |
| Timer-based scheduling drifts or misses if Mac is asleep | Use `NSWorkspace` wake notifications to check for missed schedules on wake; for v1 this is acceptable — exact timing isn't critical for a daily brief |
| ScreenCaptureKit availability varies by macOS version | Target `CGWindowListCreateImage` for macOS 13+; only use ScreenCaptureKit if targeting macOS 14+ features later |

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Context injection works | Every CLI invocation includes current time and active app; optional context toggles function correctly |
| Preinstalled skills seeded | Fresh install populates skills directory; skills appear in UI and run successfully |
| Template substitution works | Skill prompt variables are replaced with real context values at execution time |
| Scheduling functional | Morning Brief can be scheduled daily and fires at the configured time |
| Report-back on schedule | Scheduled run produces a visible notification/toast without user opening the popover |
| Persistence reliable | Schedule settings and seeding state survive app restarts and system reboots |

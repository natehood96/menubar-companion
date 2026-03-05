# Objective 7: System Integration & Polish — Phased Implementation Plan

> **Objective:** [Objective 7](../../objectives/Objective_7.md)
> **Depends on:** Objective 4 (persistent session, memory), Objective 5 (credentials, background jobs), Objective 6 (screen vision, input control, safety)
> **Feeds into:** Nothing — this is the final objective

---

## Reference Documents

- [Objective 7 — System Integration & Polish](../../objectives/Objective_7.md)
- [Objective 4 — Always-Available Companion](../../objectives/Objective_4.md)
- [Objective 5 — Scheduled Automation](../../objectives/Objective_5.md)
- [Objective 6 — Eyes and Hands](../../objectives/Objective_6.md)
- Existing codebase: `OrchestrationBootstrap.swift`, `AppDelegate.swift`

---

## Scope Summary

- Extend `OrchestrationBootstrap` to create all new directories (`jobs/`, `memory/`, `credentials/`, `cache/screenshots/`, `bin/`) and seed 3 new skills (`create-background-job`, `computer-control`, `manage-credentials`)
- Build and install 2 CLI tools (`menubot-input`, `menubot-creds`) as compiled Swift executables to `~/Library/Application Support/MenuBot/bin/`
- Implement a 6-step ordered startup sequence in `AppDelegate`
- Register MenuBot as a Login Item via `SMAppService.mainApp` with a settings toggle
- Consolidate permissions (Screen Recording, Accessibility, Keychain) into a unified lazy-request flow with friendly explanations and graceful denial
- Validate all 8 end-to-end acceptance criteria proving Objectives 4-6 compose correctly
- Ensure the app feels magical to a non-technical user

**End state:** MenuBot launches automatically at login, bootstraps all files and tools, starts all subsystems in the correct order, requests permissions only when needed, and passes all integration scenarios.

---

## Phasing Option Selected: Option C — Bootstrapping Then Integration

---

## Detailed Phase Plan

### Phase 7A — Extended Bootstrap

**Goal:** Extend `OrchestrationBootstrap` to create all required directories, seed the 3 new skills into the skills index, and compile/install both CLI tools to `bin/`.

**Tasks:**

- [ ] **7A.1** Create all new directories in `OrchestrationBootstrap.install()`:
  - `~/Library/Application Support/MenuBot/jobs/`
  - `~/Library/Application Support/MenuBot/jobs/logs/`
  - `~/Library/Application Support/MenuBot/memory/`
  - `~/Library/Application Support/MenuBot/credentials/`
  - `~/Library/Application Support/MenuBot/cache/`
  - `~/Library/Application Support/MenuBot/cache/screenshots/`
  - `~/Library/Application Support/MenuBot/bin/`
  - (Note: `skills/` and `doer-logs/` already exist)

- [ ] **7A.2** Create the 3 new skill `.md` files as bundled resources:
  - `Resources/skills/create-background-job.md` — Skill prompt for conversational background job creation (from Obj 5.5)
  - `Resources/skills/computer-control.md` — Skill prompt for vision-action loop (from Obj 6.6)
  - `Resources/skills/manage-credentials.md` — Skill prompt for credential setup (from Obj 5.2)

- [ ] **7A.3** Update the bundled `Resources/skills/skills-index.json` to include all 6 default skills:
  - Existing: `browse-web`, `create-skill`, `summarize-clipboard`
  - New: `create-background-job`, `computer-control`, `manage-credentials`

- [ ] **7A.4** Update `seedDefaultSkills()` in `OrchestrationBootstrap` to include the 3 new skill file names in the `defaultSkillFiles` array so their `.md` files are written to disk

- [ ] **7A.5** Create `menubot-creds` CLI tool as a new Xcode command-line tool target:
  - Swift executable using Security framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`)
  - Commands: `get <id>`, `set <id> --name "..." --description "..."`, `list`, `delete <id>`
  - Reads/writes `credentials-index.json` for metadata (never stores values there)
  - Stores credential values in macOS Keychain with service prefix `com.menubot.credential.<id>`

- [ ] **7A.6** Create `menubot-input` CLI tool as a new Xcode command-line tool target:
  - Swift executable using `CGEvent` APIs for mouse/keyboard control
  - Commands: `mouse_move --x N --y N`, `mouse_click --x N --y N [--button left|right] [--count N]`, `mouse_drag --x1 N --y1 N --x2 N --y2 N`, `key_type --text "..."`, `key_press --key K [--modifiers cmd,shift,...]`, `scroll --x N --y N --dx N --dy N`
  - Requires Accessibility permission (handled by the app-level permission flow)

- [ ] **7A.7** Add CLI tool installation logic to `OrchestrationBootstrap.install()`:
  - Copy compiled `menubot-creds` and `menubot-input` from the app bundle to `~/Library/Application Support/MenuBot/bin/`
  - Set executable permissions (`chmod +x`)
  - Overwrite on every launch so app updates propagate new tool versions

- [ ] **7A.8** Verify skill seeding preserves user-created skills:
  - Existing merge logic in `seedDefaultSkills()` already handles this (filters by `defaultIDs`)
  - Test: add a custom skill, relaunch, confirm it survives

**Definition of Done:**
- All directories in the spec exist after app launch
- `skills-index.json` contains all 6 default skills
- All 3 new `.md` skill files exist in the skills directory
- `menubot-creds get/set/list/delete` works from the terminal
- `menubot-input mouse_click/key_type/...` works from the terminal
- Both CLI tools are present and executable in `bin/`
- A pre-existing custom skill in `skills-index.json` survives a fresh bootstrap

---

### Phase 7B — Startup Sequence & Login Item

**Goal:** Implement the ordered 6-step startup sequence in `AppDelegate` and register MenuBot as a Login Item with a user-facing settings toggle.

**Tasks:**

- [ ] **7B.1** Refactor `AppDelegate.applicationDidFinishLaunching` into an ordered startup sequence:
  ```
  Step 1: OrchestrationBootstrap.install()          (existing — files, skills, CLI tools)
  Step 2: Start persistent orchestrator session      (Obj 4 — call into session manager)
  Step 3: Verify/repair background job LaunchAgents  (Obj 5 — call into job registry)
  Step 4: Load orchestrator memory files             (Obj 4 — trigger memory read)
  Step 5: Verify required credentials for enabled jobs (Obj 5 — check credential index)
  Step 6: Register global emergency stop shortcut    (Obj 6 — NSEvent global monitor)
  ```
  - Each step should log success/failure
  - Steps 2-6 depend on Objectives 4-6 being implemented — stub with protocol/interface calls that those objectives will fill in. If the subsystem isn't built yet, log a skip and continue.

- [ ] **7B.2** Create a `StartupSequence` coordinator (or extend `AppDelegate`) that:
  - Executes steps in order
  - Handles failures gracefully (a failed step logs the error but doesn't block subsequent steps)
  - Reports overall startup status

- [ ] **7B.3** Implement Login Item registration using `SMAppService.mainApp`:
  - Import `ServiceManagement`
  - Register on first launch (default: enabled)
  - Handle the case where registration fails (log, don't crash)

- [ ] **7B.4** Add a "Start MenuBot at login" toggle in a Settings view:
  - Default: on
  - Toggle calls `SMAppService.mainApp.register()` / `SMAppService.mainApp.unregister()`
  - Read current state via `SMAppService.mainApp.status`

- [ ] **7B.5** Create or extend a Settings view accessible from the hamburger menu:
  - "Start MenuBot at login" toggle (7B.4)
  - This view will also host the "Forget everything" button (Obj 4) and other settings in later phases

**Definition of Done:**
- App launch executes all 6 startup steps in order (visible in console logs)
- A failed/missing subsystem doesn't crash the app or block other steps
- MenuBot appears in System Settings > General > Login Items after first launch
- "Start MenuBot at login" toggle works in the Settings view
- Toggling the setting off removes MenuBot from Login Items; toggling on re-adds it

---

### Phase 7C — Permissions Consolidation & End-to-End Validation

**Goal:** Unify permission request flows across all features into a consistent pattern, then validate all 8 end-to-end acceptance criteria.

**Tasks:**

- [ ] **7C.1** Create a `PermissionsManager` (or similar) that centralizes permission state:
  - Screen Recording: `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`
  - Accessibility: `AXIsProcessTrusted()` / prompt via `AXIsProcessTrustedWithOptions`
  - Keychain: automatic (app's own items, no explicit permission needed)
  - Exposes methods like `requestScreenRecording(reason:completion:)` and `requestAccessibility(reason:completion:)`

- [ ] **7C.2** Implement lazy permission requests — permissions are requested only on first use of the relevant feature:
  - Screen Recording: first time user asks about their screen (Obj 6.1)
  - Accessibility: first time screen metadata or input control is needed (Obj 6.3 / 6.5)
  - Wire into the relevant feature code paths (screenshot capture, accessibility metadata, `menubot-input`)

- [ ] **7C.3** Create friendly in-app permission explanation UI:
  - A modal or inline message explaining why the permission is needed and what it enables
  - Non-technical language: "To see your screen, I need Screen Recording permission. This lets me take screenshots when you ask me to look at something."
  - Show before triggering the system prompt

- [ ] **7C.4** Handle permission denial gracefully:
  - If denied, show a clear fallback message: "I can't see your screen without Screen Recording permission. You can enable it in System Settings > Privacy & Security."
  - Do not re-prompt automatically. Only re-check when the user explicitly tries the feature again.
  - Accessibility permission covers both screen metadata (6.3) and input control (6.5) — ensure a single grant is sufficient and the flow doesn't ask twice

- [ ] **7C.5** End-to-end validation — test all 8 acceptance criteria:
  1. [ ] Concurrent tasks: send "find flights" then "what's the weather" — both run and return independently
  2. [ ] Job creation flow: "set up a morning newsletter" triggers full guided setup (content, schedule, delivery, credentials, job creation)
  3. [ ] Restart persistence: restart Mac, login, verify morning newsletter fires on schedule
  4. [ ] Screen reading: ask "what's this error?" while looking at a terminal error — captures screen, explains it
  5. [ ] Input control: "click the Submit button" — captures screen, identifies button, asks confirmation, clicks, verifies
  6. [ ] Multi-turn conversation: "Italian restaurants" -> "outdoor seating?" -> "book the second one" — context maintained
  7. [ ] Memory persistence: "remember I prefer window seats" — stored and recalled across restarts
  8. [ ] Credential retrieval: background job uses a Slack token set up weeks ago without user interaction

- [ ] **7C.6** Fix integration gaps discovered during E2E validation:
  - This is expected — the "glue" phase will surface edge cases where Obj 4-6 features don't compose cleanly
  - Track issues and fix in priority order

- [ ] **7C.7** UX principle validation — review each feature against "Does this feel magical to a non-technical user?":
  - User never needs to understand doers, log files, cron syntax, or session IDs
  - Setup flows are guided and conversational
  - Failures are retried silently before surfacing, with clear user actions when surfaced
  - Status is glanceable, progress is ambient
  - App feels alive — always ready, never frozen

**Definition of Done:**
- Each permission is requested only when its feature is first used
- All permission requests include a friendly, non-technical explanation
- Denied permissions produce a graceful fallback message, no repeated prompts
- Accessibility permission is requested once and covers both screen metadata and input control
- All 8 end-to-end acceptance criteria pass
- No feature exposes internal complexity to the user

---

## Phase Dependency Chain

```
Phase 7A (Bootstrap)
    |
    v
Phase 7B (Startup & Login Item)
    |
    v
Phase 7C (Permissions & E2E Validation)
```

- **Strictly sequential** — each phase depends on the previous
- 7A must complete first because 7B's startup sequence references the directories, skills, and CLI tools that 7A creates
- 7B must complete before 7C because E2E validation requires the full startup sequence to be working
- No phases can be parallelized (this is a "glue" objective — the work is inherently sequential)

**Cross-objective dependencies:**
- Phase 7B steps 2-6 depend on Objectives 4-6 being implemented (stubs are acceptable during 7B development)
- Phase 7C E2E validation requires Objectives 4-6 to be fully functional

---

## Risk Areas

| Risk | Mitigation |
|------|------------|
| CLI tools require separate Xcode targets — project file complexity | Follow existing Xcode target patterns; test build early in 7A |
| `SMAppService` can silently fail on older macOS or sandboxed apps | MenuBot targets macOS 13+ (API available) and sandbox is disabled; log failures and degrade gracefully |
| Startup sequence ordering is fragile if Obj 4-6 subsystems aren't ready | Each step checks if its subsystem exists before calling; stubs used during development; failures logged but don't block |
| Permission state can be stale — user revokes in System Settings while app is running | Re-check permission status each time the feature is invoked, not just on first use; cache only to avoid redundant UI prompts |
| E2E scenarios depend on external services (Slack, web search) | Test with mock/local equivalents where possible; document which tests require live services |
| CLI tool installation fails due to file permissions | Use `FileManager` to verify write access to `bin/`; create with correct permissions; log errors clearly |

---

## Success Criteria

| Milestone | Criteria |
|-----------|----------|
| Phase 7A complete | All directories exist, 6 skills in index, both CLI tools installed and executable |
| Phase 7B complete | 6-step startup executes in order, Login Item registered, settings toggle works |
| Phase 7C complete | All permissions flow correctly, all 8 E2E scenarios pass, UX feels magical |
| Objective 7 complete | Full file structure matches spec, app launches automatically, all features compose seamlessly |

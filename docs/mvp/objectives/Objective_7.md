# Objective 7: System Integration & Polish

## Overview

Wire everything together into a cohesive, production-ready system. This objective covers the ordered startup sequence that initializes all subsystems correctly, login item registration so MenuBot launches automatically, bootstrapping new skills and CLI tools via `OrchestrationBootstrap`, consolidating the permissions flow across features, finalizing the file structure, and validating the end-to-end acceptance criteria that prove all features work together as a seamless experience. This is the "glue" objective — it doesn't introduce new capabilities, but it ensures the capabilities from Objectives 4–6 compose correctly and the app feels like a polished product.

---

## Objectives

### 7.1 Startup Sequence & Login Item

#### Requirements

##### 7.1.1 Startup Sequence

On app launch, MenuBot must execute the following steps in order:

1. Bootstrap orchestration files (existing: `OrchestrationBootstrap.swift`)
2. Start the persistent orchestrator session (Objective 4)
3. Verify and repair background job LaunchAgents (Objective 5)
4. Load orchestrator memory files (Objective 4)
5. Verify required credentials exist for enabled jobs (Objective 5)
6. Register global emergency stop shortcut (Objective 6)

##### 7.1.2 Login Item

- MenuBot must register itself as a **Login Item** so it starts automatically when the user logs in.
- Use `SMAppService.mainApp` (macOS 13+) for modern login item registration.
- Provide a toggle in settings: "Start MenuBot at login" (default: on).

#### Acceptance Criteria

- [ ] The 6-step startup sequence executes in the correct order on every app launch
- [ ] MenuBot starts automatically when the user logs in
- [ ] A "Start MenuBot at login" toggle exists in settings (default: on)

---

### 7.2 New Skills & CLI Tools Bootstrap

#### Requirements

##### 7.2.1 New Skills to Ship

The following skills must be seeded by `OrchestrationBootstrap` on first run, using the same pattern as existing default skills:

| Skill ID | File | Source Objective | Description |
|---|---|---|---|
| `create-background-job` | `create-background-job.md` | 5 | Conversationally create scheduled background jobs |
| `computer-control` | `computer-control.md` | 6 | Vision-action loop for mouse/keyboard automation |
| `manage-credentials` | `manage-credentials.md` | 5 | Store and manage service credentials |

These must be added to `skills-index.json` alongside existing default skills (browse-web, create-skill, summarize-clipboard). User-created skills must be preserved during the merge (same pattern as existing `OrchestrationBootstrap` logic).

##### 7.2.2 New CLI Tools to Bundle

The following CLI tools must be built as compiled Swift executables (separate Xcode targets or embedded command-line tools) and installed to `~/Library/Application Support/MenuBot/bin/`:

| Tool | Location | Source Objective | Description |
|---|---|---|---|
| `menubot-input` | `~/Library/Application Support/MenuBot/bin/menubot-input` | 6 | Mouse and keyboard control primitives |
| `menubot-creds` | `~/Library/Application Support/MenuBot/bin/menubot-creds` | 5 | Keychain credential storage and retrieval |

The `bin/` directory must be created if it doesn't exist. Tools should be installed/updated on every app launch (same bootstrap pattern as skills).

#### Acceptance Criteria

- [ ] All 3 new skills are seeded on first run and registered in `skills-index.json`
- [ ] User-created skills are preserved during bootstrap merge
- [ ] Both CLI tools are compiled, installed to `bin/`, and executable by doers
- [ ] CLI tools are updated on app launch if newer versions are available

---

### 7.3 Permissions Consolidation

#### Requirements

Unify the permissions request flow across all features to ensure a consistent user experience:

| Permission | Features | When Requested |
|---|---|---|
| Screen Recording | Objective 6 (Screen Vision) | First time user asks about their screen |
| Accessibility | Objective 6 (Accessibility metadata + Mouse/Keyboard) | First time screen metadata or input control is needed |
| Keychain access | Objective 5 (Credentials) | Automatic (app's own keychain items) |

- Permissions must be requested at the right moment (first use of the relevant feature, not on app launch).
- Each permission request must include a friendly, non-technical in-app explanation of why it's needed and what it enables.
- Denial must be handled gracefully across all features — no repeated nagging, clear fallback messages.
- The Accessibility permission is shared between screen metadata (Objective 6.3) and input control (Objective 6.5) — a single grant covers both. The permission flow should not ask twice.

#### Acceptance Criteria

- [ ] Each permission is requested only when its feature is first used, not at launch
- [ ] All permission requests include a friendly explanation
- [ ] Denied permissions produce graceful fallback behavior, not repeated prompts
- [ ] Accessibility permission is requested once and covers both screen metadata and input control

---

### 7.4 File Structure & End-to-End Validation

#### Requirements

##### 7.4.1 Updated File Structure

The complete `~/Library/Application Support/MenuBot/` directory structure after all objectives are implemented:

```
~/Library/Application Support/MenuBot/
  skills/
    skills-index.json
    *.md (skill files)
  jobs/
    jobs-registry.json
    logs/
      <job-id>-<timestamp>.log
  memory/
    user-profile.md
    conversation-context.md
    task-history.md
    learned-facts.md
  credentials/
    credentials-index.json
  doer-logs/
    doer-<task>-<timestamp>.log
  cache/
    screenshots/
  bin/
    menubot-input
    menubot-creds
  protocol.md
  output-rules.md
```

All directories must be created as needed by the bootstrap or feature code. No directory should be assumed to exist without verification.

##### 7.4.2 End-to-End Acceptance Criteria

These validate the features from Objectives 4–6 working together as a cohesive experience. Every criterion must pass:

- [ ] User opens MenuBot, sends "find me flights from SLC to Dublin next week", and while that's running, sends "what's the weather today?" — both tasks execute concurrently and results arrive independently
- [ ] User says "set up a morning newsletter for me" and the orchestrator guides them through the full setup: what content, what schedule, what delivery method, credential setup, and creates a working background job
- [ ] User restarts their Mac, logs in, and the morning newsletter job fires at the scheduled time without any manual intervention
- [ ] User asks "what's this error?" while looking at a terminal error — MenuBot captures the screen, reads the error, and explains it
- [ ] User says "click the Submit button on this page" — MenuBot captures the screen, identifies the button, asks for confirmation, clicks it, and verifies the result
- [ ] User has a multi-turn conversation: "Find Italian restaurants nearby" -> "Which ones have outdoor seating?" -> "Book the second one for Friday at 7pm" — the orchestrator maintains context across all messages
- [ ] User says "remember that I prefer window seats on flights" — this is stored in memory and recalled in future flight-related tasks, even across app restarts
- [ ] A background job needs a Slack token that was set up weeks ago — it retrieves it from Keychain and uses it successfully without any user interaction

##### 7.4.3 Design Principle Validation

Every feature must be evaluated against the overarching UX principle: **"Does this feel magical to a non-technical user?"**

- The user should never need to understand internals (doers, log files, cron syntax, session IDs).
- Setup flows should be guided and conversational ("What's your Slack workspace? Here's how to get a token...").
- Failures should be retried silently before surfacing — and when surfaced, should include what was tried and what the user can do.
- Status should be glanceable. Progress should be ambient, not noisy.
- The app should feel alive — always ready, never frozen, never "loading...".

##### 7.4.4 Future Enhancements (Post-MVP v2)

These are explicitly out of scope for all objectives but documented for future planning:

- OAuth flows for credential setup (instead of manual token pasting)
- User-selected screen region capture
- Multi-monitor support for screen vision
- Job templates / skill-to-job conversion ("run this skill on a schedule")
- Shared/community skill and job libraries
- Voice input (microphone -> speech-to-text -> chat)
- File drop zone (drag files onto the popover to provide context)

#### Acceptance Criteria

- [ ] All directories in the file structure are created and verified
- [ ] All 8 end-to-end acceptance criteria pass
- [ ] UX principle is validated across all features

---

## Scope Boundary

This objective does NOT include:

- Building the persistent orchestrator session or memory system (Objective 4 — this objective wires them into the startup sequence)
- Building non-blocking chat or concurrent CommandRunner support (Objective 4)
- Building proactive toast notifications (Objective 4)
- Building credential storage, the `menubot-creds` CLI, or the credential management skill (Objective 5 — this objective bootstraps and installs them)
- Building the job registry, LaunchAgents, job execution, or Jobs UI (Objective 5 — this objective verifies them at startup)
- Building screenshot capture, accessibility metadata, or the `menubot-input` CLI (Objective 6 — this objective bootstraps and installs them)
- Building the vision-action loop, computer control skill, or safety system (Objective 6 — this objective registers the emergency stop shortcut at startup)

---

## Dependencies

- **Depends on:** Objective 4 (persistent session, memory system, non-blocking chat, proactive toasts), Objective 5 (credentials infrastructure, background jobs), Objective 6 (screen vision, input control, safety system)
- **Feeds into:** Nothing — this is the final objective

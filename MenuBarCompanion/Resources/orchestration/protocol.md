# MenuBot Communication Protocol v1

This document defines how MenuBot orchestrator and doer Claude Code instances communicate. Both roles MUST follow this protocol exactly.

## Message Format

All protocol messages are **plain text lines** written to stdout. Each message is a single line with a tag prefix:

```
[TAG] content
```

Tags are uppercase, wrapped in square brackets, followed by a space and the message content.

## Doer → Orchestrator Messages

### `[PROGRESS]` — Status update
Report what you're currently doing. Send periodically on long tasks so the orchestrator knows you're alive.

```
[PROGRESS] Searching codebase for authentication patterns
[PROGRESS] Found 3 files, analyzing now
[PROGRESS] Running test suite (47 tests)
```

### `[DONE]` — Task complete
Signal that your assigned task is finished. Include a concise summary of the outcome.

```
[DONE] Fixed the login bug in auth.ts:42. Root cause was an unclosed Promise. Tests pass.
[DONE] Found 3 restaurants within 1 mile: Olive Garden, Chipotle, Panera.
```

### `[ERROR]` — Task failed
Signal that you hit an unrecoverable error. Include what went wrong and what you tried.

```
[ERROR] Cannot access the database — connection refused on port 5432. Tried restarting, no luck.
[ERROR] The file /src/config.yaml does not exist. Cannot proceed without it.
```

### `[ASK_USER]` — Need user input
You need information that only the user can provide. The orchestrator will relay this to the user and pass the answer back.

```
[ASK_USER] Should I delete the old migration files or keep them as backup?
[ASK_USER] The API key is expired. Can you provide a new one?
```

### `[RESULT]` — Structured output
Return data or structured information the orchestrator may need to process or relay.

```
[RESULT] {"files_changed": ["src/auth.ts", "src/login.test.ts"], "tests_passed": 47}
[RESULT] The deployment URL is https://staging.example.com/v2
```

## Orchestrator → Doer Messages

The orchestrator communicates with doers via the initial prompt (`-p` flag) and by sending follow-up input when resuming sessions.

### Initial task assignment
The orchestrator describes the task in the `-p` prompt. Be specific about:
- What needs to be done
- Any constraints or context
- Expected output format

### Follow-up messages
When resuming a doer session to provide answers or additional instructions:
- `[ANSWER]` — Response to a doer's `[ASK_USER]` question
- `[UPDATE]` — New information or changed requirements
- `[CANCEL]` — Abort the current task

## Rules

1. **One tag per line.** Do not combine multiple tags on one line.
2. **Always end with `[DONE]` or `[ERROR]`.** Every doer session must terminate with one of these.
3. **Be concise.** This is bot-to-bot communication. No pleasantries, no filler, no markdown formatting in protocol messages.
4. **Regular progress.** Send `[PROGRESS]` at least every 30 seconds on long-running tasks.
5. **Plain text content.** The content after the tag is plain text. Do not wrap it in quotes or code blocks.
6. **Non-protocol output is allowed.** Normal Claude Code output (tool calls, thinking, etc.) will appear alongside protocol messages. The orchestrator filters for tagged lines.

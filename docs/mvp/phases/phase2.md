# Phase 1 — Event Model & Minimal Toast

- **Phase Number:** 1
- **Phase Name:** Event Model & Minimal Toast
- **Source:** docs/mvp/phases/overviews/objective2PhaseOverview.md

---

## 🤖 AI Agent Execution Instructions

> **READ THIS ENTIRE DOCUMENT BEFORE STARTING ANY WORK.**
>
> Once you have read and understood the full document:
>
> 1. Execute each task in order
> 2. After completing a task, come back to this document and add a ✅ checkmark emoji to that task's title
> 3. If you are interrupted or stop mid-execution, the checkmarks show exactly where you left off
> 4. Do NOT check off a task until the work is fully complete
> 5. If you need to reference another doc, b/c the doc you're currently referencing doesn't have the right info you need to fill out the task, check neighboring docs in the same folder to see if you can find the information you're looking for there.
>
> If you need any prisma commands run (e.g. `npx prisma migrate dev`), let the user know and they will run them.

---

## 📋 Task Tracking Instructions

- Each task heading includes a checkbox placeholder. Mark the task title with a ✅ emoji AFTER completing the work.
- Update this document as you go — it is the source of truth for phase progress.
- This phase cannot advance to Phase 2 until all task checkboxes are checked.
- If execution stops mid-phase, the checkmarks indicate exactly where progress was interrupted.

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Define the full typed event model for all three event types (toast, result, error), upgrade EventParser to decode JSON into typed Swift models, create a NotificationManager to coordinate event presentation, and implement a minimal toast view anchored near the menu bar icon that auto-dismisses.
- **What already exists:** `EventParser.swift` already detects the `[MENUBOT_EVENT]` prefix and parses JSON payloads using `JSONSerialization` into untyped dictionaries, returning a human-readable summary string. `PopoverViewModel.swift` routes stdout lines through EventParser and appends the result to the output text. `AppDelegate.swift` owns the `NSStatusItem` and `NSPopover`. Sandbox is disabled. The app is menu-bar-only (LSUIElement).
- **What future phases depend on:** Phase 2 (Rich Toast UI with Actions) adds action buttons, animations, and toast queuing to the toast view built here. Phase 3 (Result & Error Display States) builds result card and error state views using the event model and NotificationManager established here.

---

## 0. Mental Model (Required)

**Problem:** Claude Code emits structured event lines in stdout, but the app currently treats them as plain text — it extracts a summary string and dumps it into the output log. There is no typed event model, no dedicated notification layer, and no visual feedback beyond the text log. Users have no way to see at-a-glance notifications for completed tasks, errors, or results.

**Where it fits:** This is the first phase of Objective 2 (Event Protocol & Notifications). It lays the foundation that all subsequent notification UI is built on — the typed event model, the parsing pipeline, and the notification coordination layer. Without this phase, there is nothing to render in Phase 2 or Phase 3.

**Data flow:**
```
Claude Code stdout
  → CommandRunner (line-by-line streaming)
    → PopoverViewModel.handleOutputLine()
      → EventParser.parseEvent(json) → MenuBotEvent? (typed)
        → NotificationManager.handle(event)
          → ToastWindow (for .toast events)
          → Log only (for .result / .error — UI deferred to Phase 3)
      → Non-event lines continue to append to output text as before
```

**Core entities:**
- **MenuBotEvent** — enum with `toast`, `result`, `error` cases and typed payloads
- **ToastPayload / ResultPayload / ErrorPayload** — Codable structs for each event type
- **EventAction** — enum representing user-triggerable actions (open file, open URL, copy text)
- **EventParser** — upgraded to return typed `MenuBotEvent` instead of summary strings
- **NotificationManager** — receives parsed events and coordinates UI presentation
- **ToastWindow** — an `NSPanel` positioned near the status item that shows a transient toast

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Establish the typed event protocol model, upgrade the parser to produce typed events, and render a minimal auto-dismissing toast notification anchored to the menu bar icon when a `toast` event is received.

### Prerequisites

- Xcode project builds and runs
- `EventParser.swift` exists and detects `[MENUBOT_EVENT]` prefix
- `PopoverViewModel.swift` routes output through EventParser
- `AppDelegate.swift` owns the `NSStatusItem` with a button

### Key Deliverables

- `MenuBotEvent` enum and payload structs (`ToastPayload`, `ResultPayload`, `ErrorPayload`, `EventAction`)
- `EventParser` upgraded to Codable-based typed decoding
- `NotificationManager` class to receive and coordinate events
- `ToastWindow` — an `NSPanel`-based toast anchored near the menu bar icon
- `ToastView` — a SwiftUI view rendered inside the toast panel
- Wiring from `PopoverViewModel` through the full pipeline to toast display

### System-Level Acceptance Criteria

- A `[MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"World"}` line in stdout causes a toast bubble to appear near the menu bar icon and auto-dismiss after ~4 seconds
- Non-event stdout lines continue to render in the popover output as before and do not trigger notifications
- `result` and `error` events are parsed into typed models and logged to console but not yet rendered in notification UI
- Malformed JSON after the `[MENUBOT_EVENT]` prefix does not crash — it is logged and ignored
- Unknown event types are silently ignored

---

## 2. Execution Order

### Blocking Tasks

1. **Task 1.1** — Define event model types (must exist before parser can produce them)
2. **Task 1.2** — Upgrade EventParser to typed decoding (must work before NotificationManager can receive events)
3. **Task 1.3** — Create NotificationManager (must exist before toast can be presented)
4. **Task 1.4** — Implement ToastWindow and ToastView (must exist before wiring)
5. **Task 1.5** — Wire the full pipeline: ViewModel → Parser → NotificationManager → ToastWindow

### Parallel Tasks

- **Task 1.6** (verify non-event lines) can run in parallel with Task 1.5 wiring validation

### Final Integration

- Build and run the app
- Send a `[MENUBOT_EVENT] {"type":"toast","title":"Done!","message":"Your task is complete."}` line through stdout
- Verify: toast appears near menu bar icon, auto-dismisses, non-event output still works, result/error events log to console

---

## 3. Architectural Decisions (ONLY IF NEEDED)

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Toast presentation | NSPopover / NSPanel / NSWindow / UNUserNotification | NSPanel | NSPopover conflicts with the existing command popover; NSPanel allows precise positioning relative to the status item, can float above other windows, and is dismissable. UNUserNotification would go to Notification Center, not anchor to the menu bar. | Positioning math relative to status item may need tuning |
| Event model decoding | JSONSerialization (current) / Codable | Codable | Type-safe, less boilerplate, catches schema mismatches at decode time, integrates with Swift enums naturally | Slightly less flexible for unknown fields — mitigated by using `CodingKeys` and optional fields |
| NotificationManager ownership | Singleton / Owned by AppDelegate / Owned by ViewModel | Owned by AppDelegate, passed to ViewModel | AppDelegate owns the status item (needed for toast positioning). NotificationManager needs the status item's button frame. Avoids singletons. | Adds a parameter to ViewModel init |

---

## 4. Subtasks

### Task 1.1 — Define Event Model Types

#### User Story

As a developer, I need strongly-typed Swift models for all three event types so that the parser, notification manager, and future UI views all share a single source of truth for event structure.

#### Implementation Steps

1. Create a new file `MenuBarCompanion/Core/EventModels.swift`
2. Define the `EventAction` enum:

```swift
import Foundation

enum EventAction: Codable {
    case openFile(path: String)
    case openURL(url: String)
    case copyText(text: String)
}
```

Use a custom `Codable` implementation with a `"kind"` discriminator:

```json
{"kind": "openFile", "path": "/Users/me/output.txt"}
{"kind": "openURL", "url": "https://example.com"}
{"kind": "copyText", "text": "some content"}
```

3. Define payload structs:

```swift
struct ToastPayload: Codable {
    let title: String
    let message: String
    let action: EventAction?
}

struct ResultPayload: Codable {
    let summary: String
    let artifacts: [Artifact]

    struct Artifact: Codable {
        let label: String
        let path: String
        let action: EventAction?
    }
}

struct ErrorPayload: Codable {
    let message: String
    let guidance: String?
}
```

4. Define the top-level `MenuBotEvent` enum:

```swift
enum MenuBotEvent: Codable {
    case toast(ToastPayload)
    case result(ResultPayload)
    case error(ErrorPayload)
}
```

Use a custom `Codable` implementation that switches on a `"type"` field in the JSON root:

```json
{"type": "toast", "title": "Done!", "message": "All set."}
{"type": "result", "summary": "Created 3 files", "artifacts": [...]}
{"type": "error", "message": "Failed", "guidance": "Check permissions"}
```

The `type` field selects the enum case. The remaining fields decode into the corresponding payload. This means toast payload fields are at the root level (not nested under a `"payload"` key) for simplicity.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/EventModels.swift` | Create | `MenuBotEvent` enum, `ToastPayload`, `ResultPayload`, `ErrorPayload`, `EventAction` |

#### Acceptance Criteria

- [ ] `MenuBotEvent` enum exists with `.toast`, `.result`, `.error` cases
- [ ] Each case carries its respective typed payload
- [ ] `EventAction` enum supports `openFile`, `openURL`, `copyText`
- [ ] All types conform to `Codable`
- [ ] JSON like `{"type":"toast","title":"Hi","message":"World"}` decodes into `MenuBotEvent.toast(ToastPayload(title:"Hi", message:"World", action:nil))`

---

### Task 1.2 — Upgrade EventParser to Typed Decoding

#### User Story

As a developer, I need `EventParser` to produce typed `MenuBotEvent` values instead of summary strings so that the notification layer can switch on event type and access payload fields safely.

#### Implementation Steps

1. Open `MenuBarCompanion/Core/EventParser.swift`
2. Replace the current `JSONSerialization`-based implementation with a `JSONDecoder`-based approach
3. Keep the `[MENUBOT_EVENT]` prefix detection logic as-is
4. Replace the public API:

**Remove:**
- `func parse(_ json: String) -> String` (summary string)
- `func parseEvent(_ json: String) -> MenuBotEvent?` (old untyped version)

**Add:**
```swift
struct EventParser {
    private static let prefix = "[MENUBOT_EVENT] "
    private static let decoder = JSONDecoder()

    /// Check if a line is an event line and extract the JSON portion
    static func extractPayload(from line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let json = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        guard !json.isEmpty else { return nil }
        return json
    }

    /// Parse a JSON string into a typed MenuBotEvent
    static func parseEvent(from json: String) -> MenuBotEvent? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            return try decoder.decode(MenuBotEvent.self, from: data)
        } catch {
            print("[EventParser] Failed to decode event: \(error)")
            return nil
        }
    }
}
```

5. Make `EventParser` a `struct` with `static` methods (no instance state needed)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/EventParser.swift` | Modify | Replace JSONSerialization with Codable decoding, return typed `MenuBotEvent` |

#### Acceptance Criteria

- [ ] `EventParser.extractPayload(from:)` returns the JSON portion for event lines, `nil` for non-event lines
- [ ] `EventParser.parseEvent(from:)` returns a typed `MenuBotEvent` for valid JSON
- [ ] Malformed JSON returns `nil` and logs an error (does not crash)
- [ ] Unknown `type` values return `nil` gracefully
- [ ] The old `parse(_:)` summary string method is removed

---

### Task 1.3 — Create NotificationManager

#### User Story

As a developer, I need a centralized notification coordinator that receives typed events and decides how to present them — showing toasts for toast events now, and providing a hook point for result/error UI in future phases.

#### Implementation Steps

1. Create a new file `MenuBarCompanion/Core/NotificationManager.swift`
2. Implement the class:

```swift
import AppKit
import SwiftUI

@MainActor
final class NotificationManager {
    private let statusItem: NSStatusItem

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func handle(_ event: MenuBotEvent) {
        switch event {
        case .toast(let payload):
            showToast(payload)
        case .result(let payload):
            // Phase 3: render result card
            print("[NotificationManager] Result event received (UI deferred): \(payload.summary)")
        case .error(let payload):
            // Phase 3: render error state
            print("[NotificationManager] Error event received (UI deferred): \(payload.message)")
        }
    }

    private func showToast(_ payload: ToastPayload) {
        // Implementation in Task 1.4
    }
}
```

3. `NotificationManager` is `@MainActor` because all UI work (showing/hiding panels) must happen on the main thread
4. It takes the `NSStatusItem` at init so it can position the toast relative to the menu bar icon

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/NotificationManager.swift` | Create | Event coordinator that routes typed events to appropriate UI |

#### Acceptance Criteria

- [ ] `NotificationManager` exists and is `@MainActor`
- [ ] It accepts `MenuBotEvent` via `handle(_:)` and switches on type
- [ ] `.toast` events call `showToast()` (implementation in next task)
- [ ] `.result` and `.error` events log to console with payload summary
- [ ] It holds a reference to the `NSStatusItem` for positioning

---

### Task 1.4 — Implement ToastWindow and ToastView

#### User Story

As a user, when Claude Code finishes a task and emits a toast event, I want to see a small, friendly notification bubble appear near the menu bar icon that shows the title and message, then disappears after a few seconds — so I know something happened without needing to open the popover.

#### Implementation Steps

1. Create a new file `MenuBarCompanion/UI/ToastView.swift` with the SwiftUI view:

```swift
import SwiftUI

struct ToastView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .onTapGesture {
            onDismiss()
        }
    }
}
```

2. Create a new file `MenuBarCompanion/UI/ToastWindow.swift` with the `NSPanel`-based window:

```swift
import AppKit
import SwiftUI

final class ToastWindow {
    private var panel: NSPanel?
    private var dismissTimer: Timer?

    func show(
        payload: ToastPayload,
        relativeTo statusItem: NSStatusItem,
        dismissAfter seconds: TimeInterval = 4.0,
        onDismiss: @escaping () -> Void
    ) {
        dismiss() // Clear any existing toast

        let hostingView = NSHostingView(
            rootView: ToastView(
                title: payload.title,
                message: payload.message,
                onDismiss: { [weak self] in
                    self?.dismiss()
                    onDismiss()
                }
            )
        )
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // SwiftUI view handles its own shadow
        panel.level = .statusBar
        panel.contentView = hostingView
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position below the status item
        if let button = statusItem.button,
           let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let panelSize = hostingView.fittingSize
            let x = buttonFrame.midX - panelSize.width / 2
            let y = buttonFrame.minY - panelSize.height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.panel = panel

        dismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismiss()
                onDismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
```

3. Wire `showToast` in `NotificationManager`:

```swift
private let toastWindow = ToastWindow()

private func showToast(_ payload: ToastPayload) {
    toastWindow.show(payload: payload, relativeTo: statusItem) {
        // Toast dismissed — no-op for now; Phase 2 adds queuing
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ToastView.swift` | Create | SwiftUI view for toast content (title, message, tap to dismiss) |
| `MenuBarCompanion/UI/ToastWindow.swift` | Create | NSPanel wrapper that positions and shows the toast near the status item |
| `MenuBarCompanion/Core/NotificationManager.swift` | Modify | Wire `showToast()` to use `ToastWindow` |

#### Acceptance Criteria

- [ ] `ToastView` renders title and message with material background and rounded corners
- [ ] Clicking the toast body dismisses it
- [ ] `ToastWindow` creates a non-activating `NSPanel` at status bar level
- [ ] The panel is positioned directly below the status item's button
- [ ] The toast auto-dismisses after ~4 seconds
- [ ] Showing a new toast while one is visible replaces the existing one (no stacking yet — that's Phase 2)

---

### Task 1.5 — Wire the Full Pipeline

#### User Story

As a developer, I need the entire chain connected — from a stdout line arriving in `PopoverViewModel`, through the parser, through `NotificationManager`, to the toast appearing on screen — so the feature works end-to-end.

#### Implementation Steps

1. **Update `AppDelegate.swift`:**
   - Create `NotificationManager` after the status item is set up
   - Pass it to `PopoverViewModel` (or make it accessible)

```swift
// In AppDelegate.applicationDidFinishLaunching or setupMenuBar:
let notificationManager = NotificationManager(statusItem: statusItem)
// Pass to the popover view's view model
```

2. **Update `PopoverViewModel.swift`:**
   - Accept `NotificationManager` as an init parameter (or injectable property)
   - Update `handleOutputLine()`:

```swift
func handleOutputLine(_ line: String) {
    // Check for event
    if let json = EventParser.extractPayload(from: line) {
        if let event = EventParser.parseEvent(from: json) {
            notificationManager?.handle(event)
        }
        // Event lines are NOT appended to output text — they are handled by NotificationManager
        return
    }

    // Non-event line — append to output as before
    output += line + "\n"
}
```

3. **Key behavior change:** Event lines are now consumed by the notification pipeline and no longer appended to the output text. Non-event lines continue as before.

4. **Update `PopoverView.swift` and `AppDelegate.swift`** to thread the `NotificationManager` through the view hierarchy.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Create `NotificationManager`, pass to view model |
| `MenuBarCompanion/UI/PopoverViewModel.swift` | Modify | Accept `NotificationManager`, route events through it, stop appending event lines to output |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Update init if needed to pass through NotificationManager |

#### Acceptance Criteria

- [ ] `AppDelegate` creates `NotificationManager` with the status item
- [ ] `PopoverViewModel` receives and uses `NotificationManager`
- [ ] Event lines (`[MENUBOT_EVENT] ...`) are routed to `NotificationManager` and NOT appended to output
- [ ] Non-event lines are still appended to output as before
- [ ] A toast event line produces a visible toast near the menu bar icon
- [ ] Result and error event lines log to console (no UI yet)

---

### Task 1.6 — Verify Non-Event Lines and Edge Cases

#### User Story

As a user running Claude Code, I expect all normal output to continue appearing in the popover. Only structured event lines should be intercepted for notifications. Malformed events should not break anything.

#### Implementation Steps

1. Test with various stdout inputs:
   - Normal text: `"Hello world"` → appears in output
   - Valid toast: `[MENUBOT_EVENT] {"type":"toast","title":"Done","message":"All set"}` → toast appears, NOT in output
   - Valid result: `[MENUBOT_EVENT] {"type":"result","summary":"Created file","artifacts":[]}` → logged, NOT in output
   - Valid error: `[MENUBOT_EVENT] {"type":"error","message":"Oops","guidance":"Try again"}` → logged, NOT in output
   - Malformed JSON: `[MENUBOT_EVENT] {bad json}` → logged as parse error, NOT in output, no crash
   - Prefix but empty: `[MENUBOT_EVENT] ` → ignored, no crash
   - Almost-prefix: `[MENUBOT_EVENT]no space` → treated as normal text (prefix requires trailing space)
   - Unknown type: `[MENUBOT_EVENT] {"type":"unknown","data":123}` → logged, ignored, no crash

2. Verify the output text area in PopoverView still scrolls and updates correctly

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | Verify only | Manual testing of edge cases |

#### Acceptance Criteria

- [ ] Normal text lines appear in the popover output
- [ ] Toast event lines trigger a toast and do NOT appear in output
- [ ] Result/error event lines are consumed (logged) and do NOT appear in output
- [ ] Malformed JSON after the prefix logs an error and does not crash
- [ ] Empty payload after prefix is handled gracefully
- [ ] Unknown event types are silently ignored
- [ ] Lines that nearly match the prefix but don't are treated as normal text

---

## 5. Integration Points

- **CommandRunner stdout streaming:** Lines arrive via `readabilityHandler` callback on a background thread, routed to `PopoverViewModel` on `@MainActor` via `Task`
- **NSStatusItem button frame:** Used by `ToastWindow` to calculate toast position. The button's window frame is converted to screen coordinates for absolute positioning
- **Existing NSPopover:** The toast panel (`NSPanel`) is independent of the existing popover. Both can be visible simultaneously. The toast uses `.statusBar` level to float above the popover
- **AppKit run loop:** `Timer.scheduledTimer` is used for auto-dismiss. This runs on the main run loop, which is correct since all UI work is `@MainActor`

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

Write tests before implementation. Focus on the event model and parser — these are the most testable units.

```swift
// MenuBarCompanionTests/EventModelTests.swift
import XCTest
@testable import MenuBarCompanion

final class EventModelTests: XCTestCase {

    func testDecodeToastEvent() throws {
        let json = """
        {"type":"toast","title":"Done!","message":"Task complete"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(MenuBotEvent.self, from: json)
        if case .toast(let payload) = event {
            XCTAssertEqual(payload.title, "Done!")
            XCTAssertEqual(payload.message, "Task complete")
            XCTAssertNil(payload.action)
        } else {
            XCTFail("Expected toast event")
        }
    }

    func testDecodeToastWithAction() throws {
        let json = """
        {"type":"toast","title":"File ready","message":"output.txt","action":{"kind":"openFile","path":"/tmp/output.txt"}}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(MenuBotEvent.self, from: json)
        if case .toast(let payload) = event {
            if case .openFile(let path) = payload.action {
                XCTAssertEqual(path, "/tmp/output.txt")
            } else {
                XCTFail("Expected openFile action")
            }
        } else {
            XCTFail("Expected toast event")
        }
    }

    func testDecodeResultEvent() throws {
        let json = """
        {"type":"result","summary":"Created 2 files","artifacts":[{"label":"output.txt","path":"/tmp/output.txt"}]}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(MenuBotEvent.self, from: json)
        if case .result(let payload) = event {
            XCTAssertEqual(payload.summary, "Created 2 files")
            XCTAssertEqual(payload.artifacts.count, 1)
        } else {
            XCTFail("Expected result event")
        }
    }

    func testDecodeErrorEvent() throws {
        let json = """
        {"type":"error","message":"Permission denied","guidance":"Run with sudo"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(MenuBotEvent.self, from: json)
        if case .error(let payload) = event {
            XCTAssertEqual(payload.message, "Permission denied")
            XCTAssertEqual(payload.guidance, "Run with sudo")
        } else {
            XCTFail("Expected error event")
        }
    }

    func testMalformedJSONReturnsNil() {
        let result = EventParser.parseEvent(from: "{bad json}")
        XCTAssertNil(result)
    }

    func testUnknownTypeReturnsNil() {
        let result = EventParser.parseEvent(from: "{\"type\":\"unknown\"}")
        XCTAssertNil(result)
    }
}
```

```swift
// MenuBarCompanionTests/EventParserTests.swift
import XCTest
@testable import MenuBarCompanion

final class EventParserTests: XCTestCase {

    func testExtractPayloadFromEventLine() {
        let line = "[MENUBOT_EVENT] {\"type\":\"toast\",\"title\":\"Hi\",\"message\":\"World\"}"
        let payload = EventParser.extractPayload(from: line)
        XCTAssertNotNil(payload)
        XCTAssertTrue(payload!.contains("toast"))
    }

    func testExtractPayloadFromNonEventLine() {
        let line = "Just some normal output"
        XCTAssertNil(EventParser.extractPayload(from: line))
    }

    func testExtractPayloadFromEmptyEvent() {
        let line = "[MENUBOT_EVENT] "
        XCTAssertNil(EventParser.extractPayload(from: line))
    }

    func testExtractPayloadFromAlmostPrefix() {
        let line = "[MENUBOT_EVENT]{\"type\":\"toast\"}"
        XCTAssertNil(EventParser.extractPayload(from: line))
    }
}
```

### During Implementation: Build Against Tests

- Model decode tests will fail until `EventModels.swift` is created with correct Codable conformance
- Parser tests will fail until `EventParser.swift` is updated with the new static methods
- Use failing tests as progress indicators

### Phase End: Polish Tests

- Confirm all unit tests pass
- Manual verification covers the visual toast presentation (positioning, auto-dismiss, styling)
- Add any edge-case tests discovered during implementation

---

## 7. Definition of Done

- [ ] `EventModels.swift` defines `MenuBotEvent`, `ToastPayload`, `ResultPayload`, `ErrorPayload`, `EventAction` — all `Codable`
- [ ] `EventParser.swift` upgraded to static struct with `extractPayload(from:)` and `parseEvent(from:)` returning typed models
- [ ] `NotificationManager.swift` created, routes `.toast` to `ToastWindow`, logs `.result` / `.error`
- [ ] `ToastWindow.swift` and `ToastView.swift` created — toast appears near menu bar icon and auto-dismisses
- [ ] `AppDelegate.swift` creates `NotificationManager` and threads it to the view model
- [ ] `PopoverViewModel.swift` routes event lines through the new pipeline, non-event lines untouched
- [ ] Unit tests pass for event model decoding and parser extraction
- [ ] Manual verification: toast appears for toast events
- [ ] Manual verification: non-event output unaffected
- [ ] No build warnings

### Backward Compatibility

The only breaking change is to `EventParser`'s public API — the old `parse(_:)` → `String` method is replaced by `extractPayload(from:)` and `parseEvent(from:)`. `PopoverViewModel` is the sole consumer, and it is updated in Task 1.5. No external consumers exist.

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Phase 2 until all items below are verified.**

- [ ] **Build:** `xcodebuild -project MenuBarCompanion.xcodeproj -scheme MenuBarCompanion build` succeeds with zero errors
- [ ] **Tests:** `xcodebuild -project MenuBarCompanion.xcodeproj -scheme MenuBarCompanion test` passes all event model and parser tests
- [ ] **Manual — Toast:** Run the app. Trigger a command that emits `[MENUBOT_EVENT] {"type":"toast","title":"Hello","message":"World"}`. A toast bubble appears near the menu bar icon.
- [ ] **Manual — Auto-Dismiss:** The toast disappears after ~4 seconds without interaction.
- [ ] **Manual — Click Dismiss:** Click the toast. It dismisses immediately.
- [ ] **Manual — Non-Event Output:** Normal stdout text still appears in the popover output area.
- [ ] **Manual — Malformed Event:** A line like `[MENUBOT_EVENT] {bad}` does not crash the app.
- [ ] **Console — Result/Error:** A result or error event line produces a console log message (no UI yet).
- [ ] **Signoff:** All items above checked. Phase 1 of Objective 2 is complete.

---

## Appendix

### Project File Structure (after this phase)

```
MenuBarCompanion/
  App/
    MenuBarCompanionApp.swift
    AppDelegate.swift          ← modified: creates NotificationManager
    Info.plist
  UI/
    PopoverView.swift          ← modified: passes NotificationManager through
    PopoverViewModel.swift     ← modified: routes events through NotificationManager
    ToastView.swift            ← NEW: SwiftUI toast content view
    ToastWindow.swift          ← NEW: NSPanel-based toast window
  Core/
    CommandRunner.swift
    EventParser.swift          ← modified: Codable-based typed parsing
    EventModels.swift          ← NEW: MenuBotEvent, payloads, EventAction
    NotificationManager.swift  ← NEW: event coordinator
  Assets.xcassets/
  MenuBarCompanion.entitlements
```

### Example Event JSON Payloads

```json
// Toast (minimal)
{"type": "toast", "title": "Done!", "message": "Your task is complete."}

// Toast (with action)
{"type": "toast", "title": "File ready", "message": "output.txt created", "action": {"kind": "openFile", "path": "/Users/me/output.txt"}}

// Result
{"type": "result", "summary": "Created 3 files", "artifacts": [
  {"label": "index.html", "path": "/Users/me/project/index.html", "action": {"kind": "openFile", "path": "/Users/me/project/index.html"}},
  {"label": "style.css", "path": "/Users/me/project/style.css"}
]}

// Error
{"type": "error", "message": "Command failed with exit code 1", "guidance": "Check that the target directory exists and is writable."}
```

### EventAction JSON Encoding

```json
// openFile
{"kind": "openFile", "path": "/absolute/path/to/file"}

// openURL
{"kind": "openURL", "url": "https://example.com"}

// copyText
{"kind": "copyText", "text": "content to copy"}
```

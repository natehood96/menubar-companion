# Phase 6 — Eyes and Hands

- **Phase Number:** 6
- **Phase Name:** Eyes and Hands — Screen Vision, Input Control & Computer Control
- **Source:** docs/mvp/phases/overviews/objective6PhaseOverview.md

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

---

## 📋 Task Tracking Instructions

- Tasks use checkboxes
- Engineer checks off each task title with a ✅ emoji AFTER completing the work
- Engineer updates as they go
- Phase cannot advance until checklist complete
- If execution stops, checkmarks indicate progress

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Gives MenuBot the ability to capture screenshots, gather accessibility metadata about the user's screen, control mouse/keyboard via a CLI tool, and combine these into an autonomous vision-action loop packaged as the `computer-control` skill — all with strong safety guardrails.
- **What already exists:** Menu bar app with chat UI (`PopoverView`, `ChatViewModel`), orchestrator/doer architecture via Claude Code CLI, skills system (`Skill.swift`, `SkillsDirectoryManager.swift`, `OrchestrationBootstrap.swift`), event protocol, streaming JSON parser, `CommandRunner` for process execution. Skills are `.md` files indexed via `skills-index.json` in `~/Library/Application Support/MenuBot/skills/`.
- **What future phases depend on this:** Objective 7 needs the emergency stop shortcut registered at startup, `computer-control` skill seeded via `OrchestrationBootstrap`, `menubot-input` CLI built as an Xcode target, and permissions consolidated across features.

---

## 0. Mental Model (Required)

**Problem:** Users want MenuBot to see what's on their screen and interact with macOS applications autonomously — clicking buttons, filling forms, navigating UIs. This requires two new native macOS capabilities (screen capture + input control) and two new macOS permissions (Screen Recording + Accessibility).

**Where it fits:** This is the most self-contained objective. It depends only on the existing Phases 1–3 foundations (menu bar app, chat, skills, orchestrator/doer). Nothing else depends on it except Objective 7's startup sequence. It introduces the highest-risk feature (AI controlling mouse/keyboard), so safety guardrails are mandatory.

**Data flow:**
1. User sends a message (optionally with the "eye" toggle active, or with phrasing like "what's on my screen")
2. Orchestrator detects screen intent → calls `ScreenCaptureManager` to take a screenshot + `AccessibilityManager` to gather metadata
3. Screenshot path + metadata text are injected into the doer's prompt
4. For input control: the doer invokes `menubot-input` CLI via its Bash tool to click/type/scroll
5. For the vision-action loop: the doer repeats capture → analyze → act → wait → capture in a cycle
6. Safety layer: orchestrator prompts for confirmation before first action, emergency stop shortcut kills the doer, visual indicator shows automation is active, scope limits block dangerous targets

**Core entities:**
- `ScreenCaptureManager` — captures screenshots, manages Screen Recording permission
- `AccessibilityManager` — gathers AX metadata, manages Accessibility permission
- `menubot-input` CLI — standalone Swift binary for mouse/keyboard/scroll control via `CGEvent`
- `computer-control` skill — prompt that teaches the doer the vision-action loop pattern
- `SafetyManager` — confirmation flow, action counting, scope checks
- `EmergencyStop` — global shortcut registration and doer process termination

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Enable MenuBot to capture screenshots, gather screen metadata, control mouse/keyboard via a CLI tool, and autonomously interact with macOS applications through a vision-action loop — all gated by safety guardrails including confirmation prompts, emergency stop, and scope limits.

### Prerequisites

- Phases 1–3 complete (menu bar app, chat UI, skills system, orchestrator/doer architecture)
- `ChatViewModel` managing message flow and `CommandRunner` process execution
- `OrchestrationBootstrap` seeding skills on launch
- `SkillsDirectoryManager` scanning `skills-index.json` for available skills
- Xcode project with the `MenuBarCompanion` target, sandbox disabled, `LSUIElement=YES`
- macOS 13.0+ target

### Key Deliverables

- `ScreenCaptureManager.swift` — screenshot capture via `CGWindowListCreateImage` with permission flow and transient caching
- `AccessibilityManager.swift` — AX metadata gathering with permission flow
- Eye toggle in chat input UI for attaching screen context to messages
- `menubot-input` Swift CLI target — mouse, keyboard, and scroll primitives via `CGEvent`
- `computer-control` skill (`.md` file + index entry) for vision-action loop
- `SafetyManager.swift` — confirmation prompts, action counting, scope limits
- `EmergencyStop.swift` — global `Cmd+Shift+Escape` shortcut to halt automation
- `AutomationIndicator` — red dot on menu bar icon during active automation
- Cache directory management and cleanup in `AppDelegate`

### System-Level Acceptance Criteria

- Screenshot capture completes in under 500ms
- AX metadata queries timeout after 2 seconds without crashing
- Screen Recording and Accessibility permissions are requested with user-friendly explanations; denial is handled gracefully without nagging
- `menubot-input` CLI can perform mouse clicks, moves, drags, text typing, key combos, and scrolling
- Doers can invoke `menubot-input` from their Bash tool
- Vision-action loop works end-to-end for multi-step UI tasks
- User is always prompted for confirmation before the first input control action
- Emergency stop shortcut halts automation within 500ms
- Automation is blocked when targeting System Settings or when the screen is locked
- Maximum 100 actions per sequence before re-confirmation required
- A visual indicator is always visible when automation is actively controlling the screen

---

## 2. Execution Order

### Blocking Tasks

1. **Task 6A.1** — Screen Recording permission flow (required before any screenshot work)
2. **Task 6A.2** — Screenshot capture implementation
3. **Task 6A.3** — Screenshot caching
4. **Task 6A.4** — Performance verification
5. **Task 6A.5** — `ScreenCaptureManager` class
6. **Task 6B.1** — Accessibility permission flow
7. **Task 6B.2** — AX metadata gathering
8. **Task 6B.3** — `AccessibilityManager` class
9. **Task 6B.4** — Context assembly in orchestrator
10. **Task 6B.5** — Eye toggle in chat UI
11. **Task 6C.1–6C.7** — `menubot-input` CLI (independent of 6A/6B but ordered here)
12. **Task 6D.1–6D.5** — Vision-action loop and `computer-control` skill (depends on 6A+6B+6C)
13. **Task 6E.1–6E.6** — Safety system (depends on 6C+6D)

### Parallel Tasks

- **6A (Screenshots) and 6C (Input CLI)** can be built in parallel — they are independent capabilities
- **6A.3 (caching) and 6A.4 (performance)** can be validated in parallel once 6A.2 is done
- **6E.2 (emergency stop) and 6E.3 (visual indicator)** can be built in parallel

### Final Integration

- End-to-end test: user asks MenuBot to perform a multi-step UI task (e.g., "open TextEdit and type 'hello'") and the doer executes the full vision-action loop with safety prompts
- Verify emergency stop halts mid-loop automation
- Verify all permission flows work on a clean install (no prior grants)
- Verify cache cleanup on app quit
- Verify `menubot-input` binary is auto-installed on launch

---

## 3. Architectural Decisions

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Screenshot API | `CGWindowListCreateImage` vs `ScreenCaptureKit` | `CGWindowListCreateImage` | Broader macOS version support (13+). ScreenCaptureKit is 12.3+ but has a more complex API. Can upgrade later. | Older API may lack some features |
| Screenshot format | PNG vs JPEG | JPEG 80% quality | Balances file size with readability for Claude's vision. Reduces prompt/transfer overhead. | May lose fine detail — test early, switch to PNG if analysis suffers |
| Input control architecture | Embed in main app vs separate CLI | Separate CLI (`menubot-input`) | Doers call via Bash tool without Swift interop. Clean separation of concerns. | CLI must inherit Accessibility permission from parent app grant |
| Input control API | `CGEvent` vs Accessibility API `AXUIElementPerformAction` | `CGEvent` for mouse/keyboard | Standard low-level input API. Works across all apps. AX actions are app-specific. | CGEvent may not work with sandboxed/hardened apps |
| Emergency stop mechanism | Graceful signal vs process kill | Process kill (`terminate()`) | Safest — a runaway process should be terminated, not asked politely | May leave partial state; acceptable for safety |
| Safety enforcement | Orchestrator-only vs defense-in-depth | Both orchestrator AND CLI-level checks | Defense in depth — if orchestrator is bypassed, CLI still enforces limits | Slight complexity overhead |

---

## 4. Subtasks

### Task 6A.1 — Screen Recording Permission Flow

#### User Story

When the user first asks MenuBot to look at their screen, the app checks for Screen Recording permission. If not granted, it shows a friendly in-app explanation before triggering the system prompt. If the user denies, MenuBot shows a graceful fallback message and doesn't nag on subsequent requests (until the user explicitly tries again).

#### Implementation Steps

1. Create `MenuBarCompanion/Core/ScreenCaptureManager.swift`
2. Define a `PermissionStatus` enum:

```swift
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}
```

3. Implement permission checking:

```swift
func checkPermission() -> PermissionStatus {
    if CGPreflightScreenCaptureAccess() {
        return .granted
    }
    return .notDetermined // macOS doesn't distinguish denied vs not-asked for screen recording
}
```

4. Implement permission requesting:

```swift
func requestPermission() {
    CGRequestScreenCaptureAccess()
}
```

5. Add a `@Published var permissionDenied: Bool` flag. After requesting, re-check; if still not granted, set `permissionDenied = true`.
6. Add an in-app explanation method that returns a user-friendly string:

```swift
static let permissionExplanation = "To see your screen, I need Screen Recording permission. macOS will ask you to grant it — this lets me take screenshots when you ask me to look at something."
```

7. Cache permission status in-memory. Only re-check when a screen action is actually requested (not on every app launch).

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScreenCaptureManager.swift` | Create | Screen Recording permission check/request, screenshot capture, caching |

#### Acceptance Criteria

- [ ] `checkPermission()` returns `.granted` when Screen Recording is enabled
- [ ] `requestPermission()` triggers the macOS system prompt
- [ ] Denial is detected and stored; no repeated prompts until user explicitly retries
- [ ] Permission explanation string is available for UI display

---

### Task 6A.2 — Screenshot Capture Implementation

#### User Story

MenuBot can capture either the full screen or just the active window as an image, using macOS native APIs.

#### Implementation Steps

1. In `ScreenCaptureManager.swift`, implement full-screen capture:

```swift
func captureFullScreen() async throws -> URL {
    guard checkPermission() == .granted else {
        throw ScreenCaptureError.permissionDenied
    }
    guard let image = CGWindowListCreateImage(
        CGRect.null, // full display
        .optionOnScreenOnly,
        kCGNullWindowID,
        [.boundsIgnoreFraming]
    ) else {
        throw ScreenCaptureError.captureFailed
    }
    return try saveToCache(image)
}
```

2. Implement active-window capture:

```swift
func captureActiveWindow() async throws -> URL {
    guard checkPermission() == .granted else {
        throw ScreenCaptureError.permissionDenied
    }

    // Get frontmost app
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
        throw ScreenCaptureError.noActiveWindow
    }

    // Find the frontmost window for this app via CGWindowListCopyWindowInfo
    let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

    guard let window = windowList.first(where: {
        ($0[kCGWindowOwnerPID as String] as? Int32) == frontApp.processIdentifier &&
        ($0[kCGWindowLayer as String] as? Int) == 0
    }),
    let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
    let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
        // Fallback to full screen if we can't identify the window
        return try await captureFullScreen()
    }

    guard let image = CGWindowListCreateImage(
        bounds,
        .optionOnScreenBelowWindow,
        kCGNullWindowID,
        [.boundsIgnoreFraming]
    ) else {
        throw ScreenCaptureError.captureFailed
    }
    return try saveToCache(image)
}
```

3. Define error types:

```swift
enum ScreenCaptureError: Error, LocalizedError {
    case permissionDenied
    case captureFailed
    case noActiveWindow
    case cacheFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen Recording permission is required."
        case .captureFailed: return "Failed to capture screenshot."
        case .noActiveWindow: return "No active window found."
        case .cacheFailed: return "Failed to save screenshot to cache."
        }
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScreenCaptureManager.swift` | Modify | Add capture methods and error types |

#### Acceptance Criteria

- [ ] `captureFullScreen()` returns a URL to a saved screenshot of the entire display
- [ ] `captureActiveWindow()` returns a URL to a saved screenshot of just the frontmost window
- [ ] Both methods throw `permissionDenied` if Screen Recording is not granted
- [ ] Active window capture falls back to full screen if the window can't be identified

---

### Task 6A.3 — Screenshot Caching

#### User Story

Screenshots are stored temporarily as JPEG files in a cache directory, automatically cleaned on app quit and periodically for files older than 1 hour.

#### Implementation Steps

1. In `ScreenCaptureManager.swift`, define the cache directory:

```swift
static let cacheDirectory: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("MenuBot/cache/screenshots", isDirectory: true)
}()
```

2. Implement `saveToCache(_:)`:

```swift
private func saveToCache(_ cgImage: CGImage) throws -> URL {
    let fm = FileManager.default
    if !fm.fileExists(atPath: Self.cacheDirectory.path) {
        try fm.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
    }

    let filename = UUID().uuidString + ".jpg"
    let fileURL = Self.cacheDirectory.appendingPathComponent(filename)

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
        throw ScreenCaptureError.cacheFailed
    }
    try jpegData.write(to: fileURL)
    return fileURL
}
```

3. Implement cache cleanup:

```swift
static func cleanCache() {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
    for file in files {
        try? fm.removeItem(at: file)
    }
}

static func cleanExpiredCache() {
    let fm = FileManager.default
    let cutoff = Date().addingTimeInterval(-3600) // 1 hour
    guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
    for file in files {
        if let attrs = try? fm.attributesOfItem(atPath: file.path),
           let created = attrs[.creationDate] as? Date,
           created < cutoff {
            try? fm.removeItem(at: file)
        }
    }
}
```

4. In `AppDelegate.swift`, add cleanup on quit:

```swift
func applicationWillTerminate(_ notification: Notification) {
    ScreenCaptureManager.cleanCache()
}
```

5. Start a periodic timer in `ScreenCaptureManager.init()` to clean expired screenshots every 15 minutes:

```swift
private var cleanupTimer: Timer?

func startCleanupTimer() {
    cleanupTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
        Self.cleanExpiredCache()
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScreenCaptureManager.swift` | Modify | Add caching and cleanup methods |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Add `applicationWillTerminate` for cache cleanup |

#### Acceptance Criteria

- [ ] Screenshots are saved as JPEG (80% quality) in `~/Library/Application Support/MenuBot/cache/screenshots/`
- [ ] Cache directory is created on first use
- [ ] All cached screenshots are deleted on app quit
- [ ] Screenshots older than 1 hour are cleaned by the periodic timer
- [ ] `applicationWillTerminate` is wired up in `AppDelegate`

---

### Task 6A.4 — Performance Verification

#### User Story

Screenshot capture must complete in under 500ms to maintain a responsive user experience.

#### Implementation Steps

1. Add timing instrumentation to both capture methods:

```swift
func captureActiveWindow() async throws -> URL {
    let start = CFAbsoluteTimeGetCurrent()
    // ... existing capture logic ...
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    print("[ScreenCaptureManager] Active window capture took \(String(format: "%.0f", elapsed * 1000))ms")
    if elapsed > 0.5 {
        print("[ScreenCaptureManager] WARNING: Capture exceeded 500ms target")
    }
    return url
}
```

2. Test with various window sizes and monitor configurations
3. If capture exceeds 500ms, investigate:
   - Reduce JPEG quality to 60%
   - Skip window identification and capture full screen
   - Profile the `CGWindowListCreateImage` call vs the JPEG encoding

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScreenCaptureManager.swift` | Modify | Add timing instrumentation |

#### Acceptance Criteria

- [ ] Both capture methods log their execution time
- [ ] Full-screen capture completes in under 500ms
- [ ] Active-window capture completes in under 500ms
- [ ] Warning is logged if capture exceeds the 500ms threshold

---

### Task 6A.5 — ScreenCaptureManager Class Assembly

#### User Story

A clean `ScreenCaptureManager` class exposes the complete public API for screenshot capture, permission management, and caching — ready for use by the orchestrator and UI.

#### Implementation Steps

1. Finalize `ScreenCaptureManager` as an `@MainActor` class (or at least thread-safe for the capture methods):

```swift
import AppKit
import CoreGraphics

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()

    // Permission
    func checkPermission() -> PermissionStatus { ... }
    func requestPermission() { ... }
    static let permissionExplanation: String = ...

    // Capture
    func captureFullScreen() async throws -> URL { ... }
    func captureActiveWindow() async throws -> URL { ... }

    // Cache
    static func cleanCache() { ... }
    static func cleanExpiredCache() { ... }
    func startCleanupTimer() { ... }

    private init() {
        startCleanupTimer()
    }
}
```

2. Ensure the class is a singleton so the cleanup timer and permission state are shared
3. Add the file to the Xcode project's `Core` group and `Sources` build phase in `project.pbxproj`

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/ScreenCaptureManager.swift` | Modify | Finalize class structure and singleton |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add `ScreenCaptureManager.swift` to build |

#### Acceptance Criteria

- [ ] `ScreenCaptureManager.shared` is accessible throughout the app
- [ ] All public methods are documented
- [ ] File is added to Xcode project and builds without errors

---

### Task 6B.1 — Accessibility Permission Flow

#### User Story

When MenuBot needs to gather screen metadata or control input, it checks for Accessibility permission. If not granted, it shows a friendly explanation and guides the user to System Settings. Denial is handled gracefully.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/AccessibilityManager.swift`
2. Implement permission checking:

```swift
import AppKit
import ApplicationServices

final class AccessibilityManager {
    static let shared = AccessibilityManager()

    func checkPermission() -> PermissionStatus {
        if AXIsProcessTrusted() {
            return .granted
        }
        return .notDetermined
    }

    func requestPermission() {
        // This opens System Settings > Privacy & Security > Accessibility with our app highlighted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static let permissionExplanation = "To read screen details and control your computer, I need Accessibility permission. macOS will guide you to grant it in System Settings > Privacy & Security > Accessibility."

    private init() {}
}
```

3. Add to Xcode project's `Core` group and `Sources` build phase

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/AccessibilityManager.swift` | Create | Accessibility permission check/request and metadata gathering |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add `AccessibilityManager.swift` to build |

#### Acceptance Criteria

- [ ] `checkPermission()` returns `.granted` when Accessibility is enabled for the app
- [ ] `requestPermission()` opens System Settings with the app highlighted
- [ ] Permission explanation string is available for UI display
- [ ] File builds without errors in Xcode

---

### Task 6B.2 — Accessibility Metadata Gathering

#### User Story

MenuBot gathers structured metadata about the user's screen via the Accessibility API — the active app name, window title, focused element text, and window hierarchy — to complement screenshots with machine-readable context.

#### Implementation Steps

1. Define the metadata struct:

```swift
struct ScreenMetadata {
    let activeAppName: String
    let activeAppBundleID: String?
    let windowTitle: String?
    let focusedElementText: String?
    let focusedElementRole: String?
    let selectedText: String?
    let windowList: [(appName: String, title: String)]

    var formattedDescription: String {
        var parts: [String] = []
        parts.append("Active App: \(activeAppName)")
        if let bid = activeAppBundleID { parts.append("Bundle ID: \(bid)") }
        if let title = windowTitle { parts.append("Window Title: \(title)") }
        if let focused = focusedElementText { parts.append("Focused Element: \(focused)") }
        if let role = focusedElementRole { parts.append("Element Role: \(role)") }
        if let selected = selectedText { parts.append("Selected Text: \(selected)") }
        if !windowList.isEmpty {
            parts.append("Visible Windows:")
            for (app, title) in windowList {
                parts.append("  - \(app): \(title)")
            }
        }
        return parts.joined(separator: "\n")
    }
}
```

2. Implement metadata gathering in `AccessibilityManager`:

```swift
func gatherMetadata() async throws -> ScreenMetadata {
    guard checkPermission() == .granted else {
        throw AccessibilityError.permissionDenied
    }

    // Use a timeout wrapper
    return try await withThrowingTaskGroup(of: ScreenMetadata.self) { group in
        group.addTask {
            return self.gatherMetadataSync()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
            throw AccessibilityError.timeout
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

private func gatherMetadataSync() -> ScreenMetadata {
    let workspace = NSWorkspace.shared
    let frontApp = workspace.frontmostApplication
    let appName = frontApp?.localizedName ?? "Unknown"
    let bundleID = frontApp?.bundleIdentifier

    // Get AX element for the frontmost app
    var windowTitle: String?
    var focusedText: String?
    var focusedRole: String?
    var selectedText: String?

    if let pid = frontApp?.processIdentifier {
        let appElement = AXUIElementCreateApplication(pid)

        // Window title
        var windowValue: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
           let window = windowValue {
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success {
                windowTitle = titleValue as? String
            }
        }

        // Focused element
        var focusedValue: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
           let focused = focusedValue {
            let focusedElement = focused as! AXUIElement

            var roleValue: AnyObject?
            if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleValue) == .success {
                focusedRole = roleValue as? String
            }

            var valueObj: AnyObject?
            if AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueObj) == .success {
                focusedText = valueObj as? String
            }

            var selectedObj: AnyObject?
            if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedObj) == .success {
                selectedText = selectedObj as? String
            }
        }
    }

    // Window hierarchy from CGWindowList
    let windowList: [(String, String)] = {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let name = info[kCGWindowName as String] as? String,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  !name.isEmpty else { return nil }
            return (ownerName, name)
        }
    }()

    return ScreenMetadata(
        activeAppName: appName,
        activeAppBundleID: bundleID,
        windowTitle: windowTitle,
        focusedElementText: focusedText,
        focusedElementRole: focusedRole,
        selectedText: selectedText,
        windowList: windowList
    )
}
```

3. Define error types:

```swift
enum AccessibilityError: Error, LocalizedError {
    case permissionDenied
    case timeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Accessibility permission is required."
        case .timeout: return "Accessibility query timed out after 2 seconds."
        }
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/AccessibilityManager.swift` | Modify | Add `ScreenMetadata` struct and `gatherMetadata()` method |

#### Acceptance Criteria

- [ ] `gatherMetadata()` returns a `ScreenMetadata` with at minimum: app name, window title, focused element
- [ ] AX queries timeout after 2 seconds without crashing
- [ ] Window hierarchy lists visible windows with app names and titles
- [ ] `formattedDescription` produces a clean text summary for prompt injection

---

### Task 6B.3 — AccessibilityManager Class Assembly

#### User Story

The `AccessibilityManager` class is complete with permission management and metadata gathering, ready for use by the orchestrator.

#### Implementation Steps

1. Ensure `AccessibilityManager` singleton pattern is clean:

```swift
final class AccessibilityManager {
    static let shared = AccessibilityManager()

    func checkPermission() -> PermissionStatus { ... }
    func requestPermission() { ... }
    func gatherMetadata() async throws -> ScreenMetadata { ... }
    static let permissionExplanation: String = ...

    private init() {}
}
```

2. Verify the `PermissionStatus` enum is shared between `ScreenCaptureManager` and `AccessibilityManager`. If both files define it, extract to a shared location or define it once in a common file (e.g., `ScreenCaptureManager.swift` since it's created first, and import from there — or create a small `PermissionStatus.swift`).

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/AccessibilityManager.swift` | Modify | Finalize class structure |

#### Acceptance Criteria

- [ ] `AccessibilityManager.shared` is accessible throughout the app
- [ ] `PermissionStatus` enum is shared (not duplicated) between managers
- [ ] File builds without errors

---

### Task 6B.4 — Context Assembly in Orchestrator

#### User Story

When the user asks about their screen (or has the eye toggle active), the orchestrator captures a screenshot and gathers accessibility metadata, then bundles both into the Claude Code prompt sent to the doer.

#### Implementation Steps

1. In `ChatViewModel.swift`, add a `@Published var screenContextEnabled: Bool = false` property for the eye toggle state.

2. Add a method to assemble screen context:

```swift
private func assembleScreenContext() async -> String? {
    let captureManager = ScreenCaptureManager.shared
    let accessibilityManager = AccessibilityManager.shared

    // Check permissions first
    if captureManager.checkPermission() != .granted {
        captureManager.requestPermission()
        return nil
    }

    do {
        let screenshotURL = try await captureManager.captureActiveWindow()
        var contextParts: [String] = []
        contextParts.append("Screenshot saved to: \(screenshotURL.path)")
        contextParts.append("Read this image file to see what's on the user's screen.")

        if accessibilityManager.checkPermission() == .granted {
            let metadata = try await accessibilityManager.gatherMetadata()
            contextParts.append("\nScreen Metadata:\n\(metadata.formattedDescription)")
        }

        return contextParts.joined(separator: "\n")
    } catch {
        print("[ChatViewModel] Screen context assembly failed: \(error)")
        return nil
    }
}
```

3. Modify `sendMessage()` to detect screen intent or check the toggle:

```swift
func sendMessage() {
    let trimmed = inputText.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !isRunning else { return }

    let userMessage = ChatMessage(role: .user, content: trimmed)
    messages.append(userMessage)
    inputText = ""

    let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
    messages.append(assistantMessage)
    isRunning = true

    lineBuffer = ""
    currentLineIsUserFacing = false

    let shouldAttachScreenContext = screenContextEnabled || detectsScreenIntent(trimmed)
    // Reset toggle after use
    if screenContextEnabled { screenContextEnabled = false }

    Task {
        var screenContext: String? = nil
        if shouldAttachScreenContext {
            screenContext = await assembleScreenContext()
        }
        await startCommand(for: trimmed, screenContext: screenContext)
    }
}
```

4. Add intent detection:

```swift
private func detectsScreenIntent(_ text: String) -> Bool {
    let lowered = text.lowercased()
    let screenPhrases = [
        "look at my screen", "what's on my screen", "what am i looking at",
        "what's this", "what is this", "what do you see", "screen",
        "what app is this", "what error", "read my screen", "see my screen"
    ]
    return screenPhrases.contains(where: { lowered.contains($0) })
}
```

5. Modify `buildCommand` to accept and inject screen context:

```swift
private func buildCommand(for input: String, screenContext: String? = nil) -> (executable: String, arguments: [String]) {
    if let claudePath {
        var prompt = "/menubot-orchestrator The claude binary is at: \(claudePath). Use this full path when launching doers. \(input)"
        if let ctx = screenContext {
            prompt += "\n\n[SCREEN CONTEXT]\n\(ctx)\n[/SCREEN CONTEXT]"
        }
        return (claudePath, [
            "--dangerously-skip-permissions",
            "--permission-mode", "bypassPermissions",
            "--output-format", "stream-json",
            "--verbose",
            "-p", prompt
        ])
    }
    return ("/bin/sh", ["-c", input])
}

private func startCommand(for input: String, screenContext: String?) {
    let command = buildCommand(for: input, screenContext: screenContext)

    runner = CommandRunner(
        command: command.executable,
        arguments: command.arguments
    )

    runner?.start(
        onOutput: { [weak self] line in
            Task { @MainActor in
                self?.handleOutputLine(line)
            }
        },
        onComplete: { [weak self] exitCode in
            Task { @MainActor in
                self?.finishRun(exitCode: exitCode)
            }
        }
    )
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Add `screenContextEnabled`, `assembleScreenContext()`, `detectsScreenIntent()`, modify `sendMessage()` and `buildCommand()` |

#### Acceptance Criteria

- [ ] Messages with the eye toggle active include screen context in the doer prompt
- [ ] Messages with screen-related phrases auto-attach screen context
- [ ] Screen context includes both screenshot path and accessibility metadata
- [ ] Permission is requested on first use if not granted
- [ ] Toggle resets to off after sending a message with it active

---

### Task 6B.5 — Eye Toggle in Chat UI

#### User Story

The chat input area has a small "eye" icon button. When active (highlighted), the current message will include screen context. A subtle indicator appears on message bubbles that included screen context.

#### Implementation Steps

1. In `PopoverView.swift`, modify the `inputBar` to add the eye toggle before the text field:

```swift
private var inputBar: some View {
    HStack(spacing: 8) {
        // Eye toggle for screen context
        Button {
            viewModel.screenContextEnabled.toggle()
        } label: {
            Image(systemName: viewModel.screenContextEnabled ? "eye.fill" : "eye")
                .font(.body)
                .foregroundStyle(viewModel.screenContextEnabled ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .help("Attach screen context to this message")

        TextField("Message...", text: $viewModel.inputText, axis: .vertical)
            // ... existing styling ...

        // ... existing send/cancel buttons ...
    }
}
```

2. In `ChatMessage.swift`, add a `hasScreenContext` property:

```swift
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var hasScreenContext: Bool

    init(role: MessageRole, content: String, isStreaming: Bool = false, hasScreenContext: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isStreaming = isStreaming
        self.hasScreenContext = hasScreenContext
    }
}
```

3. In `ChatBubbleView.swift`, add a subtle screen indicator for messages with screen context:

```swift
// After the message text, if hasScreenContext:
if message.hasScreenContext {
    HStack(spacing: 2) {
        Image(systemName: "eye.fill")
            .font(.caption2)
        Text("Screen context")
            .font(.caption2)
    }
    .foregroundStyle(.secondary)
    .padding(.top, 2)
}
```

4. In `ChatViewModel.sendMessage()`, set `hasScreenContext` on the user message when screen context is being attached.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Add eye toggle button to input bar |
| `MenuBarCompanion/Core/ChatMessage.swift` | Modify | Add `hasScreenContext` property |
| `MenuBarCompanion/UI/ChatBubbleView.swift` | Modify | Add screen context indicator |
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Set `hasScreenContext` on user messages |

#### Acceptance Criteria

- [ ] Eye icon button is visible in the chat input bar
- [ ] Tapping the eye button toggles it on/off with visual feedback (filled vs outline)
- [ ] User messages sent with screen context show a subtle "Screen context" indicator
- [ ] `hasScreenContext` persists correctly in chat history (Codable)

---

### Task 6C.1 — Create menubot-input CLI Target

#### User Story

A new Swift CLI target `menubot-input` is added to the Xcode project, producing a standalone executable that can be invoked from the shell.

#### Implementation Steps

1. Create the directory `MenuBarCompanion/menubot-input/`
2. Create `MenuBarCompanion/menubot-input/main.swift` with a basic entry point:

```swift
import Foundation

// Entry point for menubot-input CLI
let args = CommandLine.arguments
guard args.count >= 2 else {
    printUsage()
    exit(1)
}

let command = args[1]
let remainingArgs = Array(args.dropFirst(2))

do {
    switch command {
    case "mouse_move":
        try MouseControl.move(args: remainingArgs)
    case "mouse_click":
        try MouseControl.click(args: remainingArgs)
    case "mouse_drag":
        try MouseControl.drag(args: remainingArgs)
    case "key_type":
        try KeyboardControl.type(args: remainingArgs)
    case "key_press":
        try KeyboardControl.press(args: remainingArgs)
    case "scroll":
        try ScrollControl.scroll(args: remainingArgs)
    case "--help", "-h", "help":
        printUsage()
    default:
        print("Error: Unknown command '\(command)'")
        printUsage()
        exit(1)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}

func printUsage() {
    print("""
    Usage: menubot-input <command> [options]

    Commands:
      mouse_move   --x <int> --y <int>
      mouse_click  --x <int> --y <int> [--button left|right] [--count 1|2]
      mouse_drag   --x1 <int> --y1 <int> --x2 <int> --y2 <int>
      key_type     --text <string>
      key_press    --key <key_name> [--modifiers <comma-separated>]
      scroll       --x <int> --y <int> --dx <int> --dy <int>
      help         Show this help message
    """)
}
```

3. Add a new CLI target to the Xcode project:
   - In `project.pbxproj`, add a new native target of type `com.apple.product-type.tool`
   - Product name: `menubot-input`
   - Add `main.swift`, `MouseControl.swift`, `KeyboardControl.swift`, `ScrollControl.swift` to the new target's Sources build phase
   - Set deployment target to macOS 13.0
   - Disable sandboxing for the CLI target

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/menubot-input/main.swift` | Create | CLI entry point with command routing |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add `menubot-input` CLI target |

#### Acceptance Criteria

- [ ] `menubot-input` target exists in Xcode and builds successfully
- [ ] Running `menubot-input --help` prints usage information
- [ ] Unknown commands produce an error message and usage info

---

### Task 6C.2 — Mouse Control Primitives

#### User Story

The `menubot-input` CLI can move the mouse cursor, click (left/right, single/double), and drag from one point to another.

#### Implementation Steps

1. Create `MenuBarCompanion/menubot-input/MouseControl.swift`:

```swift
import CoreGraphics
import Foundation

enum MouseControl {
    static func move(args: [String]) throws {
        let params = try parseArgs(args, required: ["x", "y"])
        let x = try requireInt(params, key: "x")
        let y = try requireInt(params, key: "y")
        let point = CGPoint(x: x, y: y)

        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
            throw InputError.eventCreationFailed
        }
        event.post(tap: .cghidEventTap)
        print("Moved mouse to (\(x), \(y))")
    }

    static func click(args: [String]) throws {
        let params = try parseArgs(args, required: ["x", "y"])
        let x = try requireInt(params, key: "x")
        let y = try requireInt(params, key: "y")
        let button = params["button"] ?? "left"
        let count = Int(params["count"] ?? "1") ?? 1
        let point = CGPoint(x: x, y: y)

        let mouseButton: CGMouseButton = button == "right" ? .right : .left
        let downType: CGEventType = button == "right" ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = button == "right" ? .rightMouseUp : .leftMouseUp

        for clickNum in 1...count {
            guard let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: mouseButton),
                  let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: mouseButton) else {
                throw InputError.eventCreationFailed
            }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickNum))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(clickNum))
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            if clickNum < count {
                usleep(50_000) // 50ms between clicks for double-click
            }
        }
        print("Clicked \(button) button at (\(x), \(y)) \(count) time(s)")
    }

    static func drag(args: [String]) throws {
        let params = try parseArgs(args, required: ["x1", "y1", "x2", "y2"])
        let x1 = try requireInt(params, key: "x1")
        let y1 = try requireInt(params, key: "y1")
        let x2 = try requireInt(params, key: "x2")
        let y2 = try requireInt(params, key: "y2")
        let start = CGPoint(x: x1, y: y1)
        let end = CGPoint(x: x2, y: y2)

        // Mouse down at start
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left) else {
            throw InputError.eventCreationFailed
        }
        down.post(tap: .cghidEventTap)
        usleep(50_000)

        // Drag to end
        guard let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: end, mouseButton: .left) else {
            throw InputError.eventCreationFailed
        }
        drag.post(tap: .cghidEventTap)
        usleep(50_000)

        // Mouse up at end
        guard let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left) else {
            throw InputError.eventCreationFailed
        }
        up.post(tap: .cghidEventTap)
        print("Dragged from (\(x1), \(y1)) to (\(x2), \(y2))")
    }
}
```

2. Create `MenuBarCompanion/menubot-input/InputHelpers.swift` for shared argument parsing:

```swift
import Foundation

enum InputError: Error, LocalizedError {
    case missingArgument(String)
    case invalidValue(String, String)
    case eventCreationFailed
    case actionLimitExceeded
    case blockedTarget(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name): return "Missing required argument: --\(name)"
        case .invalidValue(let name, let value): return "Invalid value for --\(name): \(value)"
        case .eventCreationFailed: return "Failed to create CGEvent"
        case .actionLimitExceeded: return "Action limit exceeded (max 100 per sequence)"
        case .blockedTarget(let app): return "Input control blocked for \(app)"
        }
    }
}

func parseArgs(_ args: [String], required: [String]) throws -> [String: String] {
    var result: [String: String] = [:]
    var i = 0
    while i < args.count {
        let arg = args[i]
        if arg.hasPrefix("--"), i + 1 < args.count {
            let key = String(arg.dropFirst(2))
            result[key] = args[i + 1]
            i += 2
        } else {
            i += 1
        }
    }
    for req in required {
        guard result[req] != nil else {
            throw InputError.missingArgument(req)
        }
    }
    return result
}

func requireInt(_ params: [String: String], key: String) throws -> Int {
    guard let str = params[key], let value = Int(str) else {
        throw InputError.invalidValue(key, params[key] ?? "nil")
    }
    return value
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/menubot-input/MouseControl.swift` | Create | Mouse move, click, drag via CGEvent |
| `MenuBarCompanion/menubot-input/InputHelpers.swift` | Create | Shared arg parsing and error types |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add files to menubot-input target |

#### Acceptance Criteria

- [ ] `menubot-input mouse_move --x 500 --y 300` moves the cursor to (500, 300)
- [ ] `menubot-input mouse_click --x 500 --y 300 --button left` clicks at (500, 300)
- [ ] `menubot-input mouse_click --x 500 --y 300 --button right --count 2` right-double-clicks
- [ ] `menubot-input mouse_drag --x1 100 --y1 100 --x2 500 --y2 500` drags between points
- [ ] Missing required arguments produce clear error messages

---

### Task 6C.3 — Keyboard Control Primitives

#### User Story

The `menubot-input` CLI can type arbitrary text strings and press key combinations with modifiers.

#### Implementation Steps

1. Create `MenuBarCompanion/menubot-input/KeyboardControl.swift`:

```swift
import CoreGraphics
import Foundation

enum KeyboardControl {
    static func type(args: [String]) throws {
        let params = try parseArgs(args, required: ["text"])
        guard let text = params["text"] else {
            throw InputError.missingArgument("text")
        }

        for char in text {
            let str = String(char)
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
                throw InputError.eventCreationFailed
            }
            event.keyboardSetUnicodeString(string: str)
            event.post(tap: .cghidEventTap)

            guard let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                throw InputError.eventCreationFailed
            }
            upEvent.keyboardSetUnicodeString(string: str)
            upEvent.post(tap: .cghidEventTap)

            usleep(10_000) // 10ms between keystrokes
        }
        print("Typed \(text.count) characters")
    }

    static func press(args: [String]) throws {
        let params = try parseArgs(args, required: ["key"])
        guard let keyName = params["key"] else {
            throw InputError.missingArgument("key")
        }
        let modifierStr = params["modifiers"] ?? ""

        guard let keyCode = keyCodeForName(keyName) else {
            throw InputError.invalidValue("key", keyName)
        }

        let modifierFlags = parseModifiers(modifierStr)

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw InputError.eventCreationFailed
        }

        down.flags = modifierFlags
        up.flags = modifierFlags

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        let modDesc = modifierStr.isEmpty ? "" : " with modifiers [\(modifierStr)]"
        print("Pressed key '\(keyName)'\(modDesc)")
    }

    // MARK: - Key Code Mapping

    private static func keyCodeForName(_ name: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "return": 0x24, "enter": 0x24, "tab": 0x30, "space": 0x31,
            "delete": 0x33, "backspace": 0x33, "escape": 0x35, "esc": 0x35,
            "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
            "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
            "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
            "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,
            "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06,
            "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
            "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
        ]
        return map[name.lowercased()]
    }

    private static func parseModifiers(_ str: String) -> CGEventFlags {
        guard !str.isEmpty else { return [] }
        var flags: CGEventFlags = []
        for mod in str.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) {
            switch mod {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        return flags
    }
}

// MARK: - CGEvent Unicode Extension

extension CGEvent {
    func keyboardSetUnicodeString(string: String) {
        let utf16 = Array(string.utf16)
        keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/menubot-input/KeyboardControl.swift` | Create | Key typing and key press with modifiers via CGEvent |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add file to menubot-input target |

#### Acceptance Criteria

- [ ] `menubot-input key_type --text "hello world"` types the text into the focused field
- [ ] `menubot-input key_press --key c --modifiers cmd` performs Cmd+C
- [ ] `menubot-input key_press --key return` presses Enter
- [ ] `menubot-input key_press --key a --modifiers cmd,shift` performs Cmd+Shift+A
- [ ] All common key names are supported (return, tab, space, delete, escape, arrow keys, letters, digits, F-keys)

---

### Task 6C.4 — Scroll Primitive

#### User Story

The `menubot-input` CLI can scroll at specified screen coordinates in both horizontal and vertical directions.

#### Implementation Steps

1. Create `MenuBarCompanion/menubot-input/ScrollControl.swift`:

```swift
import CoreGraphics
import Foundation

enum ScrollControl {
    static func scroll(args: [String]) throws {
        let params = try parseArgs(args, required: ["x", "y", "dy"])
        let x = try requireInt(params, key: "x")
        let y = try requireInt(params, key: "y")
        let dy = try requireInt(params, key: "dy")
        let dx = Int(params["dx"] ?? "0") ?? 0
        let point = CGPoint(x: x, y: y)

        // Move cursor to position first
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
            usleep(10_000) // Brief pause for cursor to settle
        }

        // Create scroll event
        guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx)) else {
            throw InputError.eventCreationFailed
        }
        scrollEvent.post(tap: .cghidEventTap)
        print("Scrolled at (\(x), \(y)) dx=\(dx) dy=\(dy)")
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/menubot-input/ScrollControl.swift` | Create | Scroll primitive via CGEvent |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add file to menubot-input target |

#### Acceptance Criteria

- [ ] `menubot-input scroll --x 500 --y 300 --dy -3` scrolls down at (500, 300)
- [ ] `menubot-input scroll --x 500 --y 300 --dy 3` scrolls up
- [ ] `menubot-input scroll --x 500 --y 300 --dx 3 --dy 0` scrolls horizontally
- [ ] `--dx` defaults to 0 if not provided

---

### Task 6C.5 — Argument Parsing and Help Output

#### User Story

The CLI provides clear error messages for missing or invalid arguments and comprehensive `--help` output.

#### Implementation Steps

1. This is already implemented in `main.swift` (`printUsage()`) and `InputHelpers.swift` (`parseArgs`, `requireInt`, `InputError`).
2. Verify and enhance:
   - Each command's `--help` subsection shows all parameters
   - Error messages clearly state which argument is missing/invalid
   - Exit code is 1 on error, 0 on success
3. Add per-command help if a command is called with `--help`:

```swift
// In main.swift, before the switch:
if remainingArgs.contains("--help") || remainingArgs.contains("-h") {
    printCommandHelp(command)
    exit(0)
}

func printCommandHelp(_ command: String) {
    switch command {
    case "mouse_move":
        print("Usage: menubot-input mouse_move --x <int> --y <int>")
        print("  Move the cursor to the specified screen coordinates.")
    case "mouse_click":
        print("Usage: menubot-input mouse_click --x <int> --y <int> [--button left|right] [--count 1|2]")
        print("  Click at the specified coordinates.")
        print("  --button: left (default) or right")
        print("  --count: 1 (default) for single-click, 2 for double-click")
    // ... etc for each command
    default:
        printUsage()
    }
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/menubot-input/main.swift` | Modify | Add per-command help output |

#### Acceptance Criteria

- [ ] `menubot-input --help` shows all commands with their parameters
- [ ] `menubot-input mouse_click --help` shows detailed help for the click command
- [ ] Missing `--x` on `mouse_move` prints "Missing required argument: --x"
- [ ] Invalid values produce clear error messages

---

### Task 6C.6 — CLI Binary Installation

#### User Story

On app launch, MenuBot copies the built `menubot-input` binary to `~/Library/Application Support/MenuBot/bin/` so doers can find it at a known path.

#### Implementation Steps

1. In `OrchestrationBootstrap.swift`, add CLI installation logic:

```swift
// In install():
let binDir = menubotDir.appendingPathComponent("bin", isDirectory: true)
try? fm.createDirectory(at: binDir, withIntermediateDirectories: true)
installInputCLI(to: binDir)

// New method:
private static func installInputCLI(to binDir: URL) {
    let fm = FileManager.default
    let destURL = binDir.appendingPathComponent("menubot-input")

    // Find the built binary in the app bundle
    guard let bundledBinary = Bundle.main.url(forResource: "menubot-input", withExtension: nil, subdirectory: "bin")
          ?? Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("menubot-input") else {
        print("[OrchestrationBootstrap] menubot-input binary not found in bundle")
        return
    }

    // Copy if missing or different size (simple version check)
    let shouldCopy: Bool
    if fm.fileExists(atPath: destURL.path) {
        let srcSize = (try? fm.attributesOfItem(atPath: bundledBinary.path)[.size] as? Int) ?? 0
        let dstSize = (try? fm.attributesOfItem(atPath: destURL.path)[.size] as? Int) ?? -1
        shouldCopy = srcSize != dstSize
    } else {
        shouldCopy = true
    }

    if shouldCopy {
        try? fm.removeItem(at: destURL)
        do {
            try fm.copyItem(at: bundledBinary, to: destURL)
            // Ensure executable permission
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)
            print("[OrchestrationBootstrap] Installed menubot-input to \(destURL.path)")
        } catch {
            print("[OrchestrationBootstrap] Failed to install menubot-input: \(error)")
        }
    }
}
```

2. Configure Xcode to copy the `menubot-input` product into the main app bundle:
   - Add a "Copy Files" build phase to the `MenuBarCompanion` target
   - Destination: "Executables" or a custom `bin/` subdirectory in the bundle
   - Copy the `menubot-input` product

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add `installInputCLI` method and call from `install()` |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add "Copy Files" build phase for `menubot-input` binary |

#### Acceptance Criteria

- [ ] On app launch, `menubot-input` binary exists at `~/Library/Application Support/MenuBot/bin/menubot-input`
- [ ] The binary is executable (755 permissions)
- [ ] If the binary is outdated (different size), it is replaced
- [ ] If the binary is already current, it is not re-copied

---

### Task 6C.7 — Doer Invocation Verification

#### User Story

A doer session (Claude Code subprocess) can invoke `menubot-input` commands from its Bash tool successfully.

#### Implementation Steps

1. Verify the `menubot-input` path is communicated to doers. The orchestrator skill prompt should include the path:

```
The menubot-input CLI is available at: ~/Library/Application Support/MenuBot/bin/menubot-input
Use it for mouse, keyboard, and scroll control. Run `menubot-input --help` for usage.
```

2. Update the orchestrator skill prompt (`menubot-orchestrator-SKILL.md`) to include this information.
3. Test that a doer can run:
   ```bash
   ~/Library/Application\ Support/MenuBot/bin/menubot-input mouse_move --x 100 --y 100
   ```
4. Verify the output is captured correctly by the doer.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/menubot-orchestrator-SKILL.md` | Modify | Add `menubot-input` path and usage to orchestrator prompt |

#### Acceptance Criteria

- [ ] A doer subprocess can invoke `menubot-input` and receive its stdout output
- [ ] The orchestrator skill prompt documents the `menubot-input` CLI path
- [ ] `menubot-input` works when invoked from a non-interactive shell (as doers use)

---

### Task 6D.1 — Computer Control Skill File

#### User Story

A `computer-control` skill is created that instructs the doer to use screenshots and `menubot-input` in a vision-action loop.

#### Implementation Steps

1. Create `MenuBarCompanion/Resources/skills/computer-control.md`:

```markdown
# Computer Control Skill

You have access to screen vision and input control. Use them together in a vision-action loop to interact with macOS applications.

## Available Tools

### Screen Capture
The orchestrator provides screenshots as image file paths. You can read these images to see what's on screen.

### Input Control CLI
Path: `~/Library/Application Support/MenuBot/bin/menubot-input`

Commands:
- `menubot-input mouse_move --x <int> --y <int>` — Move cursor
- `menubot-input mouse_click --x <int> --y <int> [--button left|right] [--count 1|2]` — Click
- `menubot-input mouse_drag --x1 <int> --y1 <int> --x2 <int> --y2 <int>` — Drag
- `menubot-input key_type --text <string>` — Type text
- `menubot-input key_press --key <key_name> [--modifiers <comma-separated>]` — Key combo
- `menubot-input scroll --x <int> --y <int> --dx <int> --dy <int>` — Scroll

## Vision-Action Loop Pattern

1. **Capture**: Take a screenshot to see the current screen state
2. **Analyze**: Identify the UI elements you need to interact with. Note their approximate screen coordinates.
3. **Act**: Use `menubot-input` to perform the next action (click a button, type in a field, etc.)
4. **Wait**: Sleep 300-500ms for the UI to update: `sleep 0.3`
5. **Repeat**: Take another screenshot to verify the action worked, then continue

## Common Patterns

### Fill out a form
1. Screenshot → identify the first text field
2. Click the field → type the value
3. Tab to next field (or click it) → type the next value
4. Screenshot → verify fields are filled → click Submit

### Navigate a UI
1. Screenshot → find the target button/link
2. Click it → wait 500ms for navigation
3. Screenshot → verify you're on the right page

### Copy content
1. Screenshot → identify the text to copy
2. Click at the start → drag to the end (or Cmd+A for all)
3. `key_press --key c --modifiers cmd` → read clipboard

### Switch apps
- Use `open -a "AppName"` for reliable app switching
- Or `key_press --key tab --modifiers cmd` for Cmd+Tab

## Important Guidelines

- **Describe** each action before executing it
- **Verify** each action's result with a new screenshot before proceeding
- **Wait** 300-500ms between action and next screenshot
- **Stop and report** if an action doesn't produce expected results after 2 retries
- **Never** interact with System Settings > Privacy & Security
- **Maximum** ~50 actions for a single task — if it takes more, break it into subtasks and check with the user
```

2. Add the skill to the bundled `skills-index.json`:

```json
{
    "id": "computer-control",
    "name": "Computer Control",
    "description": "Autonomous screen interaction — see the screen, click, type, and navigate macOS applications",
    "icon": "computermouse.fill",
    "category": "automation",
    "file": "computer-control.md"
}
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/computer-control.md` | Create | Computer control skill prompt |
| `MenuBarCompanion/Resources/skills/skills-index.json` | Modify | Add `computer-control` entry |

#### Acceptance Criteria

- [ ] `computer-control.md` exists with loop pattern, CLI reference, common patterns, and guidelines
- [ ] Skill is listed in `skills-index.json`
- [ ] The skill references the correct `menubot-input` path

---

### Task 6D.2 — Common Patterns in Skill Prompt

#### User Story

The computer-control skill includes guidance for common interaction patterns (forms, navigation, copying, app switching).

#### Implementation Steps

This is covered in Task 6D.1. The `computer-control.md` file already includes the "Common Patterns" section. Verify the patterns are practical and include enough detail for a doer to follow.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/computer-control.md` | Verify | Common patterns section is complete |

#### Acceptance Criteria

- [ ] Form filling pattern is documented with step-by-step instructions
- [ ] UI navigation pattern is documented
- [ ] Content copying pattern is documented
- [ ] App switching pattern is documented with both `open -a` and Cmd+Tab options

---

### Task 6D.3 — Loop Control in Skill Prompt

#### User Story

The skill prompt includes guidance on wait times, maximum iterations, and error recovery.

#### Implementation Steps

This is covered in Task 6D.1 in the "Important Guidelines" section. Verify:
- Wait times (300-500ms) are specified
- Maximum action guidance (~50 actions) is specified
- Error recovery (2 retries then stop and report) is specified

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/computer-control.md` | Verify | Loop control guidelines are present |

#### Acceptance Criteria

- [ ] Wait time guidance (300-500ms) is in the prompt
- [ ] Maximum iteration guidance is in the prompt
- [ ] Error recovery instructions are in the prompt

---

### Task 6D.4 — Register Computer Control Skill

#### User Story

The `computer-control` skill is seeded on first launch and appears in the skills browser.

#### Implementation Steps

1. In `OrchestrationBootstrap.swift`, ensure `computer-control` is in the `defaultSkillFiles` array:

```swift
let defaultSkillFiles = ["browse-web", "create-skill", "summarize-clipboard", "computer-control"]
```

2. Verify the skill appears in `SkillsListView` after app launch.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/OrchestrationBootstrap.swift` | Modify | Add "computer-control" to `defaultSkillFiles` |

#### Acceptance Criteria

- [ ] `computer-control` skill appears in the skills browser after app launch
- [ ] The skill can be executed from the UI

---

### Task 6D.5 — End-to-End Vision-Action Test

#### User Story

A user asks MenuBot to perform a multi-step UI task (e.g., "open TextEdit and type 'hello'"), and the doer executes the full vision-action loop: screenshot → identify target → act → screenshot again → verify.

#### Implementation Steps

1. Manually test the following scenario:
   - Send: "open TextEdit and type 'hello world'"
   - Verify the orchestrator invokes the `computer-control` skill
   - Verify the doer captures a screenshot, analyzes it, uses `menubot-input` to open TextEdit, types text
   - Verify the doer takes a verification screenshot and confirms the task completed
2. Test edge cases:
   - What happens if TextEdit is already open?
   - What happens if the doer can't find the expected UI element?
   - What happens if `menubot-input` fails (permission denied)?

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|

No file changes — this is a manual integration test.

#### Acceptance Criteria

- [ ] End-to-end test completes successfully for a simple multi-step task
- [ ] The doer captures screenshots, analyzes them, and takes appropriate actions
- [ ] The doer verifies its actions with follow-up screenshots
- [ ] Errors are handled gracefully (reported to user, not infinite loops)

---

### Task 6E.1 — Confirmation Flow

#### User Story

Before the first input control action in a sequence, the orchestrator asks the user for confirmation. The user can approve the full sequence or request step-by-step approval.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/SafetyManager.swift`:

```swift
import Foundation

final class SafetyManager {
    static let shared = SafetyManager()

    /// Number of input control actions in the current sequence
    private(set) var actionCount: Int = 0

    /// Maximum actions before re-confirmation required
    let maxActionsPerSequence = 100

    /// Whether automation is currently active
    @Published var isAutomationActive: Bool = false

    /// Reset for a new sequence
    func resetSequence() {
        actionCount = 0
    }

    /// Increment action counter. Returns false if limit exceeded.
    func recordAction() -> Bool {
        actionCount += 1
        return actionCount <= maxActionsPerSequence
    }

    /// Check if the frontmost app is a blocked target
    func isBlockedTarget() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let blockedBundleIDs = [
            "com.apple.systempreferences",
            "com.apple.Preferences"
        ]
        return blockedBundleIDs.contains(frontApp.bundleIdentifier ?? "")
    }

    /// Check if the screen is locked
    func isScreenLocked() -> Bool {
        if let dict = CGSessionCopyCurrentDictionary() as? [String: Any],
           let locked = dict["CGSSessionScreenIsLocked"] as? Bool {
            return locked
        }
        return false
    }

    private init() {}
}
```

2. The confirmation flow is primarily prompt-driven — the orchestrator skill instructs the AI to ask for confirmation before executing input control. Update the orchestrator skill prompt to include:

```
## Input Control Safety Rules

Before executing ANY mouse/keyboard control actions:
1. Describe what you're about to do to the user
2. Ask: "Should I go ahead?" and wait for confirmation
3. Only proceed if the user confirms

If the user says "go ahead" or "yes", execute the full sequence.
If the user says "step by step", describe and confirm each action individually.

After 100 actions, pause and ask the user if you should continue.
```

3. Add confirmation instructions to the orchestrator skill prompt in `menubot-orchestrator-SKILL.md`.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/SafetyManager.swift` | Create | Action counting, scope checks, blocked targets |
| `MenuBarCompanion/Resources/menubot-orchestrator-SKILL.md` | Modify | Add input control safety rules |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add `SafetyManager.swift` to build |

#### Acceptance Criteria

- [ ] `SafetyManager` tracks action count per sequence
- [ ] `isBlockedTarget()` returns true when System Settings is frontmost
- [ ] `isScreenLocked()` correctly detects locked screen
- [ ] Orchestrator skill prompt includes confirmation instructions
- [ ] `recordAction()` returns false after 100 actions

---

### Task 6E.2 — Emergency Stop Global Shortcut

#### User Story

Pressing `Cmd+Shift+Escape` immediately halts all input control actions by killing the active doer process. A toast notification confirms automation was stopped.

#### Implementation Steps

1. Create `MenuBarCompanion/Core/EmergencyStop.swift`:

```swift
import AppKit

final class EmergencyStop {
    static let shared = EmergencyStop()

    private var monitor: Any?

    /// Callback invoked when emergency stop is triggered
    var onStop: (() -> Void)?

    func register() {
        // Cmd + Shift + Escape
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 0x35 && // Escape
               event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.shift) {
                self?.triggerStop()
            }
        }
        print("[EmergencyStop] Registered global shortcut Cmd+Shift+Escape")
    }

    func unregister() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func triggerStop() {
        print("[EmergencyStop] EMERGENCY STOP TRIGGERED")
        SafetyManager.shared.isAutomationActive = false
        SafetyManager.shared.resetSequence()
        onStop?()
    }

    private init() {}
}
```

2. In `AppDelegate.swift`, register the emergency stop on launch:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ... existing code ...

    EmergencyStop.shared.register()
}
```

3. Wire the emergency stop to `ChatViewModel.cancel()`:

```swift
// In ChatViewModel.init():
EmergencyStop.shared.onStop = { [weak self] in
    Task { @MainActor in
        self?.cancel()
        // Show toast
        NotificationManager.shared?.showToast(
            title: "Emergency Stop",
            message: "All automation has been halted."
        )
    }
}
```

Or alternatively, wire it through `AppDelegate` → `NotificationManager` since `ChatViewModel` may not persist.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Core/EmergencyStop.swift` | Create | Global shortcut registration and stop trigger |
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Register emergency stop on launch |
| `MenuBarCompanion/UI/ChatViewModel.swift` | Modify | Wire emergency stop to cancel running processes |
| `MenuBarCompanion.xcodeproj/project.pbxproj` | Modify | Add `EmergencyStop.swift` to build |

#### Acceptance Criteria

- [ ] `Cmd+Shift+Escape` is registered as a global shortcut on app launch
- [ ] Pressing the shortcut kills any running doer process
- [ ] A toast/notification confirms automation was stopped
- [ ] The shortcut works even when MenuBot is not the frontmost app
- [ ] The shortcut is unregistered on app quit (prevent leaks)

---

### Task 6E.3 — Visual Indicator for Active Automation

#### User Story

When MenuBot is actively controlling mouse/keyboard, a persistent red dot badge appears on the menu bar icon so the user always knows automation is active.

#### Implementation Steps

1. In `AppDelegate.swift`, add a method to toggle the automation indicator:

```swift
func setAutomationIndicator(active: Bool) {
    guard let button = statusItem.button else { return }
    if active {
        // Use a red-tinted version of the icon or add a badge
        let icon = NSImage(named: "MenuBarIcon")
        icon?.isTemplate = false // Disable template to allow color

        // Draw a red dot overlay
        let size = NSSize(width: 18, height: 18)
        let badgedIcon = NSImage(size: size, flipped: false) { rect in
            icon?.draw(in: rect)
            // Red dot in top-right corner
            let dotSize: CGFloat = 6
            let dotRect = NSRect(x: rect.width - dotSize, y: rect.height - dotSize, width: dotSize, height: dotSize)
            NSColor.red.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        button.image = badgedIcon
    } else {
        let icon = NSImage(named: "MenuBarIcon")
        icon?.isTemplate = true
        button.image = icon
    }
}
```

2. Observe `SafetyManager.shared.isAutomationActive` and update the indicator:

```swift
// In AppDelegate, use Combine or KVO to observe:
private var automationCancellable: AnyCancellable?

// In applicationDidFinishLaunching:
automationCancellable = SafetyManager.shared.$isAutomationActive
    .receive(on: RunLoop.main)
    .sink { [weak self] active in
        self?.setAutomationIndicator(active: active)
    }
```

3. Import Combine in AppDelegate.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Add automation indicator badge on menu bar icon |

#### Acceptance Criteria

- [ ] A red dot appears on the menu bar icon when automation is active
- [ ] The red dot disappears when automation ends or is stopped
- [ ] The indicator is visible even when the popover is closed
- [ ] The indicator updates immediately (not delayed)

---

### Task 6E.4 — Scope Limits

#### User Story

Input control actions are blocked when the screen is locked, when targeting System Settings, and after 100 actions in a sequence.

#### Implementation Steps

1. In `menubot-input/main.swift`, add safety checks before executing any command:

```swift
// Before the switch statement in main.swift:
if command != "--help" && command != "-h" && command != "help" {
    // Check if screen is locked
    if let dict = CGSessionCopyCurrentDictionary() as? [String: Any],
       let locked = dict["CGSSessionScreenIsLocked"] as? Bool,
       locked {
        print("Error: Input control is blocked while the screen is locked")
        exit(1)
    }

    // Check for blocked targets
    let blockedBundleIDs = ["com.apple.systempreferences", "com.apple.Preferences"]
    if let frontApp = NSWorkspace.shared.frontmostApplication,
       let bundleID = frontApp.bundleIdentifier,
       blockedBundleIDs.contains(bundleID) {
        print("Error: Input control is blocked for System Settings")
        exit(1)
    }

    // Check action count from state file
    let stateFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MenuBot/automation-state.json")
    if let data = try? Data(contentsOf: stateFile),
       let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let count = state["actionCount"] as? Int,
       count >= 100 {
        print("Error: Action limit exceeded (100 per sequence). Re-confirmation required.")
        exit(1)
    }

    // Increment action count
    incrementActionCount(stateFile: stateFile)
}
```

2. Add action count management:

```swift
func incrementActionCount(stateFile: URL) {
    var state: [String: Any] = [:]
    if let data = try? Data(contentsOf: stateFile),
       let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        state = existing
    }
    let currentCount = (state["actionCount"] as? Int) ?? 0
    state["actionCount"] = currentCount + 1
    if let data = try? JSONSerialization.data(withJSONObject: state) {
        try? data.write(to: stateFile)
    }
}
```

3. In `SafetyManager.swift`, add a method to reset the action count state file (called when the user re-confirms):

```swift
static func resetActionCountFile() {
    let stateFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("MenuBot/automation-state.json")
    try? FileManager.default.removeItem(at: stateFile)
}
```

4. Add `import AppKit` to `main.swift` for `NSWorkspace` access.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/menubot-input/main.swift` | Modify | Add safety checks (locked screen, blocked targets, action limit) |
| `MenuBarCompanion/Core/SafetyManager.swift` | Modify | Add `resetActionCountFile()` |

#### Acceptance Criteria

- [ ] `menubot-input` exits with error when screen is locked
- [ ] `menubot-input` exits with error when System Settings is the frontmost app
- [ ] `menubot-input` exits with error after 100 actions in a sequence
- [ ] Action count persists across invocations via state file
- [ ] `SafetyManager.resetActionCountFile()` clears the counter for re-confirmation

---

### Task 6E.5 — Action Description Enforcement

#### User Story

The doer describes each action in its output stream before executing it, so the orchestrator and user can see what's happening.

#### Implementation Steps

1. This is enforced via the skill prompt. In `computer-control.md`, add explicit instructions:

```markdown
## MANDATORY: Describe Before Acting

Before EVERY `menubot-input` command, you MUST output a description of the action:

Example:
```
I'm going to click the "Save" button at coordinates (450, 320).
```

Then execute:
```bash
menubot-input mouse_click --x 450 --y 320 --button left
```

Never execute an input command without first describing what you're doing and why.
```

2. This is already partially covered in the skill prompt's "Important Guidelines" section. Ensure the language is explicit and mandatory.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Resources/skills/computer-control.md` | Modify | Add mandatory action description requirement |

#### Acceptance Criteria

- [ ] The skill prompt explicitly requires describing each action before executing it
- [ ] The instruction is clear and unambiguous ("MUST", "MANDATORY")

---

### Task 6E.6 — CLI Safety Checks

#### User Story

The `menubot-input` CLI enforces safety checks at the CLI level as defense in depth — blocked targets, screen lock detection, and action counting.

#### Implementation Steps

This is covered in Task 6E.4. Verify that all safety checks are implemented in the CLI:

1. Screen lock check via `CGSessionCopyCurrentDictionary`
2. Blocked target check via `NSWorkspace.shared.frontmostApplication`
3. Action count check via state file
4. Clear error messages for each denial

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|

No additional file changes — covered by Task 6E.4.

#### Acceptance Criteria

- [ ] All three safety checks (lock, target, count) are implemented in the CLI binary
- [ ] Each check produces a specific, actionable error message
- [ ] Safety checks run before any CGEvent is created or posted

---

## 5. Integration Points

- **macOS Screen Recording permission** — required for `CGWindowListCreateImage`. Managed by `ScreenCaptureManager`. Must be granted in System Settings.
- **macOS Accessibility permission** — required for `AXUIElement` metadata queries AND `CGEvent` input posting. Managed by `AccessibilityManager`. Single grant covers both reading and writing.
- **Claude Code CLI** — doers invoke `menubot-input` via their Bash tool. The orchestrator passes screenshot paths in the prompt.
- **OrchestrationBootstrap** — seeds the `computer-control` skill and installs the `menubot-input` binary on app launch.
- **SkillsDirectoryManager** — discovers and displays the `computer-control` skill in the UI.
- **ChatViewModel** — manages screen context toggle state, assembles screen context, detects screen intent in messages.
- **AppDelegate** — registers emergency stop shortcut, manages automation indicator, cleans screenshot cache on quit.
- **NSWorkspace / CGWindowList** — used for frontmost app detection, window enumeration, and blocked target checking.
- **Filesystem state** — `~/Library/Application Support/MenuBot/automation-state.json` for cross-process action counting; `~/Library/Application Support/MenuBot/cache/screenshots/` for transient screenshot storage.

---

## 6. Testing Strategy (Test-Driven Development)

### Phase Start: Scaffold Tests First

- **ScreenCaptureManager tests:**
  - Permission status check returns expected values
  - `captureFullScreen()` throws when permission denied
  - `captureActiveWindow()` returns a valid JPEG file URL
  - Cache cleanup removes all files
  - Expired cache cleanup only removes old files
- **AccessibilityManager tests:**
  - Permission status check returns expected values
  - `gatherMetadata()` times out after 2 seconds
  - `ScreenMetadata.formattedDescription` produces expected format
- **menubot-input tests:**
  - Argument parsing extracts correct values
  - Missing required args produce `InputError.missingArgument`
  - Key code mapping returns correct codes for all named keys
  - Modifier parsing handles comma-separated values
  - Safety checks block execution when conditions are met
- **SafetyManager tests:**
  - Action counter increments correctly
  - `recordAction()` returns false after 100 actions
  - `isBlockedTarget()` identifies System Settings
  - `resetSequence()` resets counter to 0
- **ChatViewModel tests:**
  - `detectsScreenIntent()` matches screen-related phrases
  - `screenContextEnabled` resets after sending

### During Implementation: Build Against Tests

- Implement each component until its tests pass
- Use failing tests as progress indicators
- Test `menubot-input` commands manually on a real macOS system (CGEvent tests require UI context)

### Phase End: Polish Tests

- Integration test: full send-message-with-screen-context flow
- Edge case: permission denied mid-sequence
- Edge case: screen locked during automation
- Edge case: app quits during active automation (cleanup verification)
- Remove any stub tests

---

## 7. Definition of Done

- [ ] `ScreenCaptureManager` captures full-screen and active-window screenshots as JPEG
- [ ] `AccessibilityManager` gathers metadata (app name, window title, focused element)
- [ ] Both permission flows work with user-friendly explanations and graceful denial
- [ ] Eye toggle in chat UI attaches screen context to messages
- [ ] `menubot-input` CLI performs mouse, keyboard, and scroll operations
- [ ] `menubot-input` is auto-installed to `~/Library/Application Support/MenuBot/bin/`
- [ ] `computer-control` skill is seeded and visible in the skills browser
- [ ] Vision-action loop works end-to-end for simple multi-step tasks
- [ ] Confirmation is required before input control actions
- [ ] Emergency stop (`Cmd+Shift+Escape`) halts automation immediately
- [ ] Red dot indicator visible on menu bar during active automation
- [ ] Scope limits enforced (locked screen, System Settings blocked, 100-action cap)
- [ ] All unit tests passing
- [ ] No regressions in existing chat, skills, or orchestrator functionality
- [ ] Screenshot cache cleaned on app quit

### Backward Compatibility

No backward compatibility concerns. This phase adds entirely new capabilities (screen capture, input control, safety system). No existing APIs, data formats, or user-facing behaviors are modified — only additive changes. The `ChatMessage` struct gains a new `hasScreenContext` field which defaults to `false`, maintaining compatibility with existing persisted chat history (Codable will use the default).

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Objective 7 until ALL of the following are verified:**

- [ ] **Build verification:** Both `MenuBarCompanion` and `menubot-input` targets compile without errors or warnings
- [ ] **Binary installation:** `menubot-input` is present and executable at `~/Library/Application Support/MenuBot/bin/menubot-input` after app launch
- [ ] **Permission flows:** Screen Recording and Accessibility prompts appear correctly on a clean install
- [ ] **Screenshot test:** Sending a message with "what's on my screen" captures a screenshot and returns an accurate description
- [ ] **Input control test:** `menubot-input mouse_click --x 500 --y 300 --button left` clicks at the correct coordinates
- [ ] **Keyboard test:** `menubot-input key_type --text "test"` types into a focused text field
- [ ] **Skill test:** `computer-control` skill appears in the skills browser
- [ ] **E2E test:** "open TextEdit and type hello" completes the full vision-action loop
- [ ] **Safety - confirmation:** User is prompted before input control begins
- [ ] **Safety - emergency stop:** `Cmd+Shift+Escape` halts active automation and shows a toast
- [ ] **Safety - indicator:** Red dot badge appears on menu bar icon during automation
- [ ] **Safety - blocked target:** `menubot-input` exits with error when System Settings is frontmost
- [ ] **Safety - action limit:** `menubot-input` exits with error after 100 actions
- [ ] **Cache cleanup:** Screenshot cache directory is empty after app quit
- [ ] **No regressions:** Existing chat, skills, and orchestrator features work correctly

**Signoff:** _______________  Date: _______________

---

## Appendix

### PermissionStatus Enum

```swift
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}
```

Used by both `ScreenCaptureManager` and `AccessibilityManager`. Define once in a shared location (e.g., `ScreenCaptureManager.swift` or a separate `PermissionStatus.swift` if preferred).

### menubot-input Key Code Reference

| Key Name | Code | Key Name | Code |
|----------|------|----------|------|
| return/enter | 0x24 | tab | 0x30 |
| space | 0x31 | delete/backspace | 0x33 |
| escape/esc | 0x35 | left | 0x7B |
| right | 0x7C | down | 0x7D |
| up | 0x7E | a-z | 0x00-0x06... |
| 0-9 | 0x1D, 0x12-0x19 | f1-f12 | various |

### Cache Directory Structure

```
~/Library/Application Support/MenuBot/
├── cache/
│   └── screenshots/       # Transient JPEG screenshots (cleaned on quit + hourly)
├── bin/
│   └── menubot-input      # Input control CLI binary
├── automation-state.json   # Action counter for safety limits
├── skills/
│   ├── skills-index.json
│   ├── computer-control.md
│   └── ...
```

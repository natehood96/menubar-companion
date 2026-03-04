# Phase 1 — Menu Bar Icon & App Shell Polish

- **Phase Number:** 1
- **Phase Name:** Menu Bar Icon & App Shell Polish
- **Source:** docs/mvp/phases/overviews/objective1PhaseOverview.md

---

## AI Agent Execution Instructions

> **READ THIS ENTIRE DOCUMENT BEFORE STARTING ANY WORK.**
>
> Once you have read and understood the full document:
>
> 1. Execute each task in order
> 2. After completing a task, come back to this document and add a checkmark emoji to that task's title
> 3. If you are interrupted or stop mid-execution, the checkmarks show exactly where you left off
> 4. Do NOT check off a task until the work is fully complete
> 5. If you need to reference another doc, b/c the doc you're currently referencing doesn't have the right info you need to fill out the task, check neighboring docs in the same folder to see if you can find the information you're looking for there.
>
> If you need any prisma commands run (e.g. `npx prisma migrate dev`), let the user know and they will run them.

---

## Task Tracking Instructions

- Each task heading includes a checkbox placeholder. Mark the task title with a checkmark emoji AFTER completing the work.
- Update this document as you go — it is the source of truth for phase progress.
- This phase cannot advance to Phase 2 until all task checkboxes are checked.
- If execution stops mid-phase, the checkmarks indicate exactly where progress was interrupted.

---

## Quick Context for AI Agent

- **What this phase accomplishes:** Replace the placeholder SF Symbol terminal icon with a custom friendly blob character icon in the menu bar, and verify the app shell meets all Objective 1.1 requirements (LSUIElement, light/dark mode adaptation, no dock icon).
- **What already exists:** A fully functional app shell — `AppDelegate.swift` creates an `NSStatusItem` with a system `"terminal"` SF Symbol, `PopoverView.swift` renders a command input and output area, `PopoverViewModel.swift` orchestrates command execution via `CommandRunner.swift`. The asset catalog (`Assets.xcassets`) currently only contains `AppIcon.appiconset`.
- **What future phases depend on:** Phase 2 (Popover UI) refines the popover layout. Phase 3 (CLI Execution) wires up real Claude Code CLI. Both phases assume the menu bar icon and app shell are finalized.

---

## 0. Mental Model (Required)

**Problem:** The app currently uses a generic system terminal icon (`SF Symbol "terminal"`) in the menu bar. This does not match the product identity — a friendly, approachable companion character. The icon is the user's first and most persistent touchpoint with the app; it must convey the right personality.

**Where it fits:** This is the very first phase of the very first objective. It establishes the visual identity and confirms the foundational app shell is correctly configured (menu bar only, no dock icon, light/dark mode support). Every subsequent phase builds on top of this foundation.

**Data flow:** There is no data flow in this phase. This is purely a visual/asset replacement and configuration verification phase. The icon asset flows from design -> `Assets.xcassets` -> `AppDelegate.swift` (loaded via `NSImage(named:)`) -> rendered by macOS in the menu bar.

**Core entities:**
- **Blob icon asset** — a monochrome template image (18x18pt @1x, 36x36pt @2x) representing the companion character
- **NSStatusItem** — the menu bar item that displays the icon
- **AppDelegate** — the owner of the status item, responsible for loading the icon image

---

## 1. Phase Overview

### Phase Goal (1 sentence)

Replace the placeholder terminal icon with a custom friendly blob character template image and verify the app shell meets all Objective 1.1 requirements.

### Prerequisites

- Xcode project builds and runs successfully
- `Assets.xcassets` exists in the project
- `AppDelegate.swift` is functional with the current system icon

### Key Deliverables

- Custom blob character icon asset (18x18pt @1x PNG, 36x36pt @2x PNG)
- Template image set added to `Assets.xcassets`
- `AppDelegate.swift` updated to load the custom icon
- `PopoverView.swift` header icon updated to match
- Verified: no dock icon, light/dark mode adaptation, popover still opens on click

### System-Level Acceptance Criteria

- The blob icon renders at correct size in the menu bar (not clipped, not blurry)
- The icon is a **template image** — macOS automatically adjusts it for light mode (dark icon) and dark mode (light icon)
- No dock icon appears at any point during the app lifecycle
- Clicking the icon still toggles the popover correctly
- The app builds and runs without warnings related to asset loading

---

## 2. Execution Order

### Blocking Tasks

1. **Task 1.1** — Design/source the blob icon (must exist before it can be added to assets)
2. **Task 1.2** — Render the icon at correct sizes as monochrome template PNGs (must exist before adding to Xcode)
3. **Task 1.3** — Add icon to `Assets.xcassets` (must be in the asset catalog before code can reference it)
4. **Task 1.4** — Update `AppDelegate.swift` to load the new icon (depends on asset being in catalog)

### Parallel Tasks

- **Task 1.5** (LSUIElement verification) and **Task 1.6** (light/dark mode verification) can be done in parallel after Task 1.4

### Final Integration

- Build and run the app
- Verify: blob icon visible in menu bar, no dock icon, correct appearance in both light and dark mode, popover opens/closes on click

---

## 3. Architectural Decisions (ONLY IF NEEDED)

| Decision | Options | Chosen | Reason | Risk |
|----------|---------|--------|--------|------|
| Icon format | SF Symbol custom / PNG template image / SVG | PNG template image | Simplest to create and iterate on; macOS template image rendering is well-supported; no need for SF Symbol tooling | If the design doesn't read well at 18x18pt, may need iteration |
| Icon design approach | Hand-draw / Generate programmatically / Source from icon set | Programmatic generation (Swift script or simple drawing tool) | No external design tool dependency; reproducible; can iterate quickly | May need manual touch-up if result isn't polished enough |

---

## 4. Subtasks

### ✅ Task 1.1 — Design or Source the Blob Character Icon

#### User Story

As a user, I want to see a friendly, approachable blob character in my menu bar so that the app feels like a helpful companion rather than a generic developer tool.

#### Implementation Steps

1. Create a simple blob character design that meets these criteria:
   - Friendly, smiling expression
   - Simple silhouette that reads clearly at 18x18pt
   - Monochrome (single color on transparent background) — will be used as a macOS template image
   - Companion-like personality — approachable, not intimidating
2. The blob should be a rounded, organic shape (not geometric) with minimal facial features (two eyes, a smile)
3. Create the icon as a **black shape on transparent background** — macOS template image rendering requires this format
4. Export as:
   - `blob-icon.png` at 18x18px (1x)
   - `blob-icon@2x.png` at 36x36px (2x)

**Approach:** Use a simple Python/Swift script or manual creation to produce the PNG files. The design should be intentionally simple — a rounded blob body with two dot eyes and a curved smile line.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/blob-icon.png` | Create | 18x18px monochrome blob icon (1x) |
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/blob-icon@2x.png` | Create | 36x36px monochrome blob icon (2x) |

#### Acceptance Criteria

- [ ] A blob character icon exists as a black shape on transparent background
- [ ] The design is friendly, smiling, and reads clearly at 18x18pt
- [ ] Both 1x (18x18px) and 2x (36x36px) versions are exported

---

### ✅ Task 1.2 — Render Icon as Monochrome Template Image at Correct Sizes

#### User Story

As a macOS user, I want the menu bar icon to automatically adapt to light and dark mode without any manual switching, so it always looks correct regardless of my system appearance.

#### Implementation Steps

1. Ensure the exported PNGs are **black fill on fully transparent background** — this is the requirement for macOS template images
2. Verify pixel dimensions:
   - 1x: exactly 18x18 pixels
   - 2x: exactly 36x36 pixels
3. Verify the images use only black (#000000) pixels with varying alpha for anti-aliasing, on a transparent background
4. No color information — pure grayscale/black

**Validation:** Open each PNG and confirm:
- Transparent background (alpha channel present)
- Black-only fill
- Correct pixel dimensions

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/blob-icon.png` | Verify/Update | Confirm 18x18px, black on transparent |
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/blob-icon@2x.png` | Verify/Update | Confirm 36x36px, black on transparent |

#### Acceptance Criteria

- [ ] 1x image is exactly 18x18 pixels
- [ ] 2x image is exactly 36x36 pixels
- [ ] Both images are black fill on transparent background
- [ ] No color data — suitable for macOS template image rendering

---

### ✅ Task 1.3 — Add Icon Assets to Assets.xcassets as Template Image Set

#### User Story

As a developer building the app, I need the blob icon properly registered in the Xcode asset catalog as a template image so the code can load it by name and macOS applies automatic light/dark mode rendering.

#### Implementation Steps

1. Create a new image set in `Assets.xcassets` named `MenuBarIcon`
2. Create the directory `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/`
3. Create the `Contents.json` file inside the imageset directory:

```json
{
  "images" : [
    {
      "filename" : "blob-icon.png",
      "idiom" : "mac",
      "scale" : "1x"
    },
    {
      "filename" : "blob-icon@2x.png",
      "idiom" : "mac",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

4. Place the 1x and 2x PNG files in the same directory
5. Key detail: `"template-rendering-intent": "template"` in `Contents.json` tells macOS to treat this as a template image (auto light/dark mode adaptation)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/Contents.json` | Create | Image set manifest with template rendering intent |
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/blob-icon.png` | Create | 1x icon (18x18px) |
| `MenuBarCompanion/Assets.xcassets/MenuBarIcon.imageset/blob-icon@2x.png` | Create | 2x icon (36x36px) |

#### Acceptance Criteria

- [ ] `MenuBarIcon.imageset` directory exists inside `Assets.xcassets`
- [ ] `Contents.json` specifies `"template-rendering-intent": "template"`
- [ ] Both 1x and 2x PNGs are referenced in `Contents.json` with correct filenames
- [ ] Xcode recognizes the image set (no yellow warnings in asset catalog)

---

### ✅ Task 1.4 — Update AppDelegate to Load the New Blob Icon

#### User Story

As a user, when I launch the app I should see the friendly blob character in my menu bar instead of the generic terminal icon.

#### Implementation Steps

1. Open `MenuBarCompanion/App/AppDelegate.swift`
2. Replace the current icon loading code:

**Current code (line 22-25):**
```swift
button.image = NSImage(
    systemSymbolName: "terminal",
    accessibilityDescription: "MenuBar Companion"
)
```

**Replace with:**
```swift
let icon = NSImage(named: "MenuBarIcon")
icon?.isTemplate = true  // Belt-and-suspenders — asset catalog already sets this, but explicit is safer
button.image = icon
button.image?.accessibilityDescription = "MenuBar Companion"
```

3. Also update `PopoverView.swift` to replace the terminal icon in the header (line 10):

**Current code:**
```swift
Image(systemName: "terminal")
```

**Replace with:**
```swift
Image("MenuBarIcon")
    .resizable()
    .frame(width: 18, height: 18)
```

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/App/AppDelegate.swift` | Modify | Replace SF Symbol with `NSImage(named: "MenuBarIcon")` |
| `MenuBarCompanion/UI/PopoverView.swift` | Modify | Replace header SF Symbol with custom icon |

#### Acceptance Criteria

- [ ] `AppDelegate.swift` loads `"MenuBarIcon"` from the asset catalog
- [ ] `isTemplate = true` is set on the loaded image
- [ ] `PopoverView.swift` header uses the blob icon instead of the terminal SF Symbol
- [ ] App builds without errors or warnings
- [ ] Blob icon appears in the menu bar when the app launches

---

### ✅ Task 1.5 — Verify LSUIElement Behavior

#### User Story

As a user, I expect this to be a lightweight menu bar utility — it should never show a dock icon or appear in the Cmd+Tab app switcher.

#### Implementation Steps

1. Confirm `Info.plist` contains `LSUIElement = YES` (or the `Application is agent (UIElement)` key set to `YES`)
2. Alternatively, confirm that `AppDelegate.swift` calls `NSApp.setActivationPolicy(.accessory)` on launch (line 10 — this is already present)
3. Build and run the app
4. Verify:
   - No icon appears in the Dock
   - The app does not appear in the Cmd+Tab switcher
   - The menu bar icon is the only visible presence
   - The app's popover still opens when clicking the menu bar icon

**Note:** The current codebase uses `NSApp.setActivationPolicy(.accessory)` in `AppDelegate.swift` line 10, which achieves the same effect as `LSUIElement = YES`. Both approaches are valid. Verify that at least one is in place.

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| `MenuBarCompanion/App/AppDelegate.swift` | Verify (no change expected) | Confirm `.accessory` activation policy |
| `MenuBarCompanion/App/Info.plist` | Verify (no change expected) | Confirm LSUIElement if present |

#### Acceptance Criteria

- [ ] App does not appear in the Dock
- [ ] App does not appear in the Cmd+Tab switcher
- [ ] Menu bar icon is the sole visible presence
- [ ] Popover opens/closes correctly via menu bar icon click

---

### ✅ Task 1.6 — Verify Icon Renders Correctly in Light and Dark Mode

#### User Story

As a user who switches between light and dark mode, I want the menu bar icon to always be visible and correctly contrasted against the menu bar background.

#### Implementation Steps

1. Build and run the app
2. Open **System Settings > Appearance** (or use `defaults write -g AppleInterfaceStyle -string "Dark"` / `defaults delete -g AppleInterfaceStyle` to toggle)
3. In **Light Mode**: verify the blob icon renders as a dark silhouette on the light menu bar
4. In **Dark Mode**: verify the blob icon renders as a light silhouette on the dark menu bar
5. Verify the icon does not appear washed out, clipped, or incorrectly sized in either mode
6. If the icon does not automatically adapt:
   - Check that `Contents.json` has `"template-rendering-intent": "template"`
   - Check that `isTemplate = true` is set in `AppDelegate.swift`
   - Check that the source PNG is black-on-transparent (not colored)

#### Files Created / Modified

| File | Action | Description |
|------|--------|-------------|
| (none) | Verify only | Visual verification in both appearance modes |

#### Acceptance Criteria

- [ ] Icon is clearly visible in Light Mode (dark icon on light bar)
- [ ] Icon is clearly visible in Dark Mode (light icon on dark bar)
- [ ] Icon is not blurry, clipped, or incorrectly sized
- [ ] Template image rendering is working (automatic color adaptation)

---

## 5. Integration Points

- **macOS Menu Bar (NSStatusBar):** The icon is rendered by the system via `NSStatusItem.button.image`. Template image rendering is handled automatically by AppKit.
- **Xcode Asset Catalog:** The icon must be properly registered in `Assets.xcassets` for `NSImage(named:)` to resolve it at runtime.
- **Existing Popover:** No changes to popover behavior — only the header icon reference changes. The popover must continue to open/close on icon click.
- **AppKit Template Image System:** The icon relies on macOS template image rendering. This requires: black-on-transparent source PNG + template rendering intent set in the asset catalog (or `isTemplate = true` in code).

---

## 6. Testing Strategy (Test-Driven Development)

This phase is primarily visual/asset work with minimal testable logic. The testing strategy focuses on verification rather than unit tests.

### Phase Start: Scaffold Tests First

- **Asset loading test:** Write a test that verifies `NSImage(named: "MenuBarIcon")` returns a non-nil image
- **Template flag test:** Write a test that verifies the loaded image has `isTemplate == true`
- **Size test:** Write a test that verifies the loaded image size is 18x18 points

```swift
// MenuBarCompanionTests/IconTests.swift
import XCTest
@testable import MenuBarCompanion

final class IconTests: XCTestCase {
    func testMenuBarIconLoads() {
        let image = NSImage(named: "MenuBarIcon")
        XCTAssertNotNil(image, "MenuBarIcon should load from asset catalog")
    }

    func testMenuBarIconIsTemplate() {
        let image = NSImage(named: "MenuBarIcon")
        XCTAssertTrue(image?.isTemplate ?? false, "MenuBarIcon should be a template image")
    }

    func testMenuBarIconSize() {
        let image = NSImage(named: "MenuBarIcon")
        XCTAssertEqual(image?.size.width, 18, accuracy: 1)
        XCTAssertEqual(image?.size.height, 18, accuracy: 1)
    }
}
```

### During Implementation: Build Against Tests

- The asset loading test will fail until the image set is added to `Assets.xcassets`
- The template test will fail until `Contents.json` specifies template rendering intent
- Use these as progress indicators

### Phase End: Polish Tests

- Confirm all three tests pass
- Manual verification covers the visual aspects (light/dark mode, menu bar rendering) that cannot be unit tested

---

## 7. Definition of Done

- [ ] Custom blob icon asset created (1x and 2x PNGs)
- [ ] Icon added to `Assets.xcassets` as a template image set
- [ ] `AppDelegate.swift` loads the custom icon
- [ ] `PopoverView.swift` header uses the custom icon
- [ ] Unit tests pass (icon loads, is template, correct size)
- [ ] Manual verification: icon visible in menu bar
- [ ] Manual verification: no dock icon
- [ ] Manual verification: correct rendering in light and dark mode
- [ ] Manual verification: popover opens/closes on click
- [ ] No build warnings related to assets

### Backward Compatibility

Not applicable — this is a greenfield phase (Phase 1 of Objective 1). There are no existing consumers, no data schemas, and no external integrations that could break. The only change is replacing a placeholder SF Symbol with a custom icon.

### End-of-Phase Checklist (Hard Gate)

**STOP. Do not proceed to Phase 2 until all items below are verified.**

- [ ] **Build:** `xcodebuild -project MenuBarCompanion.xcodeproj -scheme MenuBarCompanion build` succeeds with zero errors
- [ ] **Tests:** `xcodebuild -project MenuBarCompanion.xcodeproj -scheme MenuBarCompanion test` passes all icon tests
- [ ] **Manual — Icon:** Launch the app. A friendly blob icon (not the terminal icon) is visible in the menu bar.
- [ ] **Manual — No Dock:** The app does not appear in the Dock or Cmd+Tab switcher.
- [ ] **Manual — Light Mode:** Switch to Light Mode. The icon is a dark silhouette on the light menu bar.
- [ ] **Manual — Dark Mode:** Switch to Dark Mode. The icon is a light silhouette on the dark menu bar.
- [ ] **Manual — Popover:** Click the menu bar icon. The popover opens. Click again. It closes.
- [ ] **Signoff:** All items above checked. Phase 1 is complete.

---

## Appendix

### Asset Catalog Structure (after this phase)

```
MenuBarCompanion/Assets.xcassets/
  AppIcon.appiconset/
    Contents.json
    (app icon images)
  MenuBarIcon.imageset/
    Contents.json          <-- template-rendering-intent: template
    blob-icon.png          <-- 18x18px, black on transparent
    blob-icon@2x.png       <-- 36x36px, black on transparent
  Contents.json
```

### Template Image Requirements

- Source PNG must be **black (#000000) on fully transparent background**
- Anti-aliasing pixels should use varying alpha of black (not gray pixels)
- macOS renders template images by using the shape as a mask and applying the system-appropriate color (dark in light mode, light in dark mode)
- Setting `"template-rendering-intent": "template"` in the asset catalog `Contents.json` is the recommended approach; calling `isTemplate = true` in code is a secondary safeguard

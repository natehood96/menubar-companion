import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
        )
        self.popover = popover

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            button.image = icon
            button.image?.accessibilityDescription = "MenuBar Companion"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

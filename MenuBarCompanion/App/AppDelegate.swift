import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var notificationManager: NotificationManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install orchestration skills and protocol files
        OrchestrationBootstrap.install()

        // Hide dock icon (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            button.image = icon
            button.image?.accessibilityDescription = "MenuBar Companion"
            button.action = #selector(togglePopover)
            button.target = self
        }

        notificationManager = NotificationManager(statusItem: statusItem)

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(notificationManager: notificationManager)
        )
        self.popover = popover
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

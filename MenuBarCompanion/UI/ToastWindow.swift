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
        panel.hasShadow = false
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
            let y = buttonFrame.minY - panelSize.height - 1  // Arrow tip sits close to the menu bar
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

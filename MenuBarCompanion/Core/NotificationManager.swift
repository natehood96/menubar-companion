import AppKit
import SwiftUI

@MainActor
final class NotificationManager {
    private let statusItem: NSStatusItem
    private let toastWindow = ToastWindow()

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func handle(_ event: MenuBotEvent) {
        switch event {
        case .toast(let payload):
            showToast(payload)
        case .result(let payload):
            print("[NotificationManager] Result event received (UI deferred): \(payload.summary)")
        case .error(let payload):
            print("[NotificationManager] Error event received (UI deferred): \(payload.message)")
        }
    }

    private func showToast(_ payload: ToastPayload) {
        toastWindow.show(payload: payload, relativeTo: statusItem) {
            // Toast dismissed — no-op for now; Phase 2 adds queuing
        }
    }
}

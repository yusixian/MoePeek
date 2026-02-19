import AppKit
import SwiftUI

/// Manages the onboarding window lifecycle for LSUIElement apps.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let permissionManager: PermissionManager
    var onComplete: (() -> Void)?

    init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func showWindow() {
        if let window, window.isVisible {
            window.orderFrontRegardless()
            return
        }

        let onboardingView = OnboardingView(
            permissionManager: permissionManager,
            onComplete: { [weak self] in
                self?.closeWindow()
                self?.onComplete?()
            }
        )
        let hostingView = NSHostingView(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MoePeek"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        self.window = window

        window.orderFrontRegardless()
    }

    func closeWindow() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_: Notification) {
        Task { @MainActor [weak self] in
            self?.window = nil
        }
    }
}

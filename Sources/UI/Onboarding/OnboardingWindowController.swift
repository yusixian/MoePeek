import AppKit
import Defaults
import SwiftUI

/// Manages the onboarding window lifecycle for LSUIElement apps.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let permissionManager: PermissionManager
    private let registry: TranslationProviderRegistry
    private var needsRestorePolicy = false

    init(permissionManager: PermissionManager, registry: TranslationProviderRegistry) {
        self.permissionManager = permissionManager
        self.registry = registry
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func showWindow() {
        let onboardingView = OnboardingView(
            permissionManager: permissionManager,
            registry: registry,
            onComplete: { [weak self] in
                self?.closeWindow()
            }
        )
        presentWindow(contentView: onboardingView, size: NSSize(width: 380, height: 480))
    }

    func showPermissionRecovery() {
        let recoveryView = PermissionRecoveryView(
            permissionManager: permissionManager,
            onAllGranted: { [weak self] in
                self?.closeWindow()
            }
        )
        presentWindow(contentView: recoveryView, size: NSSize(width: 380, height: 320))
    }

    func closeWindow() {
        restorePolicyIfNeeded()
        window?.contentView = nil
        window?.close()
        window = nil
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.restorePolicyIfNeeded()
            self.window?.contentView = nil
            self.window = nil
        }
    }

    // MARK: - Private

    private func presentWindow(contentView: some View, size: NSSize) {
        if let window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Temporarily switch to .regular so the window reliably appears in front.
        // LSUIElement (.accessory) apps cannot always activate themselves on first launch.
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
            needsRestorePolicy = true
        }

        let hostingView = NSHostingView(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
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

        // orderFrontRegardless is more reliable than makeKeyAndOrderFront during app launch,
        // because the app may not yet be the active app in the window server.
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Restore .accessory policy unless user has showInDock enabled.
    /// Idempotent — safe to call from both `closeWindow()` and `windowWillClose`.
    private func restorePolicyIfNeeded() {
        guard needsRestorePolicy else { return }
        needsRestorePolicy = false
        if !Defaults[.showInDock] {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

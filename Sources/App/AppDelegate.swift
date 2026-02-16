import AppKit
import KeyboardShortcuts

/// Handles app lifecycle, permission checks, and global shortcut registration.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: TranslationCoordinator!
    var panelController: PopupPanelController!
    var permissionManager: PermissionManager!

    func applicationDidFinishLaunching(_: Notification) {
        permissionManager = PermissionManager()
        coordinator = TranslationCoordinator(permissionManager: permissionManager)
        panelController = PopupPanelController(coordinator: coordinator)

        setupShortcuts()

        // Prompt for accessibility if not yet granted
        if !permissionManager.isAccessibilityGranted {
            permissionManager.requestAccessibility()
        }
    }

    private func setupShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .translateSelection) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.translateSelection()
                if case .idle = self.coordinator.state { return }
                self.panelController.showAtCursor()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .ocrScreenshot) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.coordinator.ocrAndTranslate()
                if case .idle = self.coordinator.state { return }
                self.panelController.showAtCursor()
            }
        }
    }
}

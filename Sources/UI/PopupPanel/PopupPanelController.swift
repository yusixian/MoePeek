import AppKit
import Defaults
import SwiftUI

/// Manages the lifecycle and positioning of the popup translation panel.
@MainActor
final class PopupPanelController {
    var onDismiss: (() -> Void)?

    private var panel: PopupPanel?
    private var dismissMonitor: PopupDismissMonitor?

    private let coordinator: TranslationCoordinator

    init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    func showAtCursor() {
        let cursorPos = NSEvent.mouseLocation

        // Read default size from user preferences
        let initialSize = CGSize(
            width: CGFloat(Defaults[.popupDefaultWidth]),
            height: CGFloat(Defaults[.popupDefaultHeight])
        )

        if panel == nil {
            panel = PopupPanel(contentRect: NSRect(origin: .zero, size: initialSize))
        }

        guard let panel else { return }

        let contentView = PopupView(coordinator: coordinator)
            .environment(\.popupPanel, panel)
        let hostingView = NSHostingView(rootView: contentView)
        // Prevent NSHostingView from auto-resizing the window on content changes,
        // which causes an infinite constraint update loop during streaming.
        hostingView.sizingOptions = []

        panel.contentView = hostingView

        // Position near cursor, adjusted for screen bounds
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = PopupPositioning.panelFrame(
            contentSize: initialSize,
            cursor: cursorPos,
            screen: screen
        )
        panel.setFrame(frame, display: true)
        panel.orderFront(nil)

        // Start monitoring for dismiss events
        dismissMonitor = PopupDismissMonitor(panel: panel) { [weak self] in
            self?.dismiss()
        }
        dismissMonitor?.start()

    }

    func dismiss() {
        dismissMonitor?.stop()
        dismissMonitor = nil
        panel?.contentView = nil
        panel?.orderOut(nil)
        coordinator.dismiss()
        onDismiss?()
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

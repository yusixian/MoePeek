import AppKit
import SwiftUI

/// Manages the lifecycle and positioning of the popup translation panel.
@MainActor
final class PopupPanelController {
    private var panel: PopupPanel?
    private var dismissMonitor: PopupDismissMonitor?

    private let coordinator: TranslationCoordinator

    init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    func showAtCursor() {
        let cursorPos = NSEvent.mouseLocation

        let contentView = PopupView(coordinator: coordinator)
        let hostingView = NSHostingView(rootView: contentView)

        // Initial size — will be resized after layout
        let initialSize = CGSize(width: 380, height: 200)

        if panel == nil {
            panel = PopupPanel(contentRect: NSRect(origin: .zero, size: initialSize))
        }

        guard let panel else { return }

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

        // Re-layout after SwiftUI settles to get proper content size
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel else { return }
            let fittingSize = hostingView.fittingSize
            let clampedSize = CGSize(
                width: min(max(fittingSize.width, 280), 500),
                height: min(max(fittingSize.height, 80), 400)
            )
            let newFrame = PopupPositioning.panelFrame(
                contentSize: clampedSize,
                cursor: cursorPos,
                screen: screen
            )
            panel.setFrame(newFrame, display: true, animate: false)
        }
    }

    func dismiss() {
        dismissMonitor?.stop()
        dismissMonitor = nil
        panel?.orderOut(nil)
        coordinator.dismiss()
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

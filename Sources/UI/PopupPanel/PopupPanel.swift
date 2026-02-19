import AppKit
import Defaults
import SwiftUI

// MARK: - Environment Key

private struct PopupPanelKey: EnvironmentKey {
    static let defaultValue: PopupPanel? = nil
}

extension EnvironmentValues {
    var popupPanel: PopupPanel? {
        get { self[PopupPanelKey.self] }
        set { self[PopupPanelKey.self] = newValue }
    }
}

/// A floating, non-activating panel for showing translation results near the cursor.
final class PopupPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        isReleasedWhenClosed = false
        minSize = CGSize(width: 280, height: 200)
        maxSize = CGSize(width: 800, height: 800)

        // Rounded corners
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 12
        contentView?.layer?.masksToBounds = true
    }

    // Allow becoming key window so users can select/copy text within the panel.
    override var canBecomeKey: Bool { true }
}

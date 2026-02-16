import AppKit

enum PopupPositioning {
    /// Calculate the frame for the popup panel near the cursor, keeping it within screen bounds.
    static func panelFrame(contentSize: CGSize, cursor: CGPoint, screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 8
        let cursorOffset: CGFloat = 20

        // Start below-right of cursor
        var x = cursor.x + cursorOffset
        var y = cursor.y - contentSize.height - cursorOffset

        // Clamp to screen right edge
        if x + contentSize.width + padding > screenFrame.maxX {
            x = cursor.x - contentSize.width - cursorOffset
        }
        // Clamp to screen left edge
        if x < screenFrame.minX + padding {
            x = screenFrame.minX + padding
        }

        // Clamp to screen bottom edge
        if y < screenFrame.minY + padding {
            y = cursor.y + cursorOffset
        }
        // Clamp to screen top edge
        if y + contentSize.height + padding > screenFrame.maxY {
            y = screenFrame.maxY - contentSize.height - padding
        }

        return NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
    }
}

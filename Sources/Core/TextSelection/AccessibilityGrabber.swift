import AppKit
import ApplicationServices

enum AccessibilityGrabber {
    /// Read the selected text from the frontmost application using the Accessibility API.
    /// Returns nil if no text is selected or the app doesn't support AX text selection.
    ///
    /// - Parameter clickPoint: If provided, validates that the click occurred within (or near)
    ///   the focused element's bounds. This filters out stale selections from distant text fields
    ///   when the user clicks on non-text elements. Uses `NSEvent.mouseLocation` coordinate space
    ///   (bottom-left origin).
    @MainActor
    static func grabSelectedText(near clickPoint: CGPoint? = nil) -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusResult == .success,
              let focusedRef = focusedValue,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else { return nil }

        // Safe: CFGetTypeID verified above; as?/as! cannot express CF type casts cleanly.
        let focusedElement = unsafeBitCast(focusedRef, to: AXUIElement.self)

        var selectedValue: CFTypeRef?
        let selectResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )
        guard selectResult == .success, let text = selectedValue as? String, !text.isEmpty else {
            return nil
        }

        // If a click point is provided, verify the click is within the focused element's bounds.
        // This prevents returning stale selected text from a distant text field when the user
        // clicks on a non-text element (button, icon, etc.).
        if let clickPoint {
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute as CFString, &positionValue)
            AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute as CFString, &sizeValue)

            if let positionValue, let sizeValue,
               CFGetTypeID(positionValue) == AXValueGetTypeID(),
               CFGetTypeID(sizeValue) == AXValueGetTypeID() {
                var position = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

                // NSEvent.mouseLocation uses bottom-left origin; AX uses top-left origin
                let screenHeight = NSScreen.screens.first?.frame.height ?? 0
                let axClickY = screenHeight - clickPoint.y

                let tolerance: CGFloat = 20
                let expandedRect = CGRect(
                    x: position.x - tolerance,
                    y: position.y - tolerance,
                    width: size.width + tolerance * 2,
                    height: size.height + tolerance * 2
                )

                if !expandedRect.contains(CGPoint(x: clickPoint.x, y: axClickY)) {
                    return nil
                }
            }
        }

        return text
    }
}

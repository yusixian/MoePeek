import AppKit
import ApplicationServices

enum AccessibilityGrabber {
    /// Read the selected text from the frontmost application using the Accessibility API.
    /// Returns nil if no text is selected or the app doesn't support AX text selection.
    @MainActor
    static func grabSelectedText() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusResult == .success else { return nil }

        let focusedElement = focusedValue as! AXUIElement

        var selectedValue: CFTypeRef?
        let selectResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )
        guard selectResult == .success, let text = selectedValue as? String, !text.isEmpty else {
            return nil
        }

        return text
    }
}

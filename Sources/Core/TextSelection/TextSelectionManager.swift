/// Three-tier fallback strategy for grabbing selected text:
/// 1. Accessibility API (most apps)
/// 2. AppleScript (Safari-specific)
/// 3. Clipboard simulation (universal fallback)
enum TextSelectionManager {
    @MainActor
    static func grabSelectedText() async -> String? {
        // Tier 1: Accessibility API
        if let text = AccessibilityGrabber.grabSelectedText() {
            return text
        }

        // Tier 2: Safari AppleScript
        if let text = await AppleScriptGrabber.grabFromSafari() {
            return text
        }

        // Tier 3: Clipboard simulation
        return await ClipboardGrabber.grabViaClipboard()
    }
}

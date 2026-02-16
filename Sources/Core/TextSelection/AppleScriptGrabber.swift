import AppKit

enum AppleScriptGrabber {
    /// Grab selected text from Safari using AppleScript + JavaScript.
    /// Returns nil if Safari is not frontmost or the script fails.
    static func grabFromSafari() async -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "com.apple.Safari"
        else { return nil }

        let script = """
            tell application "Safari"
                do JavaScript "window.getSelection().toString()" in front document
            end tell
            """

        guard let appleScript = NSAppleScript(source: script) else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let result = appleScript.executeAndReturnError(&error)

                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    let text = result.stringValue
                    continuation.resume(returning: text?.isEmpty == false ? text : nil)
                }
            }
        }
    }
}

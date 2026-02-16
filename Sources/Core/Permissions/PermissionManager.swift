import AppKit

/// Manages Accessibility permission state with polling, since macOS provides no callback.
@MainActor
@Observable
final class PermissionManager {
    private(set) var isAccessibilityGranted = false
    private var pollTimer: Timer?

    init() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// Prompt the system permission dialog and start polling for changes.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    /// Start polling AXIsProcessTrusted() every 1.5 seconds.
    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if trusted != self.isAccessibilityGranted {
                    self.isAccessibilityGranted = trusted
                }
                if trusted {
                    self.stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

import AppKit
import Defaults

/// Monitors global mouse events and detects text selection via 3-tier fallback:
/// AX API → AppleScript (Safari) → Clipboard (⌘C simulation).
/// Tier 2-3 only trigger on drag or multi-click to avoid invasive clipboard access on plain clicks.
@MainActor
final class SelectionMonitor {
    var onTextSelected: ((String, CGPoint) -> Void)?
    var onMouseDown: ((CGPoint) -> Void)?

    private var globalMonitor: Any?
    private var mouseDownMonitor: Any?
    private var mouseDownPoint: CGPoint?
    private var isSuppressed = false
    private var suppressTask: Task<Void, Never>?

    deinit {
        if let monitor = mouseDownMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        suppressTask?.cancel()
    }

    func start() {
        guard globalMonitor == nil else { return }
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let screenPoint = NSEvent.mouseLocation
            Task { @MainActor in
                self?.mouseDownPoint = screenPoint
                self?.onMouseDown?(screenPoint)
            }
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            let screenPoint = NSEvent.mouseLocation
            let clickCount = event.clickCount
            Task { @MainActor in
                self?.handleMouseUp(at: screenPoint, clickCount: clickCount)
            }
        }
    }

    func stop() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        suppressTask?.cancel()
        suppressTask = nil
    }

    /// Suppress detection for 0.5s — called after dismissing popup/icon to prevent re-trigger.
    func suppressBriefly() {
        isSuppressed = true
        suppressTask?.cancel()
        suppressTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.isSuppressed = false
        }
    }

    private func handleMouseUp(at point: CGPoint, clickCount: Int) {
        guard Defaults[.isAutoDetectEnabled], !isSuppressed else { return }

        // Determine if the gesture looks like a text selection (drag or multi-click)
        var wasDragOrMultiClick = clickCount >= 2
        if !wasDragOrMultiClick, let downPoint = mouseDownPoint {
            let dx = point.x - downPoint.x
            let dy = point.y - downPoint.y
            let distance = sqrt(dx * dx + dy * dy)
            wasDragOrMultiClick = distance > 3
        }
        mouseDownPoint = nil

        Task { @MainActor [weak self] in
            // Wait 100ms for the target app to update its AX selection state
            try? await Task.sleep(for: .milliseconds(100))
            guard let self else { return }

            // Tier 1: Accessibility API — fast, non-invasive
            if let text = AccessibilityGrabber.grabSelectedText(),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.onTextSelected?(text, point)
                return
            }

            // Only attempt fallback tiers if the gesture looks like a selection
            guard wasDragOrMultiClick else { return }

            // Tier 2: AppleScript — Safari-specific JS selection
            if let text = await AppleScriptGrabber.grabFromSafari(),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.onTextSelected?(text, point)
                return
            }

            // Tier 3: Clipboard — simulate ⌘C, read pasteboard, restore
            if let text = await ClipboardGrabber.grabViaClipboard(),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.onTextSelected?(text, point)
                return
            }
        }
    }

}

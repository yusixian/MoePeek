import AppKit

/// Monitors for clicks outside the panel and Escape key to dismiss the popup.
@MainActor
final class PopupDismissMonitor {
    private let panel: NSPanel
    private let onDismiss: @MainActor () -> Void

    private var globalClickMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localClickMonitor: Any?
    private var localKeyMonitor: Any?

    init(panel: NSPanel, onDismiss: @escaping @MainActor () -> Void) {
        self.panel = panel
        self.onDismiss = onDismiss
    }

    func start() {
        // Global monitors: clicks and keys in OTHER applications
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onDismiss()
            }
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.onDismiss()
                }
            }
        }

        // Local monitors: clicks and keys in OUR app (global monitors don't capture these)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            // Only dismiss if click is outside the panel
            let clickLocation = event.locationInWindow
            if event.window !== self.panel {
                Task { @MainActor in
                    self.onDismiss()
                }
            } else if !self.panel.contentView!.frame.contains(clickLocation) {
                Task { @MainActor in
                    self.onDismiss()
                }
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.onDismiss()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }

        globalClickMonitor = nil
        globalKeyMonitor = nil
        localClickMonitor = nil
        localKeyMonitor = nil
    }

    deinit {
        // Safety: remove monitors if stop() wasn't called
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
    }
}

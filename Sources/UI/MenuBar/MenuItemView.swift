import KeyboardShortcuts
import SwiftUI

/// Content for the menu bar dropdown.
struct MenuItemView: View {
    let coordinator: TranslationCoordinator
    let panelController: PopupPanelController

    var body: some View {
        Button("Translate Selection") {
            Task {
                await coordinator.translateSelection()
                panelController.showAtCursor()
            }
        }
        .keyboardShortcut("d", modifiers: .option)

        Button("OCR Screenshot") {
            Task {
                await coordinator.ocrAndTranslate()
                if case .error = coordinator.state {
                    // Don't show panel on cancel
                } else {
                    panelController.showAtCursor()
                }
            }
        }
        .keyboardShortcut("s", modifiers: .option)

        Divider()

        SettingsLink {
            Text("Settings...")
        }

        Divider()

        Button("Quit MoePeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

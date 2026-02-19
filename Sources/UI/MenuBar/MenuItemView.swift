import Defaults
import KeyboardShortcuts
import SwiftUI

/// Content for the menu bar dropdown.
struct MenuItemView: View {
    @Environment(\.openSettings) private var openSettings
    let appDelegate: AppDelegate

    var body: some View {
        Button("About MoePeek") {
            Defaults[.selectedSettingsTab] = .about
            appDelegate.openSettings()
        }

        Divider()

        Button("显示引导页") {
            appDelegate.onboardingController?.showWindow()
        }

        Divider()

        Button("翻译选中文字") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.translateSelection()
                panelController.showAtCursor()
            }
        }
        .keyboardShortcut("d", modifiers: .option)

        Button("OCR 截图翻译") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.ocrAndTranslate()
                if case .idle = coordinator.phase {
                    // Don't show panel on cancel
                } else {
                    panelController.showAtCursor()
                }
            }
        }
        .keyboardShortcut("s", modifiers: .option)

        Divider()

        Button("设置...") {
            appDelegate.openSettings()
        }

        Divider()

        Button("退出 MoePeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openSettings()
        }
    }
}

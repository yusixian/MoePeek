import SwiftUI

@main
struct MoePeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar icon + dropdown
        MenuBarExtra("MoePeek", systemImage: "character.bubble") {
            if let coordinator = appDelegate.coordinator,
               let panelController = appDelegate.panelController
            {
                MenuItemView(coordinator: coordinator, panelController: panelController)
            }
        }

        // Settings window
        Settings {
            SettingsView()
        }
    }
}

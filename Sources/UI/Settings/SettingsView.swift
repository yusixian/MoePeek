import Defaults
import SwiftUI

struct SettingsView: View {
    let registry: TranslationProviderRegistry
    let updaterController: UpdaterController?

    @Default(.selectedSettingsTab) private var selectedTab

    private var tabHeight: CGFloat {
        switch selectedTab {
        case .general: return 680
        case .services: return 580
        case .about: return 420
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            ServiceSettingsView(registry: registry)
                .tabItem {
                    Label("Services", systemImage: "globe")
                }
                .tag(SettingsTab.services)

            AboutSettingsView(updaterController: updaterController)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 720, idealWidth: 720, minHeight: tabHeight, idealHeight: tabHeight)
        .onDisappear {
            // Restore .accessory policy when the Settings window closes,
            // reversing the temporary .regular switch from the popup gear button.
            // Idempotent: no-op when policy is already .accessory or user has showInDock enabled.
            if !Defaults[.showInDock] {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

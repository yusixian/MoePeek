import Defaults
import SwiftUI

struct SettingsView: View {
    let registry: TranslationProviderRegistry
    let updaterController: UpdaterController?

    @Default(.selectedSettingsTab) private var selectedTab

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
        .frame(minWidth: 550, idealWidth: 600, maxWidth: 800,
               minHeight: 400, idealHeight: 480, maxHeight: 700)
    }
}

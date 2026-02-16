import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ServiceSettingsView()
                .tabItem {
                    Label("Services", systemImage: "globe")
                }
        }
        .frame(width: 450, height: 350)
    }
}

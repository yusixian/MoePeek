import SwiftUI

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("MoePeek")
                .font(.title.bold())

            Text("Version \(appVersion) (\(buildNumber))")
                .foregroundStyle(.secondary)

            Text("Copyright © 2025 MoePeek. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Licensed under AGPL-3.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            HStack {
                Link(destination: URL(string: "https://discord.gg/placeholder")!) {
                    Label("Discord 反馈", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsSettingsView: View {
    @Default(.excludedAppBundleIDs) private var excludedAppBundleIDs

    @State private var resolvedExcludedApps: [AppInfo] = []
    @State private var selectedBundleID: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Apps in the blocklist will not trigger automatic text selection detection.")
                .padding(.top)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(resolvedExcludedApps, id: \.bundleID) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text(app.name)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedBundleID == app.bundleID ? Color.accentColor.opacity(0.3) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedBundleID = app.bundleID
                        }
                    }
                }
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            HStack(spacing: 0) {
                Button(action: addApp) {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 32, height: 24)

                Divider().frame(height: 16)

                Button(action: removeSelected) {
                    Image(systemName: "minus")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 32, height: 24)
                .disabled(selectedBundleID == nil)

                Spacer()
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .onChange(of: excludedAppBundleIDs, initial: true) { _, newValue in
            resolvedExcludedApps = newValue.sorted().map { AppInfo.resolve($0) }
            if let id = selectedBundleID, !newValue.contains(id) {
                selectedBundleID = nil
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add")

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            if let bundle = Bundle(url: url),
               let bundleID = bundle.bundleIdentifier {
                excludedAppBundleIDs.insert(bundleID)
            }
        }
    }

    private func removeSelected() {
        guard let bundleID = selectedBundleID else { return }
        excludedAppBundleIDs.remove(bundleID)
        selectedBundleID = nil
    }
}

// MARK: - App Info Resolution

private struct AppInfo {
    let bundleID: String
    let name: String
    let icon: NSImage

    static func resolve(_ bundleID: String) -> AppInfo {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return AppInfo(bundleID: bundleID, name: name, icon: icon)
        }
        let fallbackIcon = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 20, height: 20))
        return AppInfo(bundleID: bundleID, name: bundleID, icon: fallbackIcon)
    }
}

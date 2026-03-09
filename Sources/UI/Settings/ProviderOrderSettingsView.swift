import Defaults
import SwiftUI

/// Settings view for reordering enabled translation providers via drag-and-drop.
struct ProviderOrderSettingsView: View {
    let registry: TranslationProviderRegistry

    @Default(.enabledProviders) private var enabledProviders
    @Default(.providerOrder) private var providerOrder

    /// Enabled providers sorted by the user's preferred order.
    private var orderedProviders: [any TranslationProvider] {
        let enabled = registry.providers.filter { enabledProviders.contains($0.id) }
        var seen = Set<String>()
        var result: [any TranslationProvider] = []

        for id in providerOrder {
            if let provider = enabled.first(where: { $0.id == id }) {
                result.append(provider)
                seen.insert(id)
            }
        }
        for provider in enabled where !seen.contains(provider.id) {
            result.append(provider)
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Provider Display Order")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 4)

            Text("Drag to reorder. This controls the display order of translation results.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if orderedProviders.isEmpty {
                ContentUnavailableView(
                    "No Providers Enabled",
                    systemImage: "globe",
                    description: Text("Enable at least one provider in the Services tab to configure display order.")
                )
            } else {
                List {
                    ForEach(orderedProviders, id: \.id) { provider in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                                .font(.callout)

                            ProviderIconView(provider: provider, size: 18)

                            Text(provider.displayName)
                                .font(.body)

                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { source, destination in
                        moveProviders(from: source, to: destination)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Helpers

    private func moveProviders(from source: IndexSet, to destination: Int) {
        var ids = orderedProviders.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        providerOrder = ids
    }
}

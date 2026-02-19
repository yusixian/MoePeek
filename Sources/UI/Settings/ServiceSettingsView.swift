import Defaults
import SwiftUI

/// Settings view for translation providers — left-right split layout.
struct ServiceSettingsView: View {
    let registry: TranslationProviderRegistry

    @Default(.enabledProviders) private var enabledProviders
    @State private var selectedProviderID: String?

    var body: some View {
        HSplitView {
            // Left: Provider list
            providerList
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 220)

            // Right: Selected provider settings
            providerDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedProviderID == nil {
                selectedProviderID = registry.providers.first?.id
            }
        }
    }

    // MARK: - Provider List

    @ViewBuilder
    private var providerList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Providers")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            List(selection: $selectedProviderID) {
                ForEach(registry.providers, id: \.id) { provider in
                    HStack(spacing: 8) {
                        Toggle("", isOn: providerEnabledBinding(for: provider.id))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()

                        Image(systemName: provider.iconSystemName)
                            .font(.callout)
                            .frame(width: 16)

                        Text(provider.displayName)
                            .font(.callout)

                        Spacer()
                    }
                    .tag(provider.id)
                    .contentShape(Rectangle())
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Provider Detail

    @ViewBuilder
    private var providerDetail: some View {
        if let id = selectedProviderID,
           let provider = registry.provider(withID: id)
        {
            ScrollView {
                provider.makeSettingsView()
            }
        } else {
            ContentUnavailableView(
                "Select a Provider",
                systemImage: "globe",
                description: Text("Choose a provider from the list to configure it.")
            )
        }
    }

    // MARK: - Helpers

    private func providerEnabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabledProviders.contains(id) },
            set: { isEnabled in
                if isEnabled {
                    enabledProviders.insert(id)
                } else {
                    enabledProviders.remove(id)
                }
            }
        )
    }
}

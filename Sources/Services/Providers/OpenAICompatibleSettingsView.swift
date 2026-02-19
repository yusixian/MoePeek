import Defaults
import SwiftUI

/// Settings view for an OpenAI-compatible provider. Reads keys from the provider instance.
struct OpenAICompatibleSettingsView: View {
    let provider: OpenAICompatibleProvider

    @State private var apiKey: String = ""

    var body: some View {
        Form {
            Section("API Configuration") {
                TextField("Base URL:", text: Defaults.binding(provider.baseURLKey))
                    .textFieldStyle(.roundedBorder)

                TextField("Model:", text: Defaults.binding(provider.modelKey))
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key:", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        if newValue.isEmpty {
                            KeychainHelper.delete(key: provider.keychainKey)
                        } else {
                            KeychainHelper.save(key: provider.keychainKey, value: newValue)
                        }
                    }
            }

            Section("System Prompt") {
                TextEditor(text: Defaults.binding(provider.systemPromptKey))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                Text("Use {targetLang} as placeholder for target language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            apiKey = KeychainHelper.load(key: provider.keychainKey) ?? ""
        }
    }
}

// MARK: - Defaults Binding Helper

private extension Defaults {
    static func binding(_ key: Defaults.Key<String>) -> Binding<String> {
        Binding(
            get: { Defaults[key] },
            set: { Defaults[key] = $0 }
        )
    }
}

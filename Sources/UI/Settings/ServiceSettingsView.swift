import Defaults
import SwiftUI

struct ServiceSettingsView: View {
    @Default(.openAIBaseURL) private var baseURL
    @Default(.openAIModel) private var model
    @Default(.preferredService) private var preferredService
    @Default(.systemPromptTemplate) private var systemPrompt

    @State private var apiKey: String = KeychainHelper.load(key: "openai_api_key") ?? ""

    private var isAppleTranslationAvailable: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            Section("Preferred Service") {
                Picker("Default Service:", selection: $preferredService) {
                    Text("OpenAI Compatible").tag("openai")
                    if isAppleTranslationAvailable {
                        Text("Apple Translation").tag("apple")
                    }
                }
            }

            Section("OpenAI Compatible API") {
                TextField("Base URL:", text: $baseURL)
                    .textFieldStyle(.roundedBorder)

                TextField("Model:", text: $model)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key:", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        if newValue.isEmpty {
                            KeychainHelper.delete(key: "openai_api_key")
                        } else {
                            KeychainHelper.save(key: "openai_api_key", value: newValue)
                        }
                    }

                DisclosureGroup("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                    Text("Use {targetLang} as placeholder for target language.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isAppleTranslationAvailable {
                Section("Apple Translation") {
                    Text("Available on this system (macOS 15+). No API key needed.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

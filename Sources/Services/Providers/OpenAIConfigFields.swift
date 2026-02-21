import Defaults
import SwiftUI

/// Reusable OpenAI-compatible API configuration fields with model fetching and connection testing.
/// Binds directly to Defaults keys so values update immediately when switching providers.
struct OpenAIConfigFields: View {
    let provider: OpenAICompatibleProvider

    @State private var connectionManager = OpenAIConnectionManager()

    private var baseURL: Binding<String> { Defaults.binding(provider.baseURLKey) }
    private var apiKey: Binding<String> { Defaults.binding(provider.apiKeyKey) }
    private var model: Binding<String> { Defaults.binding(provider.modelKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.subheadline.bold())
                TextField(provider.baseURLKey.defaultValue, text: baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.subheadline.bold())
                SecureField("sk-...", text: apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    TextField(provider.modelKey.defaultValue, text: model)
                        .textFieldStyle(.roundedBorder)

                    ModelFetchAccessory(
                        connectionManager: connectionManager,
                        model: model,
                        baseURL: baseURL.wrappedValue,
                        apiKey: apiKey.wrappedValue
                    )
                }
            }

            if let error = connectionManager.modelFetchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ConnectionTestView(
                connectionManager: connectionManager,
                baseURL: baseURL.wrappedValue,
                apiKey: apiKey.wrappedValue,
                model: model.wrappedValue
            )
        }
        .onChange(of: baseURL.wrappedValue) { _, _ in connectionManager.clearModels() }
        .onChange(of: apiKey.wrappedValue) { _, _ in connectionManager.clearModels() }
    }
}

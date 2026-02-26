import Defaults
import SwiftUI

/// Reusable OpenAI-compatible API configuration fields with model fetching and connection testing.
/// Binds directly to Defaults keys so values update immediately when switching providers.
struct OpenAIConfigFields: View {
    let provider: OpenAICompatibleProvider
    var compact: Bool = false

    @State private var connectionManager: OpenAIConnectionManager
    @State private var baseURLText: String
    @State private var apiKeyText: String
    @State private var modelText: String
    @State private var enabledModelsState: Set<String>
    private let metaService = ModelMetadataService.shared

    init(provider: OpenAICompatibleProvider, compact: Bool = false) {
        self.provider = provider
        self.compact = compact
        self._connectionManager = State(initialValue: OpenAIConnectionManager())
        self._baseURLText = State(initialValue: Defaults[provider.baseURLKey])
        self._apiKeyText = State(initialValue: Defaults[provider.apiKeyKey])
        self._modelText = State(initialValue: Defaults[provider.modelKey])
        self._enabledModelsState = State(initialValue: Defaults[provider.enabledModelsKey])
    }

    private var model: Binding<String> {
        Binding(
            get: { modelText },
            set: { newValue in
                modelText = newValue
                Defaults[provider.modelKey] = newValue
            }
        )
    }
    private var enabledModels: Binding<Set<String>> {
        Binding(
            get: { enabledModelsState },
            set: {
                enabledModelsState = $0
                Defaults[provider.enabledModelsKey] = $0
            }
        )
    }

    /// Chat-like model IDs to keep; filters out embedding, audio, image, moderation models.
    private static let excludedPrefixes = ["embedding", "text-embedding", "whisper", "dall-e", "tts", "davinci", "babbage"]
    private static let excludedSuffixes = ["-embedding", "-search", "-similarity"]

    private var filteredModels: [String] {
        connectionManager.fetchedModels.filter { id in
            let lower = id.lowercased()
            let excluded = Self.excludedPrefixes.contains { lower.hasPrefix($0) }
                || Self.excludedSuffixes.contains { lower.hasSuffix($0) }
                || lower.contains("embed")
                || lower.contains("moderation")
            return !excluded
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Base URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL")
                    .font(.subheadline.bold())
                TextField(provider.baseURLKey.defaultValue, text: $baseURLText)
                    .textFieldStyle(.roundedBorder)
            }

            // API Key
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.subheadline.bold())
                SecureField("sk-...", text: $apiKeyText)
                    .textFieldStyle(.roundedBorder)
            }

            // Default Model (fallback when no multi-model enabled)
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Model")
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    TextField(provider.modelKey.defaultValue, text: model)
                        .textFieldStyle(.roundedBorder)

                    ModelFetchAccessory(
                        connectionManager: connectionManager,
                        model: model,
                        baseURL: baseURLText,
                        apiKey: apiKeyText,
                        extraHeaders: provider.extraHeaders
                    )
                }
                if !compact, enabledModels.wrappedValue.isEmpty {
                    Text("Used when no models are selected below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = connectionManager.modelFetchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !compact {
                // Multi-model selection
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Parallel Models")
                            .font(.subheadline.bold())
                        Spacer()
                    }

                    ParallelModelsList(
                        fetchedModels: filteredModels,
                        enabledModels: enabledModels,
                        metaService: metaService,
                        defaultModel: modelText
                    )
                }
            }

            ConnectionTestView(
                connectionManager: connectionManager,
                baseURL: baseURLText,
                apiKey: apiKeyText,
                model: model.wrappedValue,
                extraHeaders: provider.extraHeaders
            )
        }
        .onChange(of: baseURLText) { _, newValue in
            Defaults[provider.baseURLKey] = newValue
            connectionManager.clearModels()
        }
        .onChange(of: apiKeyText) { _, newValue in
            Defaults[provider.apiKeyKey] = newValue
            connectionManager.clearModels()
        }
        .onReceive(Defaults.publisher(provider.baseURLKey).map(\.newValue)) { newValue in
            if baseURLText != newValue { baseURLText = newValue }
        }
        .onReceive(Defaults.publisher(provider.apiKeyKey).map(\.newValue)) { newValue in
            if apiKeyText != newValue { apiKeyText = newValue }
        }
        .onReceive(Defaults.publisher(provider.modelKey).map(\.newValue)) { newValue in
            if modelText != newValue { modelText = newValue }
        }
        .onReceive(Defaults.publisher(provider.enabledModelsKey).map(\.newValue)) { newValue in
            if enabledModelsState != newValue { enabledModelsState = newValue }
        }
        .task {
            if !compact,
               connectionManager.fetchedModels.isEmpty,
               !apiKeyText.isEmpty,
               !baseURLText.isEmpty {
                await connectionManager.fetchModels(
                    baseURL: baseURLText,
                    apiKey: apiKeyText,
                    extraHeaders: provider.extraHeaders,
                    silent: true
                )
            }
            if !compact {
                await metaService.fetchIfNeeded()
            }
        }
    }

}

// MARK: - Model Checkbox Row

struct ModelCheckboxRow: View {
    let modelID: String
    let isEnabled: Bool
    let isUnknown: Bool
    let isDisabled: Bool
    var isDefault: Bool = false
    var metaMatch: ModelMetadataService.MetaMatch? = nil
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if isDefault {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                }
                Text(modelID)
                    .lineLimit(1)
                if isDefault {
                    Text("(default)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if isUnknown && metaMatch == nil && !isDefault {
                    Text("(unknown)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let match = metaMatch {
                    ModelCapabilityBadges(match: match)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isDefault)
        .opacity(isDisabled ? 0.5 : 1)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
}

// MARK: - Model Capability Badges

private struct ModelCapabilityBadges: View {
    let match: ModelMetadataService.MetaMatch

    private var meta: ModelMetadataService.ModelMeta { match.meta }
    private var isApproximate: Bool { match.matchKind == .approximate }

    var body: some View {
        HStack(spacing: 4) {
            if let ctx = meta.contextWindow {
                Text(formatContext(ctx))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if meta.toolCall {
                Image(systemName: "hammer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help(LocalizedStringKey("Supports tool calling"))
            }
            if meta.reasoning {
                Image(systemName: "brain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help(LocalizedStringKey("Supports reasoning / chain-of-thought"))
            }
            if isApproximate {
                Image(systemName: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help(LocalizedStringKey("Capability info based on approximate match and may be inaccurate"))
            }
        }
        .opacity(isApproximate ? 0.6 : 1)
    }

    private func formatContext(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return tokens % 1_000_000 == 0
                ? "\(tokens / 1_000_000)M"
                : String(format: "%.1fM", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 { return "\(tokens / 1_000)K" }
        return "\(tokens)"
    }
}

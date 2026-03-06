import Defaults
import Foundation
import Observation

/// Container for all registered translation providers.
@MainActor @Observable
final class TranslationProviderRegistry {
    /// All providers available on this system (filtered by `isAvailable`).
    private(set) var providers: [any TranslationProvider]

    init(providers: [any TranslationProvider]) {
        self.providers = providers.filter { $0.isAvailable }
    }

    /// Providers the user has enabled (via Defaults).
    var enabledProviders: [any TranslationProvider] {
        let ids = Defaults[.enabledProviders]
        return providers.filter { ids.contains($0.id) }
    }

    /// Enabled providers expanded into per-model slots.
    /// Multi-model providers yield one `ModelSlotProvider` per active model;
    /// single-model providers pass through unchanged (preserving their original id).
    /// Order respects `providerOrder` user preference; unordered providers append at end.
    var enabledSlots: [any TranslationProvider] {
        let ids = Defaults[.enabledProviders]
        let enabledProviders = providers.filter { ids.contains($0.id) }

        // Build ordered list: providerOrder first, then remaining by registration order
        let order = Defaults[.providerOrder]
        var seen = Set<String>()
        var ordered: [any TranslationProvider] = []

        for id in order {
            if let provider = enabledProviders.first(where: { $0.id == id }) {
                appendSlots(for: provider, to: &ordered)
                seen.insert(id)
            }
        }
        for provider in enabledProviders where !seen.contains(provider.id) {
            appendSlots(for: provider, to: &ordered)
        }

        return ordered
    }

    /// Expand a single provider into its model slots and append to the result array.
    private func appendSlots(for provider: any TranslationProvider, to result: inout [any TranslationProvider]) {
        let models = provider.activeModels
        if models.isEmpty {
            result.append(provider)
        } else {
            for model in models.prefix(maxParallelModels) {
                result.append(ModelSlotProvider(inner: provider, modelOverride: model))
            }
        }
    }

    func provider(withID id: String) -> (any TranslationProvider)? {
        providers.first { $0.id == id }
    }

    /// Providers grouped by category, preserving registration order within each group.
    var groupedProviders: [(category: ProviderCategory, providers: [any TranslationProvider])] {
        var grouped: [ProviderCategory: [any TranslationProvider]] = [:]
        for provider in providers {
            grouped[provider.category, default: []].append(provider)
        }
        return ProviderCategory.allCases.compactMap { category in
            guard let list = grouped[category], !list.isEmpty else { return nil }
            return (category: category, providers: list)
        }
    }

    // MARK: - Custom Provider Management

    func addCustomProvider(_ def: CustomProviderDefinition) {
        var defs = Defaults[.customProviders]
        defs.append(def)
        Defaults[.customProviders] = defs
        providers.append(OpenAICompatibleProvider(definition: def))
    }

    func removeCustomProvider(id: String) {
        // Persist removal to Defaults before mutating `providers`,
        // because @Observable triggers immediate UI refresh.
        var defs = Defaults[.customProviders]
        defs.removeAll { $0.id == id }
        Defaults[.customProviders] = defs
        var enabled = Defaults[.enabledProviders]
        enabled.remove(id)
        Defaults[.enabledProviders] = enabled
        Defaults[.providerOrder].removeAll { $0 == id }
        OpenAICompatibleProvider.cleanupDefaults(for: id)
        providers.removeAll { $0.id == id }
    }

    /// Factory method returning the built-in provider set.
    static func builtIn() -> TranslationProviderRegistry {
        var allProviders: [any TranslationProvider] = [
            // Free Translation
            GoogleTranslateProvider(),
            BingTranslateProvider(),
            YoudaoTranslateProvider(),

            // Translation APIs
            DeepLProvider(),
            DeepLXProvider(),
            BaiduTranslateProvider(),
            NiuTransProvider(),
            CaiyunProvider(),

            // LLM Services
            OpenAICompatibleProvider(
                id: "openai",
                displayName: "OpenAI",
                iconSystemName: "brain",
                iconAssetName: "OpenAI",
                defaultBaseURL: "https://api.openai.com/v1",
                defaultModel: "gpt-4o-mini",
                guideURL: "https://platform.openai.com/api-keys"
            ),
            OpenAICompatibleProvider(
                id: "deepseek",
                displayName: "DeepSeek",
                iconSystemName: "brain.head.profile",
                iconAssetName: "DeepSeek",
                defaultBaseURL: "https://api.deepseek.com/v1",
                defaultModel: "deepseek-chat",
                guideURL: "https://platform.deepseek.com/api_keys"
            ),
            OpenAICompatibleProvider(
                id: "zhipu",
                displayName: "智谱 GLM",
                iconSystemName: "sparkles",
                iconAssetName: "Zhipu",
                defaultBaseURL: "https://open.bigmodel.cn/api/paas/v4",
                defaultModel: "glm-4-flash",
                guideURL: "https://open.bigmodel.cn/usercenter/apikeys"
            ),
            OpenAICompatibleProvider(
                id: "openrouter",
                displayName: "OpenRouter",
                iconSystemName: "network",
                iconAssetName: "OpenRouter",
                defaultBaseURL: "https://openrouter.ai/api/v1",
                defaultModel: "openrouter/auto",
                guideURL: "https://openrouter.ai/keys",
                extraHeaders: [
                    "HTTP-Referer": "https://github.com/cosZone/MoePeek",
                    "X-OpenRouter-Title": "MoePeek",
                ]
            ),
            AnthropicProvider(),
            OllamaProvider(),
            LMStudioProvider(),
        ]

        // System
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            allProviders.append(AppleTranslationProvider())
        }
        #endif

        // Custom providers
        for def in Defaults[.customProviders] {
            allProviders.append(OpenAICompatibleProvider(definition: def))
        }

        return TranslationProviderRegistry(providers: allProviders)
    }
}

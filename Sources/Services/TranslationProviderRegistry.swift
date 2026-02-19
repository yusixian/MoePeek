import Defaults

/// Container for all registered translation providers.
@MainActor
final class TranslationProviderRegistry {
    /// All providers available on this system (filtered by `isAvailable`).
    let providers: [any TranslationProvider]

    init(providers: [any TranslationProvider]) {
        self.providers = providers.filter { $0.isAvailable }
    }

    /// Providers the user has enabled (via Defaults).
    var enabledProviders: [any TranslationProvider] {
        let ids = Defaults[.enabledProviders]
        return providers.filter { ids.contains($0.id) }
    }

    func provider(withID id: String) -> (any TranslationProvider)? {
        providers.first { $0.id == id }
    }

    /// Factory method returning the built-in provider set.
    static func builtIn() -> TranslationProviderRegistry {
        var allProviders: [any TranslationProvider] = [
            OpenAICompatibleProvider(
                id: "openai",
                displayName: "OpenAI",
                iconSystemName: "brain",
                defaultBaseURL: "https://api.openai.com/v1",
                defaultModel: "gpt-4o-mini"
            ),
        ]

        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            allProviders.append(AppleTranslationProvider())
        }
        #endif

        return TranslationProviderRegistry(providers: allProviders)
    }
}

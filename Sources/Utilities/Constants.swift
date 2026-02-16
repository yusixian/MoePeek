import Defaults
import KeyboardShortcuts

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let translateSelection = Self("translateSelection", default: .init(.d, modifiers: .option))
    static let ocrScreenshot = Self("ocrScreenshot", default: .init(.s, modifiers: .option))
}

// MARK: - User Defaults Keys

extension Defaults.Keys {
    static let targetLanguage = Key<String>("targetLanguage", default: "zh-Hans")
    static let sourceLanguage = Key<String>("sourceLanguage", default: "auto")

    // OpenAI-compatible API
    static let openAIBaseURL = Key<String>("openAIBaseURL", default: "https://api.openai.com/v1")
    static let openAIModel = Key<String>("openAIModel", default: "gpt-4o-mini")
    static let systemPromptTemplate = Key<String>(
        "systemPromptTemplate",
        default: "Translate the following text to {targetLang}. Only output the translation, nothing else."
    )

    // Translation service
    static let preferredService = Key<String>("preferredService", default: "openai")

    // Clipboard grabber timeout
    static let clipboardTimeout = Key<Int>("clipboardTimeout", default: 200)
}

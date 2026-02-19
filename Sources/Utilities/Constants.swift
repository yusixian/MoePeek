import Defaults
import KeyboardShortcuts

// MARK: - Supported Languages

/// Languages available for translation UI and provider checks.
enum SupportedLanguages {
    /// All supported language codes and display names.
    static let all: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("pt-BR", "Português (Brasil)"),
        ("ru", "Русский"),
        ("ar", "العربية"),
        ("it", "Italiano"),
        ("th", "ไทย"),
        ("vi", "Tiếng Việt"),
    ]

    /// Set of all supported language codes.
    static let codes: Set<String> = Set(all.map(\.code))
}

// MARK: - Settings Tab

enum SettingsTab: String, Defaults.Serializable {
    case general
    case services
    case about
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let translateSelection = Self("translateSelection", default: .init(.d, modifiers: .option))
    static let ocrScreenshot = Self("ocrScreenshot", default: .init(.s, modifiers: .option))
}

// MARK: - User Defaults Keys

extension Defaults.Keys {
    static let targetLanguage = Key<String>("targetLanguage", default: "zh-Hans")
    static let sourceLanguage = Key<String>("sourceLanguage", default: "auto")

    // Enabled translation providers
    static let enabledProviders = Key<Set<String>>("enabledProviders", default: ["openai"])

    // Clipboard grabber timeout
    static let clipboardTimeout = Key<Int>("clipboardTimeout", default: 200)

    // Auto-detect text selection
    static let isAutoDetectEnabled = Key<Bool>("isAutoDetectEnabled", default: true)

    // Appearance
    static let showInDock = Key<Bool>("showInDock", default: true)

    // Onboarding
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)

    // Popup panel default size
    static let popupDefaultWidth = Key<Int>("popupDefaultWidth", default: 450)
    static let popupDefaultHeight = Key<Int>("popupDefaultHeight", default: 350)

    // Settings tab selection
    static let selectedSettingsTab = Key<SettingsTab>("selectedSettingsTab", default: .general)
}

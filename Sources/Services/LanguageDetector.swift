import NaturalLanguage

enum LanguageDetector {
    /// Detect the dominant language of the given text using NLLanguageRecognizer.
    /// Returns a BCP 47 language code (e.g. "en", "zh-Hans", "ja") or nil if undetermined.
    static func detect(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else { return nil }

        // Map NLLanguage raw values to standard BCP 47 codes
        switch language {
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        default: return language.rawValue
        }
    }
}

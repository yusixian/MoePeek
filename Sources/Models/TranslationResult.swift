import Foundation

struct TranslationResult: Codable, Identifiable, Sendable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLang: String
    let targetLang: String
    let service: String
    let timestamp: Date

    init(
        sourceText: String,
        translatedText: String,
        sourceLang: String,
        targetLang: String,
        service: String
    ) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.service = service
        self.timestamp = Date()
    }
}

/// Protocol for translation backends.
protocol TranslationService: Sendable {
    var name: String { get }

    /// Translate text, returning the full result at once.
    func translate(_ text: String, from sourceLang: String?, to targetLang: String) async throws -> String

    /// Translate text, streaming partial results as they arrive.
    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error>
}

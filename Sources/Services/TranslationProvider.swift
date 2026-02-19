import SwiftUI

/// Plugin protocol for translation backends. Each provider is self-contained:
/// owns its translation logic, settings UI, and configuration storage.
protocol TranslationProvider: Sendable {
    /// Unique identifier used for Defaults/Keychain namespacing, e.g. "openai", "apple".
    var id: String { get }
    /// Display name shown in UI.
    var displayName: String { get }
    /// SF Symbol icon name.
    var iconSystemName: String { get }
    /// Whether this provider supports streaming output.
    var supportsStreaming: Bool { get }
    /// Whether this provider is available on the current system.
    var isAvailable: Bool { get }
    /// Whether the provider has been configured (e.g. API key set).
    @MainActor var isConfigured: Bool { get }

    /// Stream translation results. Non-streaming providers yield the full result at once.
    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error>

    /// Return a settings view for this provider.
    @MainActor func makeSettingsView() -> AnyView
}

// MARK: - Translation Errors

enum TranslationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingAPIKey
    case apiError(statusCode: Int, message: String)
    case emptyResult
    case languageNotInstalled(source: String?, target: String)
    case languageUnsupported(source: String?, target: String)
    case translationSessionFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid API URL"
        case .invalidResponse: "Invalid response from server"
        case .missingAPIKey: "API key not configured. Go to Settings to set it up."
        case let .apiError(code, msg): "API error (\(code)): \(msg)"
        case .emptyResult: "Translation returned empty result"
        case let .languageNotInstalled(src, tgt):
            "Language pack not downloaded (\(src ?? "auto") → \(tgt)). Download it in Settings or try another provider."
        case let .languageUnsupported(src, tgt):
            "Language pair not supported (\(src ?? "auto") → \(tgt)). Try another provider."
        case .translationSessionFailed:
            "Translation session ended unexpectedly. Please try again."
        }
    }
}

import Defaults
import Foundation
import SwiftUI

/// A parameterized provider for any OpenAI-compatible API (OpenAI, DeepSeek, Groq, etc.).
struct OpenAICompatibleProvider: TranslationProvider {
    let id: String
    let displayName: String
    let iconSystemName: String
    let supportsStreaming = true
    let isAvailable = true

    // Namespaced Defaults keys
    let baseURLKey: Defaults.Key<String>
    let modelKey: Defaults.Key<String>
    let systemPromptKey: Defaults.Key<String>
    let keychainKey: String

    init(
        id: String,
        displayName: String,
        iconSystemName: String = "globe",
        defaultBaseURL: String,
        defaultModel: String
    ) {
        self.id = id
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.baseURLKey = .init("provider_\(id)_baseURL", default: defaultBaseURL)
        self.modelKey = .init("provider_\(id)_model", default: defaultModel)
        self.systemPromptKey = .init(
            "provider_\(id)_systemPrompt",
            default: "Translate the following text to {targetLang}. Only output the translation, nothing else."
        )
        self.keychainKey = "provider.\(id).apiKey"
    }

    @MainActor
    var isConfigured: Bool {
        guard let apiKey = KeychainHelper.load(key: keychainKey), !apiKey.isEmpty else {
            return false
        }
        return true
    }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try buildRequest(text: text, sourceLang: sourceLang, targetLang: targetLang)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw TranslationError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        throw TranslationError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONDecoder().decode(SSEChunk.self, from: data),
                              let content = json.choices.first?.delta.content
                        else { continue }

                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor
    func makeSettingsView() -> AnyView {
        AnyView(OpenAICompatibleSettingsView(provider: self))
    }

    // MARK: - Private

    private func buildRequest(text: String, sourceLang: String?, targetLang: String) throws -> URLRequest {
        let baseURL = Defaults[baseURLKey].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw TranslationError.invalidURL
        }
        guard let apiKey = KeychainHelper.load(key: keychainKey), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey
        }

        let promptTemplate = Defaults[systemPromptKey]
        let systemPrompt = promptTemplate.replacingOccurrences(of: "{targetLang}", with: targetLang)

        let body: [String: Any] = [
            "model": Defaults[modelKey],
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
        ]

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}

// MARK: - SSE JSON Models

private struct SSEChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }
}

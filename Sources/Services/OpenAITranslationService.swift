import Defaults
import Foundation

struct OpenAITranslationService: TranslationService {
    let name = "openai"

    func translate(_ text: String, from sourceLang: String?, to targetLang: String) async throws -> String {
        var result = ""
        for try await chunk in translateStream(text, from: sourceLang, to: targetLang) {
            result += chunk
        }
        return result
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
                        // Read error body
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

    // MARK: - Private

    private func buildRequest(text: String, sourceLang: String?, targetLang: String) throws -> URLRequest {
        let baseURL = Defaults[.openAIBaseURL].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw TranslationError.invalidURL
        }
        guard let apiKey = KeychainHelper.load(key: "openai_api_key"), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey
        }

        let promptTemplate = Defaults[.systemPromptTemplate]
        let systemPrompt = promptTemplate.replacingOccurrences(of: "{targetLang}", with: targetLang)

        let body: [String: Any] = [
            "model": Defaults[.openAIModel],
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
        ]

        var request = URLRequest(url: url)
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

// MARK: - Errors

enum TranslationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingAPIKey
    case apiError(statusCode: Int, message: String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid API URL"
        case .invalidResponse: "Invalid response from server"
        case .missingAPIKey: "API key not configured. Go to Settings to set it up."
        case let .apiError(code, msg): "API error (\(code)): \(msg)"
        case .emptyResult: "Translation returned empty result"
        }
    }
}

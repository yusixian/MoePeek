import Foundation

/// Manager for testing connections and fetching models from the Anthropic API.
@MainActor @Observable
final class AnthropicConnectionManager {

    // MARK: - Connection Test State

    var isTestingConnection = false
    var testResult: TestResult?

    // MARK: - Model Fetch State

    var fetchedModels: [String] = []
    var isFetchingModels = false
    var modelFetchError: String?

    enum TestResult: Equatable {
        case success(latencyMs: Int)
        case failure(message: String)
    }

    // MARK: - Actions

    func fetchModels(baseURL: String, apiKey: String, silent: Bool = false) async {
        guard !isFetchingModels else { return }
        guard let baseValidated = validatedURL(base: baseURL, path: "/v1/models", apiKey: apiKey) else {
            if !silent {
                modelFetchError = String(localized: "Please enter a valid Base URL (starting with http:// or https://) and API Key")
            }
            return
        }

        isFetchingModels = true
        modelFetchError = nil
        defer { isFetchingModels = false }

        var allModels: [String] = []
        var afterID: String? = nil
        let maxPages = 50

        do {
            for _ in 0..<maxPages {
                guard var components = URLComponents(url: baseValidated, resolvingAgainstBaseURL: false) else {
                    if !silent { modelFetchError = String(localized: "Invalid URL") }
                    return
                }
                var queryItems = components.queryItems ?? []
                if let afterID {
                    queryItems.append(URLQueryItem(name: "after_id", value: afterID))
                }
                components.queryItems = queryItems.isEmpty ? nil : queryItems

                guard let requestURL = components.url else {
                    if !silent { modelFetchError = String(localized: "Invalid URL") }
                    return
                }
                var request = URLRequest(url: requestURL)
                request.timeoutInterval = 15
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue(AnthropicProvider.apiVersion, forHTTPHeaderField: "anthropic-version")

                let (data, response) = try await translationURLSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    if !silent { modelFetchError = String(localized: "Invalid response") }
                    return
                }
                guard httpResponse.statusCode == 200 else {
                    if !silent { modelFetchError = String(localized: "Request failed (\(httpResponse.statusCode))") }
                    return
                }

                let decoded = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
                allModels.append(contentsOf: decoded.data.map(\.id))

                if decoded.hasMore, let lastID = decoded.lastId {
                    afterID = lastID
                } else {
                    break
                }
            }
            fetchedModels = allModels.sorted()
        } catch is DecodingError {
            if !silent { modelFetchError = String(localized: "Invalid response format") }
        } catch {
            if !silent { modelFetchError = String(localized: "Network error: \(error.localizedDescription)") }
        }
    }

    func testConnection(baseURL: String, apiKey: String, model: String) async {
        guard !isTestingConnection else { return }
        guard !model.isEmpty,
              let url = validatedURL(base: baseURL, path: "/v1/messages", apiKey: apiKey) else {
            testResult = .failure(message: String(localized: "Please fill in the complete configuration (URL must start with http:// or https://)"))
            return
        }

        isTestingConnection = true
        testResult = nil
        defer { isTestingConnection = false }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "stream": false,
            "messages": [
                ["role": "user", "content": "Hi"],
            ],
        ]

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicProvider.apiVersion, forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            testResult = .failure(message: String(localized: "Request build failed"))
            return
        }

        let start = ContinuousClock.now
        do {
            let (data, response) = try await translationURLSession.data(for: request)
            let ms = Int((ContinuousClock.now - start) / .milliseconds(1))

            guard let httpResponse = response as? HTTPURLResponse else {
                testResult = .failure(message: String(localized: "Invalid response"))
                return
            }
            guard httpResponse.statusCode == 200 else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                if let errorData = bodyText.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: errorData) {
                    testResult = .failure(message: "HTTP \(httpResponse.statusCode): \(decoded.error.message)")
                } else {
                    let preview = String(bodyText.prefix(200))
                    testResult = .failure(message: "HTTP \(httpResponse.statusCode): \(preview)")
                }
                return
            }
            testResult = .success(latencyMs: ms)
        } catch {
            testResult = .failure(message: error.localizedDescription)
        }
    }

    func clearModels() {
        fetchedModels = []
        modelFetchError = nil
        testResult = nil
    }

    // MARK: - Private

    private func validatedURL(base: String, path: String, apiKey: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .init(charactersIn: "/"))
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
              !apiKey.isEmpty else { return nil }
        return URL(string: "\(trimmed)\(path)")
    }
}

// MARK: - Anthropic Error Response (shared with AnthropicProvider)

struct AnthropicErrorResponse: Decodable, Sendable {
    let error: ErrorContent

    struct ErrorContent: Decodable, Sendable {
        let type: String
        let message: String
    }
}

// MARK: - Anthropic Models Response

private struct AnthropicModelsResponse: Decodable {
    let data: [ModelEntry]
    let hasMore: Bool
    let lastId: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case lastId = "last_id"
    }

    struct ModelEntry: Decodable {
        let id: String
    }
}

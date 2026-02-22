import CommonCrypto
import CryptoKit
import Foundation
import SwiftUI

private let youdaoUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

private func youdaoMD5Hex(_ string: String) -> String {
    let data = Data(string.utf8)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// Youdao Translate (有道翻译) provider using the free web API (no API key required).
struct YoudaoTranslateProvider: TranslationProvider {
    let id = "youdao"
    let displayName = "Youdao"
    let iconSystemName = "character.book.closed.fill"
    let category: ProviderCategory = .freeTranslation
    let supportsStreaming = false
    let isAvailable = true

    @MainActor
    var isConfigured: Bool { true }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error> {
        singleResultStream { [self] in try await translate(text, from: sourceLang, to: targetLang) }
    }

    @MainActor
    func makeSettingsView() -> AnyView {
        AnyView(YoudaoTranslateSettingsView())
    }

    // MARK: - Private

    private static let client = "fanyideskweb"
    private static let product = "webfanyi"

    private func translate(_ text: String, from sourceLang: String?, to targetLang: String, retryCount: Int = 0) async throws -> String {
        let sl = LanguageCodeMapping.resolve(sourceLang, using: LanguageCodeMapping.youdao) ?? "auto"
        let tl = LanguageCodeMapping.resolveTarget(targetLang, using: LanguageCodeMapping.youdao)

        let keys = try await YoudaoKeyManager.shared.getKeys()
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let sign = youdaoMD5Hex("client=\(Self.client)&mysticTime=\(timestamp)&product=\(Self.product)&key=\(keys.secretKey)")

        guard let url = URL(string: "https://dict.youdao.com/webtranslate") else {
            throw TranslationError.invalidURL
        }

        let formParts = [
            "i=\(URLFormEncoding.encode(text))",
            "from=\(URLFormEncoding.encode(sl))",
            "to=\(URLFormEncoding.encode(tl))",
            "dictResult=false",
            "keyid=webfanyi",
            "sign=\(URLFormEncoding.encode(sign))",
            "client=\(Self.client)",
            "product=\(Self.product)",
            "appVersion=1.0.0",
            "vendor=web",
            "pointParam=client,mysticTime,product",
            "mysticTime=\(timestamp)",
            "keyfrom=fanyi.web",
        ]

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(youdaoUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://fanyi.youdao.com/", forHTTPHeaderField: "Referer")
        request.setValue("OUTFOX_SEARCH_USER_ID=0@0.0.0.0;", forHTTPHeaderField: "Cookie")
        request.httpBody = formParts.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await translationURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        if httpResponse.statusCode == 429 || httpResponse.statusCode == 401 {
            await YoudaoKeyManager.shared.invalidate()
            throw TranslationError.apiError(
                statusCode: httpResponse.statusCode,
                message: String(localized: "Rate limited by Youdao. Please try again later.")
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslationError.apiError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? ""
            )
        }

        guard let encryptedText = String(data: data, encoding: .utf8), !encryptedText.isEmpty else {
            throw TranslationError.invalidResponse
        }

        guard let decryptedJSON = YoudaoCrypto.decrypt(encryptedText, key: keys.aesKey, iv: keys.aesIv) else {
            // Decryption failed — keys may be stale, invalidate and report error
            await YoudaoKeyManager.shared.invalidate()
            throw TranslationError.apiError(
                statusCode: 0,
                message: String(localized: "Youdao decryption failed. Please try again.")
            )
        }

        guard let jsonData = decryptedJSON.data(using: .utf8) else {
            throw TranslationError.invalidResponse
        }

        let decoded: YoudaoTranslateResponse
        do {
            decoded = try JSONDecoder().decode(YoudaoTranslateResponse.self, from: jsonData)
        } catch {
            // Decrypted data is not valid JSON — keys may be stale
            await YoudaoKeyManager.shared.invalidate()
            if retryCount < 1 {
                return try await translate(text, from: sourceLang, to: targetLang, retryCount: retryCount + 1)
            }
            throw TranslationError.apiError(
                statusCode: 0,
                message: String(localized: "Youdao response parsing failed. The service may be temporarily unavailable.")
            )
        }

        guard decoded.code == 0 else {
            throw TranslationError.apiError(
                statusCode: 0,
                message: "Youdao error code: \(decoded.code)"
            )
        }

        let result = decoded.translateResult
            .map { group in group.map(\.tgt).joined() }
            .joined(separator: "\n")

        guard !result.isEmpty else {
            throw TranslationError.emptyResult
        }

        return result
    }

}

// MARK: - Response Models

private struct YoudaoTranslateResponse: Decodable {
    let code: Int
    let translateResult: [[TranslateResultItem]]

    struct TranslateResultItem: Decodable {
        let tgt: String
    }
}

private struct YoudaoKeyResponse: Decodable {
    let code: Int
    let data: KeyData

    struct KeyData: Decodable {
        let secretKey: String
        let aesKey: String
        let aesIv: String
    }
}

// MARK: - Key Manager

/// Thread-safe manager for Youdao web translate session keys.
/// Fetches and caches secretKey, aesKey, aesIv from the Youdao key endpoint.
private actor YoudaoKeyManager {
    static let shared = YoudaoKeyManager()

    private static let defaultSecretKey = "asdjnjfenknafdfsdfsd"

    struct Keys: Sendable {
        let secretKey: String
        let aesKey: String
        let aesIv: String
    }

    private static func makeFallbackKeys() -> Keys {
        Keys(
            secretKey: defaultSecretKey,
            aesKey: "ydsecret://query/key/B*RGygVywfNBwpmBaZg*WT7SIOUP2T0C9WHMZN39j^DAdaZhAnxvGcCY6VYFwnHl",
            aesIv: "ydsecret://query/iv/C@lZe2YzHtZ2CYgaXKSVfsb7Y4QWHjITPPZ0nQp87fBeJ!Iv6v^6fvi2WN@bYpJ4"
        )
    }

    private var cachedKeys: Keys?
    private var fetchedAt: Date?
    private let expiryInterval: TimeInterval = 3600 // 1 hour
    private var refreshTask: Task<Keys, Error>?

    func getKeys() async throws -> Keys {
        if let cachedKeys, let fetchedAt, Date().timeIntervalSince(fetchedAt) < expiryInterval {
            return cachedKeys
        }
        // Coalesce concurrent refresh requests into a single network call
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task { try await refreshKeys() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    func invalidate() {
        cachedKeys = nil
        fetchedAt = nil
    }

    private func refreshKeys() async throws -> Keys {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let signText = "client=fanyideskweb&mysticTime=\(timestamp)&product=webfanyi&key=\(Self.defaultSecretKey)"
        let sign = youdaoMD5Hex(signText)

        guard var components = URLComponents(string: "https://dict.youdao.com/webtranslate/key") else {
            throw TranslationError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "keyid", value: "webfanyi-key-getter"),
            URLQueryItem(name: "sign", value: sign),
            URLQueryItem(name: "client", value: "fanyideskweb"),
            URLQueryItem(name: "product", value: "webfanyi"),
            URLQueryItem(name: "appVersion", value: "1.0.0"),
            URLQueryItem(name: "vendor", value: "web"),
            URLQueryItem(name: "pointParam", value: "client,mysticTime,product"),
            URLQueryItem(name: "mysticTime", value: timestamp),
            URLQueryItem(name: "keyfrom", value: "fanyi.web"),
        ]

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(youdaoUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://fanyi.youdao.com/", forHTTPHeaderField: "Referer")
        request.setValue("OUTFOX_SEARCH_USER_ID=0@0.0.0.0;", forHTTPHeaderField: "Cookie")

        let (data, response) = try await translationURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // Fallback to hardcoded defaults if key fetch fails
            let fallback = Self.makeFallbackKeys()
            self.cachedKeys = fallback
            self.fetchedAt = Date()
            return fallback
        }

        let decoded: YoudaoKeyResponse
        do {
            decoded = try JSONDecoder().decode(YoudaoKeyResponse.self, from: data)
        } catch {
            // Key endpoint returned non-JSON — fall back to hardcoded defaults
            let fallback = Self.makeFallbackKeys()
            self.cachedKeys = fallback
            self.fetchedAt = Date()
            return fallback
        }

        guard decoded.code == 0 else {
            throw TranslationError.apiError(
                statusCode: 0,
                message: "Youdao key fetch error code: \(decoded.code)"
            )
        }

        let keys = Keys(
            secretKey: decoded.data.secretKey,
            aesKey: decoded.data.aesKey,
            aesIv: decoded.data.aesIv
        )
        self.cachedKeys = keys
        self.fetchedAt = Date()
        return keys
    }

}

// MARK: - AES Decryption

/// AES-128-CBC decryption for Youdao's encrypted response using CommonCrypto.
private enum YoudaoCrypto {
    /// Decrypt Youdao's URL-safe base64 encoded, AES-128-CBC encrypted response.
    static func decrypt(_ encryptedText: String, key: String, iv: String) -> String? {
        // MD5 hash the key and iv strings to get 16-byte AES key and IV
        let keyHash = md5Data(key)
        let ivHash = md5Data(iv)

        // Convert URL-safe base64 to standard base64 and add padding
        var standardBase64 = encryptedText
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = standardBase64.count % 4
        if remainder > 0 {
            standardBase64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let encryptedData = Data(base64Encoded: standardBase64) else { return nil }

        // AES-128-CBC decrypt with PKCS7 padding
        let bufferSize = encryptedData.count + kCCBlockSizeAES128
        var decryptedData = Data(count: bufferSize)
        var decryptedLength = 0

        let status = keyHash.withUnsafeBytes { keyBytes in
            ivHash.withUnsafeBytes { ivBytes in
                encryptedData.withUnsafeBytes { dataBytes in
                    decryptedData.withUnsafeMutableBytes { outputBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, encryptedData.count,
                            outputBytes.baseAddress, bufferSize,
                            &decryptedLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }

        decryptedData.count = decryptedLength
        return String(data: decryptedData, encoding: .utf8)
    }

    private static func md5Data(_ string: String) -> Data {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return Data(digest)
    }
}

// MARK: - Settings View

private struct YoudaoTranslateSettingsView: View {
    var body: some View {
        Form {
            Section("Status") {
                Label("Free, no API key needed.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
                Text("Uses Youdao Translate, may be rate-limited.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

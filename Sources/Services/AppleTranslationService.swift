import Foundation
import SwiftUI

#if canImport(Translation)
import Translation

/// Apple Translation framework service — only available on macOS 15.0+.
///
/// NOTE: `TranslationSession` has no public initializer and can only be obtained via
/// SwiftUI's `.translationTask` modifier. We use a hidden NSHostingView bridge to
/// access the session from non-SwiftUI code.
@available(macOS 15.0, *)
struct AppleTranslationService: TranslationService {
    let name = "apple"

    func translate(_ text: String, from sourceLang: String?, to targetLang: String) async throws -> String {
        let source = sourceLang.flatMap { Locale.Language(identifier: $0) }
        let target = Locale.Language(identifier: targetLang)

        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let config = TranslationSession.Configuration(source: source, target: target)
                let bridge = TranslationBridgeView(text: text, configuration: config) { result in
                    continuation.resume(with: result)
                }

                let hostingView = NSHostingView(rootView: bridge)
                // Attach to a hidden window briefly to trigger SwiftUI lifecycle
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: true
                )
                window.contentView = hostingView
                window.orderBack(nil)
                // Window will be deallocated after continuation completes
            }
        }
    }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await translate(text, from: sourceLang, to: targetLang)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Hidden SwiftUI view that uses `.translationTask` to obtain a `TranslationSession`.
@available(macOS 15.0, *)
private struct TranslationBridgeView: View {
    let text: String
    let configuration: TranslationSession.Configuration
    let onComplete: (Result<String, Error>) -> Void

    @State private var completed = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration) { session in
                guard !completed else { return }
                completed = true
                do {
                    let response = try await session.translate(text)
                    onComplete(.success(response.targetText))
                } catch {
                    onComplete(.failure(error))
                }
            }
    }
}
#endif

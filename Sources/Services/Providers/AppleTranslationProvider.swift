import Foundation
import SwiftUI

#if canImport(Translation)
import Translation

/// Apple Translation framework provider — macOS 15.0+ only.
@available(macOS 15.0, *)
struct AppleTranslationProvider: TranslationProvider {
    let id = "apple"
    let displayName = "Apple Translation"
    let iconSystemName = "apple.logo"
    let supportsStreaming = false
    let isAvailable = true

    /// Languages supported by Apple Translation framework.
    static var supportedLanguageCodes: Set<String> { SupportedLanguages.codes }

    @MainActor
    var isConfigured: Bool { true }

    func translateStream(
        _ text: String,
        from sourceLang: String?,
        to targetLang: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await translate(text, from: sourceLang, to: targetLang)
                    continuation.yield(result)
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
        AnyView(AppleTranslationSettingsView())
    }

    // MARK: - Private

    private func translate(_ text: String, from sourceLang: String?, to targetLang: String) async throws -> String {
        let validSource = sourceLang.flatMap { Self.supportedLanguageCodes.contains($0) ? $0 : nil }
        let source = validSource.flatMap { Locale.Language(identifier: $0) }
        let target = Locale.Language(identifier: targetLang)

        let availability = LanguageAvailability()
        if let source {
            let status = await availability.status(from: source, to: target)
            switch status {
            case .installed:
                break
            case .supported:
                throw TranslationError.languageNotInstalled(source: sourceLang, target: targetLang)
            case .unsupported:
                throw TranslationError.languageUnsupported(source: sourceLang, target: targetLang)
            @unknown default:
                break
            }
        } else {
            let status = try await availability.status(for: text, to: target)
            switch status {
            case .installed:
                break
            case .supported:
                throw TranslationError.languageNotInstalled(source: nil, target: targetLang)
            case .unsupported:
                throw TranslationError.languageUnsupported(source: nil, target: targetLang)
            @unknown default:
                break
            }
        }

        let windowRef = UncheckedSendable<NSWindow?>(nil)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    let config = TranslationSession.Configuration(source: source, target: target)

                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                        styleMask: .borderless,
                        backing: .buffered,
                        defer: true
                    )
                    window.isReleasedWhenClosed = false
                    windowRef.value = window

                    if Task.isCancelled {
                        window.close()
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    let bridge = TranslationBridgeView(text: text, configuration: config) { result in
                        continuation.resume(with: result)
                        Task { @MainActor in
                            window.close()
                        }
                    }

                    let hostingView = NSHostingView(rootView: bridge)
                    window.contentView = hostingView
                    window.orderBack(nil)
                }
            }
        } onCancel: {
            Task { @MainActor in
                windowRef.value?.close()
            }
        }
    }
}

// MARK: - Sendable Box

/// A mutable box for passing references across concurrency boundaries when the
/// value is logically protected by the caller (e.g. only mutated on @MainActor).
private final class UncheckedSendable<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Translation Bridge

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
            .onDisappear {
                guard !completed else { return }
                completed = true
                onComplete(.failure(TranslationError.translationSessionFailed))
            }
    }
}

// MARK: - Settings View

@available(macOS 15.0, *)
struct AppleTranslationSettingsView: View {
    var body: some View {
        Form {
            Section("Status") {
                Label("Available on this system (macOS 15+). No API key needed.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            Section("Language Packs") {
                LanguageDownloadView()
            }
        }
        .formStyle(.grouped)
    }
}

@available(macOS 15.0, *)
struct LanguageDownloadView: View {
    private enum PairStatus {
        case checking, installed, needsDownload, unsupported, unknown

        var label: String {
            switch self {
            case .checking: "Checking…"
            case .installed: "Installed"
            case .needsDownload: "Needs download"
            case .unsupported: "Unsupported"
            case .unknown: "Unknown"
            }
        }

        var color: Color {
            self == .installed ? .green : .secondary
        }
    }

    static var languages: [(code: String, name: String)] { SupportedLanguages.all }

    @State private var selectedSource = "en"
    @State private var selectedTarget = "zh-Hans"
    @State private var pairStatus: PairStatus?
    @State private var downloadConfiguration: TranslationSession.Configuration?

    private var selectionId: String { "\(selectedSource)-\(selectedTarget)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("From:", selection: $selectedSource) {
                    ForEach(Self.languages, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }
                .frame(maxWidth: 200)

                Picker("To:", selection: $selectedTarget) {
                    ForEach(Self.languages, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }
                .frame(maxWidth: 200)
            }

            HStack {
                Button("Check & Download") {
                    downloadConfiguration = .init(
                        source: Locale.Language(identifier: selectedSource),
                        target: Locale.Language(identifier: selectedTarget)
                    )
                }

                if let pairStatus {
                    Text(pairStatus.label)
                        .font(.callout)
                        .foregroundStyle(pairStatus.color)
                }
            }
        }
        .task(id: selectionId) {
            pairStatus = .checking
            let availability = LanguageAvailability()
            let source = Locale.Language(identifier: selectedSource)
            let target = Locale.Language(identifier: selectedTarget)
            let status = await availability.status(from: source, to: target)
            pairStatus = switch status {
            case .installed: .installed
            case .supported: .needsDownload
            case .unsupported: .unsupported
            @unknown default: .unknown
            }
        }
        .translationTask(downloadConfiguration) { session in
            do {
                try await session.prepareTranslation()
                pairStatus = .installed
            } catch {
                let availability = LanguageAvailability()
                let source = Locale.Language(identifier: selectedSource)
                let target = Locale.Language(identifier: selectedTarget)
                let status = await availability.status(from: source, to: target)
                pairStatus = status == .installed ? .installed : .needsDownload
            }
        }
    }
}
#endif

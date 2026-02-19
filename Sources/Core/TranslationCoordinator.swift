import AppKit
import Defaults

/// Central coordinator that orchestrates: text grabbing → language detection → multi-provider translation.
@MainActor
@Observable
final class TranslationCoordinator {
    /// Overall translation phase.
    enum Phase: Sendable {
        case idle
        case grabbing
        case active
    }

    /// Per-provider translation state.
    enum ProviderState: Sendable, Equatable {
        case waiting
        case translating
        case streaming(partial: String)
        case completed(text: String)
        case error(message: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var sourceText: String = ""
    private(set) var detectedLanguage: String?
    private(set) var targetLanguage: String = ""
    private(set) var providerStates: [String: ProviderState] = [:]
    private(set) var globalError: String?

    let registry: TranslationProviderRegistry
    private let permissionManager: PermissionManager
    private var activeTasks: [String: Task<Void, Never>] = [:]

    init(permissionManager: PermissionManager, registry: TranslationProviderRegistry) {
        self.permissionManager = permissionManager
        self.registry = registry
    }

    // MARK: - Public Actions

    /// Triggered by keyboard shortcut: grab selected text → translate.
    func translateSelection() async {
        guard permissionManager.isAccessibilityGranted else {
            phase = .active
            sourceText = ""
            globalError = "Accessibility permission not granted. Open Settings to enable it."
            return
        }

        phase = .grabbing

        guard let text = await TextSelectionManager.grabSelectedText() else {
            phase = .active
            sourceText = ""
            globalError = "No text selected. Select some text and try again."
            return
        }

        translate(text)
    }

    /// Triggered by OCR shortcut: screen capture → OCR → translate.
    func ocrAndTranslate() async {
        phase = .grabbing

        do {
            let text = try await ScreenCaptureOCR.captureAndRecognize()
            translate(text)
        } catch is OCRError {
            phase = .idle
        } catch {
            phase = .active
            sourceText = ""
            globalError = "OCR failed: \(error.localizedDescription)"
        }
    }

    /// Translate text with all enabled providers in parallel.
    /// Launches provider tasks in the background and returns immediately.
    func translate(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .active
            sourceText = ""
            globalError = "Empty text"
            return
        }

        cancelAll()
        globalError = nil

        sourceText = trimmed
        detectedLanguage = LanguageDetector.detect(trimmed)
        targetLanguage = resolveTargetLanguage(detected: detectedLanguage)
        phase = .active

        let providers = registry.enabledProviders
        guard !providers.isEmpty else {
            globalError = "No providers enabled. Enable at least one in Settings."
            return
        }

        // Initialize all provider states
        providerStates = [:]
        for provider in providers {
            providerStates[provider.id] = .waiting
        }

        // Launch parallel tasks
        for provider in providers {
            let task = Task {
                await runProvider(provider, text: trimmed, from: detectedLanguage, to: targetLanguage)
            }
            activeTasks[provider.id] = task
        }
    }

    /// Retry a single provider that previously errored.
    func retryProvider(_ provider: any TranslationProvider) {
        guard phase == .active, !sourceText.isEmpty else { return }
        activeTasks[provider.id]?.cancel()
        providerStates[provider.id] = .waiting
        let text = sourceText
        let target = targetLanguage
        let source = detectedLanguage
        let task = Task {
            await runProvider(provider, text: text, from: source, to: target)
        }
        activeTasks[provider.id] = task
    }

    func dismiss() {
        cancelAll()
        phase = .idle
        sourceText = ""
        detectedLanguage = nil
        targetLanguage = ""
        providerStates = [:]
        globalError = nil
    }

    // MARK: - Computed Helpers

    /// Whether any provider has completed with a result.
    var hasAnyResult: Bool {
        providerStates.values.contains { state in
            if case .completed = state { return true }
            return false
        }
    }

    /// Whether all providers have finished (completed or error).
    var allFinished: Bool {
        guard !providerStates.isEmpty else { return true }
        return providerStates.values.allSatisfy { state in
            switch state {
            case .completed, .error: return true
            default: return false
            }
        }
    }

    // MARK: - Private

    private func runProvider(
        _ provider: any TranslationProvider,
        text: String,
        from sourceLang: String?,
        to targetLang: String
    ) async {
        defer {
            if !Task.isCancelled {
                activeTasks.removeValue(forKey: provider.id)
            }
        }
        providerStates[provider.id] = .translating

        do {
            var accumulated = ""
            for try await chunk in provider.translateStream(text, from: sourceLang, to: targetLang) {
                guard !Task.isCancelled else { return }
                accumulated += chunk
                providerStates[provider.id] = .streaming(partial: accumulated)
            }

            guard !Task.isCancelled else { return }

            if accumulated.isEmpty {
                providerStates[provider.id] = .error(message: "Empty result")
            } else {
                providerStates[provider.id] = .completed(text: accumulated)
            }
        } catch {
            guard !Task.isCancelled else { return }
            providerStates[provider.id] = .error(message: error.localizedDescription)
        }
    }

    private func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    private func resolveTargetLanguage(detected: String?) -> String {
        let preferred = Defaults[.targetLanguage]

        guard let detected else { return preferred }

        if detected.hasPrefix("zh") && preferred.hasPrefix("zh") {
            return "en"
        }
        if detected == preferred {
            return detected.hasPrefix("zh") ? "en" : "zh-Hans"
        }

        return preferred
    }
}

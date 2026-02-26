import Defaults
import SwiftUI

/// Settings view for an OpenAI-compatible provider.
/// Delegates to `OpenAIConfigFields` which renders the full Anthropic-style Form layout.
struct OpenAICompatibleSettingsView: View {
    let provider: OpenAICompatibleProvider

    var body: some View {
        OpenAIConfigFields(provider: provider)
    }
}

// MARK: - Defaults Binding Helper

extension Defaults {
    static func binding(_ key: Defaults.Key<String>) -> Binding<String> {
        Binding(
            get: { Defaults[key] },
            set: { Defaults[key] = $0 }
        )
    }
}

import Defaults
import SwiftUI

/// Language selection bar with source (auto-detect) + swap + target picker.
struct LanguageBarView: View {
    let detectedLanguage: String?
    @Binding var targetLanguage: String
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Source language display
            HStack(spacing: 4) {
                Image(systemName: "text.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sourceDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Target language picker
            Picker("", selection: $targetLanguage) {
                ForEach(SupportedLanguages.all, id: \.code) { code, name in
                    Text(name).tag(code)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var sourceDisplayName: String {
        if let lang = detectedLanguage {
            return Locale.current.localizedString(forIdentifier: lang) ?? lang
        }
        return "Auto Detect"
    }
}

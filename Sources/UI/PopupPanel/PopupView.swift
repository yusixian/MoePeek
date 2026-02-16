import SwiftUI

/// The SwiftUI content displayed inside the popup translation panel.
struct PopupView: View {
    let coordinator: TranslationCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch coordinator.state {
            case .idle:
                EmptyView()

            case .grabbing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Grabbing text...")
                        .foregroundStyle(.secondary)
                }

            case let .translating(sourceText):
                sourceTextView(sourceText)
                Divider()
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating...")
                        .foregroundStyle(.secondary)
                }

            case let .streaming(sourceText, partial):
                sourceTextView(sourceText)
                Divider()
                Text(partial)
                    .textSelection(.enabled)

            case let .completed(result):
                sourceTextView(result.sourceText)
                Divider()
                Text(result.translatedText)
                    .textSelection(.enabled)
                HStack {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.translatedText, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Text(result.service)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

            case let .error(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Button("Retry") {
                    // Retry would need to re-trigger the last action;
                    // for now, user can re-select and re-invoke.
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(minWidth: 280, maxWidth: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func sourceTextView(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .textSelection(.enabled)
    }
}

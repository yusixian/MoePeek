import Defaults
import SwiftUI

/// The SwiftUI content displayed inside the popup translation panel.
struct PopupView: View {
    let coordinator: TranslationCoordinator

    @State private var editableText: String = ""
    @State private var expandedProviders: Set<String> = []
    @State private var targetLang: String = Defaults[.targetLanguage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch coordinator.phase {
            case .idle:
                EmptyView()

            case .grabbing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Grabbing text...")
                        .foregroundStyle(.secondary)
                }
                .padding(14)

            case .active:
                activeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            ResizeGripView()
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: coordinator.sourceText) { _, newValue in
            editableText = newValue
        }
        .onChange(of: coordinator.targetLanguage) { _, newValue in
            targetLang = newValue
        }
        .onAppear {
            editableText = coordinator.sourceText
            targetLang = coordinator.targetLanguage
            expandedProviders = Set(coordinator.registry.enabledProviders.map(\.id))
        }
    }

    // MARK: - Active Content

    @ViewBuilder
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Global error (no providers, permissions, etc.)
            if let message = coordinator.globalError {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                .padding(14)
            } else {
                // Source input
                SourceInputView(
                    text: $editableText,
                    onSubmit: {
                        coordinator.translate(editableText)
                    }
                )
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)

                Divider()
                    .padding(.horizontal, 10)

                // Language bar + settings button
                HStack(spacing: 4) {
                    LanguageBarView(
                        detectedLanguage: coordinator.detectedLanguage,
                        targetLanguage: $targetLang,
                        onSwap: {
                            if let detected = coordinator.detectedLanguage {
                                targetLang = detected
                            }
                        }
                    )

                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("打开设置")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .onChange(of: targetLang) { _, newValue in
                    Defaults[.targetLanguage] = newValue
                    // Skip retranslation when this change came from coordinator sync
                    guard newValue != coordinator.targetLanguage else { return }
                    if !editableText.isEmpty {
                        coordinator.translate(editableText)
                    }
                }

                Divider()
                    .padding(.horizontal, 10)

                // Provider results
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(coordinator.registry.enabledProviders, id: \.id) { provider in
                            if let state = coordinator.providerStates[provider.id] {
                                ProviderResultCard(
                                    provider: provider,
                                    state: state,
                                    isExpanded: expandedBinding(for: provider.id),
                                    onRetry: {
                                        coordinator.retryProvider(provider)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Helpers

    private func expandedBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedProviders.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedProviders.insert(id)
                } else {
                    expandedProviders.remove(id)
                }
            }
        )
    }
}

// MARK: - Resize Grip

/// A draggable grip in the bottom-right corner for resizing the popup panel.
/// Uses SwiftUI DragGesture with NSEvent.mouseLocation (screen coordinates) to avoid
/// EXC_BAD_ACCESS caused by overriding mouse events on NSPanel with NSHostingView.
private struct ResizeGripView: View {
    @Environment(\.popupPanel) private var panel
    @State private var dragStartMouse: NSPoint?
    @State private var dragStartFrame: NSRect?

    var body: some View {
        Canvas { context, size in
            let lineCount = 3
            let spacing: CGFloat = 3
            let lineWidth: CGFloat = 1
            let totalSize = CGFloat(lineCount - 1) * spacing

            for i in 0..<lineCount {
                let offset = CGFloat(i) * spacing
                let start = CGPoint(x: size.width - totalSize + offset, y: size.height)
                let end = CGPoint(x: size.width, y: size.height - totalSize + offset)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(.secondary.opacity(0.4)), lineWidth: lineWidth)
            }
        }
        .frame(width: 12, height: 12)
        .padding(4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    let mouse = NSEvent.mouseLocation
                    if dragStartMouse == nil {
                        dragStartMouse = mouse
                        dragStartFrame = panel?.frame
                    }
                    guard let start = dragStartMouse,
                          let initial = dragStartFrame,
                          let panel else { return }

                    let deltaX = mouse.x - start.x
                    let deltaY = mouse.y - start.y

                    let newW = min(max(initial.width + deltaX, panel.minSize.width), panel.maxSize.width)
                    let newH = min(max(initial.height - deltaY, panel.minSize.height), panel.maxSize.height)

                    // Keep top-left corner fixed
                    let newY = initial.maxY - newH
                    panel.setFrame(
                        NSRect(x: initial.origin.x, y: newY, width: newW, height: newH),
                        display: true
                    )
                }
                .onEnded { _ in
                    if let panel {
                        Defaults[.popupDefaultWidth] = Int(panel.frame.width)
                        Defaults[.popupDefaultHeight] = Int(panel.frame.height)
                    }
                    dragStartMouse = nil
                    dragStartFrame = nil
                }
        )
        .onHover { hovering in
            if hovering {
                if #available(macOS 15.0, *) {
                    NSCursor.frameResize(position: .bottomRight, directions: .all).set()
                } else {
                    NSCursor.crosshair.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

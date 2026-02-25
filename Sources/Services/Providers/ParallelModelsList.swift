import SwiftUI

/// Reusable parallel model selection list with search, toggle, and custom model input.
/// Shared between OpenAIConfigFields and AnthropicSettingsView.
struct ParallelModelsList: View {
    /// All fetched model IDs (already sorted/filtered by caller).
    let fetchedModels: [String]
    /// Binding to the set of user-enabled model IDs.
    @Binding var enabledModels: Set<String>
    let metaService: ModelMetadataService

    @State private var modelSearchQuery = ""
    @State private var customModelInput = ""

    /// All model IDs to display: fetched models + enabled but not in fetch list.
    private var displayModels: [String] {
        let fetched = Set(fetchedModels)
        let unknown = enabledModels.subtracting(fetched).sorted()
        return fetchedModels + unknown
    }

    private var searchFilteredModels: [String] {
        let query = modelSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return displayModels }
        return displayModels.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Select models to run in parallel during translation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !enabledModels.isEmpty {
                    Button("Clear All") {
                        enabledModels = []
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }

            if displayModels.isEmpty {
                Text("Click the refresh button above to fetch available models, or add a custom model below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                TextField("Search models…", text: $modelSearchQuery)
                    .textFieldStyle(.roundedBorder)

                if searchFilteredModels.isEmpty && !modelSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("No models match your search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(searchFilteredModels, id: \.self) { modelID in
                                ModelCheckboxRow(
                                    modelID: modelID,
                                    isEnabled: enabledModels.contains(modelID),
                                    isUnknown: !fetchedModels.contains(modelID),
                                    isDisabled: !enabledModels.contains(modelID) && enabledModels.count >= maxParallelModels,
                                    metaMatch: metaService.meta(for: modelID),
                                    onToggle: { toggleModel(modelID) }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }

            // Add custom model
            HStack(spacing: 4) {
                TextField("Add custom model…", text: $customModelInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCustomModel() }

                Button {
                    addCustomModel()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(customModelInput.trimmingCharacters(in: .whitespaces).isEmpty || enabledModels.count >= maxParallelModels)
            }

            let count = enabledModels.count
            if count > 0 {
                Text("\(count) model(s) enabled — will run in parallel during translation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if metaService.hasFetched, let modelsDevURL = URL(string: "https://models.dev") {
                HStack(spacing: 4) {
                    Text("Capability data from")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Link("Models.dev", destination: modelsDevURL)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func toggleModel(_ modelID: String) {
        if enabledModels.contains(modelID) {
            enabledModels.remove(modelID)
        } else {
            guard enabledModels.count < maxParallelModels else { return }
            enabledModels.insert(modelID)
        }
    }

    private func addCustomModel() {
        let trimmed = customModelInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, enabledModels.count < maxParallelModels else { return }
        enabledModels.insert(trimmed)
        customModelInput = ""
    }
}

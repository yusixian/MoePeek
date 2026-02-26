import SwiftUI

/// Reusable parallel model selection list with search, toggle, and custom model input.
/// Shared between OpenAIConfigFields and AnthropicSettingsView.
///
/// Layout: Selected section (default model locked + user-picked models) above
/// the full All Models list where checked items remain visible for comparison.
struct ParallelModelsList: View {
    /// All fetched model IDs (already sorted/filtered by caller).
    let fetchedModels: [String]
    /// Binding to the set of user-enabled model IDs (excludes default model).
    @Binding var enabledModels: Set<String>
    let metaService: ModelMetadataService
    /// Current default model ID — always shown as checked & locked.
    let defaultModel: String

    @State private var modelSearchQuery = ""
    @State private var customModelInput = ""

    /// Whether the default model appears in the available list.
    private var defaultModelInList: Bool {
        let trimmed = defaultModel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return fetchedModels.contains(trimmed) || enabledModels.contains(trimmed)
    }

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

    /// Models explicitly selected by the user (excluding the default model).
    private var selectedModels: [String] {
        enabledModels.subtracting([defaultModel]).sorted()
    }

    /// Whether the "Selected" section should be visible.
    private var hasSelectedSection: Bool {
        defaultModelInList || !selectedModels.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
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

            // MARK: - Selected Section
            if hasSelectedSection {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    if defaultModelInList {
                        ModelCheckboxRow(
                            modelID: defaultModel,
                            isEnabled: true,
                            isUnknown: false,
                            isDisabled: false,
                            isDefault: true,
                            metaMatch: metaService.meta(for: defaultModel),
                            onToggle: {}
                        )
                    }

                    ForEach(selectedModels, id: \.self) { modelID in
                        ModelCheckboxRow(
                            modelID: modelID,
                            isEnabled: true,
                            isUnknown: !fetchedModels.contains(modelID),
                            isDisabled: false,
                            metaMatch: metaService.meta(for: modelID),
                            onToggle: { toggleModel(modelID) }
                        )
                    }
                }

                Divider()
            }

            // MARK: - All Models Section
            if displayModels.isEmpty {
                Text("Click the refresh button above to fetch available models, or add a custom model below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                if hasSelectedSection {
                    Text("All Models")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

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
                                let isDefaultRow = modelID == defaultModel && defaultModelInList
                                ModelCheckboxRow(
                                    modelID: modelID,
                                    isEnabled: enabledModels.contains(modelID) || isDefaultRow,
                                    isUnknown: !fetchedModels.contains(modelID) && !isDefaultRow,
                                    isDisabled: !enabledModels.contains(modelID) && !isDefaultRow && enabledModels.count >= maxParallelModels,
                                    isDefault: isDefaultRow,
                                    metaMatch: metaService.meta(for: modelID),
                                    onToggle: { if !isDefaultRow { toggleModel(modelID) } }
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

            let totalCount = enabledModels.subtracting([defaultModel]).count + (defaultModelInList ? 1 : 0)
            if totalCount > 0 {
                Text("\(totalCount) model(s) enabled — will run in parallel during translation.")
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
        .onAppear {
            // Clean up: remove default model from enabledModels if present (it's implicit now)
            if enabledModels.contains(defaultModel) {
                enabledModels.remove(defaultModel)
            }
        }
        .onChange(of: defaultModel) { _, newDefault in
            if enabledModels.contains(newDefault) {
                enabledModels.remove(newDefault)
            }
        }
    }

    private func toggleModel(_ modelID: String) {
        guard modelID != defaultModel else { return }
        if enabledModels.contains(modelID) {
            enabledModels.remove(modelID)
        } else {
            guard enabledModels.count < maxParallelModels else { return }
            enabledModels.insert(modelID)
        }
    }

    private func addCustomModel() {
        let trimmed = customModelInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != defaultModel, enabledModels.count < maxParallelModels else { return }
        enabledModels.insert(trimmed)
        customModelInput = ""
    }
}

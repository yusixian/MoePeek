import Foundation

/// Fetches and caches model capability metadata from models.dev.
/// Data is fetched once per app session and silently ignored on network failure.
@MainActor @Observable
final class ModelMetadataService {
    static let shared = ModelMetadataService()

    /// Keyed by full model id as it appears in models.dev (e.g. "kimi-k2.5", "moonshotai/Kimi-K2.5").
    /// Stores all candidates from different providers sharing the same model id.
    private var modelIndex: [String: [ModelMeta]] = [:]
    /// Keyed by lowercased short name (last path component after "/").
    /// Stores all candidates sharing the same short name to detect ambiguous matches.
    private var shortIndex: [String: [ModelMeta]] = [:]
    private var isFetching = false
    private(set) var hasFetched = false

    struct ModelMeta: Sendable {
        let toolCall: Bool
        let reasoning: Bool
        let contextWindow: Int?     // limit.context (tokens)
    }

    enum MatchKind: Sendable { case exact, approximate }

    struct MetaMatch: Sendable {
        let meta: ModelMeta
        let matchKind: MatchKind
    }

    private init() {}

    /// Fetches models.dev data if not already fetched. Safe to call multiple times.
    func fetchIfNeeded() async {
        guard !hasFetched, !isFetching else { return }
        isFetching = true
        defer {
            isFetching = false
            hasFetched = true  // Once per session, even on failure
        }

        guard let url = URL(string: "https://models.dev/api.json") else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }

        // Parse and build indexes off the main thread to avoid blocking UI.
        let result = await Task.detached(priority: .utility) { () -> (index: [String: [ModelMeta]], short: [String: [ModelMeta]])? in
            // api.json top-level is { "provider-id": { "models": { "model-id": {...}, ... } } }
            guard let providers = try? JSONDecoder().decode([String: RawProvider].self, from: data) else { return nil }
            var index: [String: [ModelMeta]] = [:]
            var short: [String: [ModelMeta]] = [:]
            for provider in providers.values {
                for (modelID, model) in provider.models ?? [:] {
                    let meta = ModelMeta(
                        toolCall: model.toolCall ?? false,
                        reasoning: model.reasoning ?? false,
                        contextWindow: model.limit?.context
                    )
                    index[modelID, default: []].append(meta)
                    let bare = (modelID.components(separatedBy: "/").last ?? modelID).lowercased()
                    short[bare, default: []].append(meta)
                }
            }
            return (index, short)
        }.value

        guard let result else { return }
        modelIndex = result.index
        shortIndex = result.short
    }

    /// Returns metadata for the given model ID with match confidence.
    /// Tries exact match first, then falls back to short-name (case-insensitive) lookup.
    /// When multiple candidates have conflicting capabilities, returns a conservative merge
    /// marked as `.approximate`.
    func meta(for modelID: String) -> MetaMatch? {
        // 1. Exact model ID match (across all providers)
        if let candidates = modelIndex[modelID] {
            return merge(candidates)
        }

        // 2. Short-name fallback
        let bare = (modelID.components(separatedBy: "/").last ?? modelID).lowercased()
        guard let candidates = shortIndex[bare] else { return nil }
        return merge(candidates)
    }

    /// Merges multiple candidate metadata entries into a single `MetaMatch`.
    /// - Single candidate or all-consistent capabilities → `.exact`
    /// - Conflicting capabilities → conservative merge marked `.approximate`
    private func merge(_ candidates: [ModelMeta]) -> MetaMatch? {
        guard !candidates.isEmpty else { return nil }

        if candidates.count == 1 {
            return MetaMatch(meta: candidates[0], matchKind: .exact)
        }

        let allSame = candidates.allSatisfy {
            $0.toolCall == candidates[0].toolCall &&
            $0.reasoning == candidates[0].reasoning
        }

        if allSame {
            let merged = ModelMeta(
                toolCall: candidates[0].toolCall,
                reasoning: candidates[0].reasoning,
                contextWindow: candidates.compactMap(\.contextWindow).max()
            )
            return MetaMatch(meta: merged, matchKind: .exact)
        }

        // Capabilities conflict — conservative: only mark supported if ALL agree
        let merged = ModelMeta(
            toolCall: candidates.allSatisfy(\.toolCall),
            reasoning: candidates.allSatisfy(\.reasoning),
            contextWindow: candidates.compactMap(\.contextWindow).max()
        )
        return MetaMatch(meta: merged, matchKind: .approximate)
    }
}

// MARK: - Private JSON types

private extension ModelMetadataService {
    struct RawProvider: Decodable {
        // models is keyed by model id
        let models: [String: RawModel]?
    }

    struct RawModel: Decodable {
        let toolCall: Bool?
        let reasoning: Bool?
        let limit: Limit?

        enum CodingKeys: String, CodingKey {
            case toolCall = "tool_call"
            case reasoning, limit
        }

        struct Limit: Decodable { let context: Int? }
    }
}

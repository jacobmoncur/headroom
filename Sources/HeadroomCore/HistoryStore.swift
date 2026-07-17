import Foundation

public actor HistoryStore {
    private let directory: URL
    private let snapshotsURL: URL
    private let actionsURL: URL
    private let feedbackURL: URL
    private let rootIndexURL: URL

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Headroom", directoryHint: .isDirectory)
        self.directory = base
        self.snapshotsURL = base.appending(path: "snapshots.json")
        self.actionsURL = base.appending(path: "actions.json")
        self.feedbackURL = base.appending(path: "recommendation-feedback.json")
        self.rootIndexURL = base.appending(path: "root-index.json")
    }

    public func loadSnapshots() -> [StorageSnapshot] { load([StorageSnapshot].self, from: snapshotsURL) ?? [] }
    public func loadActions() -> [ActionRecord] { load([ActionRecord].self, from: actionsURL) ?? [] }
    public func loadFeedback() -> [RecommendationFeedback] { load([RecommendationFeedback].self, from: feedbackURL) ?? [] }
    public func loadRootIndex() -> [String: StorageSnapshot] { load([String: StorageSnapshot].self, from: rootIndexURL) ?? [:] }

    public func save(snapshot: StorageSnapshot) throws {
        var values = loadSnapshots(); values.append(snapshot)
        if values.count > 90 { values.removeFirst(values.count - 90) }
        try save(values, to: snapshotsURL)
    }

    public func save(action: ActionRecord) throws {
        var values = loadActions(); values.insert(action, at: 0)
        try save(Array(values.prefix(200)), to: actionsURL)
    }

    public func save(actions: [ActionRecord]) throws {
        try save(Array(actions.prefix(200)), to: actionsURL)
    }

    public func save(feedback: RecommendationFeedback) throws {
        var values = loadFeedback(); values.insert(feedback, at: 0)
        try save(Array(values.prefix(500)), to: feedbackURL)
    }

    public func save(rootIndex: [String: StorageSnapshot]) throws {
        try save(rootIndex, to: rootIndexURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }
}

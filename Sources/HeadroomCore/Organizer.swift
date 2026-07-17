import CryptoKit
import Foundation

public enum FileOrganizer {
    public static func suggestions(for snapshot: StorageSnapshot) -> [OrganizationSuggestion] {
        let items = snapshot.largeItems
        var results: [OrganizationSuggestion] = []
        var claimed = Set<String>()

        let screenshots = items.filter {
            let name = $0.url.lastPathComponent.lowercased()
            return name.contains("screenshot") || name.contains("screen shot") || name.hasPrefix("clean shot")
        }
        if qualifies(screenshots) {
            results.append(make(
                source: .onDevice,
                title: "Bring scattered screenshots together",
                detail: "These screenshots are spread across \(folderCount(screenshots)) folders. A single reference folder would make them easier to review and keep out of active work areas.",
                reason: "Their filenames identify them as screenshots, and they currently live in different locations.",
                suggestedFolder: "Pictures/Screenshots",
                confidence: .high,
                items: screenshots
            ))
            claimed.formUnion(screenshots.map(\.id))
        }

        let candidates = items.filter { !claimed.contains($0.id) }
        let tokenGroups = Dictionary(grouping: candidates.flatMap { item in
            meaningfulTokens(for: item).map { ($0, item) }
        }, by: \.0)
        let ranked = tokenGroups.compactMap { token, pairs -> (String, [ScannedItem])? in
            let group = Array(Dictionary(uniqueKeysWithValues: pairs.map { ($0.1.id, $0.1) }).values)
            guard qualifies(group) else { return nil }
            return (token, group)
        }.sorted {
            if $0.1.count != $1.1.count { return $0.1.count > $1.1.count }
            return $0.0 < $1.0
        }

        for (token, group) in ranked {
            let unclaimed = group.filter { !claimed.contains($0.id) }
            guard qualifies(unclaimed) else { continue }
            let label = token.prefix(1).uppercased() + token.dropFirst()
            results.append(make(
                source: .onDevice,
                title: "Create one home for \(label)",
                detail: "These files share the ‘\(token)’ project or topic signal but live across \(folderCount(unclaimed)) folders.",
                reason: "Related names are a useful organization clue even when file types differ. Headroom will not move anything until you review the group.",
                suggestedFolder: "Documents/Projects/\(label)",
                confidence: .medium,
                items: unclaimed
            ))
            claimed.formUnion(unclaimed.map(\.id))
            if results.count >= 8 { break }
        }
        return results
    }

    private static func qualifies(_ items: [ScannedItem]) -> Bool {
        items.count >= 2 && folderCount(items) >= 2
    }

    private static func folderCount(_ items: [ScannedItem]) -> Int {
        Set(items.map { $0.url.deletingLastPathComponent().path }).count
    }

    private static func meaningfulTokens(for item: ScannedItem) -> Set<String> {
        let stopWords: Set<String> = [
            "copy", "final", "draft", "image", "photo", "video", "document", "file", "download",
            "desktop", "documents", "pictures", "movies", "screen", "screenshot", "recording",
            "with", "from", "that", "this", "the", "and", "for", "untitled"
        ]
        let source = item.url.deletingPathExtension().lastPathComponent + " " + item.url.deletingLastPathComponent().lastPathComponent
        return Set(source.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter {
            $0.count >= 4 && !stopWords.contains($0) && !$0.allSatisfy(\.isNumber)
        })
    }

    private static func make(source: OrganizationSuggestionSource, title: String, detail: String,
                             reason: String, suggestedFolder: String, confidence: Confidence,
                             items: [ScannedItem]) -> OrganizationSuggestion {
        let identity = title + items.map(\.id).sorted().joined(separator: "|")
        let id = SHA256.hash(data: Data(identity.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return OrganizationSuggestion(id: "organize-\(id)", source: source, title: title, detail: detail,
                                      reason: reason, suggestedFolder: suggestedFolder,
                                      confidence: confidence, items: items.sorted { $0.modifiedAt > $1.modifiedAt })
    }
}

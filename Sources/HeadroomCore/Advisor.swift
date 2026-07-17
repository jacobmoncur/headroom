import Foundation
import CryptoKit

public enum StorageAdvisor {
    public static func health(current: StorageSnapshot?, previous: StorageSnapshot?, reserve: Int64) -> StorageHealth {
        guard let current else { return .init(freeSpace: 0, reserve: reserve, dailyGrowth: 0) }
        var rate = 0.0
        if let previous {
            let interval = current.capturedAt.timeIntervalSince(previous.capturedAt)
            if interval >= 6 * 60 * 60 {
                rate = max(0, Double(previous.freeSpace - current.freeSpace) / (interval / 86_400))
            }
        }
        return .init(freeSpace: current.freeSpace, reserve: reserve, dailyGrowth: rate)
    }

    public static func deltas(current: StorageSnapshot?, previous: StorageSnapshot?) -> [StorageDelta] {
        guard let current, let previous else { return [] }
        let old = Dictionary(uniqueKeysWithValues: previous.groups.map { ($0.name, $0.bytes) })
        return current.groups.map { StorageDelta(name: $0.name, bytes: $0.bytes - old[$0.name, default: 0]) }
            .filter { abs($0.bytes) > 1_000_000 }
            .sorted { abs($0.bytes) > abs($1.bytes) }
    }

    public static func anomalies(in deltas: [StorageDelta]) -> [StorageDelta] {
        let growth = deltas.filter { $0.bytes > 0 }
        guard !growth.isEmpty else { return [] }
        let average = Double(growth.reduce(0) { $0 + $1.bytes }) / Double(growth.count)
        return growth.filter { $0.bytes >= 5_000_000_000 && Double($0.bytes) >= average * 1.5 }
    }

    public static func recoveryPlan(targetBytes: Int64, from recommendations: [Recommendation]) -> RecoveryPlan {
        let ordered = recommendations.sorted {
            let lhsRisk = riskRank($0.risk), rhsRisk = riskRank($1.risk)
            if lhsRisk != rhsRisk { return lhsRisk < rhsRisk }
            if $0.confidence != $1.confidence { return confidenceRank($0.confidence) > confidenceRank($1.confidence) }
            return $0.score > $1.score
        }
        var selected: [Recommendation] = [], recovered: Int64 = 0
        for recommendation in ordered where recovered < targetBytes {
            selected.append(recommendation); recovered += recommendation.recoveryBytes
        }
        return RecoveryPlan(targetBytes: targetBytes, recommendations: selected)
    }

    private static func riskRank(_ risk: RiskLevel) -> Int { risk == .low ? 0 : (risk == .medium ? 1 : 2) }
    private static func confidenceRank(_ confidence: Confidence) -> Int { confidence == .high ? 2 : (confidence == .medium ? 1 : 0) }

    public static func recommendations(for snapshot: StorageSnapshot, duplicates: [[ScannedItem]] = [],
                                       protectedPaths: Set<String> = [], protectedFileTypes: Set<String> = []) -> [Recommendation] {
        let now = Date.now
        var results: [Recommendation] = []
        var usedIDs = Set<String>()
        let eligible = snapshot.largeItems.filter { item in
            !protectedPaths.contains(where: { item.url.path.hasPrefix($0) }) && !protectedFileTypes.contains(item.fileType ?? "")
        }
        let cloudBacked = eligible.filter { $0.cloudBacked == true }
        if !cloudBacked.isEmpty { results.append(make(kind: .cloudLocalCopy, title: "Free space without deleting your iCloud files",
            detail: "These files are already stored in iCloud. Headroom can remove the downloaded copies from this Mac, and they will download again when you open them.",
            items: cloudBacked, risk: .low, confidence: .high, reversible: true, urgency: 1.3)) }
        usedIDs.formUnion(cloudBacked.map(\.id))
        let generatedRecipes: [(String, String, Confidence, (ScannedItem) -> Bool)] = [
            ("Remove old Xcode build files", "Xcode created these while building apps. Files not changed in three days can be recreated the next time you build.", .high,
             { $0.url.path.lowercased().contains("/deriveddata/") && now.timeIntervalSince($0.modifiedAt) > 3 * 86_400 }),
            ("Clear older temporary app files", "Apps created these files to run faster. Headroom includes only cache files that have not changed in a week.", .high,
             { $0.url.path.lowercased().contains("/library/caches/") && now.timeIntervalSince($0.modifiedAt) > 7 * 86_400 }),
            ("Remove downloaded project packages", "These project packages have not changed in two weeks and a dependency list was found nearby, so they can be downloaded again.", .medium,
             { $0.url.path.lowercased().contains("/node_modules/") && now.timeIntervalSince($0.modifiedAt) > 14 * 86_400 && hasDependencyManifest(near: $0.url) })
        ]
        for (title, detail, confidence, matches) in generatedRecipes {
            let items = eligible.filter { !usedIDs.contains($0.id) && matches($0) }
            if !items.isEmpty { results.append(make(kind: .generatedData, title: title, detail: detail,
                items: items, risk: .low, confidence: confidence, reversible: true, urgency: 1.2)) }
            usedIDs.formUnion(items.map(\.id))
        }

        let installers = eligible.filter {
            !usedIDs.contains($0.id) && ["dmg", "pkg", "zip", "xip"].contains($0.url.pathExtension.lowercased()) && now.timeIntervalSince($0.modifiedAt) > 14 * 86_400
        }
        if !installers.isEmpty { results.append(make(kind: .oldInstaller, title: "Remove old installers and downloads",
            detail: "These files are more than two weeks old and are usually only needed once. You can review every file before anything moves to Trash.",
            items: installers, risk: .low, confidence: .high, reversible: true, urgency: 1.0)) }
        usedIDs.formUnion(installers.map(\.id))

        let screenRecordings = eligible.filter {
            let name = $0.url.lastPathComponent.lowercased()
            return !usedIDs.contains($0.id) && $0.fileType == "Video" &&
                (name.contains("screen recording") || name.contains("screenrecording")) &&
                now.timeIntervalSince($0.modifiedAt) > 30 * 86_400
        }
        if !screenRecordings.isEmpty { results.append(make(kind: .screenRecording,
            title: "Review older screen recordings",
            detail: "Screen recordings can quietly become some of the largest files on a Mac. These have not changed in at least a month.",
            items: screenRecordings, risk: .medium, confidence: .high, reversible: true, urgency: 0.95)) }
        usedIDs.formUnion(screenRecordings.map(\.id))

        let olderVideos = eligible.filter {
            !usedIDs.contains($0.id) && $0.fileType == "Video" && now.timeIntervalSince($0.modifiedAt) > 60 * 86_400
        }.prefix(20)
        if !olderVideos.isEmpty { results.append(make(kind: .largeVideo,
            title: "Review large videos you may be finished with",
            detail: "These are older videos using the most room. Headroom cannot know whether you still need them, so each one must be reviewed.",
            items: Array(olderVideos), risk: .medium, confidence: .medium, reversible: true, urgency: 0.72)) }
        usedIDs.formUnion(olderVideos.map(\.id))

        for group in duplicates where group.count > 1 {
            let recoverable = Array(group.dropFirst()).filter { item in
                eligible.contains(where: { $0.id == item.id }) && !usedIDs.contains(item.id)
            }
            guard !recoverable.isEmpty else { continue }
            results.append(make(kind: .duplicate, title: "Remove extra copies of the same files",
                detail: "Headroom compared the file contents and found exact matches. One copy is kept; only the extras are included.",
                items: recoverable, risk: .low, confidence: .high, reversible: true, urgency: 1.15))
            usedIDs.formUnion(recoverable.map(\.id))
        }

        let recent = eligible.filter {
            !usedIDs.contains($0.id) && now.timeIntervalSince($0.modifiedAt) < 30 * 86_400
        }.prefix(12)
        if !recent.isEmpty { results.append(make(kind: .largeRecentFile, title: "Review large files added recently",
            detail: "These are some of the largest files added in the last 30 days. Headroom will not change them unless you choose to.",
            items: Array(recent), risk: .medium, confidence: .medium, reversible: true, urgency: 0.75)) }
        return results.sorted { $0.score > $1.score }
    }

    private static func make(kind: RecommendationKind, title: String, detail: String, items: [ScannedItem],
                             risk: RiskLevel, confidence: Confidence, reversible: Bool, urgency: Double) -> Recommendation {
        let bytes = items.reduce(0) { $0 + $1.allocatedSize }
        let riskCost: Double = risk == .low ? 1 : (risk == .medium ? 2 : 4)
        let confidenceValue: Double = confidence == .high ? 1 : (confidence == .medium ? 0.75 : 0.4)
        let identityData = Data((kind.rawValue + items.map(\.id).joined(separator: "|")).utf8)
        let stableID = SHA256.hash(data: identityData).prefix(10).map { String(format: "%02x", $0) }.joined()
        let newestDate = items.map(\.modifiedAt).max() ?? .now
        let ageDays = max(0, Int(Date.now.timeIntervalSince(newestDate) / 86_400))
        let ageDescription = ageDays == 0 ? "today" : "\(ageDays) day\(ageDays == 1 ? "" : "s") ago"
        let evidence = "\(items.count) file\(items.count == 1 ? "" : "s") · newest item changed \(ageDescription)"
        let restoration = kind == .cloudLocalCopy
            ? "Open the file and macOS will download it from iCloud again."
            : "Open Trash, select the file, and choose Put Back before emptying Trash."
        return Recommendation(id: kind.rawValue + "-" + stableID, kind: kind,
            title: title, detail: detail, recoveryBytes: bytes, affectedItems: items, risk: risk,
            confidence: confidence, reversible: reversible,
            score: log10(max(Double(bytes), 1)) * urgency * confidenceValue / riskCost,
            evidence: evidence, restoration: restoration)
    }

    private static func hasDependencyManifest(near url: URL) -> Bool {
        let fm = FileManager.default
        var folder = url.deletingLastPathComponent()
        for _ in 0..<8 {
            if ["package-lock.json", "pnpm-lock.yaml", "yarn.lock", "package.json"].contains(where: {
                fm.fileExists(atPath: folder.appending(path: $0).path)
            }) { return true }
            let parent = folder.deletingLastPathComponent()
            guard parent.path != folder.path else { break }
            folder = parent
        }
        return false
    }

    public static func exactDuplicateGroups(in items: [ScannedItem]) -> [[ScannedItem]] {
        let bySize = Dictionary(grouping: items, by: \.logicalSize).values.filter { $0.count > 1 }
        var hashes: [String: [ScannedItem]] = [:]
        for group in bySize {
            for item in group {
                guard let handle = try? FileHandle(forReadingFrom: item.url) else { continue }
                var hasher = SHA256()
                while autoreleasepool(invoking: {
                    guard let data = try? handle.read(upToCount: 4 * 1_024 * 1_024), !data.isEmpty else { return false }
                    hasher.update(data: data); return true
                }) {}
                try? handle.close()
                hashes[hasher.finalize().map { String(format: "%02x", $0) }.joined(), default: []].append(item)
            }
        }
        return hashes.values.filter { $0.count > 1 }
    }
}

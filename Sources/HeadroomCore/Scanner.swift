import Foundation

public struct ScanProgress: Sendable {
    public let phase: String
    public let items: Int
    public let scannedBytes: Int64
    public let completedRoots: Int
    public let totalRoots: Int
    public var fraction: Double { totalRoots == 0 ? 0 : Double(completedRoots) / Double(totalRoots) }
}

public enum StorageScanner {
    public static func volumeOverview() -> StorageSnapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let volume = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        return StorageSnapshot(capacity: Int64(volume?.volumeTotalCapacity ?? 0),
            freeSpace: volume?.volumeAvailableCapacityForImportantUsage ?? 0,
            scannedBytes: 0, scannedItemCount: 0, groups: [], largeItems: [], inaccessiblePaths: [])
    }

    public static func defaultRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        ["Desktop", "Documents", "Downloads", "Movies", "Pictures", "Music",
         "Library/Developer/Xcode/DerivedData", "Library/Developer/Xcode/Archives",
         "Library/Developer/CoreSimulator/Caches", "Library/Caches"]
            .map { home.appending(path: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    public static func scan(roots: [URL], progress: @escaping @Sendable (ScanProgress) -> Void = { _ in }) -> StorageSnapshot {
        var seenFileIdentities = Set<String>()
        return scan(roots: roots, seenFileIdentities: &seenFileIdentities, progress: progress)
    }

    private static func scan(roots: [URL], seenFileIdentities: inout Set<String>,
                             progress: @escaping @Sendable (ScanProgress) -> Void) -> StorageSnapshot {
        let startedAt = Date.now
        let fm = FileManager.default
        let scanRoots = normalizedRoots(roots)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
            .fileAllocatedSizeKey, .contentModificationDateKey, .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey, .fileResourceIdentifierKey]
        var groupBytes: [String: Int64] = [:]
        var groupCounts: [String: Int] = [:]
        var applicationBytes: [String: Int64] = [:], applicationCounts: [String: Int] = [:]
        var typeBytes: [String: Int64] = [:], typeCounts: [String: Int] = [:]
        var largeItems: [ScannedItem] = []
        var inaccessible: [String] = []
        var total: Int64 = 0
        var count = 0
        var deduplicatedHardLinks = 0

        for (rootIndex, root) in scanRoots.enumerated() {
            let group = root.lastPathComponent
            progress(.init(phase: "Scanning \(group)", items: count, scannedBytes: total,
                           completedRoots: rootIndex, totalRoots: scanRoots.count))
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { url, _ in inaccessible.append(url.path); return true }) else {
                inaccessible.append(root.path); continue
            }
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true,
                      values.isSymbolicLink != true else { continue }
                if let identifier = values.fileResourceIdentifier {
                    let identity = String(describing: identifier)
                    guard seenFileIdentities.insert(identity).inserted else {
                        deduplicatedHardLinks += 1
                        continue
                    }
                }
                let logical = Int64(values.fileSize ?? 0)
                let allocated = Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
                let size = max(allocated, 0)
                total += size; count += 1
                groupBytes[group, default: 0] += size
                groupCounts[group, default: 0] += 1
                let type = fileType(for: url), app = application(for: url, category: group)
                typeBytes[type, default: 0] += size; typeCounts[type, default: 0] += 1
                applicationBytes[app, default: 0] += size; applicationCounts[app, default: 0] += 1
                if size >= 10_000_000 {
                    largeItems.append(.init(url: url, logicalSize: logical, allocatedSize: size,
                                            modifiedAt: values.contentModificationDate ?? .distantPast,
                                            category: group, fileType: type, application: app,
                                            cloudBacked: values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus == .current))
                }
                if count.isMultiple(of: 1_000) {
                    progress(.init(phase: "Scanning \(group)", items: count, scannedBytes: total,
                                   completedRoots: rootIndex, totalRoots: scanRoots.count))
                    Thread.sleep(forTimeInterval: 0.008)
                }
            }
            progress(.init(phase: "Finished \(group)", items: count, scannedBytes: total,
                           completedRoots: rootIndex + 1, totalRoots: scanRoots.count))
        }

        let overview = volumeOverview()
        let groups = groupBytes.map { StorageGroup(name: $0.key, bytes: $0.value, itemCount: groupCounts[$0.key, default: 0]) }
            .sorted { $0.bytes > $1.bytes }
        let applications = applicationBytes.map { StorageGroup(name: $0.key, bytes: $0.value, itemCount: applicationCounts[$0.key, default: 0]) }.sorted { $0.bytes > $1.bytes }
        let fileTypes = typeBytes.map { StorageGroup(name: $0.key, bytes: $0.value, itemCount: typeCounts[$0.key, default: 0]) }.sorted { $0.bytes > $1.bytes }
        return StorageSnapshot(capacity: overview.capacity,
            freeSpace: overview.freeSpace,
            scannedBytes: total, scannedItemCount: count, groups: groups, applications: applications, fileTypes: fileTypes,
            largeItems: largeItems.sorted { $0.allocatedSize > $1.allocatedSize },
            inaccessiblePaths: Array(inaccessible.prefix(100)),
            scanDuration: Date.now.timeIntervalSince(startedAt),
            deduplicatedHardLinks: deduplicatedHardLinks,
            accountingNotes: accountingNotes(inaccessible: inaccessible, hardLinks: deduplicatedHardLinks))
    }

    /// Builds a durable unit of accounting for each monitored root. Filesystem events can then
    /// refresh only the roots that changed and merge them with the last verified root snapshots.
    public static func scanIndex(roots: [URL], progress: @escaping @Sendable (ScanProgress) -> Void = { _ in }) -> [String: StorageSnapshot] {
        let roots = normalizedRoots(roots)
        var index: [String: StorageSnapshot] = [:]
        var seenFileIdentities = Set<String>()
        for (rootIndex, root) in roots.enumerated() {
            let completedItems = index.values.reduce(0) { $0 + $1.scannedItemCount }
            let completedBytes = index.values.reduce(0) { $0 + $1.scannedBytes }
            index[root.path] = scan(roots: [root], seenFileIdentities: &seenFileIdentities) { rootProgress in
                progress(.init(phase: rootProgress.phase,
                               items: completedItems + rootProgress.items,
                               scannedBytes: completedBytes + rootProgress.scannedBytes,
                               completedRoots: rootIndex + rootProgress.completedRoots,
                               totalRoots: roots.count))
            }
        }
        return index
    }

    public static func mergedSnapshot(from index: [String: StorageSnapshot], roots: [URL]) -> StorageSnapshot {
        let allowed = Set(normalizedRoots(roots).map(\.path))
        let snapshots = index.filter { allowed.contains($0.key) }.map(\.value)
        let overview = volumeOverview()
        return StorageSnapshot(
            capacity: overview.capacity,
            freeSpace: overview.freeSpace,
            scannedBytes: snapshots.reduce(0) { $0 + $1.scannedBytes },
            scannedItemCount: snapshots.reduce(0) { $0 + $1.scannedItemCount },
            groups: mergeGroups(snapshots.flatMap(\.groups)),
            applications: mergeGroups(snapshots.flatMap { $0.applications ?? [] }),
            fileTypes: mergeGroups(snapshots.flatMap { $0.fileTypes ?? [] }),
            largeItems: snapshots.flatMap(\.largeItems).sorted { $0.allocatedSize > $1.allocatedSize },
            inaccessiblePaths: Array(snapshots.flatMap(\.inaccessiblePaths).prefix(100)),
            scanDuration: snapshots.reduce(0) { $0 + ($1.scanDuration ?? 0) },
            deduplicatedHardLinks: snapshots.reduce(0) { $0 + ($1.deduplicatedHardLinks ?? 0) },
            accountingNotes: Array(Set(snapshots.flatMap { $0.accountingNotes ?? [] })).sorted()
        )
    }

    public static func normalizedRoots(_ roots: [URL]) -> [URL] {
        let ordered = roots.map(\.standardizedFileURL).sorted { $0.path.count < $1.path.count }
        var result: [URL] = []
        for root in ordered where !result.contains(where: { root.path == $0.path || root.path.hasPrefix($0.path + "/") }) {
            result.append(root)
        }
        return result
    }

    private static func mergeGroups(_ groups: [StorageGroup]) -> [StorageGroup] {
        let grouped = Dictionary(grouping: groups, by: \.name)
        return grouped.map { name, values in
            StorageGroup(name: name,
                         bytes: values.reduce(0) { $0 + $1.bytes },
                         itemCount: values.reduce(0) { $0 + $1.itemCount })
        }.sorted { $0.bytes > $1.bytes }
    }

    private static func fileType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext) { return "Video" }
        if ["jpg", "jpeg", "png", "heic", "raw", "tiff", "gif"].contains(ext) { return "Images" }
        if ["zip", "dmg", "pkg", "xip", "tar", "gz", "7z"].contains(ext) { return "Archives & installers" }
        if ["mp3", "m4a", "wav", "aiff", "flac"].contains(ext) { return "Audio" }
        if ["pdf", "doc", "docx", "pages", "txt", "md", "rtf", "odt"].contains(ext) { return "Documents" }
        if ["xls", "xlsx", "numbers", "csv"].contains(ext) { return "Spreadsheets" }
        if ["ppt", "pptx", "key"].contains(ext) { return "Presentations" }
        if ["swift", "js", "jsx", "ts", "tsx", "py", "go", "rs", "java", "c", "cpp", "h", "json", "yaml", "yml"].contains(ext) { return "Project files" }
        return ext.isEmpty ? "Other" : ext.uppercased()
    }

    private static func application(for url: URL, category: String) -> String {
        let path = url.path.lowercased()
        if path.contains("/developer/xcode/") || path.contains("/deriveddata/") { return "Xcode" }
        if path.contains("/docker/") || path.contains("com.docker") { return "Docker" }
        if path.contains("/adobe/") { return "Adobe" }
        if path.contains("/final cut") || path.contains("finalcut") { return "Final Cut Pro" }
        if path.contains("/garageband/") { return "GarageBand" }
        if path.contains("/logic/") || path.contains("logic pro") { return "Logic Pro" }
        if path.contains("/photos library.photoslibrary/") { return "Photos" }
        if path.contains("/messages/") { return "Messages" }
        if path.contains("/google/chrome/") { return "Google Chrome" }
        if path.contains("/mozilla/firefox/") { return "Firefox" }
        if path.contains("/apple/safari/") || path.contains("/safari/") { return "Safari" }
        if path.contains("/downloads/") { return "Downloads" }
        if path.contains("/library/caches/") { return "Temporary app files" }
        return category
    }

    private static func accountingNotes(inaccessible: [String], hardLinks: Int) -> [String] {
        var notes = ["APFS clone savings are managed by macOS and may not be attributable to a single file."]
        if hardLinks > 0 { notes.append("Hard-linked files were counted once instead of once per folder entry.") }
        if !inaccessible.isEmpty { notes.append("Some folders were unavailable, so monitored-folder totals are incomplete.") }
        return notes
    }
}

import Foundation

public enum FileExplanationConfidence: String, Codable, Sendable {
    case high, medium, low

    public var label: String { rawValue.capitalized + " confidence" }
}

public enum FileExplanationSource: String, Codable, Sendable {
    case onDevice = "On-device explanation"
    case ai = "AI recommendation"
}

/// A grounded explanation of what a file is likely doing and the safest next decision.
public struct FileUseExplanation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let source: FileExplanationSource
    public let headline: String
    public let summary: String
    public let confidence: FileExplanationConfidence
    public let evidence: [String]
    public let caution: String
    public let decision: FileDecision
    public let decisionReason: String
    public let organizationSuggestion: String?
    public let previewWasAnalyzed: Bool

    public init(id: String, source: FileExplanationSource, headline: String, summary: String,
                confidence: FileExplanationConfidence, evidence: [String], caution: String,
                decision: FileDecision = .review,
                decisionReason: String = "Headroom does not have enough evidence to make a stronger recommendation.",
                organizationSuggestion: String? = nil, previewWasAnalyzed: Bool = false) {
        self.id = id; self.source = source; self.headline = headline; self.summary = summary
        self.confidence = confidence; self.evidence = evidence; self.caution = caution
        self.decision = decision; self.decisionReason = decisionReason
        self.organizationSuggestion = organizationSuggestion; self.previewWasAnalyzed = previewWasAnalyzed
    }
}

/// The intentionally small context that may be sent to an AI provider after consent.
public struct AIFileExplanationInput: Codable, Sendable {
    public let fileName: String
    public let fileExtension: String
    public let parentFolders: [String]
    public let sizeBytes: Int64
    public let daysSinceModified: Int
    public let detectedType: String?
    public let detectedApplication: String?
    public let localExplanation: String
    public let localEvidence: [String]
    public let relatedFileSignals: [String]
    public let previewIncluded: Bool

    public init(item: ScannedItem, localExplanation: FileUseExplanation,
                relatedFileSignals: [String] = [], previewIncluded: Bool = false) {
        fileName = item.url.lastPathComponent
        fileExtension = item.url.pathExtension.lowercased()
        // Avoid sending a complete path. The last few folder names are enough for a useful guess.
        parentFolders = privacySafeParentFolders(for: item.url, limit: 4)
        sizeBytes = item.allocatedSize
        daysSinceModified = max(0, Int(Date.now.timeIntervalSince(item.modifiedAt) / 86_400))
        detectedType = item.fileType
        detectedApplication = item.application
        self.localExplanation = localExplanation.summary
        localEvidence = localExplanation.evidence
        self.relatedFileSignals = Array(relatedFileSignals.prefix(6))
        self.previewIncluded = previewIncluded
    }
}

public struct AIOrganizationCandidate: Codable, Sendable {
    public let id: String
    public let fileName: String
    public let parentFolders: [String]
    public let sizeBytes: Int64
    public let daysSinceModified: Int
    public let detectedType: String?
    public let detectedApplication: String?

    public init(id: String, item: ScannedItem) {
        self.id = id
        fileName = item.url.lastPathComponent
        parentFolders = privacySafeParentFolders(for: item.url, limit: 3)
        sizeBytes = item.allocatedSize
        daysSinceModified = max(0, Int(Date.now.timeIntervalSince(item.modifiedAt) / 86_400))
        detectedType = item.fileType
        detectedApplication = item.application
    }
}

private func privacySafeParentFolders(for url: URL, limit: Int) -> [String] {
    var parts = url.deletingLastPathComponent().pathComponents.filter { $0 != "/" }
    if let usersIndex = parts.firstIndex(where: { $0.caseInsensitiveCompare("Users") == .orderedSame }),
       parts.indices.contains(usersIndex + 1) {
        parts.removeSubrange(0...(usersIndex + 1))
    }
    return Array(parts.suffix(limit))
}

public enum FileUseExplainer {
    public static func explain(_ item: ScannedItem, now: Date = .now) -> FileUseExplanation {
        let name = item.url.lastPathComponent.lowercased()
        let path = item.url.path.lowercased()
        let age = max(0, Int(now.timeIntervalSince(item.modifiedAt) / 86_400))
        let baseEvidence = [
            "File name: \(item.url.lastPathComponent)",
            "Last changed \(age == 0 ? "today" : "\(age) day\(age == 1 ? "" : "s") ago")",
            "Uses \(byteDescription(item.allocatedSize)) on this Mac"
        ]

        if item.cloudBacked == true {
            return result(item, headline: "A file already stored in iCloud", confidence: .high,
                          summary: "macOS reports that this file is stored in iCloud and a downloaded copy is currently using space on this Mac.",
                          evidence: baseEvidence + ["macOS reports a current iCloud copy"],
                          caution: "Offloading removes only the local download. Confirm that iCloud is available before relying on it while offline.",
                          decision: .offload,
                          decisionReason: "A verified cloud copy remains available, so removing only the local download frees space without deleting the file.")
        }

        if isScreenshot(name) {
            let isOlder = age > 120
            return result(item, headline: "A screenshot kept for reference", confidence: .high,
                          summary: "This appears to be a screenshot. Screenshots often capture decisions, product states, receipts, or visual references that are useful after the original moment has passed.",
                          evidence: baseEvidence + ["The filename follows a common screenshot naming pattern"],
                          caution: "Headroom has not inspected the image itself. Quick Look it or ask AI to inspect a reduced preview before deciding.",
                          decision: isOlder ? .offload : .keep,
                          decisionReason: isOlder
                            ? "It may still be useful as reference, but its age makes cloud or external storage a better home than scarce local space."
                            : "It is recent enough that it may still support active work; keep it until its context is clearer.",
                          organizationSuggestion: "Group it with screenshots from the same project or topic instead of leaving it loose on the Desktop or in Downloads.")
        }

        if name == "icudtl.dat" {
            return result(item, headline: "Chromium language and text data", confidence: .high,
                          summary: "This is a standard ICU data file used by Chromium-based apps such as Chrome, Electron, and tools that bundle a web engine. It supports text, language, and date handling.",
                          evidence: baseEvidence + ["The filename is a known Chromium ICU data file"],
                          caution: "It is not a personal document. Its app or build artifact may download or recreate it again.",
                          decision: .remove, decisionReason: "This is replaceable runtime data, not unique work. Remove it through the owning app, cache, or build folder rather than deleting only this file.")
        }
        if name == "resources.pak" {
            return result(item, headline: "Chromium or Electron app resources", confidence: .high,
                          summary: "This is a packed resource bundle used by Chromium-based apps. It commonly contains interface text and runtime resources needed by an app or build artifact.",
                          evidence: baseEvidence + ["The filename is a known Chromium resource bundle"],
                          caution: "Removing it may make its app or cached artifact unusable until it is downloaded or rebuilt again.",
                          decision: .remove, decisionReason: "It is replaceable app or build data. Delete the containing cache or unused app artifact when the owning app is closed.")
        }
        if name == "engines.json" && path.contains("prisma") {
            return result(item, headline: "Prisma database-engine package data", confidence: .high,
                          summary: "This appears to be part of Prisma, a database toolkit used by software projects. It helps a project locate or manage the database-engine files it needs.",
                          evidence: baseEvidence + ["It is inside a Prisma package folder"],
                          caution: "Removing it on its own can break that project until dependencies are installed again.",
                          decision: .remove, decisionReason: "A package manager can restore this dependency data. Delete the full dependency installation only when the project can reinstall it.")
        }
        if path.contains("swiftpm") && (path.contains("artifact") || name.contains("firebase")) {
            return result(item, headline: "Downloaded Swift package build artifact", confidence: .high,
                          summary: "This looks like a package artifact downloaded for an Apple app project—likely part of Firebase or another Swift Package Manager dependency used while building an app.",
                          evidence: baseEvidence + ["The folder trail points to Swift Package Manager artifacts"],
                          caution: "Removing the full derived-data or package cache is safer than deleting one artifact; Xcode can download it again.",
                          decision: .remove, decisionReason: "Xcode or Swift Package Manager can download this artifact again, making it a strong cleanup candidate.")
        }
        if isOpaqueCacheName(name), path.contains("cache") {
            return result(item, headline: "Cached download or network response", confidence: .medium,
                          summary: "This opaque name is typical of a cache entry. It is likely stored data from a download, web request, build tool, or app session rather than a file you created directly.",
                          evidence: baseEvidence + ["Opaque filename inside a cache-like folder"],
                          caution: "The owning app may recreate it. Headroom cannot tell exactly which request created it without inspecting file contents.",
                          decision: .remove, decisionReason: "Its cache location and opaque name strongly suggest replaceable data, but remove it as part of the owning app's cache rather than in isolation.")
        }
        if path.contains("/library/developer/xcode/deriveddata/") {
            return result(item, headline: "Xcode build output", confidence: .high,
                          summary: "Xcode generated this while building or indexing a project. It is working data, not the project’s source code.",
                          evidence: baseEvidence + ["Located in Xcode DerivedData"],
                          caution: "Xcode can rebuild it, although the next build may take longer.",
                          decision: .remove, decisionReason: "This is generated build output, so deleting it trades a little rebuild time for local space without losing source code.")
        }
        if path.contains("/library/caches/") {
            return result(item, headline: "Temporary app cache data", confidence: .medium,
                          summary: "This is stored in a macOS cache location, where apps keep downloaded or temporary data to work faster.",
                          evidence: baseEvidence + ["Located in Library/Caches"],
                          caution: "It is usually regenerable, but Headroom cannot guarantee it is safe for every app without more context.",
                          decision: .remove, decisionReason: "Its cache location makes it likely to be replaceable. Close the owning app and remove the containing cache only after review.")
        }
        if path.contains("/node_modules/") {
            return result(item, headline: "Installed project dependency", confidence: .high,
                          summary: "This belongs to a project dependency installed by a package manager. It supports a project rather than being a personal document.",
                          evidence: baseEvidence + ["Located in a node_modules dependency folder"],
                          caution: "Removing the full dependency folder requires another install or build to download it again.",
                          decision: .remove, decisionReason: "Installed dependencies are replaceable when the project has a package manifest and lockfile; the next install will restore them.")
        }
        if path.contains("coresimulator") {
            return result(item, headline: "iPhone Simulator working data", confidence: .high,
                          summary: "This was created by Apple’s Simulator while running or testing an app. It is working data for a simulated device.",
                          evidence: baseEvidence + ["Located in CoreSimulator data"],
                          caution: "Removing a whole simulator cache is safer than deleting an unfamiliar file by itself.",
                          decision: .remove, decisionReason: "Simulator working data is replaceable. Prefer removing an unused simulator or its full cache through developer tools.")
        }
        if ["dmg", "pkg", "xip"].contains(item.url.pathExtension.lowercased()), age > 14 {
            return result(item, headline: "An installer that has probably finished its job", confidence: .high,
                          summary: "This is an installer package. Once its app or tool is installed, keeping the installer usually adds little value because it can normally be downloaded again.",
                          evidence: baseEvidence + ["Installer format and more than two weeks old"],
                          caution: "Keep it if the installer is rare, licensed, customized, or difficult to download again.",
                          decision: .remove, decisionReason: "It is old, usually used once, and normally downloadable again, making it a good deletion candidate.")
        }
        if item.fileType == "Video" {
            let shouldOffload = age > 60
            return result(item, headline: "A video file", confidence: .high,
                          summary: "This is a video file. Headroom can identify its size and age, but cannot tell whether it is a finished export, a recording, or active work without an optional AI recommendation.",
                          evidence: baseEvidence + ["Detected as video from its file type"],
                          caution: "Review it in Quick Look before moving or deleting it.",
                          decision: shouldOffload ? .offload : .keep,
                          decisionReason: shouldOffload
                            ? "The file is older and potentially irreplaceable, so archive it instead of deleting it."
                            : "It is recent and may be active work, so keep it local until the project is finished.",
                          organizationSuggestion: "Keep it beside its source project, exports, and related assets so its role is obvious.")
        }
        return result(item, headline: "An unfamiliar file", confidence: .low,
                      summary: "Headroom can see this file’s name, location, age, and size, but those signals are not enough to reliably identify its purpose.",
                      evidence: baseEvidence + ["No known application or cache pattern matched"],
                      caution: "Use Quick Look or ask for an AI recommendation before deciding whether to remove it.",
                      decision: .review,
                      decisionReason: "The metadata does not prove that this file is replaceable, backed up, or inactive, so Headroom should not guess.")
    }

    private static func result(_ item: ScannedItem, headline: String, confidence: FileExplanationConfidence,
                               summary: String, evidence: [String], caution: String,
                               decision: FileDecision = .review,
                               decisionReason: String = "Review the file before deciding.",
                               organizationSuggestion: String? = nil) -> FileUseExplanation {
        FileUseExplanation(id: item.id, source: .onDevice, headline: headline, summary: summary,
                           confidence: confidence, evidence: Array(evidence.prefix(4)), caution: caution,
                           decision: decision, decisionReason: decisionReason,
                           organizationSuggestion: organizationSuggestion)
    }

    private static func isOpaqueCacheName(_ name: String) -> Bool {
        let hex = CharacterSet(charactersIn: "0123456789abcdef")
        let stem = name.split(separator: ".").first.map(String.init) ?? name
        return stem.count >= 20 && stem.unicodeScalars.allSatisfy { hex.contains($0) }
    }

    private static func isScreenshot(_ name: String) -> Bool {
        name.contains("screenshot") || name.contains("screen shot") || name.hasPrefix("clean shot")
    }

    private static func byteDescription(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

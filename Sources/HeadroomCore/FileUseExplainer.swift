import Foundation

public enum FileExplanationConfidence: String, Codable, Sendable {
    case high, medium, low

    public var label: String { rawValue.capitalized + " confidence" }
}

public enum FileExplanationSource: String, Codable, Sendable {
    case onDevice = "On-device explanation"
    case ai = "AI second opinion"
}

/// A cautious explanation of what a file is likely doing. It never decides whether to delete it.
public struct FileUseExplanation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let source: FileExplanationSource
    public let headline: String
    public let summary: String
    public let confidence: FileExplanationConfidence
    public let evidence: [String]
    public let caution: String

    public init(id: String, source: FileExplanationSource, headline: String, summary: String,
                confidence: FileExplanationConfidence, evidence: [String], caution: String) {
        self.id = id; self.source = source; self.headline = headline; self.summary = summary
        self.confidence = confidence; self.evidence = evidence; self.caution = caution
    }
}

/// The intentionally small, metadata-only context that may be sent to an AI provider after consent.
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

    public init(item: ScannedItem, localExplanation: FileUseExplanation) {
        fileName = item.url.lastPathComponent
        fileExtension = item.url.pathExtension.lowercased()
        // Avoid sending a complete path. The last few folder names are enough for a useful guess.
        let parts = item.url.deletingLastPathComponent().pathComponents.filter { $0 != "/" }
        parentFolders = Array(parts.suffix(4))
        sizeBytes = item.allocatedSize
        daysSinceModified = max(0, Int(Date.now.timeIntervalSince(item.modifiedAt) / 86_400))
        detectedType = item.fileType
        detectedApplication = item.application
        self.localExplanation = localExplanation.summary
        localEvidence = localExplanation.evidence
    }
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

        if name == "icudtl.dat" {
            return result(item, headline: "Chromium language and text data", confidence: .high,
                          summary: "This is a standard ICU data file used by Chromium-based apps such as Chrome, Electron, and tools that bundle a web engine. It supports text, language, and date handling.",
                          evidence: baseEvidence + ["The filename is a known Chromium ICU data file"],
                          caution: "It is not a personal document. If it belongs to an active app or downloaded build artifact, that app may download or recreate it again.")
        }
        if name == "resources.pak" {
            return result(item, headline: "Chromium or Electron app resources", confidence: .high,
                          summary: "This is a packed resource bundle used by Chromium-based apps. It commonly contains interface text and other runtime resources needed by an app or build artifact.",
                          evidence: baseEvidence + ["The filename is a known Chromium resource bundle"],
                          caution: "It is not a personal document. Removing it may make its app or cached artifact unusable until it is downloaded or rebuilt again.")
        }
        if name == "engines.json" && path.contains("prisma") {
            return result(item, headline: "Prisma database-engine package data", confidence: .high,
                          summary: "This appears to be part of Prisma, a database toolkit used by software projects. It helps a project locate or manage the database-engine files it needs.",
                          evidence: baseEvidence + ["It is inside a Prisma package folder"],
                          caution: "This is project dependency data, not a personal file. Removing it on its own can break that project until dependencies are installed again.")
        }
        if path.contains("swiftpm") && (path.contains("artifact") || name.contains("firebase")) {
            return result(item, headline: "Downloaded Swift package build artifact", confidence: .high,
                          summary: "This looks like a package artifact downloaded for an Apple app project—likely part of Firebase or another Swift Package Manager dependency used while building an app.",
                          evidence: baseEvidence + ["The folder trail points to Swift Package Manager artifacts"],
                          caution: "It is not a personal document. Removing the full derived-data or package cache is usually safer than deleting one artifact; Xcode can download it again.")
        }
        if isOpaqueCacheName(name), path.contains("cache") {
            return result(item, headline: "Cached download or network response", confidence: .medium,
                          summary: "This opaque name is typical of a cache entry. It is likely stored data from a download, web request, build tool, or app session rather than a file you created directly.",
                          evidence: baseEvidence + ["Opaque filename inside a cache-like folder"],
                          caution: "The owning app may recreate it. Headroom cannot tell exactly which request created it without inspecting file contents.")
        }
        if path.contains("/library/developer/xcode/deriveddata/") {
            return result(item, headline: "Xcode build output", confidence: .high,
                          summary: "Xcode generated this while building or indexing a project. It is working data, not the project’s source code.",
                          evidence: baseEvidence + ["Located in Xcode DerivedData"],
                          caution: "Xcode can rebuild it, although the next build may take longer.")
        }
        if path.contains("/library/caches/") {
            return result(item, headline: "Temporary app cache data", confidence: .medium,
                          summary: "This is stored in a macOS cache location, where apps keep downloaded or temporary data to work faster.",
                          evidence: baseEvidence + ["Located in Library/Caches"],
                          caution: "It is usually regenerable, but Headroom cannot guarantee it is safe for every app without more context.")
        }
        if path.contains("/node_modules/") {
            return result(item, headline: "Installed project dependency", confidence: .high,
                          summary: "This belongs to a project dependency installed by a package manager. It supports a project rather than being a personal document.",
                          evidence: baseEvidence + ["Located in a node_modules dependency folder"],
                          caution: "Removing the full dependency folder may be fine when the project has a lockfile, but the next install or build will need to download it again.")
        }
        if path.contains("coresimulator") {
            return result(item, headline: "iPhone Simulator working data", confidence: .high,
                          summary: "This was created by Apple’s Simulator while running or testing an app. It is working data for a simulated device.",
                          evidence: baseEvidence + ["Located in CoreSimulator data"],
                          caution: "Simulator tools may recreate it. Removing a whole simulator cache is safer than deleting an unfamiliar file by itself.")
        }
        if item.fileType == "Video" {
            return result(item, headline: "A video file", confidence: .high,
                          summary: "This is a video file. Headroom can identify its size and age, but cannot tell whether it is a finished export, a recording, or active work without an optional AI second opinion.",
                          evidence: baseEvidence + ["Detected as video from its file type"],
                          caution: "Review it in Quick Look before moving it to Trash.")
        }
        return result(item, headline: "An unfamiliar file", confidence: .low,
                      summary: "Headroom can see this file’s name, location, age, and size, but those signals are not enough to reliably identify its purpose.",
                      evidence: baseEvidence + ["No known application or cache pattern matched"],
                      caution: "Use Quick Look or ask for an AI second opinion before deciding whether to remove it.")
    }

    private static func result(_ item: ScannedItem, headline: String, confidence: FileExplanationConfidence,
                               summary: String, evidence: [String], caution: String) -> FileUseExplanation {
        FileUseExplanation(id: item.id, source: .onDevice, headline: headline, summary: summary,
                           confidence: confidence, evidence: evidence, caution: caution)
    }

    private static func isOpaqueCacheName(_ name: String) -> Bool {
        let hex = CharacterSet(charactersIn: "0123456789abcdef")
        let stem = name.split(separator: ".").first.map(String.init) ?? name
        return stem.count >= 20 && stem.unicodeScalars.allSatisfy { hex.contains($0) }
    }

    private static func byteDescription(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

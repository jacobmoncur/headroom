import Foundation

public enum RiskLevel: String, Codable, Sendable { case low, medium, high }
public enum Confidence: String, Codable, Sendable { case high, medium, low }
public enum RecommendationKind: String, Codable, Sendable {
    case generatedData, oldInstaller, largeRecentFile, duplicate, cloudLocalCopy, screenRecording, largeVideo
}

public enum ActionVerificationStatus: String, Codable, Sendable {
    case awaitingTrash, verifying, verified, partial, failed
}

public enum RecommendationFeedbackReason: String, Codable, CaseIterable, Sendable {
    case stillNeeded, feelsUnsafe, unclear, notRelevant
}

public struct ScannedItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let logicalSize: Int64
    public let allocatedSize: Int64
    public let modifiedAt: Date
    public let category: String
    public let fileType: String?
    public let application: String?
    public let cloudBacked: Bool?

    public init(url: URL, logicalSize: Int64, allocatedSize: Int64, modifiedAt: Date, category: String,
                fileType: String? = nil, application: String? = nil, cloudBacked: Bool? = nil) {
        self.id = url.path
        self.url = url
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.modifiedAt = modifiedAt
        self.category = category
        self.fileType = fileType; self.application = application; self.cloudBacked = cloudBacked
    }
}

public struct StorageGroup: Identifiable, Codable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let bytes: Int64
    public let itemCount: Int
}

public struct StorageSnapshot: Identifiable, Codable, Sendable {
    public let id: UUID
    public let capturedAt: Date
    public let capacity: Int64
    public let freeSpace: Int64
    public let scannedBytes: Int64
    public let scannedItemCount: Int
    public let groups: [StorageGroup]
    public let applications: [StorageGroup]?
    public let fileTypes: [StorageGroup]?
    public let largeItems: [ScannedItem]
    public let inaccessiblePaths: [String]
    public let scanDuration: TimeInterval?
    public let deduplicatedHardLinks: Int?
    public let accountingNotes: [String]?

    public init(id: UUID = UUID(), capturedAt: Date = .now, capacity: Int64, freeSpace: Int64,
                scannedBytes: Int64, scannedItemCount: Int, groups: [StorageGroup],
                applications: [StorageGroup]? = nil, fileTypes: [StorageGroup]? = nil,
                largeItems: [ScannedItem], inaccessiblePaths: [String],
                scanDuration: TimeInterval? = nil, deduplicatedHardLinks: Int? = nil,
                accountingNotes: [String]? = nil) {
        self.id = id; self.capturedAt = capturedAt; self.capacity = capacity; self.freeSpace = freeSpace
        self.scannedBytes = scannedBytes; self.scannedItemCount = scannedItemCount; self.groups = groups
        self.applications = applications; self.fileTypes = fileTypes
        self.largeItems = largeItems; self.inaccessiblePaths = inaccessiblePaths
        self.scanDuration = scanDuration; self.deduplicatedHardLinks = deduplicatedHardLinks
        self.accountingNotes = accountingNotes
    }
}

public struct StorageDelta: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let bytes: Int64
}

public struct Recommendation: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: RecommendationKind
    public let title: String
    public let detail: String
    public let recoveryBytes: Int64
    public let affectedItems: [ScannedItem]
    public let risk: RiskLevel
    public let confidence: Confidence
    public let reversible: Bool
    public let score: Double
    public let evidence: String?
    public let restoration: String?

    public init(id: String, kind: RecommendationKind, title: String, detail: String,
                recoveryBytes: Int64, affectedItems: [ScannedItem], risk: RiskLevel,
                confidence: Confidence, reversible: Bool, score: Double,
                evidence: String? = nil, restoration: String? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.detail = detail
        self.recoveryBytes = recoveryBytes; self.affectedItems = affectedItems
        self.risk = risk; self.confidence = confidence; self.reversible = reversible
        self.score = score; self.evidence = evidence; self.restoration = restoration
    }
}

public struct RecoveryPlan: Sendable {
    public let targetBytes: Int64
    public let recommendations: [Recommendation]
    public var estimatedRecovery: Int64 { recommendations.reduce(0) { $0 + $1.recoveryBytes } }
    public var meetsTarget: Bool { estimatedRecovery >= targetBytes }
    public var itemCount: Int { recommendations.reduce(0) { $0 + $1.affectedItems.count } }
}

public struct ActionRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let performedAt: Date
    public let title: String
    public let expectedBytes: Int64
    public let recoveredBytes: Int64
    public let itemCount: Int
    public let result: String
    public let verificationStatus: ActionVerificationStatus?
    public let freeSpaceBefore: Int64?
    public let verificationMessage: String?
    public let affectedPaths: [String]?
    public let completedAt: Date?

    public init(id: UUID = UUID(), performedAt: Date = .now, title: String, expectedBytes: Int64,
                recoveredBytes: Int64, itemCount: Int, result: String,
                verificationStatus: ActionVerificationStatus? = nil,
                freeSpaceBefore: Int64? = nil, verificationMessage: String? = nil,
                affectedPaths: [String]? = nil, completedAt: Date? = nil) {
        self.id = id; self.performedAt = performedAt; self.title = title
        self.expectedBytes = expectedBytes; self.recoveredBytes = recoveredBytes
        self.itemCount = itemCount; self.result = result
        self.verificationStatus = verificationStatus; self.freeSpaceBefore = freeSpaceBefore
        self.verificationMessage = verificationMessage; self.affectedPaths = affectedPaths
        self.completedAt = completedAt
    }

    public var effectiveVerificationStatus: ActionVerificationStatus {
        if let verificationStatus { return verificationStatus }
        return result.localizedCaseInsensitiveContains("partial") ? .partial : .verified
    }

    public func verified(with recoveredBytes: Int64, status: ActionVerificationStatus,
                         message: String, completedAt: Date = .now) -> ActionRecord {
        ActionRecord(id: id, performedAt: performedAt, title: title, expectedBytes: expectedBytes,
                     recoveredBytes: recoveredBytes, itemCount: itemCount, result: result,
                     verificationStatus: status, freeSpaceBefore: freeSpaceBefore,
                     verificationMessage: message, affectedPaths: affectedPaths, completedAt: completedAt)
    }
}

public struct RecommendationFeedback: Identifiable, Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let recommendationID: String
    public let recommendationKind: RecommendationKind
    public let reason: RecommendationFeedbackReason

    public init(id: UUID = UUID(), createdAt: Date = .now, recommendationID: String,
                recommendationKind: RecommendationKind, reason: RecommendationFeedbackReason) {
        self.id = id; self.createdAt = createdAt; self.recommendationID = recommendationID
        self.recommendationKind = recommendationKind; self.reason = reason
    }
}

public struct StorageHealth: Sendable {
    public let freeSpace: Int64
    public let reserve: Int64
    public let dailyGrowth: Double
    public var spendable: Int64 { max(0, freeSpace - reserve) }
    public var runwayDays: Int? {
        guard dailyGrowth > 0 else { return nil }
        return max(0, Int(Double(freeSpace - reserve) / dailyGrowth))
    }
    public var isHealthy: Bool { freeSpace > reserve }
}

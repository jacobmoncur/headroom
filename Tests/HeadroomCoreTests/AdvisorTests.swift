import XCTest
@testable import HeadroomCore

final class AdvisorTests: XCTestCase {
    func testRunwayUsesProtectedReserve() {
        let now = Date()
        let old = snapshot(date: now.addingTimeInterval(-2 * 86_400), free: 100_000_000_000)
        let current = snapshot(date: now, free: 80_000_000_000)
        let health = StorageAdvisor.health(current: current, previous: old, reserve: 50_000_000_000)
        XCTAssertEqual(health.runwayDays, 3)
        XCTAssertEqual(health.spendable, 30_000_000_000)
    }

    func testShortIntervalDoesNotProduceMisleadingDailyForecast() {
        let now = Date()
        let old = snapshot(date: now.addingTimeInterval(-30 * 60), free: 100_000_000_000)
        let current = snapshot(date: now, free: 80_000_000_000)
        let health = StorageAdvisor.health(current: current, previous: old, reserve: 50_000_000_000)
        XCTAssertEqual(health.dailyGrowth, 0)
        XCTAssertNil(health.runwayDays)
    }

    func testInstallerRecommendationIsLowRiskAndReversible() {
        let item = ScannedItem(url: URL(fileURLWithPath: "/tmp/old.dmg"), logicalSize: 1_000_000_000,
            allocatedSize: 1_000_000_000, modifiedAt: .now.addingTimeInterval(-20 * 86_400), category: "Downloads")
        let snapshot = StorageSnapshot(capacity: 1, freeSpace: 1, scannedBytes: 1, scannedItemCount: 1,
            groups: [], largeItems: [item], inaccessiblePaths: [])
        let recommendation = StorageAdvisor.recommendations(for: snapshot).first { $0.kind == .oldInstaller }
        XCTAssertEqual(recommendation?.risk, .low)
        XCTAssertEqual(recommendation?.reversible, true)
    }

    func testDeltasCompareGroups() {
        let old = snapshot(date: .now.addingTimeInterval(-100), free: 10, groups: [.init(name: "Downloads", bytes: 1_000_000, itemCount: 1)])
        let current = snapshot(date: .now, free: 9, groups: [.init(name: "Downloads", bytes: 5_000_000, itemCount: 2)])
        XCTAssertEqual(StorageAdvisor.deltas(current: current, previous: old).first?.bytes, 4_000_000)
    }

    func testNoChangeClaimWithoutBaseline() {
        XCTAssertTrue(StorageAdvisor.deltas(current: snapshot(date: .now, free: 10), previous: nil).isEmpty)
    }

    func testProtectedPathsAreExcluded() {
        let item = ScannedItem(url: URL(fileURLWithPath: "/tmp/protected/old.zip"), logicalSize: 1_000_000_000,
            allocatedSize: 1_000_000_000, modifiedAt: .now.addingTimeInterval(-30 * 86_400), category: "Downloads")
        let value = StorageSnapshot(capacity: 1, freeSpace: 1, scannedBytes: 1, scannedItemCount: 1,
            groups: [], largeItems: [item], inaccessiblePaths: [])
        XCTAssertTrue(StorageAdvisor.recommendations(for: value, protectedPaths: ["/tmp/protected"]).isEmpty)
    }

    func testProtectedFileTypesAreExcluded() {
        let item = ScannedItem(url: URL(fileURLWithPath: "/tmp/movie.mov"), logicalSize: 1_000_000_000,
            allocatedSize: 1_000_000_000, modifiedAt: .now, category: "Movies", fileType: "Video")
        let value = StorageSnapshot(capacity: 1, freeSpace: 1, scannedBytes: 1, scannedItemCount: 1,
            groups: [], largeItems: [item], inaccessiblePaths: [])
        XCTAssertTrue(StorageAdvisor.recommendations(for: value, protectedFileTypes: ["Video"]).isEmpty)
    }

    func testCloudBackedFileGetsEvictionRecommendation() {
        let item = ScannedItem(url: URL(fileURLWithPath: "/tmp/cloud.mov"), logicalSize: 1_000_000_000,
            allocatedSize: 1_000_000_000, modifiedAt: .now, category: "Movies", cloudBacked: true)
        let value = StorageSnapshot(capacity: 1, freeSpace: 1, scannedBytes: 1, scannedItemCount: 1,
            groups: [], largeItems: [item], inaccessiblePaths: [])
        XCTAssertTrue(StorageAdvisor.recommendations(for: value).contains { $0.kind == .cloudLocalCopy })
    }

    func testOldScreenRecordingGetsSpecificRecommendation() {
        let item = ScannedItem(url: URL(fileURLWithPath: "/tmp/Screen Recording 2026-01-01.mov"),
            logicalSize: 2_000_000_000, allocatedSize: 2_000_000_000,
            modifiedAt: .now.addingTimeInterval(-40 * 86_400), category: "Movies", fileType: "Video")
        let value = StorageSnapshot(capacity: 1, freeSpace: 1, scannedBytes: 1, scannedItemCount: 1,
            groups: [], largeItems: [item], inaccessiblePaths: [])
        let recommendations = StorageAdvisor.recommendations(for: value)
        XCTAssertTrue(recommendations.contains { $0.kind == .screenRecording })
        XCTAssertFalse(recommendations.contains { $0.kind == .largeRecentFile })
    }

    func testAnomalyDetectionRequiresMeaningfulOutlier() {
        let values = [StorageDelta(name: "Movies", bytes: 12_000_000_000), StorageDelta(name: "Other", bytes: 1_000_000_000)]
        XCTAssertEqual(StorageAdvisor.anomalies(in: values).map(\.name), ["Movies"])
    }

    func testRecoveryPlanPrefersLowRiskAndStopsAtTarget() {
        let low = recommendation(id: "low", bytes: 8_000_000_000, risk: .low, confidence: .high)
        let medium = recommendation(id: "medium", bytes: 20_000_000_000, risk: .medium, confidence: .high)
        let plan = StorageAdvisor.recoveryPlan(targetBytes: 7_000_000_000, from: [medium, low])
        XCTAssertEqual(plan.recommendations.map(\.id), ["low"])
        XCTAssertTrue(plan.meetsTarget)
    }

    func testRecoveryPlanCombinesActionsWhenNeeded() {
        let first = recommendation(id: "first", bytes: 8_000_000_000, risk: .low, confidence: .high)
        let second = recommendation(id: "second", bytes: 5_000_000_000, risk: .low, confidence: .medium)
        let plan = StorageAdvisor.recoveryPlan(targetBytes: 10_000_000_000, from: [second, first])
        XCTAssertEqual(plan.recommendations.count, 2)
        XCTAssertEqual(plan.estimatedRecovery, 13_000_000_000)
    }

    private func snapshot(date: Date, free: Int64, groups: [StorageGroup] = []) -> StorageSnapshot {
        StorageSnapshot(capturedAt: date, capacity: 200_000_000_000, freeSpace: free,
            scannedBytes: 0, scannedItemCount: 0, groups: groups, largeItems: [], inaccessiblePaths: [])
    }

    private func recommendation(id: String, bytes: Int64, risk: RiskLevel, confidence: Confidence) -> Recommendation {
        Recommendation(id: id, kind: .largeRecentFile, title: id, detail: "", recoveryBytes: bytes,
            affectedItems: [], risk: risk, confidence: confidence, reversible: true, score: 1)
    }
}

import XCTest
@testable import HeadroomCore

final class ScannerAndHistoryTests: XCTestCase {
    func testScannerBuildsBreakdownsAndLargeItemEvidence() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "sample.mov")
        try Data(repeating: 1, count: 51_000_000).write(to: file)

        let snapshot = StorageScanner.scan(roots: [root])
        XCTAssertEqual(snapshot.scannedItemCount, 1)
        XCTAssertEqual(snapshot.largeItems.first?.fileType, "Video")
        XCTAssertFalse(snapshot.fileTypes?.isEmpty ?? true)
        XCTAssertFalse(snapshot.applications?.isEmpty ?? true)
    }

    func testHistoryPersistsSnapshotsAndActions() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HistoryStore(directory: root)
        let snapshot = StorageSnapshot(capacity: 2, freeSpace: 1, scannedBytes: 0, scannedItemCount: 0,
            groups: [], largeItems: [], inaccessiblePaths: [])
        try await store.save(snapshot: snapshot)
        try await store.save(action: ActionRecord(title: "Test", expectedBytes: 10, recoveredBytes: 9, itemCount: 1, result: "Done"))
        let loadedSnapshots = await store.loadSnapshots()
        let loadedActions = await store.loadActions()
        XCTAssertEqual(loadedSnapshots.count, 1)
        XCTAssertEqual(loadedActions.first?.recoveredBytes, 9)
    }

    func testNestedScanRootsAreDeduplicated() {
        let parent = URL(fileURLWithPath: "/tmp/Headroom")
        let child = parent.appending(path: "Nested")
        XCTAssertEqual(StorageScanner.normalizedRoots([child, parent, parent]).map(\.path), [parent.path])
    }

    func testHardLinksAreCountedOnce() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appending(path: "original.bin")
        let linked = root.appending(path: "linked.bin")
        try Data(repeating: 1, count: 12_000_000).write(to: original)
        try FileManager.default.linkItem(at: original, to: linked)

        let snapshot = StorageScanner.scan(roots: [root])
        XCTAssertEqual(snapshot.scannedItemCount, 1)
        XCTAssertEqual(snapshot.deduplicatedHardLinks, 1)
    }

    func testPendingActionAndFeedbackRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HistoryStore(directory: root)
        let action = ActionRecord(title: "Old downloads", expectedBytes: 100, recoveredBytes: 0,
            itemCount: 2, result: "Moved to Trash", verificationStatus: .awaitingTrash,
            freeSpaceBefore: 1_000, verificationMessage: "Empty Trash, then check.")
        let feedback = RecommendationFeedback(recommendationID: "oldInstaller-1",
            recommendationKind: .oldInstaller, reason: .stillNeeded)
        try await store.save(action: action)
        try await store.save(feedback: feedback)

        let loadedActions = await store.loadActions()
        let loadedFeedback = await store.loadFeedback()
        XCTAssertEqual(loadedActions.first?.effectiveVerificationStatus, .awaitingTrash)
        XCTAssertEqual(loadedFeedback.first?.reason, .stillNeeded)
    }
}

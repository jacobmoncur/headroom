import XCTest
@testable import HeadroomCore

final class OrganizerTests: XCTestCase {
    func testScatteredScreenshotsBecomeOrganizationSuggestion() {
        let items = [
            fixture("/Users/example/Desktop/Screenshot 2026-07-01.png"),
            fixture("/Users/example/Documents/Reference/Screenshot 2026-07-02.png")
        ]
        let suggestions = FileOrganizer.suggestions(for: snapshot(items))
        let screenshots = suggestions.first { $0.title.localizedCaseInsensitiveContains("screenshots") }
        XCTAssertEqual(screenshots?.source, .onDevice)
        XCTAssertEqual(screenshots?.distinctFolderCount, 2)
        XCTAssertEqual(screenshots?.suggestedFolder, "Pictures/Screenshots")
    }

    func testSharedProjectNameAcrossFoldersBecomesSuggestion() {
        let items = [
            fixture("/Users/example/Desktop/Headroom mockup.png"),
            fixture("/Users/example/Documents/Notes/Headroom research.pdf")
        ]
        let suggestions = FileOrganizer.suggestions(for: snapshot(items))
        XCTAssertTrue(suggestions.contains { $0.title.localizedCaseInsensitiveContains("Headroom") })
    }

    func testBroadFileTypeAloneDoesNotCreateSuggestion() {
        let items = [
            fixture("/Users/example/Desktop/alpha.png"),
            fixture("/Users/example/Documents/beta.png")
        ]
        XCTAssertTrue(FileOrganizer.suggestions(for: snapshot(items)).isEmpty)
    }

    private func fixture(_ path: String) -> ScannedItem {
        ScannedItem(url: URL(fileURLWithPath: path), logicalSize: 12_000_000,
                    allocatedSize: 12_000_000, modifiedAt: .now,
                    category: "Documents", fileType: "Images")
    }

    private func snapshot(_ items: [ScannedItem]) -> StorageSnapshot {
        StorageSnapshot(capacity: 1, freeSpace: 1, scannedBytes: 1,
                        scannedItemCount: items.count, groups: [],
                        largeItems: items, inaccessiblePaths: [])
    }
}

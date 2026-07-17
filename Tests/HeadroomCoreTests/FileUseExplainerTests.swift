import XCTest
@testable import HeadroomCore

final class FileUseExplainerTests: XCTestCase {
    func testChromiumICUDataGetsSpecificOnDeviceExplanation() {
        let item = fixture(path: "/Users/example/Library/Caches/SomeApp/Resources/icudtl.dat")
        let explanation = FileUseExplainer.explain(item)
        XCTAssertEqual(explanation.confidence, .high)
        XCTAssertEqual(explanation.headline, "Chromium language and text data")
        XCTAssertTrue(explanation.summary.localizedCaseInsensitiveContains("Chromium"))
    }

    func testPrismaEngineManifestGetsSpecificOnDeviceExplanation() {
        let item = fixture(path: "/Users/example/Library/Caches/project/node_modules/@prisma/engines/engines.json")
        let explanation = FileUseExplainer.explain(item)
        XCTAssertEqual(explanation.confidence, .high)
        XCTAssertTrue(explanation.headline.localizedCaseInsensitiveContains("Prisma"))
    }

    func testOpaqueCacheFileExplainsUncertainty() {
        let item = fixture(path: "/Users/example/Library/Caches/app/a58e09047d1fb15cefaa2ea9752221192a46fed45d881c8a20fda70b.body")
        let explanation = FileUseExplainer.explain(item)
        XCTAssertEqual(explanation.confidence, .medium)
        XCTAssertTrue(explanation.headline.localizedCaseInsensitiveContains("cache"))
    }

    func testAIInputExcludesCompletePath() {
        let item = fixture(path: "/Users/private-name/Documents/secret-project/Library/Caches/app/icudtl.dat")
        let local = FileUseExplainer.explain(item)
        let input = AIFileExplanationInput(item: item, localExplanation: local)
        XCTAssertEqual(input.fileName, "icudtl.dat")
        XCTAssertFalse(input.parentFolders.joined(separator: "/").contains("/Users/private-name"))
        XCTAssertLessThanOrEqual(input.parentFolders.count, 4)
    }

    private func fixture(path: String) -> ScannedItem {
        ScannedItem(url: URL(fileURLWithPath: path), logicalSize: 10_500_000,
                    allocatedSize: 10_500_000, modifiedAt: .now.addingTimeInterval(-8 * 86_400),
                    category: "Caches", fileType: "Other", application: "Temporary app files")
    }
}

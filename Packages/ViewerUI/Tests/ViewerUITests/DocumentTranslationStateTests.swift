@testable import ViewerUI
import XCTest

final class DocumentTranslationStateTests: XCTestCase {
    func testFirstClickStartsTranslationAndSecondClickShowsEnglish() {
        var state = DocumentTranslationState()

        XCTAssertEqual(state.toggle(), .startTranslation)
        XCTAssertTrue(state.isTranslating)
        XCTAssertFalse(state.isShowingChinese)

        state.complete(with: [1: "你好，世界"])

        XCTAssertTrue(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
        XCTAssertEqual(state.translatedBlocks[1], "你好，世界")

        XCTAssertEqual(state.toggle(), .showEnglish)
        XCTAssertFalse(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
    }

    func testCachedTranslationCanBeShownWithoutStartingAnotherTranslation() {
        var state = DocumentTranslationState()
        _ = state.toggle()
        state.complete(with: [1: "中文"])
        _ = state.toggle()

        XCTAssertEqual(state.toggle(), .showCachedChinese)
        XCTAssertTrue(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
    }

    func testDocumentChangeResetsTranslationState() {
        var state = DocumentTranslationState()
        _ = state.toggle()
        state.complete(with: [1: "中文"])

        state.reset()

        XCTAssertEqual(state, DocumentTranslationState())
    }

    func testTranslationFailureReturnsToEnglish() {
        var state = DocumentTranslationState()
        _ = state.toggle()

        state.fail(with: "Translation unavailable")

        XCTAssertFalse(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
        XCTAssertEqual(state.errorMessage, "Translation unavailable")
    }

    /// Function: DocumentTranslationState.beginTranslation and translatedBlockArrived.
    /// Input: Three translation responses represented by line IDs 1...3 and short Chinese strings.
    /// Output: Incremental state exposes the completed count, progress text, and translated values.
    func testIncrementalResponsesUpdateProgress() {
        var state = DocumentTranslationState()
        state.beginTranslation(totalBlockCount: 3)

        state.translatedBlockArrived(line: 1, text: "第一段")
        state.translatedBlockArrived(line: 2, text: "第二段")

        XCTAssertEqual(state.completedBlockCount, 2)
        XCTAssertEqual(state.totalBlockCount, 3)
        XCTAssertEqual(state.progressText, "Translating 2/3…")
        XCTAssertEqual(state.translatedBlocks[1], "第一段")
        XCTAssertEqual(state.translatedBlocks[2], "第二段")
        XCTAssertTrue(state.isShowingChinese)
    }

    /// Function: DocumentTranslationState.cancel.
    /// Input: An active translation with two expected blocks and one partial response.
    /// Output: Translation activity and partial progress are cleared without an error message.
    func testCancellationClearsActiveTranslation() {
        var state = DocumentTranslationState()
        state.beginTranslation(totalBlockCount: 2)
        state.translatedBlockArrived(line: 1, text: "部分结果")

        state.cancel()

        XCTAssertFalse(state.isTranslating)
        XCTAssertFalse(state.isShowingChinese)
        XCTAssertNil(state.progressText)
        XCTAssertEqual(state.completedBlockCount, 0)
        XCTAssertEqual(state.totalBlockCount, 0)
    }

    #if os(macOS)
    /// Function: TranslationCache.save and TranslationCache.load.
    /// Input: A temporary cache directory, one SHA-like key, and two translated block values.
    /// Output: A later load returns the same line-to-translation dictionary.
    func testTranslationCacheRoundTrip() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("translation-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = TranslationCache(directory: directory)
        let blocks = [1: "第一段", 4: "第四段"]
        cache.save(blocks, for: "document-key")

        XCTAssertEqual(cache.load(for: "document-key"), blocks)
        XCTAssertNil(cache.load(for: "missing-key"))
    }
    #endif
}

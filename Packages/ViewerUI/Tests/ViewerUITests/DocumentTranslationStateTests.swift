@testable import ViewerUI
import XCTest

final class DocumentTranslationStateTests: XCTestCase {
    func testFirstClickStartsTranslationAndSecondClickShowsEnglish() {
        var state = DocumentTranslationState()

        XCTAssertEqual(state.toggle(), .startTranslation)
        XCTAssertTrue(state.isTranslating)
        XCTAssertFalse(state.isShowingChinese)

        state.complete(with: ["1": "你好，世界"])

        XCTAssertTrue(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
        XCTAssertEqual(state.translatedBlocks["1"], "你好，世界")

        XCTAssertEqual(state.toggle(), .showEnglish)
        XCTAssertFalse(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
    }

    func testCachedTranslationCanBeShownWithoutStartingAnotherTranslation() {
        var state = DocumentTranslationState()
        _ = state.toggle()
        state.complete(with: ["1": "中文"])
        _ = state.toggle()

        XCTAssertEqual(state.toggle(), .showCachedChinese)
        XCTAssertTrue(state.isShowingChinese)
        XCTAssertFalse(state.isTranslating)
    }

    func testDocumentChangeResetsTranslationState() {
        var state = DocumentTranslationState()
        _ = state.toggle()
        state.complete(with: ["1": "中文"])

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
    /// Input: Three translation responses represented by block keys 1...3 and short Chinese strings.
    /// Output: Incremental state exposes the completed count, progress text, and translated values.
    func testIncrementalResponsesUpdateProgress() {
        var state = DocumentTranslationState()
        state.beginTranslation(totalBlockCount: 3)

        state.translatedBlockArrived(key: TranslationKey.block(line: 1), text: "第一段")
        state.translatedBlockArrived(key: TranslationKey.block(line: 2), text: "第二段")

        XCTAssertEqual(state.completedBlockCount, 2)
        XCTAssertEqual(state.totalBlockCount, 3)
        XCTAssertEqual(state.progressText, "Translating 2/3…")
        XCTAssertEqual(state.translatedBlocks["1"], "第一段")
        XCTAssertEqual(state.translatedBlocks["2"], "第二段")
        XCTAssertTrue(state.isShowingChinese)
    }

    /// Function: DocumentTranslationState.cancel.
    /// Input: An active translation with two expected blocks and one partial response.
    /// Output: Translation activity and partial progress are cleared without an error message.
    func testCancellationClearsActiveTranslation() {
        var state = DocumentTranslationState()
        state.beginTranslation(totalBlockCount: 2)
        state.translatedBlockArrived(key: TranslationKey.block(line: 1), text: "部分结果")

        state.cancel()

        XCTAssertFalse(state.isTranslating)
        XCTAssertFalse(state.isShowingChinese)
        XCTAssertNil(state.progressText)
        XCTAssertEqual(state.completedBlockCount, 0)
        XCTAssertEqual(state.totalBlockCount, 0)
    }

    // MARK: - Table cells

    /// Function: TranslationKey.block and TranslationKey.tableCell.
    /// Input: A block on line 5 and the cells of a table that also starts on line 5.
    /// Output: Cell keys are distinct from each other and from the whole-block key.
    func testTableCellKeysAreDistinctFromBlockKeys() {
        let blockKey = TranslationKey.block(line: 5)
        let header = TranslationKey.tableCell(line: 5, row: 0, column: 0)
        let sameRow = TranslationKey.tableCell(line: 5, row: 0, column: 1)
        let sameColumn = TranslationKey.tableCell(line: 5, row: 1, column: 0)

        XCTAssertEqual(blockKey, "5")
        XCTAssertEqual(header, "5#0#0")
        XCTAssertNotEqual(header, blockKey)
        XCTAssertNotEqual(header, sameRow)
        XCTAssertNotEqual(header, sameColumn)
        XCTAssertNotEqual(sameRow, sameColumn)
    }

    /// Function: DocumentTranslationState.translatedBlockArrived with table-cell keys.
    /// Input: Four cells of a 2x2 table starting on line 3, arriving one at a time.
    /// Output: Every cell is stored under its own key and each counts once toward progress.
    func testTableCellsAreTrackedIndividually() {
        var state = DocumentTranslationState()
        state.beginTranslation(totalBlockCount: 4)

        state.translatedBlockArrived(key: TranslationKey.tableCell(line: 3, row: 0, column: 0), text: "名称")
        state.translatedBlockArrived(key: TranslationKey.tableCell(line: 3, row: 0, column: 1), text: "说明")
        state.translatedBlockArrived(key: TranslationKey.tableCell(line: 3, row: 1, column: 0), text: "第一项")
        state.translatedBlockArrived(key: TranslationKey.tableCell(line: 3, row: 1, column: 1), text: "第一项说明")

        XCTAssertEqual(state.completedBlockCount, 4)
        XCTAssertEqual(state.translatedBlocks["3#0#0"], "名称")
        XCTAssertEqual(state.translatedBlocks["3#0#1"], "说明")
        XCTAssertEqual(state.translatedBlocks["3#1#0"], "第一项")
        XCTAssertEqual(state.translatedBlocks["3#1#1"], "第一项说明")
    }

    /// Function: DocumentTranslationState.translatedBlockArrived.
    /// Input: The same table cell delivered twice (a retry or duplicate response).
    /// Output: The text is overwritten but progress is only counted once.
    func testRepeatedCellResponseDoesNotDoubleCountProgress() {
        var state = DocumentTranslationState()
        state.beginTranslation(totalBlockCount: 2)
        let key = TranslationKey.tableCell(line: 3, row: 1, column: 0)

        state.translatedBlockArrived(key: key, text: "旧值")
        state.translatedBlockArrived(key: key, text: "新值")

        XCTAssertEqual(state.completedBlockCount, 1)
        XCTAssertEqual(state.translatedBlocks[key], "新值")
    }

    #if os(macOS)
    /// Function: TranslationCache.save and TranslationCache.load.
    /// Input: A temporary cache directory, one SHA-like key, and translated block and table-cell values.
    /// Output: A later load returns the same key-to-translation dictionary.
    func testTranslationCacheRoundTrip() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("translation-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = TranslationCache(directory: directory)
        let blocks = [
            TranslationKey.block(line: 1): "第一段",
            TranslationKey.block(line: 4): "第四段",
            TranslationKey.tableCell(line: 6, row: 0, column: 0): "名称",
            TranslationKey.tableCell(line: 6, row: 1, column: 1): "第一项说明"
        ]
        cache.save(blocks, for: "document-key")

        XCTAssertEqual(cache.load(for: "document-key"), blocks)
        XCTAssertNil(cache.load(for: "missing-key"))
    }
    #endif
}

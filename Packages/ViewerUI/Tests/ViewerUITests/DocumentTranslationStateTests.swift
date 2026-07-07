import XCTest
@testable import ViewerUI

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
}

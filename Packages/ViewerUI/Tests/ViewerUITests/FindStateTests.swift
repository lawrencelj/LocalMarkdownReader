// FindStateTests - Functional tests for FindState navigation and the persisted
// find-bar position setting (C1).

@testable import ViewerUI
import XCTest

@MainActor
final class FindStateTests: XCTestCase {
    // MARK: - Navigation

    /// Function: `goToNextMatch()` with wrap.
    /// Input: matchCount = 3, starting currentIndex 0 (Int). Output: 1, 2, 0 (wraps past the end).
    func testNextWrapsAround() {
        let state = FindState()
        state.matchCount = 3
        state.currentIndex = 0

        state.goToNextMatch()
        XCTAssertEqual(state.currentIndex, 1)
        state.goToNextMatch()
        XCTAssertEqual(state.currentIndex, 2)
        state.goToNextMatch()
        XCTAssertEqual(state.currentIndex, 0, "Next past the last match wraps to the first")
    }

    /// Function: `goToPreviousMatch()` with wrap.
    /// Input: matchCount = 3, currentIndex 0. Output: 2 (wraps to the last).
    func testPreviousWrapsAround() {
        let state = FindState()
        state.matchCount = 3
        state.currentIndex = 0

        state.goToPreviousMatch()
        XCTAssertEqual(state.currentIndex, 2, "Previous before the first match wraps to the last")
    }

    /// Function: `goToNextMatch()`/`goToPreviousMatch()` with no matches.
    /// Input: matchCount = 0. Output: currentIndex stays 0 (no crash, no divide-by-zero).
    func testNavigationWithNoMatchesIsSafe() {
        let state = FindState()
        state.matchCount = 0
        state.goToNextMatch()
        state.goToPreviousMatch()
        XCTAssertEqual(state.currentIndex, 0)
    }

    /// Function: `clampCurrentIndex()`.
    /// Input: currentIndex 5 with matchCount shrinking to 2, then to 0.
    /// Output: clamped to 1 (last valid), then 0.
    func testClampCurrentIndex() {
        let state = FindState()
        state.currentIndex = 5

        state.matchCount = 2
        state.clampCurrentIndex()
        XCTAssertEqual(state.currentIndex, 1, "Index clamps to the last valid match")

        state.matchCount = 0
        state.clampCurrentIndex()
        XCTAssertEqual(state.currentIndex, 0, "Index resets to 0 when there are no matches")
    }

    /// Function: `displayIndex` (1-based counter value).
    /// Input: matchCount 0 then 4 with currentIndex 2. Output: 0 then 3.
    func testDisplayIndex() {
        let state = FindState()
        XCTAssertEqual(state.displayIndex, 0, "No matches shows 0")

        state.matchCount = 4
        state.currentIndex = 2
        XCTAssertEqual(state.displayIndex, 3, "displayIndex is 1-based")
    }

    /// Function: `close()`.
    /// Input: a visible state with matches. Output: isVisible false and match bookkeeping reset.
    func testCloseResetsState() {
        let state = FindState()
        state.isVisible = true
        state.query = "x"
        state.matchCount = 5
        state.currentIndex = 3
        state.regexInvalid = true

        state.close()

        XCTAssertFalse(state.isVisible)
        XCTAssertEqual(state.matchCount, 0)
        XCTAssertEqual(state.currentIndex, 0)
        XCTAssertFalse(state.regexInvalid)
    }

    /// Function: `options` computed property.
    /// Input: toggles set. Output: a matching FindOptions value.
    func testOptionsReflectToggles() {
        let state = FindState()
        state.caseSensitive = true
        state.useRegex = true
        XCTAssertEqual(state.options, FindOptions(caseSensitive: true, wholeWord: false, useRegex: true))
    }

    // MARK: - Position setting persistence

    /// Function: `UIState.findBarPosition` load + save round-trip through UserDefaults.
    /// Input: set to `.bottom` on one UIState (String rawValue persisted).
    /// Output: a freshly constructed UIState reads back `.bottom`; default is `.top`.
    func testFindBarPositionPersists() {
        let key = "findBarPosition"
        let saved = UserDefaults.standard.string(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(UIState().findBarPosition, .top, "Default position is Top")

        let writer = UIState()
        writer.findBarPosition = .bottom
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "bottom", "Setting persists to UserDefaults")

        XCTAssertEqual(UIState().findBarPosition, .bottom, "A new session restores the saved position")
    }
}

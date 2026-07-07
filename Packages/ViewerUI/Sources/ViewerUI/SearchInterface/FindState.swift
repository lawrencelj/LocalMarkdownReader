/// FindState - Observable state for a single in-pane find bar.
///
/// One instance backs the source-pane bar and another the content-pane bar; the two
/// are fully independent (separate query and options). The owning pane computes
/// `matchCount`/`regexInvalid` from its own content via `FindMatching` and updates
/// `currentIndex` navigation; the bar UI only reads these and edits the query/options.

import Foundation

/// Where the find bars dock within their pane. A single global setting drives both bars.
public enum FindBarPosition: String, CaseIterable, Sendable {
    case top
    case bottom

    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }
}

/// Which pane a find action targets. Tracks focus so Cmd-F opens the right bar.
public enum FindPane: Sendable {
    case source
    case content
}

@Observable
public final class FindState {
    /// Whether the bar is shown for its pane.
    public var isVisible: Bool = false
    /// The current search text.
    public var query: String = ""
    /// Opt-in case sensitivity (default off → case-insensitive).
    public var caseSensitive: Bool = false
    /// Opt-in whole-word matching (default off; ignored while `useRegex` is on).
    public var wholeWord: Bool = false
    /// Opt-in regular-expression mode (default off).
    public var useRegex: Bool = false

    /// Total matches in the pane for the current query, set by the owning pane.
    public var matchCount: Int = 0
    /// 0-based index of the active match; `0` when there are none.
    public var currentIndex: Int = 0
    /// True when `useRegex` is on and the query does not compile.
    public var regexInvalid: Bool = false

    public init() {}

    /// The matching options expressed by the current toggles.
    public var options: FindOptions {
        FindOptions(caseSensitive: caseSensitive, wholeWord: wholeWord, useRegex: useRegex)
    }

    /// 1-based position shown in the counter (`0` when there are no matches).
    public var displayIndex: Int {
        matchCount == 0 ? 0 : currentIndex + 1
    }

    /// Advances to the next match, wrapping to the first after the last.
    public func goToNextMatch() {
        guard matchCount > 0 else { return }
        currentIndex = (currentIndex + 1) % matchCount
    }

    /// Steps to the previous match, wrapping to the last before the first.
    public func goToPreviousMatch() {
        guard matchCount > 0 else { return }
        currentIndex = (currentIndex - 1 + matchCount) % matchCount
    }

    /// Clamps `currentIndex` into `0..<matchCount` after the match set changes.
    public func clampCurrentIndex() {
        if matchCount == 0 {
            currentIndex = 0
        } else if currentIndex >= matchCount {
            currentIndex = matchCount - 1
        } else if currentIndex < 0 {
            currentIndex = 0
        }
    }

    /// Opens the bar. Kept as a method so callers read as intent, not field-poking.
    public func show() {
        isVisible = true
    }

    /// Closes the bar and drops match bookkeeping (the pane clears its highlights).
    public func close() {
        isVisible = false
        matchCount = 0
        currentIndex = 0
        regexInvalid = false
    }
}

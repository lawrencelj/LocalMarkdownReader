// ContentFindHighlighter - Applies find highlights to a rendered `AttributedString`.
//
// Used by the content pane, where markdown markers are stripped during rendering, so
// matches are found in the *displayed* text (the `AttributedString`'s characters) and the
// highlight background is applied to those ranges. Extracted from the view so the
// index-mapping logic can be unit-tested directly.

import SwiftUI

enum ContentFindHighlighter {
    /// Background for non-current matches.
    static let matchColor = Color.yellow.opacity(0.45)
    /// Background for the current match.
    static let currentColor = Color.orange

    /// Returns `attributed` with find matches highlighted.
    ///
    /// - Parameters:
    ///   - attributed: the rendered leaf text.
    ///   - query: the search text.
    ///   - options: matching options.
    ///   - currentOccurrence: index (within this leaf) of the match to emphasize, or `nil`
    ///     if the current match is in a different leaf.
    /// - Returns: a copy with backgrounds applied (unchanged if the query is empty or has no matches).
    static func highlight(
        _ attributed: AttributedString,
        query: String,
        options: FindOptions,
        currentOccurrence: Int?
    ) -> AttributedString {
        guard !query.isEmpty else { return attributed }

        let plain = String(attributed.characters)
        let ranges = FindMatching.matchRanges(in: plain, query: query, options: options)
        guard !ranges.isEmpty else { return attributed }

        var result = attributed
        for (occurrence, nsRange) in ranges.enumerated() {
            guard let swiftRange = Range(nsRange, in: plain) else { continue }
            let lower = plain.distance(from: plain.startIndex, to: swiftRange.lowerBound)
            let length = plain.distance(from: swiftRange.lowerBound, to: swiftRange.upperBound)
            let start = result.characters.index(result.characters.startIndex, offsetBy: lower)
            let end = result.characters.index(start, offsetBy: length)

            let isCurrent = (occurrence == currentOccurrence)
            result[start ..< end].backgroundColor = isCurrent ? currentColor : matchColor
            if isCurrent {
                result[start ..< end].foregroundColor = Color.black
            }
        }
        return result
    }
}

// FindMatching - Single source of truth for in-pane find-bar matching.
//
// Both the source pane (`NSTextView`) and the content pane (rendered markdown)
// use this engine so their match sets, counts, and navigation stay identical.
//
// Matching is **case-insensitive by default**; callers opt into case sensitivity,
// whole-word boundaries, or regular-expression mode via `FindOptions`. Literal
// (non-regex) queries are matched by escaping the query into a pattern, so a
// single `NSRegularExpression` path serves every mode.

import Foundation

/// User-selectable matching options. All default to the least-restrictive value.
public struct FindOptions: Equatable, Hashable, Sendable {
    /// When `false` (default) matching ignores case.
    public var caseSensitive: Bool
    /// When `true`, a literal query only matches whole words (ignored in regex mode).
    public var wholeWord: Bool
    /// When `true`, the query is treated as a regular expression.
    public var useRegex: Bool

    public init(caseSensitive: Bool = false, wholeWord: Bool = false, useRegex: Bool = false) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.useRegex = useRegex
    }
}

/// Stateless matching helpers shared by both find bars.
public enum FindMatching {
    /// Returns the `NSRange`s of every non-empty match of `query` in `text`.
    ///
    /// - Returns: `[]` for an empty query or an invalid regex (never throws, never crashes).
    ///   Zero-length matches (e.g. regex `a*`) are discarded so highlighting can't loop forever.
    public static func matchRanges(in text: String, query: String, options: FindOptions) -> [NSRange] {
        guard !query.isEmpty, let regex = makeRegex(query: query, options: options) else { return [] }
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: full)
            .map(\.range)
            .filter { $0.length > 0 }
    }

    /// Convenience wrapper returning `String.Index` ranges for SwiftUI/`AttributedString` callers.
    public static func matches(in text: String, query: String, options: FindOptions) -> [Range<String.Index>] {
        matchRanges(in: text, query: query, options: options).compactMap { Range($0, in: text) }
    }

    /// Reports whether `query` is a usable pattern.
    ///
    /// Always `true` for literal mode or an empty query; in regex mode it reflects
    /// whether the pattern compiles. Drives the bar's "Invalid regex" indicator.
    public static func isValidRegex(_ query: String, options: FindOptions) -> Bool {
        guard options.useRegex, !query.isEmpty else { return true }
        return (try? NSRegularExpression(pattern: query)) != nil
    }

    // MARK: - Replacement

    /// Returns `text` with the single match at `index` replaced by `replacement`
    /// (inserted verbatim — no regex templating), or `nil` if there is no match at
    /// that index. Uses the same match set as `matchRanges`, so the index lines up
    /// with the find bar's current-match counter.
    public static func replacingMatch(
        in text: String,
        query: String,
        options: FindOptions,
        with replacement: String,
        at index: Int
    ) -> String? {
        let ranges = matchRanges(in: text, query: query, options: options)
        guard index >= 0, index < ranges.count else { return nil }
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: ranges[index], with: replacement)
        return mutable as String
    }

    /// Returns `text` with every match replaced by `replacement` (verbatim), and the
    /// number of matches replaced. Replacements are applied back-to-front so earlier
    /// match ranges stay valid; overlapping is not possible since matches are the
    /// non-overlapping ranges from `matchRanges`.
    public static func replacingAllMatches(
        in text: String,
        query: String,
        options: FindOptions,
        with replacement: String
    ) -> (result: String, count: Int) {
        let ranges = matchRanges(in: text, query: query, options: options)
        guard !ranges.isEmpty else { return (text, 0) }
        let mutable = NSMutableString(string: text)
        for range in ranges.reversed() {
            mutable.replaceCharacters(in: range, with: replacement)
        }
        return (mutable as String, ranges.count)
    }

    // MARK: - Private

    /// Builds the regex that expresses `query` under `options`, or `nil` if it does not compile.
    private static func makeRegex(query: String, options: FindOptions) -> NSRegularExpression? {
        let pattern: String
        if options.useRegex {
            pattern = query
        } else {
            let escaped = NSRegularExpression.escapedPattern(for: query)
            pattern = options.wholeWord ? "\\b\(escaped)\\b" : escaped
        }

        var regexOptions: NSRegularExpression.Options = []
        if !options.caseSensitive {
            regexOptions.insert(.caseInsensitive)
        }
        return try? NSRegularExpression(pattern: pattern, options: regexOptions)
    }
}

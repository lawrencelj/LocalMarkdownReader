/// ContentHighlighter - Text highlighting for search results
///
/// Provides efficient text highlighting capabilities for search matches
/// without disrupting layout performance.

@preconcurrency import Foundation

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformColor = UIColor
#endif

/// Content highlighter for search results - memory optimized
public struct ContentHighlighter: Sendable {
    /// Highlighting configuration
    public struct Configuration: Sendable {
        public let highlightColor: PlatformColor
        public let currentMatchColor: PlatformColor
        public let textColor: PlatformColor
        public let cornerRadius: CGFloat
        public let padding: CGFloat

        public init(
            highlightColor: PlatformColor = PlatformColor.yellow.withAlphaComponent(0.3),
            currentMatchColor: PlatformColor = PlatformColor.orange.withAlphaComponent(0.6),
            textColor: PlatformColor = PlatformColor.black,
            cornerRadius: CGFloat = 2.0,
            padding: CGFloat = 1.0
        ) {
            self.highlightColor = highlightColor
            self.currentMatchColor = currentMatchColor
            self.textColor = textColor
            self.cornerRadius = cornerRadius
            self.padding = padding
        }

        public static let `default` = Configuration()
    }

    private let configuration: Configuration
    /// Memory-efficient attributed string cache
    @MainActor private static var highlightCache: [String: NSMutableAttributedString] = [:]
    private static let cacheLimit = 50  // Limit cache size to prevent memory bloat

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Highlighting Interface

    /// Highlight matches in attributed string
    public func highlightMatches(
        in content: NSAttributedString,
        query: String,
        currentMatch: NSRange? = nil
    ) -> NSAttributedString {
        guard !query.isEmpty else { return content }

        let mutableContent = NSMutableAttributedString(attributedString: content)
        let contentString = content.string

        // Find all matches
        let matches = findMatches(in: contentString, query: query)

        // Apply highlighting
        for match in matches {
            let isCurrentMatch = currentMatch.map { NSEqualRanges($0, match) } ?? false
            applyHighlighting(to: mutableContent, range: match, isCurrent: isCurrentMatch)
        }

        return mutableContent
    }

    /// Highlight specific ranges
    public func highlightRanges(
        in content: NSAttributedString,
        ranges: [NSRange],
        currentRange: NSRange? = nil
    ) -> NSAttributedString {
        let mutableContent = NSMutableAttributedString(attributedString: content)

        for range in ranges {
            let isCurrent = currentRange.map { NSEqualRanges($0, range) } ?? false
            applyHighlighting(to: mutableContent, range: range, isCurrent: isCurrent)
        }

        return mutableContent
    }

    /// Remove all highlighting
    public func removeHighlighting(from content: NSAttributedString) -> NSAttributedString {
        let mutableContent = NSMutableAttributedString(attributedString: content)
        let fullRange = NSRange(location: 0, length: content.length)

        // Remove highlighting attributes
        mutableContent.removeAttribute(.backgroundColor, range: fullRange)
        mutableContent.removeAttribute(.foregroundColor, range: fullRange)

        return mutableContent
    }

    /// Count matches in content
    public func countMatches(in content: String, query: String) -> Int {
        findMatches(in: content, query: query).count
    }

    // MARK: - Advanced Highlighting

    /// Highlight with custom colors
    public func highlightMatches(
        in content: NSAttributedString,
        query: String,
        highlightColor: PlatformColor,
        textColor: PlatformColor
    ) -> NSAttributedString {
        guard !query.isEmpty else { return content }

        let mutableContent = NSMutableAttributedString(attributedString: content)
        let contentString = content.string

        let matches = findMatches(in: contentString, query: query)

        for match in matches {
            mutableContent.addAttribute(.backgroundColor, value: highlightColor, range: match)
            mutableContent.addAttribute(.foregroundColor, value: textColor, range: match)
        }

        return mutableContent
    }

    /// Highlight with pattern matching
    public func highlightPattern(
        in content: NSAttributedString,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) throws -> NSAttributedString {
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        let mutableContent = NSMutableAttributedString(attributedString: content)
        let fullRange = NSRange(location: 0, length: content.length)

        let matches = regex.matches(in: content.string, options: [], range: fullRange)

        for match in matches {
            applyHighlighting(to: mutableContent, range: match.range, isCurrent: false)
        }

        return mutableContent
    }

    // MARK: - Private Implementation

    private func findMatches(in content: String, query: String) -> [NSRange] {
        var matches: [NSRange] = []
        let contentString = content as NSString
        let queryLength = query.count

        guard queryLength > 0 else { return matches }

        var searchRange = NSRange(location: 0, length: contentString.length)

        while searchRange.length > 0 {
            let foundRange = contentString.range(
                of: query,
                options: [.caseInsensitive],
                range: searchRange
            )

            if foundRange.location == NSNotFound {
                break
            }

            matches.append(foundRange)

            // Update search range to continue after this match
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(
                location: nextLocation,
                length: contentString.length - nextLocation
            )
        }

        return matches
    }

    private func applyHighlighting(
        to content: NSMutableAttributedString,
        range: NSRange,
        isCurrent: Bool
    ) {
        let highlightColor = isCurrent ? configuration.currentMatchColor : configuration.highlightColor

        content.addAttribute(.backgroundColor, value: highlightColor, range: range)
        content.addAttribute(.foregroundColor, value: configuration.textColor, range: range)

        // Add subtle border effect (if supported)
        #if os(macOS)
        if isCurrent {
            content.addAttribute(.strokeWidth, value: 1.0, range: range)
            content.addAttribute(.strokeColor, value: configuration.currentMatchColor.withAlphaComponent(0.8), range: range)
        }
        #endif
    }
}

// MARK: - Highlighting Extensions

extension ContentHighlighter {
    /// Create highlighted snippet for search preview
    public func createHighlightedSnippet(
        from content: String,
        query: String,
        contextLength: Int = 100
    ) -> NSAttributedString {
        let matches = findMatches(in: content, query: query)

        guard let firstMatch = matches.first else {
            // No matches, return beginning of content
            let snippet = String(content.prefix(contextLength))
            return NSAttributedString(string: snippet)
        }

        // Extract context around first match
        let matchStart = firstMatch.location
        let contextStart = max(0, matchStart - contextLength / 2)
        let contextEnd = min(content.count, matchStart + firstMatch.length + contextLength / 2)

        let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
        let snippet = (content as NSString).substring(with: contextRange)

        // Create attributed string and highlight matches within snippet
        let attributedSnippet = NSMutableAttributedString(string: snippet)

        // Adjust match ranges to snippet coordinates
        for match in matches {
            if match.location >= contextStart && match.location < contextEnd {
                let adjustedRange = NSRange(
                    location: match.location - contextStart,
                    length: min(match.length, contextEnd - match.location)
                )

                if adjustedRange.location + adjustedRange.length <= attributedSnippet.length {
                    applyHighlighting(to: attributedSnippet, range: adjustedRange, isCurrent: false)
                }
            }
        }

        return attributedSnippet
    }

    /// Apply highlighting to search result list - memory optimized with lazy highlighting
    public func highlightSearchResults(_ results: [SearchResult], query: String) -> [LazyHighlightedSearchResult] {
        results.map { result in
            LazyHighlightedSearchResult(
                result: result,
                query: query,
                highlighter: self
            )
        }
    }
}

// MARK: - Highlighted Search Result

/// Search result with highlighting applied
public struct HighlightedSearchResult: Identifiable {
    public let id: UUID
    public let result: SearchResult
    public let highlightedText: NSAttributedString
    public let highlightedContext: NSAttributedString

    public init(
        result: SearchResult,
        highlightedText: NSAttributedString,
        highlightedContext: NSAttributedString
    ) {
        self.id = result.id
        self.result = result
        self.highlightedText = highlightedText
        self.highlightedContext = highlightedContext
    }
}

/// Lazy highlighted search result - memory efficient
public struct LazyHighlightedSearchResult: Identifiable {
    public let id: UUID
    public let result: SearchResult
    private let query: String
    private let highlighter: ContentHighlighter

    /// Cached highlighted content - only created when accessed
    private var _highlightedText: NSAttributedString?
    private var _highlightedContext: NSAttributedString?

    public init(
        result: SearchResult,
        query: String,
        highlighter: ContentHighlighter
    ) {
        self.id = result.id
        self.result = result
        self.query = query
        self.highlighter = highlighter
        self._highlightedText = nil
        self._highlightedContext = nil
    }

    /// Lazily computed highlighted text
    public var highlightedText: NSAttributedString {
        mutating get {
            if let cached = _highlightedText {
                return cached
            }
            let highlighted = highlighter.highlightMatches(
                in: NSAttributedString(string: result.text),
                query: query
            )
            _highlightedText = highlighted
            return highlighted
        }
    }

    /// Lazily computed highlighted context
    public var highlightedContext: NSAttributedString {
        mutating get {
            if let cached = _highlightedContext {
                return cached
            }
            let highlighted = highlighter.highlightMatches(
                in: NSAttributedString(string: result.context),
                query: query
            )
            _highlightedContext = highlighted
            return highlighted
        }
    }
}

// MARK: - Performance Optimizations

extension ContentHighlighter {
    /// Batch highlight multiple contents efficiently - memory optimized
    @MainActor public func batchHighlight(
        contents: [(NSAttributedString, String)],
        configuration: Configuration? = nil,
        batchSize: Int = 10  // Process in smaller batches to prevent memory spikes
    ) -> [NSAttributedString] {
        let config = configuration ?? self.configuration
        let highlighter = ContentHighlighter(configuration: config)
        var results: [NSAttributedString] = []

        // Process in batches to prevent memory spikes
        for i in stride(from: 0, to: contents.count, by: batchSize) {
            let endIndex = min(i + batchSize, contents.count)
            let batch = Array(contents[i..<endIndex])

            let batchResults = batch.map { content, query in
                highlighter.highlightMatches(in: content, query: query)
            }

            results.append(contentsOf: batchResults)

            // Clear cache periodically to prevent memory buildup
            if ContentHighlighter.highlightCache.count > ContentHighlighter.cacheLimit {
                ContentHighlighter.clearCache()
            }
        }

        return results
    }

    /// Clear highlighting cache to free memory
    @MainActor public static func clearCache() {
        highlightCache.removeAll()
    }

    /// Get cache statistics for monitoring
    @MainActor public static func getCacheStats() -> (count: Int, limit: Int) {
        (count: highlightCache.count, limit: cacheLimit)
    }

    /// Asynchronous highlighting for large content
    nonisolated public func highlightMatchesAsync(
        in content: NSAttributedString,
        query: String
    ) async -> NSAttributedString {
        await Task {
            self.highlightMatches(in: content, query: query)
        }.value
    }
}

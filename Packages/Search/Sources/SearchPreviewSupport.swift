/// SearchPreviewSupport - Preview data for Search types
///
/// Provides preview instances of SearchResult and OutlineItem
/// for SwiftUI previews and development.

import Foundation

// MARK: - OutlineItem Preview Support

extension OutlineItem {
    /// Preview level 1 heading
    public static var previewLevel1: OutlineItem {
        OutlineItem(
            level: 1,
            title: "Introduction",
            range: NSRange(location: 0, length: 12),
            position: 0,
            children: [
                OutlineItem(level: 2, title: "Getting Started", range: NSRange(location: 50, length: 15), position: 40),
                OutlineItem(level: 2, title: "Prerequisites", range: NSRange(location: 100, length: 13), position: 80)
            ]
        )
    }

    /// Preview with specific level
    public static func preview(level: Int) -> OutlineItem {
        OutlineItem(
            level: level,
            title: "Heading Level \(level)",
            range: NSRange(location: level * 50, length: 15),
            position: CGFloat(level * 40)
        )
    }

    /// Word count for preview (computed from title)
    public var wordCount: Int {
        title.components(separatedBy: .whitespaces).count * 50
    }
}

// MARK: - SearchResult Preview Support

extension SearchResult {
    /// Preview exact match result
    public static var previewExact: SearchResult {
        SearchResult(
            documentId: UUID(),
            text: "markdown",
            context: "This is a sample markdown document with rich formatting.",
            range: NSRange(location: 20, length: 8),
            lineNumber: 5,
            columnNumber: 20,
            relevanceScore: 0.95,
            matchType: .content,
            headingContext: "Introduction"
        )
    }

    /// Preview partial match result
    public static var previewPartial: SearchResult {
        SearchResult(
            documentId: UUID(),
            text: "mark",
            context: "The markdown format is widely used for documentation.",
            range: NSRange(location: 4, length: 4),
            lineNumber: 12,
            columnNumber: 4,
            relevanceScore: 0.7,
            matchType: .heading,
            headingContext: "Features"
        )
    }

    /// Preview fuzzy match result
    public static var previewFuzzy: SearchResult {
        SearchResult(
            documentId: UUID(),
            text: "formatting",
            context: "Advanced formatting options include tables and code blocks.",
            range: NSRange(location: 9, length: 10),
            lineNumber: 25,
            columnNumber: 9,
            relevanceScore: 0.5,
            matchType: .content,
            headingContext: "Advanced Features"
        )
    }

    // MARK: - Properties for SearchResultView

    /// The matched text content
    public var matchedText: String {
        text
    }

    /// Surrounding context for display
    public var surroundingContext: String {
        context
    }

    /// Containing heading for context
    public var containingHeading: String? {
        headingContext
    }

    /// Match type for display categorization
    public var matchTypeDisplay: SearchResultMatchType {
        switch matchType {
        case .heading: return .exactMatch
        case .content: return .partialMatch
        case .codeBlock: return .regexMatch
        case .link: return .fuzzyMatch
        case .emphasis: return .partialMatch
        }
    }
}

/// Match type for UI display purposes
public enum SearchResultMatchType {
    case exactMatch
    case partialMatch
    case fuzzyMatch
    case regexMatch
}

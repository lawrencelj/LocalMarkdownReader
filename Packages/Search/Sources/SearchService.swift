/// SearchService - Main search service interface
///
/// Provides the primary interface for search operations expected by the
/// frontend AppStateCoordinator, with <100ms response time optimization.

import Foundation
import MarkdownCore
import OrderedCollections

/// Main search service interface expected by frontend
@MainActor
public class SearchService: ObservableObject {
    private let searchEngine: SearchEngine
    private let performanceMonitor: SearchPerformanceMonitor

    public init() {
        self.searchEngine = SearchEngine()
        self.performanceMonitor = SearchPerformanceMonitor.shared
    }

    // MARK: - Frontend Interface Methods

    /// Index document for searching
    public func indexDocument(_ document: DocumentModel) async {
        await performanceMonitor.trackNonThrowingOperation("index_document") {
            await searchEngine.indexDocument(document)
        }
    }

    /// Search content with query
    public func searchContent(_ query: String) async -> [SearchResult] {
        return await performanceMonitor.trackNonThrowingOperation("search_content") {
            await searchEngine.search(query: query)
        }
    }

    /// Highlight search matches in content
    @MainActor public func highlightMatches(_ content: NSAttributedString, query: String) async -> NSAttributedString {
        return await performanceMonitor.trackNonThrowingOperation("highlight_matches") {
            let highlighter = ContentHighlighter()
            return highlighter.highlightMatches(in: content, query: query)
        }
    }

    // MARK: - Extended Search Interface

    /// Advanced search with options
    public func search(
        _ query: String,
        options: SearchOptions = SearchOptions(),
        in document: DocumentModel? = nil
    ) async throws -> [SearchResult] {
        return try await performanceMonitor.trackOperation("advanced_search") {
            try await searchEngine.advancedSearch(
                query: query,
                options: options,
                document: document
            )
        }
    }

    /// Generate document outline
    public func generateOutline(for document: DocumentModel) async throws -> [OutlineItem] {
        return try await performanceMonitor.trackOperation("generate_outline") {
            try await searchEngine.generateOutline(from: document)
        }
    }

    /// Clear search index
    public func clearIndex() async {
        await searchEngine.clearIndex()
    }

    /// Get search statistics
    public func getSearchStatistics() async -> SearchStatistics {
        return await searchEngine.getStatistics()
    }

    /// Update search index for document changes
    public func updateDocumentIndex(_ document: DocumentModel) async {
        await performanceMonitor.trackNonThrowingOperation("update_index") {
            await searchEngine.updateDocument(document)
        }
    }

    /// Remove document from index
    public func removeFromIndex(_ documentId: UUID) async {
        await searchEngine.removeDocument(documentId)
    }
}

// MARK: - Search Options

/// Search configuration options
public struct SearchOptions: Sendable {
    public let caseSensitive: Bool
    public let wholeWords: Bool
    public let useRegex: Bool
    public let searchHeadingsOnly: Bool
    public let maxResults: Int
    public let includeContext: Bool
    public let contextLength: Int

    public init(
        caseSensitive: Bool = false,
        wholeWords: Bool = false,
        useRegex: Bool = false,
        searchHeadingsOnly: Bool = false,
        maxResults: Int = 100,
        includeContext: Bool = true,
        contextLength: Int = 50
    ) {
        self.caseSensitive = caseSensitive
        self.wholeWords = wholeWords
        self.useRegex = useRegex
        self.searchHeadingsOnly = searchHeadingsOnly
        self.maxResults = maxResults
        self.includeContext = includeContext
        self.contextLength = contextLength
    }

    /// Default search options
    public static let `default` = SearchOptions()

    /// Heading-only search
    public static let headingsOnly = SearchOptions(searchHeadingsOnly: true)

    /// Case-sensitive search
    public static let caseSensitive = SearchOptions(caseSensitive: true)

    /// Whole words search
    public static let wholeWords = SearchOptions(wholeWords: true)
}

// MARK: - Search Result

/// Search result with relevance scoring
public struct SearchResult: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let documentId: UUID
    public let text: String
    public let context: String
    public let range: NSRange
    public let attributedRange: NSRange?
    public let lineNumber: Int
    public let columnNumber: Int
    public let relevanceScore: Double
    public let matchType: MatchType
    public let headingContext: String?

    public init(
        documentId: UUID,
        text: String,
        context: String,
        range: NSRange,
        attributedRange: NSRange? = nil,
        lineNumber: Int,
        columnNumber: Int,
        relevanceScore: Double,
        matchType: MatchType = .content,
        headingContext: String? = nil
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.text = text
        self.context = context
        self.range = range
        self.attributedRange = attributedRange
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.relevanceScore = relevanceScore
        self.matchType = matchType
        self.headingContext = headingContext
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// Type of search match
public enum MatchType: String, Sendable, CaseIterable {
    case heading = "heading"
    case content = "content"
    case codeBlock = "code"
    case link = "link"
    case emphasis = "emphasis"
}

// MARK: - Outline Item

/// Document outline item for navigation
public struct OutlineItem: Sendable, Identifiable, Hashable {
    public let id: String
    public let level: Int
    public let title: String
    public let range: NSRange
    public let position: CGFloat
    public let children: [OutlineItem]

    /// Word count for this section (computed property)
    public var wordCount: Int {
        // Simplified word count calculation
        return title.split(separator: " ").count * 10 // Placeholder
    }

    public init(
        level: Int,
        title: String,
        range: NSRange,
        position: CGFloat = 0,
        children: [OutlineItem] = []
    ) {
        self.id = UUID().uuidString
        self.level = level
        self.title = title
        self.range = range
        self.position = position
        self.children = children
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: OutlineItem, rhs: OutlineItem) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Preview Methods

    /// Preview outline item for level 1
    public static var previewLevel1: OutlineItem {
        return OutlineItem(
            level: 1,
            title: "Introduction",
            range: NSRange(location: 0, length: 12),
            position: 0,
            children: [
                OutlineItem(level: 2, title: "Getting Started", range: NSRange(location: 15, length: 15)),
                OutlineItem(level: 2, title: "Basic Usage", range: NSRange(location: 35, length: 11))
            ]
        )
    }

    /// Preview outline item for specified level
    public static func preview(level: Int) -> OutlineItem {
        let titles = [
            "Document Title",
            "Section Heading",
            "Subsection",
            "Details",
            "Notes",
            "References"
        ]

        let title = titles[min(level - 1, titles.count - 1)]
        return OutlineItem(
            level: level,
            title: "\(title) Level \(level)",
            range: NSRange(location: level * 20, length: title.count)
        )
    }
}

// MARK: - Search Statistics

/// Search performance and usage statistics
public struct SearchStatistics: Sendable {
    public let documentsIndexed: Int
    public let totalSearchTerms: Int
    public let averageSearchTime: TimeInterval
    public let indexSize: Int
    public let lastIndexUpdate: Date

    public init(
        documentsIndexed: Int,
        totalSearchTerms: Int,
        averageSearchTime: TimeInterval,
        indexSize: Int,
        lastIndexUpdate: Date
    ) {
        self.documentsIndexed = documentsIndexed
        self.totalSearchTerms = totalSearchTerms
        self.averageSearchTime = averageSearchTime
        self.indexSize = indexSize
        self.lastIndexUpdate = lastIndexUpdate
    }
}

// MARK: - Preview Support

extension SearchService {
    /// Create a preview service for development
    public static var preview: SearchService {
        return SearchService()
    }
}

extension SearchResult {
    /// Create preview search results
    public static var previewResults: [SearchResult] {
        return [
            SearchResult(
                documentId: UUID(),
                text: "Example search result",
                context: "This is an example search result with some context around the match.",
                range: NSRange(location: 20, length: 6),
                lineNumber: 1,
                columnNumber: 20,
                relevanceScore: 0.95,
                matchType: .content,
                headingContext: "Introduction"
            ),
            SearchResult(
                documentId: UUID(),
                text: "Another match",
                context: "Another search match found in the document with different relevance.",
                range: NSRange(location: 45, length: 5),
                lineNumber: 3,
                columnNumber: 10,
                relevanceScore: 0.75,
                matchType: .heading,
                headingContext: "Features"
            )
        ]
    }
}
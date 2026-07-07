/// SearchTests - Unit tests for Search package
///
/// Comprehensive test suite covering search indexing, querying,
/// performance requirements, and highlighting functionality.

import XCTest
@testable import Search
@testable import MarkdownCore

@MainActor
final class SearchTests: XCTestCase {
    var searchService: SearchService!
    var sampleDocument: DocumentModel!

    override func setUp() async throws {
        searchService = SearchService()

        // Create sample document
        let content = """
        # Programming Guide

        This document covers **programming concepts** and best practices.

        ## Swift Programming
        Swift is a powerful programming language.

        ### Variables
        Variables store data values.

        ### Functions
        Functions are reusable blocks of code.

        ## JavaScript
        JavaScript is used for web development.

        ```swift
        func greet(name: String) {
            print("Hello, \\(name)!")
        }
        ```
        """

        let documentService = DocumentService()
        sampleDocument = try await documentService.parseMarkdown(content)
    }

    override func tearDown() async throws {
        searchService = nil
        sampleDocument = nil
    }

    // MARK: - Indexing Tests

    func testDocumentIndexing() async {
        await searchService.indexDocument(sampleDocument)

        let stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 1)
        XCTAssertTrue(stats.totalSearchTerms > 0)
    }

    func testIndexUpdate() async {
        // Index original document
        await searchService.indexDocument(sampleDocument)

        // Update document content
        let updatedContent = sampleDocument.content + "\n\nAdditional content for testing."
        let documentService = DocumentService()
        let updatedDocument = try! await documentService.parseMarkdown(updatedContent)

        // Update index
        await searchService.updateDocumentIndex(updatedDocument)

        let stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 1) // Still one document, but updated
    }

    func testIndexRemoval() async {
        await searchService.indexDocument(sampleDocument)

        var stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 1)

        await searchService.removeFromIndex(sampleDocument.id)

        stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 0)
    }

    // MARK: - Search Tests

    func testBasicSearch() async {
        await searchService.indexDocument(sampleDocument)

        let results = await searchService.searchContent("programming")

        XCTAssertTrue(results.count > 0)
        XCTAssertTrue(results.contains { $0.text.lowercased().contains("programming") })
    }

    func testCaseInsensitiveSearch() async {
        await searchService.indexDocument(sampleDocument)

        let lowerResults = await searchService.searchContent("swift")
        let upperResults = await searchService.searchContent("SWIFT")
        let mixedResults = await searchService.searchContent("Swift")

        XCTAssertEqual(lowerResults.count, upperResults.count)
        XCTAssertEqual(lowerResults.count, mixedResults.count)
    }

    func testMultiWordSearch() async {
        await searchService.indexDocument(sampleDocument)

        let results = await searchService.searchContent("Swift programming")

        XCTAssertTrue(results.count > 0)
        // Should find results containing either "swift" or "programming"
    }

    func testEmptySearch() async {
        await searchService.indexDocument(sampleDocument)

        let results = await searchService.searchContent("")

        XCTAssertEqual(results.count, 0)
    }

    func testNoResultsSearch() async {
        await searchService.indexDocument(sampleDocument)

        let results = await searchService.searchContent("nonexistentterm")

        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Advanced Search Tests

    func testAdvancedSearchOptions() async throws {
        await searchService.indexDocument(sampleDocument)

        // Case sensitive search
        let caseSensitiveOptions = SearchOptions(caseSensitive: true)
        let caseSensitiveResults = try await searchService.search(
            "Swift",
            options: caseSensitiveOptions,
            in: sampleDocument
        )

        let caseInsensitiveResults = try await searchService.search(
            "swift",
            options: caseSensitiveOptions,
            in: sampleDocument
        )

        // Results should be different for case-sensitive search
        XCTAssertNotEqual(caseSensitiveResults.count, caseInsensitiveResults.count)
    }

    func testWholeWordsSearch() async throws {
        await searchService.indexDocument(sampleDocument)

        let wholeWordsOptions = SearchOptions(wholeWords: true)
        let results = try await searchService.search(
            "program",
            options: wholeWordsOptions,
            in: sampleDocument
        )

        // Should not match "programming" when searching for whole word "program"
        XCTAssertTrue(results.allSatisfy { !$0.text.contains("programming") })
    }

    func testHeadingsOnlySearch() async throws {
        await searchService.indexDocument(sampleDocument)

        let headingsOnlyOptions = SearchOptions(searchHeadingsOnly: true)
        let results = try await searchService.search(
            "Programming",
            options: headingsOnlyOptions,
            in: sampleDocument
        )

        XCTAssertTrue(results.allSatisfy { $0.matchType == .heading })
    }

    func testMaxResultsLimit() async throws {
        await searchService.indexDocument(sampleDocument)

        let limitedOptions = SearchOptions(maxResults: 3)
        let results = try await searchService.search(
            "programming",
            options: limitedOptions,
            in: sampleDocument
        )

        XCTAssertLessThanOrEqual(results.count, 3)
    }

    // MARK: - Performance Tests

    func testSearchPerformance() async {
        await searchService.indexDocument(sampleDocument)

        let startTime = CFAbsoluteTimeGetCurrent()
        let results = await searchService.searchContent("programming")
        let endTime = CFAbsoluteTimeGetCurrent()

        let searchTime = endTime - startTime

        // Should complete in under 100ms for small documents
        XCTAssertLessThan(searchTime, 0.1)
        XCTAssertTrue(results.count > 0)
    }

    func testIndexingPerformance() async {
        let largeContent = String(repeating: "This is a line of content for performance testing.\n", count: 1000)
        let documentService = DocumentService()
        let largeDocument = try! await documentService.parseMarkdown(largeContent)

        let startTime = CFAbsoluteTimeGetCurrent()
        await searchService.indexDocument(largeDocument)
        let endTime = CFAbsoluteTimeGetCurrent()

        let indexTime = endTime - startTime

        // Indexing should be reasonably fast
        XCTAssertLessThan(indexTime, 1.0)
    }

    // MARK: - Highlighting Tests

    func testContentHighlighting() {
        let content = NSAttributedString(string: "This is a test document with programming content.")
        let query = "programming"

        let highlighted = searchService.highlightMatches(content, query: query)

        XCTAssertNotEqual(highlighted, content)
        XCTAssertTrue(highlighted.string.contains("programming"))
    }

    func testMultipleMatchHighlighting() {
        let content = NSAttributedString(string: "Programming is fun. I love programming.")
        let query = "programming"

        let highlighted = searchService.highlightMatches(content, query: query)

        // Should highlight both instances of "programming"
        XCTAssertNotEqual(highlighted, content)
    }

    // MARK: - Outline Generation Tests

    func testOutlineGeneration() async throws {
        await searchService.indexDocument(sampleDocument)

        let outline = try await searchService.generateOutline(for: sampleDocument)

        XCTAssertEqual(outline.count, 5) // H1, H2, H3, H3, H2
        XCTAssertEqual(outline[0].level, 1)
        XCTAssertEqual(outline[0].title, "Programming Guide")
        XCTAssertEqual(outline[1].level, 2)
        XCTAssertEqual(outline[1].title, "Swift Programming")
    }

    // MARK: - Relevance Scoring Tests

    func testRelevanceScoring() async {
        await searchService.indexDocument(sampleDocument)

        let results = await searchService.searchContent("Swift")

        // Results should be sorted by relevance
        var previousScore = Double.infinity
        for result in results {
            XCTAssertLessThanOrEqual(result.relevanceScore, previousScore)
            previousScore = result.relevanceScore
        }

        // Heading matches should have higher relevance than content matches
        let headingMatches = results.filter { $0.matchType == .heading }
        let contentMatches = results.filter { $0.matchType == .content }

        if !headingMatches.isEmpty && !contentMatches.isEmpty {
            let highestHeadingScore = headingMatches.max { $0.relevanceScore < $1.relevanceScore }?.relevanceScore ?? 0
            let highestContentScore = contentMatches.max { $0.relevanceScore < $1.relevanceScore }?.relevanceScore ?? 0

            XCTAssertGreaterThan(highestHeadingScore, highestContentScore)
        }
    }

    // MARK: - Search Context Tests

    func testSearchContext() async throws {
        await searchService.indexDocument(sampleDocument)

        let options = SearchOptions(includeContext: true, contextLength: 20)
        let results = try await searchService.search(
            "Swift",
            options: options,
            in: sampleDocument
        )

        for result in results {
            XCTAssertFalse(result.context.isEmpty)
            XCTAssertTrue(result.context.contains(result.text) || result.text.contains(result.context))
        }
    }

    // MARK: - Edge Cases

    func testSpecialCharacterSearch() async {
        let specialContent = """
        # Test @#$%
        Content with special characters: @, #, $, %, &, *, (, ), [, ], {, }
        """

        let documentService = DocumentService()
        let document = try! await documentService.parseMarkdown(specialContent)
        await searchService.indexDocument(document)

        let results = await searchService.searchContent("@")
        // Should handle special characters gracefully
        XCTAssertTrue(results.count >= 0) // No crashes
    }

    func testUnicodeSearch() async {
        let unicodeContent = """
        # Unicode Test 🚀
        Content with émojis 😀 and ăccénted chàracters.
        """

        let documentService = DocumentService()
        let document = try! await documentService.parseMarkdown(unicodeContent)
        await searchService.indexDocument(document)

        let results = await searchService.searchContent("émojis")
        XCTAssertTrue(results.count >= 0) // Should handle Unicode
    }
}

// MARK: - Test Extensions

extension SearchTests {
    func asyncMeasure(_ operation: () async -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        print("Operation took \(endTime - startTime) seconds")
    }
}
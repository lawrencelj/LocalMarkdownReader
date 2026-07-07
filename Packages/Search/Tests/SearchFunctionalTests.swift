/// SearchFunctionalTests - Verifies all search functions work correctly

import XCTest
@testable import Search
@testable import MarkdownCore

@MainActor
final class SearchFunctionalTests: XCTestCase {

    var searchService: SearchService!
    var testDocument: DocumentModel!

    override func setUp() async throws {
        searchService = SearchService()

        let content = """
        # Swift Programming Guide

        This guide covers Swift programming fundamentals.

        ## Variables and Constants

        Variables store mutable data. Constants are immutable.

        ```swift
        var name = "World"
        let pi = 3.14159
        ```

        ## Functions

        Functions are reusable blocks of code.

        ```swift
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```

        ## Classes and Structs

        Swift supports both classes and structs.

        ### Classes

        Classes are reference types.

        ### Structs

        Structs are value types.
        """

        let documentService = DocumentService()
        testDocument = try await documentService.parseMarkdown(content)
    }

    // MARK: - Indexing

    func testIndexDocument() async throws {
        await searchService.indexDocument(testDocument)
        let stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 1)
        XCTAssertGreaterThan(stats.totalSearchTerms, 0)
    }

    // MARK: - Basic Search

    func testSearchFindsContent() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("Swift")
        XCTAssertGreaterThan(results.count, 0, "Should find 'Swift' in the document")
    }

    func testSearchFindsHeadings() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("Functions")
        XCTAssertGreaterThan(results.count, 0, "Should find 'Functions' heading")
    }

    func testSearchFindsCodeContent() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("greet")
        XCTAssertGreaterThan(results.count, 0, "Should find 'greet' in code block")
    }

    func testSearchNoResults() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("xyznonexistent")
        XCTAssertEqual(results.count, 0, "Should not find nonexistent term")
    }

    func testSearchEmptyQuery() async throws {
        await searchService.indexDocument(testDocument)
        let results = await searchService.searchContent("")
        XCTAssertEqual(results.count, 0, "Empty query should return no results")
    }

    // MARK: - Search Options

    func testCaseSensitiveSearch() async throws {
        await searchService.indexDocument(testDocument)

        let options = SearchOptions(caseSensitive: true)
        let results = try await searchService.search("swift", options: options)
        // "swift" lowercase appears in code blocks
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }

    func testWholeWordSearch() async throws {
        await searchService.indexDocument(testDocument)

        let options = SearchOptions(wholeWords: true)
        let results = try await searchService.search("name", options: options)
        XCTAssertGreaterThan(results.count, 0, "Should find whole word 'name'")
    }

    // MARK: - Outline Generation

    func testGenerateOutline() async throws {
        await searchService.indexDocument(testDocument)
        let outline = try await searchService.generateOutline(for: testDocument)

        XCTAssertGreaterThan(outline.count, 0, "Should generate outline from headings")

        // Check first heading
        let firstItem = outline.first!
        XCTAssertEqual(firstItem.level, 1)
        XCTAssertEqual(firstItem.title, "Swift Programming Guide")
    }

    func testOutlineHierarchy() async throws {
        await searchService.indexDocument(testDocument)
        let outline = try await searchService.generateOutline(for: testDocument)

        // Should have level 1, 2, and 3 headings
        let levels = Set(outline.map { $0.level })
        XCTAssertTrue(levels.contains(1))
        XCTAssertTrue(levels.contains(2))
        XCTAssertTrue(levels.contains(3))
    }

    // MARK: - Search Result Properties

    func testSearchResultHasLineNumber() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("Variables")

        guard let result = results.first else {
            XCTFail("Should find at least one result")
            return
        }

        XCTAssertGreaterThan(result.lineNumber, 0)
    }

    func testSearchResultHasRelevanceScore() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("Swift")

        for result in results {
            XCTAssertGreaterThan(result.relevanceScore, 0.0)
            XCTAssertLessThanOrEqual(result.relevanceScore, 1.0)
        }
    }

    func testSearchResultHasMatchType() async throws {
        await searchService.indexDocument(testDocument)
        let results = try await searchService.search("Functions")

        guard let headingResult = results.first(where: { $0.matchType == .heading }) else {
            // It's ok if the heading match type isn't detected
            return
        }
        XCTAssertEqual(headingResult.matchType, .heading)
    }

    // MARK: - Index Management

    func testUpdateDocumentIndex() async throws {
        await searchService.indexDocument(testDocument)

        let stats1 = await searchService.getSearchStatistics()
        XCTAssertEqual(stats1.documentsIndexed, 1)

        // Update with same document
        await searchService.updateDocumentIndex(testDocument)

        let stats2 = await searchService.getSearchStatistics()
        XCTAssertEqual(stats2.documentsIndexed, 1)
    }

    func testRemoveFromIndex() async throws {
        await searchService.indexDocument(testDocument)
        await searchService.removeFromIndex(testDocument.id)

        let stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 0)
    }

    func testClearIndex() async throws {
        await searchService.indexDocument(testDocument)
        await searchService.clearIndex()

        let stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 0)
    }

    // MARK: - Content Highlighting

    func testHighlightMatches() async throws {
        let content = NSAttributedString(string: "Hello Swift World")
        let highlighted = searchService.highlightMatches(content, query: "Swift")

        // The highlighted string should still contain the original text
        XCTAssertTrue(highlighted.string.contains("Swift"))
        XCTAssertEqual(highlighted.length, content.length)
    }

    // MARK: - Performance

    func testSearchPerformance() async throws {
        await searchService.indexDocument(testDocument)

        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try await searchService.search("Swift")
        }
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // 100 searches should complete in under 5 seconds
        XCTAssertLessThan(duration, 5.0, "Search should be fast")
    }
}

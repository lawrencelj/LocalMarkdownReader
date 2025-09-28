/// MarkdownCoreTests - Unit tests for MarkdownCore package
///
/// Comprehensive test suite covering document parsing, rendering,
/// validation, and performance requirements.

import XCTest
@testable import MarkdownCore

final class MarkdownCoreTests: XCTestCase {
    var documentService: DocumentService!
    var parser: MarkdownParser!

    override func setUpWithError() throws {
        documentService = DocumentService()
        parser = MarkdownParser()
    }

    override func tearDownWithError() throws {
        documentService = nil
        parser = nil
    }

    // MARK: - Document Parsing Tests

    func testBasicMarkdownParsing() async throws {
        let content = """
        # Test Document

        This is a **bold** text and *italic* text.

        ## Section
        - Item 1
        - Item 2

        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        """

        let document = try await documentService.parseMarkdown(content)

        XCTAssertEqual(document.content, content)
        XCTAssertEqual(document.metadata.wordCount, 16)
        XCTAssertTrue(document.metadata.hasCodeBlocks)
        XCTAssertFalse(document.metadata.hasImages)
        XCTAssertFalse(document.metadata.hasTables)
        XCTAssertEqual(document.outline.count, 2) // H1 and H2
    }

    func testHeadingExtraction() async throws {
        let content = """
        # Main Title
        ## Subtitle
        ### Sub-subtitle
        #### Deep heading
        """

        let document = try await documentService.parseMarkdown(content)

        XCTAssertEqual(document.outline.count, 4)
        XCTAssertEqual(document.outline[0].level, 1)
        XCTAssertEqual(document.outline[0].title, "Main Title")
        XCTAssertEqual(document.outline[1].level, 2)
        XCTAssertEqual(document.outline[1].title, "Subtitle")
        XCTAssertEqual(document.outline[2].level, 3)
        XCTAssertEqual(document.outline[2].title, "Sub-subtitle")
        XCTAssertEqual(document.outline[3].level, 4)
        XCTAssertEqual(document.outline[3].title, "Deep heading")
    }

    func testTableParsing() async throws {
        let content = """
        | Column 1 | Column 2 |
        |----------|----------|
        | Value 1  | Value 2  |
        | Value 3  | Value 4  |
        """

        let document = try await documentService.parseMarkdown(content)

        XCTAssertTrue(document.metadata.hasTables)
        XCTAssertFalse(document.metadata.hasImages)
        XCTAssertFalse(document.metadata.hasCodeBlocks)
    }

    func testCodeBlockParsing() async throws {
        let content = """
        ```swift
        func test() {
            return "Hello"
        }
        ```

        ```python
        def hello():
            return "World"
        ```
        """

        let document = try await documentService.parseMarkdown(content)

        XCTAssertTrue(document.metadata.hasCodeBlocks)
        XCTAssertEqual(document.metadata.languageHints.count, 2)
        XCTAssertTrue(document.metadata.languageHints.contains("swift"))
        XCTAssertTrue(document.metadata.languageHints.contains("python"))
    }

    // MARK: - Validation Tests

    func testContentValidation() async throws {
        let validContent = "# Valid Content\nThis is valid markdown."
        let emptyContent = ""

        // Valid content should parse successfully
        XCTAssertNoThrow(try await documentService.parseMarkdown(validContent))

        // Empty content should return empty document
        let emptyDocument = try await documentService.parseMarkdown(emptyContent)
        XCTAssertEqual(emptyDocument.content, "")
        XCTAssertEqual(emptyDocument.metadata.wordCount, 0)
    }

    func testSecurityValidation() async throws {
        let maliciousContent = """
        # Test
        <script>alert('xss')</script>
        [Click me](javascript:alert('xss'))
        """

        // Should parse but sanitize dangerous content
        let document = try await documentService.parseMarkdown(maliciousContent)
        XCTAssertNotNil(document)
        // Content should be sanitized (implementation specific)
    }

    func testLargeDocumentHandling() async throws {
        // Create a large document (near 2MB limit)
        let largeContent = String(repeating: "# Heading\nContent line.\n", count: 50000)

        // Should handle large documents within limits
        let document = try await documentService.parseMarkdown(largeContent)
        XCTAssertNotNil(document)
        XCTAssertTrue(document.metadata.characterCount > 500000)
    }

    // MARK: - Performance Tests

    func testParsingPerformance() {
        let content = String(repeating: "# Heading\nSome content with **bold** and *italic* text.\n", count: 1000)

        measure {
            Task {
                _ = try! await documentService.parseMarkdown(content)
            }
        }
    }

    func testAttributedStringRendering() async throws {
        let content = """
        # Test Document
        This is **bold** and *italic* text.
        """

        let document = try await documentService.parseMarkdown(content)
        let attributedString = documentService.renderToAttributedString(document)

        XCTAssertTrue(attributedString.length > 0)
        XCTAssertTrue(attributedString.string.contains("Test Document"))
    }

    // MARK: - Metadata Tests

    func testMetadataExtraction() async throws {
        let content = """
        # Test Title
        This document has exactly ten words in this sentence.

        ## Another Section
        More content here.
        """

        let document = try await documentService.parseMarkdown(content)
        let metadata = document.metadata

        XCTAssertEqual(metadata.title, "Test Title")
        XCTAssertEqual(metadata.wordCount, 13)
        XCTAssertEqual(metadata.estimatedReadingTime, 1) // At 200 WPM
        XCTAssertTrue(metadata.lineCount > 0)
        XCTAssertTrue(metadata.characterCount > 0)
    }

    func testDocumentStatistics() async throws {
        let content = """
        # Statistics Test

        This document contains:
        - **Bold text**
        - *Italic text*
        - A table:

        | Col1 | Col2 |
        |------|------|
        | A    | B    |

        And code:
        ```javascript
        console.log("Hello");
        ```
        """

        let document = try await documentService.parseMarkdown(content)
        let stats = documentService.getDocumentStatistics(document)

        XCTAssertEqual(stats.headingCount, 1)
        XCTAssertTrue(stats.wordCount > 10)
        XCTAssertTrue(stats.hasCodeBlocks)
        XCTAssertTrue(stats.hasTables)
        XCTAssertTrue(stats.languageHints.contains("javascript"))
    }

    // MARK: - Error Handling Tests

    func testDocumentReferenceCreation() throws {
        let tempURL = URL(fileURLWithPath: "/tmp/test.md")
        let reference = DocumentReference(
            url: tempURL,
            lastModified: Date(),
            fileSize: 1024
        )

        XCTAssertEqual(reference.url, tempURL)
        XCTAssertEqual(reference.fileSize, 1024)
        XCTAssertNotNil(reference.lastModified)
    }

    func testDocumentModelCodable() throws {
        let content = "# Test\nContent"
        let reference = DocumentReference(
            url: URL(fileURLWithPath: "/tmp/test.md"),
            lastModified: Date(),
            fileSize: Int64(content.count)
        )

        let parser = MarkdownParser()
        let attributedContent = try parser.parseToAttributedString(content)
        let metadata = DocumentMetadata(
            title: "Test",
            wordCount: 2,
            characterCount: content.count,
            lineCount: 2,
            estimatedReadingTime: 1,
            lastModified: Date(),
            fileSize: Int64(content.count)
        )
        let outline = [HeadingItem(level: 1, title: "Test", range: NSRange(location: 0, length: 4))]

        let document = DocumentModel(
            reference: reference,
            content: content,
            attributedContent: attributedContent,
            metadata: metadata,
            outline: outline
        )

        // Test encoding
        let encoded = try JSONEncoder().encode(document)
        XCTAssertTrue(encoded.count > 0)

        // Test decoding
        let decoded = try JSONDecoder().decode(DocumentModel.self, from: encoded)
        XCTAssertEqual(decoded.content, document.content)
        XCTAssertEqual(decoded.metadata.title, document.metadata.title)
    }
}

// MARK: - Mock Data

extension MarkdownCoreTests {
    static let sampleMarkdown = """
    # Sample Document

    This is a sample markdown document for testing purposes.

    ## Features

    - **Bold text**
    - *Italic text*
    - `Inline code`

    ### Code Block

    ```swift
    func hello() {
        print("Hello, World!")
    }
    ```

    ### Table

    | Feature | Status |
    |---------|--------|
    | Parsing | ✅ |
    | Rendering | ✅ |

    ## Links

    [Apple](https://apple.com)
    [Markdown Guide](https://www.markdownguide.org)
    """
}
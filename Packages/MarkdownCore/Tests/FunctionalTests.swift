// FunctionalTests - Verifies all core functions work correctly
//
// Tests document parsing, metadata extraction, outline generation,
// validation, and the document service pipeline.

@testable import MarkdownCore
import XCTest

@MainActor
final class FunctionalTests: XCTestCase {
    // MARK: - Document Parsing

    func testParseSimpleMarkdown() throws {
        let parser = MarkdownParser()
        let content = "# Hello World\n\nThis is a paragraph."
        let result = try parser.parseToAttributedString(content)
        XCTAssertFalse(String(result.characters).isEmpty)
    }

    func testParseHeadings() throws {
        let parser = MarkdownParser()
        let content = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        #### Heading 4
        """
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("Heading 1"))
        XCTAssertTrue(text.contains("Heading 2"))
        XCTAssertTrue(text.contains("Heading 3"))
        XCTAssertTrue(text.contains("Heading 4"))
    }

    func testParseBoldAndItalic() throws {
        let parser = MarkdownParser()
        let content = "This is **bold** and *italic* text."
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("bold"))
        XCTAssertTrue(text.contains("italic"))
    }

    func testParseCodeBlock() throws {
        let parser = MarkdownParser()
        let content = """
        ```swift
        func hello() {
            print("Hello")
        }
        ```
        """
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("hello()"))
    }

    func testParseLinks() throws {
        let parser = MarkdownParser()
        let content = "Visit [Apple](https://apple.com) for more."
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("Apple"))
    }

    func testParseLists() throws {
        let parser = MarkdownParser()
        let content = """
        - Item 1
        - Item 2
        - Item 3
        """
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("Item 1"))
        XCTAssertTrue(text.contains("Item 2"))
    }

    func testParseOrderedList() throws {
        let parser = MarkdownParser()
        let content = """
        1. First
        2. Second
        3. Third
        """
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("First"))
        XCTAssertTrue(text.contains("Second"))
    }

    func testParseBlockquote() throws {
        let parser = MarkdownParser()
        let content = "> This is a quote"
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("This is a quote"))
    }

    func testParseTable() throws {
        let parser = MarkdownParser()
        let content = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let result = try parser.parseToAttributedString(content)
        let text = String(result.characters)
        // Table content should be present in some form
        XCTAssertFalse(text.isEmpty, "Table should produce some output")
    }

    func testParseEmptyContent() throws {
        let parser = MarkdownParser()
        let result = try parser.parseToAttributedString("")
        XCTAssertTrue(String(result.characters).isEmpty)
    }

    // MARK: - Document Service

    func testDocumentServiceParseMarkdown() async throws {
        let service = DocumentService()
        let content = "# Test\n\nHello world."
        let document = try await service.parseMarkdown(content)

        XCTAssertEqual(document.content, content)
        XCTAssertNotNil(document.metadata.title)
        XCTAssertEqual(document.metadata.title, "Test")
        XCTAssertGreaterThan(document.metadata.wordCount, 0)
    }

    func testDocumentServiceMetadataExtraction() async throws {
        let service = DocumentService()
        let content = """
        # My Document

        This is a paragraph with several words in it.

        ## Section Two

        More content here with additional words.
        """
        let document = try await service.parseMarkdown(content)

        XCTAssertEqual(document.metadata.title, "My Document")
        XCTAssertGreaterThan(document.metadata.wordCount, 10)
        XCTAssertGreaterThan(document.metadata.characterCount, 50)
        XCTAssertGreaterThan(document.metadata.lineCount, 3)
        XCTAssertGreaterThanOrEqual(document.metadata.estimatedReadingTime, 1)
    }

    func testDocumentServiceOutlineExtraction() async throws {
        let service = DocumentService()
        let content = """
        # Introduction

        Some intro text.

        ## Getting Started

        Getting started content.

        ## Advanced Topics

        Advanced content.

        ### Sub Topic

        Sub topic content.
        """
        let document = try await service.parseMarkdown(content)

        XCTAssertGreaterThanOrEqual(document.outline.count, 3)
        XCTAssertEqual(document.outline.first?.title, "Introduction")
        XCTAssertEqual(document.outline.first?.level, 1)
    }

    func testDocumentServiceStatistics() async throws {
        let service = DocumentService()
        let content = """
        # Code Example

        Here is some code:

        ```swift
        let x = 42
        ```

        And a table:

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let document = try await service.parseMarkdown(content)
        let stats = service.getDocumentStatistics(document)

        XCTAssertGreaterThan(stats.wordCount, 0)
        XCTAssertGreaterThan(stats.characterCount, 0)
        XCTAssertTrue(stats.hasCodeBlocks)
        XCTAssertTrue(stats.hasTables)
    }

    func testLaTeXDocumentServicePipeline() async throws {
        let content = #"""
        \documentclass{article}
        \title{Functional LaTeX Test}
        \begin{document}
        \section{Introduction}
        Text with $\alpha + \beta$.
        \subsection{Details}
        \begin{lstlisting}[language=Swift]
        print("Hello")
        \end{lstlisting}
        \end{document}
        """#
        let reference = DocumentReference(
            url: URL(fileURLWithPath: "/tmp/functional.tex"),
            fileSize: Int64(content.utf8.count)
        )

        let document = try await MarkdownParser().parseDocument(
            content: content,
            reference: reference
        )

        XCTAssertEqual(document.format, .latex)
        XCTAssertEqual(document.title, "Functional LaTeX Test")
        XCTAssertEqual(document.outline.map(\.title), ["Introduction", "Details"])
        XCTAssertEqual(document.outline.map(\.level), [1, 2])
        XCTAssertTrue(document.metadata.hasCodeBlocks)
        XCTAssertTrue(document.metadata.languageHints.contains("swift"))
    }

    // MARK: - Validation

    func testValidContentPasses() throws {
        let parser = MarkdownParser()
        let content = "# Valid\n\nThis is valid markdown content."
        // Should not throw
        let result = try parser.parseToAttributedString(content)
        XCTAssertFalse(String(result.characters).isEmpty)
    }

    func testSecurityValidation() async throws {
        let parser = MarkdownParser(configuration: .default)
        let content = "# Safe Content\n\nNo scripts here."
        // Safe content should parse fine
        let reference = DocumentReference(url: URL(fileURLWithPath: "/tmp/test.md"), fileSize: Int64(content.count))
        let document = try await parser.parseDocument(content: content, reference: reference)
        XCTAssertNotNil(document)
    }

    // MARK: - Document Model

    func testDocumentModelProperties() async throws {
        let service = DocumentService()
        let content = "# Title\n\nContent with words."
        let document = try await service.parseMarkdown(content)

        // Test convenience properties
        XCTAssertEqual(document.title, "Title")
        XCTAssertGreaterThan(document.wordCount, 0)
        XCTAssertGreaterThanOrEqual(document.estimatedReadingTime, 1)
    }

    func testDocumentModelEquality() async throws {
        let service = DocumentService()
        let content = "# Test"
        let doc1 = try await service.parseMarkdown(content)
        let doc2 = try await service.parseMarkdown(content)

        // Different documents (different UUIDs)
        XCTAssertNotEqual(doc1, doc2)
        // Same document equals itself
        XCTAssertEqual(doc1, doc1)
    }

    // MARK: - Content Features Detection

    func testDetectsImages() async throws {
        let service = DocumentService()
        let content = "# Doc\n\n![Alt text](image.png)"
        let document = try await service.parseMarkdown(content)
        XCTAssertTrue(document.metadata.hasImages)
    }

    func testDetectsCodeBlocks() async throws {
        let service = DocumentService()
        let content = "# Doc\n\n```python\nprint('hi')\n```"
        let document = try await service.parseMarkdown(content)
        XCTAssertTrue(document.metadata.hasCodeBlocks)
        XCTAssertTrue(document.metadata.languageHints.contains("python"))
    }

    func testDetectsTables() async throws {
        let service = DocumentService()
        let content = "# Doc\n\n| A | B |\n|---|---|\n| 1 | 2 |"
        let document = try await service.parseMarkdown(content)
        XCTAssertTrue(document.metadata.hasTables)
    }

    // MARK: - Performance

    func testLargeDocumentParsing() async throws {
        let service = DocumentService()
        // Generate a large document
        var content = "# Large Document\n\n"
        for i in 1 ... 100 {
            content += "## Section \(i)\n\nThis is paragraph \(i) with some content to make it realistic. "
            content += "It contains multiple sentences and various markdown features.\n\n"
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let document = try await service.parseMarkdown(content)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertGreaterThan(document.metadata.wordCount, 500)
        XCTAssertLessThan(duration, 5.0, "Large document should parse in under 5 seconds")
    }
}

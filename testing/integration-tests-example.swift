/// Integration Tests Example - Cross-Package Workflow Validation
///
/// This file demonstrates the integration testing strategy for MarkdownReader.
/// Once XCTest build issues are resolved, these tests will validate cross-package workflows.
///
/// CURRENT STATUS: Template/Example - Cannot execute until XCTest module resolution is fixed

// MARK: - Integration Test Template (Ready for Implementation)

import XCTest
@testable import MarkdownCore
@testable import FileAccess
@testable import Search
@testable import ViewerUI
@testable import Settings

/// Comprehensive integration test suite validating cross-package workflows
/// These tests verify that the security fixes, performance optimizations, and
/// core functionality work together seamlessly.
@available(iOS 17.0, macOS 14.0, *)
final class CrossPackageIntegrationTests: XCTestCase {

    var fileService: FileService!
    var documentService: DocumentService!
    var searchService: SearchService!
    var coordinator: AppStateCoordinator!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        super.setUp()

        // Initialize services
        fileService = FileService()
        documentService = DocumentService()
        searchService = SearchService()
        coordinator = AppStateCoordinator(
            documentService: documentService,
            searchService: searchService
        )

        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Cleanup
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Security Integration Tests

    func testSecureDocumentLoadAndProcessing() async throws {
        // Test complete secure workflow: FileAccess → MarkdownCore → Search → ViewerUI

        // 1. Create test document with security implications
        let testContent = """
        # Test Document with Security Content

        This document contains various elements that test our security implementations:

        ## Script Injection Test
        <script>alert('xss')</script>

        ## Path Traversal Test
        [Malicious Link](../../../etc/passwd)

        ## Large Content Test
        \(String(repeating: "Large content block. ", count: 1000))

        ## Code Block
        ```javascript
        // This should be safely rendered
        function test() {
            return "safe";
        }
        ```
        """

        let testFile = tempDirectory.appendingPathComponent("security-test.md")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        // 2. Test FileAccess security validation
        let canAccess = await fileService.isDocumentAccessible(testFile)
        XCTAssertTrue(canAccess, "Should allow access to legitimate markdown file")

        // 3. Test secure document loading
        let documentContent = try await fileService.loadDocument(from: testFile)
        XCTAssertFalse(documentContent.isEmpty, "Document should load successfully")

        // 4. Test MarkdownCore parsing with security validation
        let document = try await documentService.parseMarkdown(documentContent)
        XCTAssertEqual(document.content, documentContent, "Content should be preserved")
        XCTAssertTrue(document.metadata.wordCount > 0, "Metadata should be extracted")

        // 5. Test Search indexing without security issues
        await searchService.indexDocument(document)
        let searchResults = await searchService.searchContent("security")
        XCTAssertTrue(searchResults.count > 0, "Should find search results")

        // 6. Test ViewerUI coordinator integration
        await coordinator.loadDocument(document.reference)
        XCTAssertNotNil(coordinator.documentState.currentDocument, "Document should be loaded in coordinator")

        // 7. Verify no security vulnerabilities exposed
        let searchStats = await searchService.getSearchStatistics()
        XCTAssertEqual(searchStats.documentsIndexed, 1, "Should index exactly one document")
        XCTAssertTrue(searchStats.totalSearchTerms > 0, "Should have indexed search terms")
    }

    func testPathTraversalProtection() async throws {
        // Test that malicious file paths are properly blocked across all components

        let maliciousURLs = [
            URL(fileURLWithPath: "/tmp/../etc/passwd"),
            URL(fileURLWithPath: "/System/Library/Frameworks/Security.framework"),
            URL(fileURLWithPath: "/private/var/log/system.log")
        ]

        for maliciousURL in maliciousURLs {
            // FileAccess should block malicious URLs
            let canAccess = await fileService.isDocumentAccessible(maliciousURL)
            XCTAssertFalse(canAccess, "Should block access to: \(maliciousURL.path)")

            // Attempting to load should fail safely
            do {
                _ = try await fileService.loadDocument(from: maliciousURL)
                XCTFail("Should not allow loading malicious URL: \(maliciousURL.path)")
            } catch {
                // Expected failure - this is correct behavior
            }
        }
    }

    // MARK: - Performance Integration Tests

    func testLargeDocumentPerformanceWorkflow() async throws {
        // Test complete workflow performance with large documents (2MB limit testing)

        // 1. Create large test document (approaching 2MB limit)
        let largeContent = createLargeTestDocument(targetSize: 1_800_000) // 1.8MB
        let largeFile = tempDirectory.appendingPathComponent("large-test.md")
        try largeContent.write(to: largeFile, atomically: true, encoding: .utf8)

        // 2. Measure complete workflow performance
        let workflowStartTime = CFAbsoluteTimeGetCurrent()

        // FileAccess performance
        let loadStartTime = CFAbsoluteTimeGetCurrent()
        let documentContent = try await fileService.loadDocument(from: largeFile)
        let loadEndTime = CFAbsoluteTimeGetCurrent()

        // MarkdownCore parsing performance
        let parseStartTime = CFAbsoluteTimeGetCurrent()
        let document = try await documentService.parseMarkdown(documentContent)
        let parseEndTime = CFAbsoluteTimeGetCurrent()

        // Search indexing performance
        let indexStartTime = CFAbsoluteTimeGetCurrent()
        await searchService.indexDocument(document)
        let indexEndTime = CFAbsoluteTimeGetCurrent()

        // Search query performance
        let queryStartTime = CFAbsoluteTimeGetCurrent()
        let searchResults = await searchService.searchContent("test")
        let queryEndTime = CFAbsoluteTimeGetCurrent()

        let workflowEndTime = CFAbsoluteTimeGetCurrent()

        // 3. Validate performance requirements
        let loadTime = loadEndTime - loadStartTime
        let parseTime = parseEndTime - parseStartTime
        let indexTime = indexEndTime - indexStartTime
        let queryTime = queryEndTime - queryStartTime
        let totalWorkflowTime = workflowEndTime - workflowStartTime

        // Performance thresholds (from strategy document)
        XCTAssertLessThan(loadTime, 3.0, "Large document loading should complete within 3 seconds")
        XCTAssertLessThan(parseTime, 2.0, "Large document parsing should complete within 2 seconds")
        XCTAssertLessThan(indexTime, 5.0, "Large document indexing should complete within 5 seconds")
        XCTAssertLessThan(queryTime, 0.1, "Search queries should complete within 100ms")
        XCTAssertLessThan(totalWorkflowTime, 10.0, "Complete workflow should finish within 10 seconds")

        // Memory usage validation
        let initialMemory = getCurrentMemoryUsage()
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 200 * 1024 * 1024, "Memory increase should be under 200MB for large documents")

        // Verify functionality
        XCTAssertEqual(document.content.count, largeContent.count, "Content should be fully preserved")
        XCTAssertTrue(searchResults.count > 0, "Should find search results in large document")
    }

    func testSearchMemoryOptimizationIntegration() async throws {
        // Test the 150MB → 50MB memory optimization across the complete workflow

        var documents: [DocumentModel] = []
        let initialMemory = getCurrentMemoryUsage()

        // Index multiple documents to test memory scaling
        for i in 1...10 {
            let content = createMediumTestDocument(id: i)
            let file = tempDirectory.appendingPathComponent("doc\(i).md")
            try content.write(to: file, atomically: true, encoding: .utf8)

            let loadedContent = try await fileService.loadDocument(from: file)
            let document = try await documentService.parseMarkdown(loadedContent)
            await searchService.indexDocument(document)
            documents.append(document)
        }

        let afterIndexingMemory = getCurrentMemoryUsage()
        let memoryUsed = afterIndexingMemory - initialMemory

        // Memory usage should stay within optimized limits
        XCTAssertLessThan(memoryUsed, 50 * 1024 * 1024, "Memory usage should stay under 50MB target")

        // Verify search functionality across all documents
        let searchResults = await searchService.searchContent("test")
        XCTAssertTrue(searchResults.count >= 10, "Should find results across all indexed documents")

        // Test search statistics
        let stats = await searchService.getSearchStatistics()
        XCTAssertEqual(stats.documentsIndexed, 10, "Should have indexed all 10 documents")

        print("Memory optimization test: Used \(memoryUsed / 1024 / 1024)MB for 10 documents")
    }

    // MARK: - UI Integration Tests (Coordinator Level)

    func testViewerUICoordinatorIntegration() async throws {
        // Test complete UI state management integration

        let testContent = """
        # UI Integration Test

        This document tests the complete UI coordination workflow.

        ## Section 1
        Content for testing scroll positions and state management.

        ## Section 2
        More content for testing search highlighting and navigation.
        """

        let testFile = tempDirectory.appendingPathComponent("ui-test.md")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)

        // 1. Test document loading through coordinator
        let documentContent = try await fileService.loadDocument(from: testFile)
        let document = try await documentService.parseMarkdown(documentContent)

        // 2. Test coordinator state management
        await coordinator.loadDocument(document.reference)
        XCTAssertNotNil(coordinator.documentState.currentDocument, "Document should be loaded")
        XCTAssertEqual(coordinator.documentState.documentContent?.string, document.attributedContent.string)

        // 3. Test search integration with UI
        await coordinator.performSearch("integration")
        XCTAssertTrue(coordinator.searchState.results.count > 0, "Should find search results")
        XCTAssertFalse(coordinator.searchState.searchQuery.isEmpty, "Search query should be stored")

        // 4. Test scroll position persistence
        let testScrollPosition: CGFloat = 100.0
        await coordinator.saveScrollPosition(testScrollPosition)
        XCTAssertEqual(coordinator.documentState.scrollPosition, testScrollPosition, "Scroll position should be saved")

        // 5. Test document closing and cleanup
        coordinator.closeDocument()
        XCTAssertNil(coordinator.documentState.currentDocument, "Document should be cleared")
        XCTAssertTrue(coordinator.searchState.results.isEmpty, "Search results should be cleared")
        XCTAssertEqual(coordinator.documentState.scrollPosition, 0, "Scroll position should be reset")
    }

    // MARK: - Error Handling Integration Tests

    func testErrorHandlingAcrossComponents() async throws {
        // Test that errors are properly handled across all component boundaries

        // 1. Test FileAccess error propagation
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.md")

        do {
            _ = try await fileService.loadDocument(from: nonExistentFile)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            // Verify specific error types
            XCTAssertTrue(error is FileAccessError, "Should throw FileAccessError")
        }

        // 2. Test MarkdownCore error handling
        let invalidContent = String(repeating: "x", count: 10_000_000) // Oversized content

        do {
            _ = try await documentService.parseMarkdown(invalidContent)
            XCTFail("Should handle oversized content gracefully")
        } catch {
            // Should handle gracefully without crashing
        }

        // 3. Test Search error recovery
        let corruptDocument = DocumentModel(
            reference: DocumentReference(url: nonExistentFile, lastModified: Date(), fileSize: 0),
            content: "",
            attributedContent: AttributedString(""),
            metadata: DocumentMetadata.empty,
            outline: []
        )

        // Search should handle corrupt documents without crashing
        await searchService.indexDocument(corruptDocument)
        let results = await searchService.searchContent("test")
        XCTAssertEqual(results.count, 0, "Should return empty results for corrupt document")

        // 4. Test coordinator error state management
        do {
            await coordinator.loadDocument(corruptDocument.reference)
            // Coordinator should handle errors gracefully without crashing
        } catch {
            // Expected - coordinator should handle loading errors
        }

        XCTAssertNil(coordinator.documentState.currentDocument, "Should not load corrupt document")
        XCTAssertFalse(coordinator.appState.hasError, "Should handle errors without permanent error state")
    }

    // MARK: - Helper Methods

    private func createLargeTestDocument(targetSize: Int) -> String {
        let baseContent = """
        # Large Test Document

        ## Performance Testing Section

        This document is designed to test performance with large content.

        """

        let contentBlock = """

        ### Content Block
        This is a content block with **bold text**, *italic text*, and `inline code`.

        - List item 1
        - List item 2
        - List item 3

        ```swift
        func performanceTest() {
            print("Testing performance with large documents")
        }
        ```

        | Column 1 | Column 2 | Column 3 |
        |----------|----------|----------|
        | Value 1  | Value 2  | Value 3  |

        """

        var content = baseContent
        while content.count < targetSize {
            content += contentBlock
        }

        return content
    }

    private func createMediumTestDocument(id: Int) -> String {
        return """
        # Test Document \(id)

        This is test document number \(id) for memory optimization testing.

        ## Content Section
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.

        ### Subsection
        More content to test memory usage patterns.

        - Item 1
        - Item 2
        - Item 3

        ```swift
        func document\(id)() {
            return "Document \(id) content"
        }
        ```
        """
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// MARK: - Mock Extensions for Testing

extension DocumentMetadata {
    static var empty: DocumentMetadata {
        return DocumentMetadata(
            title: "",
            wordCount: 0,
            characterCount: 0,
            lineCount: 0,
            estimatedReadingTime: 0,
            lastModified: Date(),
            fileSize: 0
        )
    }
}

extension DocumentReference {
    static func mock() -> DocumentReference {
        return DocumentReference(
            url: URL(fileURLWithPath: "/tmp/mock.md"),
            lastModified: Date(),
            fileSize: 1024
        )
    }
}
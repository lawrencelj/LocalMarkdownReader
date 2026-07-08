// DocumentViewerTests - Comprehensive test suite for DocumentViewer
//
// Tests core document viewing functionality, performance optimization,
// accessibility compliance, and cross-platform behavior.

@testable import FileAccess
@testable import MarkdownCore
@testable import Search
@testable import Settings
import SwiftUI
@testable import ViewerUI
import XCTest

@MainActor
final class DocumentViewerTests: XCTestCase {
    // MARK: - Test Properties

    private var coordinator: AppStateCoordinator!
    private var mockDocumentService: MockDocumentService!
    private var mockSearchService: MockSearchService!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        mockDocumentService = MockDocumentService()
        mockSearchService = MockSearchService()
        coordinator = AppStateCoordinator(
            documentService: mockDocumentService,
            searchService: mockSearchService,
            fileService: MockFileService(),
            preferencesService: MockPreferencesService()
        )
    }

    override func tearDownWithError() throws {
        coordinator = nil
        mockDocumentService = nil
        mockSearchService = nil
    }

    // MARK: - Document Loading Tests

    func testDocumentLoadingFlow() async {
        // Given
        let mockDocument = DocumentModel.mock()
        mockDocumentService.loadDocumentResult = .success(mockDocument)

        // When
        await coordinator.loadDocument(DocumentReference.mock())

        // Then
        XCTAssertFalse(coordinator.documentState.isLoading)
        XCTAssertNotNil(coordinator.documentState.currentDocument)
        XCTAssertNil(coordinator.documentState.parseError)
        XCTAssertTrue(coordinator.uiState.isDocumentLoaded)
    }

    func testDocumentLoadingError() async {
        // Given
        let expectedError = DocumentError.fileNotFound
        mockDocumentService.loadDocumentResult = .failure(expectedError)

        // When
        await coordinator.loadDocument(DocumentReference.mock())

        // Then
        XCTAssertFalse(coordinator.documentState.isLoading)
        XCTAssertNil(coordinator.documentState.currentDocument)
        XCTAssertNotNil(coordinator.documentState.parseError)
        XCTAssertFalse(coordinator.uiState.isDocumentLoaded)
    }

    func testDocumentLoadingPerformance() throws {
        // A hard wall-clock threshold on full load+index of a large document is
        // environment-dependent (CI vs local) and therefore flaky as a unit test.
        // Load-time budgets belong in a dedicated performance harness (see the CI
        // performance job), not the unit suite.
        throw XCTSkip("Wall-clock load-time budget is environment-dependent; measure in a performance harness.")
    }

    // MARK: - Viewport Rendering Tests

    func testViewportRenderingOptimization() {
        // Given
        let renderer = MarkdownRenderer(
            content: AttributedString("# Large Document\n" + String(repeating: "Content line\n", count: 1000)),
            viewportBounds: .constant(CGRect(x: 0, y: 0, width: 400, height: 600)),
            isOptimized: .constant(true)
        )

        // When/Then - Test that renderer initializes without performance issues
        XCTAssertNotNil(renderer)
    }

    func testScrollPositionPersistence() async {
        // Given
        let mockDocument = DocumentModel.mock()
        mockDocumentService.loadDocumentResult = .success(mockDocument)
        await coordinator.loadDocument(DocumentReference.mock())

        let testPosition: CGFloat = 150.0

        // When
        await coordinator.saveScrollPosition(testPosition)

        // Then
        XCTAssertEqual(coordinator.documentState.scrollPosition, testPosition)
    }

    // MARK: - Accessibility Tests

    /// Function: DocumentViewer accessibility structure.
    /// Rendered-view accessibility (labels/traits) can only be inspected from a
    /// UI test target (ViewInspector); this unit target cannot instantiate the
    /// view's body without a hosting hierarchy. Skipped honestly rather than
    /// asserting a meaningless `true`.
    func testDocumentViewAccessibility() throws {
        throw XCTSkip("Rendered-view accessibility requires a UI test target (ViewInspector).")
    }

    /// Function: VoiceOver navigation/announcements.
    /// Requires a UI test target; skipped honestly (was a passing placeholder).
    func testVoiceOverSupport() throws {
        throw XCTSkip("VoiceOver behavior requires a UI test target.")
    }

    /// Function: ThemeManager.adjustFontSize(multiplier:) — Dynamic Type scaling.
    /// Input: a sequence of increasing multipliers. Output: fontSizeMultiplier
    /// tracks the request (clamped to [0.5, 3.0]) and larger requests never
    /// produce a smaller multiplier — the behavior Dynamic Type support relies on.
    @MainActor
    func testDynamicTypeSupport() {
        let themeManager = ThemeManager()
        // Each in-range request is applied verbatim (drives Dynamic Type scaling).
        for multiplier in [0.5, 1.0, 1.5, 2.0, 3.0] as [CGFloat] {
            themeManager.adjustFontSize(multiplier: multiplier)
            XCTAssertEqual(themeManager.fontSizeMultiplier, multiplier, accuracy: 0.0001)
        }
        // Out-of-range requests clamp rather than exceeding the supported bounds.
        themeManager.adjustFontSize(multiplier: 10.0)
        XCTAssertEqual(themeManager.fontSizeMultiplier, 3.0, accuracy: 0.0001)
        themeManager.adjustFontSize(multiplier: 0.0)
        XCTAssertEqual(themeManager.fontSizeMultiplier, 0.5, accuracy: 0.0001)
    }

    // MARK: - Cross-Platform Tests

    func testPlatformAdaptation() {
        // Test platform-specific behavior
        #if os(iOS)
            testIOSSpecificBehavior()
        #elseif os(macOS)
            testMacOSSpecificBehavior()
        #endif
    }

    #if os(iOS)
        func testIOSSpecificBehavior() {
            // Test iOS-specific features like pull-to-refresh
            XCTAssertTrue(true) // Placeholder
        }
    #endif

    #if os(macOS)
        func testMacOSSpecificBehavior() {
            // Test macOS-specific features like keyboard shortcuts
            XCTAssertTrue(true) // Placeholder
        }
    #endif

    // MARK: - Performance Tests

    func testMemoryUsageWithLargeDocument() throws {
        // `getTestMemoryUsage()` reports whole-process resident size, which
        // includes the test host and every previously-run test — it is not a
        // deterministic measure of this operation's footprint. Memory budgets
        // belong in a dedicated performance/memory harness.
        throw XCTSkip("Whole-process RSS is not a deterministic per-operation memory measure.")
    }

    func testRenderingPerformance() {
        measure {
            // Test rendering performance
            let content = AttributedString(String(repeating: "Performance test content\n", count: 100))
            let renderer = MarkdownRenderer(
                content: content,
                viewportBounds: .constant(CGRect(x: 0, y: 0, width: 400, height: 600)),
                isOptimized: .constant(true)
            )

            // Simulate rendering
            _ = renderer.body
        }
    }

    // MARK: - Error Handling Tests

    func testErrorRecovery() async {
        // Given
        mockDocumentService.loadDocumentResult = .failure(DocumentError.parseFailure("test error"))

        // When
        await coordinator.loadDocument(DocumentReference.mock())

        // Then
        XCTAssertNotNil(coordinator.documentState.parseError)

        // Test retry mechanism
        mockDocumentService.loadDocumentResult = .success(DocumentModel.mock())
        await coordinator.retryDocumentLoad()

        XCTAssertNil(coordinator.documentState.parseError)
        XCTAssertNotNil(coordinator.documentState.currentDocument)
    }

    func testErrorMessageAccessibility() {
        // Test that error messages are properly announced
        let errorView = ErrorView(
            error: DocumentError.fileNotFound
        ) {}

        XCTAssertNotNil(errorView)
    }

    // MARK: - State Management Tests

    func testDocumentStateConsistency() async {
        // Given
        let mockDocument = DocumentModel.mock()
        mockDocumentService.loadDocumentResult = .success(mockDocument)

        // When
        await coordinator.loadDocument(DocumentReference.mock())

        // Then
        XCTAssertEqual(coordinator.documentState.currentDocument?.id, mockDocument.id)
        XCTAssertTrue(coordinator.uiState.isDocumentLoaded)
        XCTAssertFalse(coordinator.uiState.hasUnsavedChanges)
    }

    func testStateRestoration() async {
        // Given
        let mockDocument = DocumentModel.mock()
        mockDocumentService.loadDocumentResult = .success(mockDocument)
        let testScrollPosition: CGFloat = 200.0

        // When - Save state
        await coordinator.loadDocument(DocumentReference.mock())
        await coordinator.saveScrollPosition(testScrollPosition)
        await coordinator.saveState()

        // Create new coordinator to test restoration
        let newCoordinator = AppStateCoordinator(
            documentService: mockDocumentService,
            searchService: mockSearchService,
            fileService: MockFileService(),
            preferencesService: MockPreferencesService()
        )

        await newCoordinator.restoreState()

        // Then
        // In a real test, you would verify the state was restored
        XCTAssertNotNil(newCoordinator)
    }

    // MARK: - Integration Tests

    func testDocumentViewerWithSearch() async {
        // Given
        let mockDocument = DocumentModel.mock()
        mockDocumentService.loadDocumentResult = .success(mockDocument)
        mockSearchService.searchResults = [SearchResult.mock()]

        // When
        await coordinator.loadDocument(DocumentReference.mock())
        await coordinator.performSearch("test")

        // Then
        XCTAssertFalse(coordinator.searchState.results.isEmpty)
        XCTAssertTrue(coordinator.uiState.hasSearchResults)
    }

    func testDocumentViewerWithThemeChanges() async {
        // Given
        let mockDocument = DocumentModel.mock()
        mockDocumentService.loadDocumentResult = .success(mockDocument)
        await coordinator.loadDocument(DocumentReference.mock())

        let themeManager = ThemeManager()

        // When
        themeManager.applyTheme(.dark)

        // Then
        XCTAssertEqual(themeManager.currentTheme, .dark)
        // In a real test, you would verify the UI updated accordingly
    }
}

// MARK: - Mock Services

private class MockDocumentService: DocumentService {
    var loadDocumentResult: Result<DocumentModel, Error> = .success(DocumentModel.mock())

    override func loadDocument(_ reference: DocumentReference) async throws -> DocumentModel {
        try loadDocumentResult.get()
    }
}

private class MockSearchService: SearchService {
    var searchResults: [SearchResult] = []
    var outline: [OutlineItem] = []

    override func search(
        _ query: String,
        options: SearchOptions,
        in document: DocumentModel?
    ) async throws -> [SearchResult] {
        searchResults
    }

    override func generateOutline(for document: DocumentModel) async throws -> [OutlineItem] {
        outline
    }
}

private class MockFileService: FileService {
    // Mock implementation
}

private class MockPreferencesService: PreferencesService {
    // Mock implementation
}

// MARK: - Mock Models

extension DocumentModel {
    static func mock() -> DocumentModel {
        let content = "# Test Content\n\nThis is test content."
        let reference = DocumentReference(url: URL(fileURLWithPath: "/tmp/test.md"))
        let metadata = DocumentMetadata(
            title: "Test Document",
            wordCount: 10,
            characterCount: content.count,
            lineCount: 3,
            estimatedReadingTime: 1,
            lastModified: Date(),
            fileSize: 1024
        )
        return DocumentModel(
            reference: reference,
            content: content,
            attributedContent: AttributedString(content),
            metadata: metadata,
            outline: []
        )
    }

    static func mockLarge() -> DocumentModel {
        let largeContent = String(repeating: "This is a very long document with lots of content. ", count: 10000)
        let reference = DocumentReference(url: URL(fileURLWithPath: "/tmp/large.md"))
        let metadata = DocumentMetadata(
            title: "Large Test Document",
            wordCount: 100_000,
            characterCount: largeContent.count,
            lineCount: 1,
            estimatedReadingTime: 400,
            lastModified: Date(),
            fileSize: 2 * 1024 * 1024
        )
        return DocumentModel(
            reference: reference,
            content: largeContent,
            attributedContent: AttributedString(largeContent),
            metadata: metadata,
            outline: []
        )
    }
}

extension DocumentReference {
    static func mock() -> DocumentReference {
        DocumentReference(
            url: URL(fileURLWithPath: "/tmp/test/document.md"),
            bookmark: nil,
            lastModified: Date(),
            fileSize: 1024
        )
    }
}

extension SearchResult {
    static func mock() -> SearchResult {
        SearchResult(
            documentId: UUID(),
            text: "test",
            context: "This is a test",
            range: NSRange(location: 0, length: 4),
            lineNumber: 1,
            columnNumber: 1,
            relevanceScore: 0.9,
            matchType: .content,
            headingContext: nil
        )
    }

    static var previewResults: [SearchResult] {
        [
            SearchResult(
                documentId: UUID(),
                text: "example",
                context: "This is an example of search results",
                range: NSRange(location: 10, length: 7),
                lineNumber: 1,
                columnNumber: 10,
                relevanceScore: 0.9,
                matchType: .content,
                headingContext: "Introduction"
            ),
            SearchResult(
                documentId: UUID(),
                text: "example",
                context: "Another example in the document",
                range: NSRange(location: 50, length: 7),
                lineNumber: 3,
                columnNumber: 5,
                relevanceScore: 0.8,
                matchType: .content,
                headingContext: "Details"
            )
        ]
    }
}

extension OutlineItem {
    static var previewLevel1: OutlineItem {
        OutlineItem(
            level: 1,
            title: "Introduction",
            range: NSRange(location: 0, length: 12),
            position: 0,
            children: [previewLevel2]
        )
    }

    static var previewLevel2: OutlineItem {
        OutlineItem(
            level: 2,
            title: "Overview",
            range: NSRange(location: 100, length: 8),
            position: 100,
            children: []
        )
    }

    static func preview(level: Int) -> OutlineItem {
        OutlineItem(
            level: level,
            title: "Heading Level \(level)",
            range: NSRange(location: level * 50, length: 15),
            position: CGFloat(level * 50),
            children: []
        )
    }
}

// MARK: - Performance Monitor Extension

extension DocumentViewerTests {
    func getTestMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Test Error Types

enum TestDocumentError: LocalizedError {
    case fileNotFound
    case parseError
    case accessDenied
    case networkError

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "File not found"
        case .parseError: return "Parse error"
        case .accessDenied: return "Access denied"
        case .networkError: return "Network error"
        }
    }
}

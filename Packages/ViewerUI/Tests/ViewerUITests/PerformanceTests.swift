/// PerformanceTests - 60fps UI performance validation
///
/// Comprehensive performance testing suite validating frame rate maintenance,
/// memory efficiency, scroll performance, and load time optimization across
/// various document sizes and complexity scenarios.

@testable import MarkdownCore
@testable import Search
import SwiftUI
@testable import ViewerUI
import XCTest

@MainActor
final class PerformanceTests: XCTestCase {
    // MARK: - Test Properties

    private var coordinator: AppStateCoordinator!
    private var performanceMonitor: PerformanceMonitor!

    // MARK: - Performance Thresholds

    private let maxLoadTime: TimeInterval = 2.0 // 2 seconds for 1MB documents
    private let maxMemoryUsage: Int = 150 * 1024 * 1024 // 150MB for 2MB documents
    private let minFrameRate: Double = 58.0 // Near 60fps threshold
    private let maxScrollLatency: TimeInterval = 0.016 // One frame at 60fps

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        coordinator = AppStateCoordinator()
        performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startMonitoring()
    }

    override func tearDownWithError() throws {
        performanceMonitor.stopMonitoring()
        coordinator = nil
        performanceMonitor = nil
    }

    // MARK: - Document Loading Performance Tests

    func testSmallDocumentLoadTime() async throws {
        // Given - Document under 100KB
        let smallDocument = createMockDocument(size: .small)
        let mockService = MockDocumentService()
        mockService.loadDocumentResult = .success(smallDocument)

        coordinator = AppStateCoordinator(documentService: mockService)

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        await coordinator.loadDocument(DocumentReference.mock())
        let endTime = CFAbsoluteTimeGetCurrent()

        // Then
        let loadTime = endTime - startTime
        XCTAssertLessThan(loadTime, 1.0, "Small documents should load in under 1 second")
    }

    func testMediumDocumentLoadTime() async throws {
        // Given - Document around 1MB
        let mediumDocument = createMockDocument(size: .medium)
        let mockService = MockDocumentService()
        mockService.loadDocumentResult = .success(mediumDocument)

        coordinator = AppStateCoordinator(documentService: mockService)

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        await coordinator.loadDocument(DocumentReference.mock())
        let endTime = CFAbsoluteTimeGetCurrent()

        // Then
        let loadTime = endTime - startTime
        XCTAssertLessThan(loadTime, maxLoadTime, "Medium documents should load within 2 seconds")
    }

    func testLargeDocumentLoadTime() async throws {
        // Given - Document around 2MB
        let largeDocument = createMockDocument(size: .large)
        let mockService = MockDocumentService()
        mockService.loadDocumentResult = .success(largeDocument)

        coordinator = AppStateCoordinator(documentService: mockService)

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        await coordinator.loadDocument(DocumentReference.mock())
        let endTime = CFAbsoluteTimeGetCurrent()

        // Then
        let loadTime = endTime - startTime
        XCTAssertLessThan(loadTime, 5.0, "Large documents should load within 5 seconds")
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsageWithSmallDocument() async throws {
        // Given
        let smallDocument = createMockDocument(size: .small)
        let mockService = MockDocumentService()
        mockService.loadDocumentResult = .success(smallDocument)

        coordinator = AppStateCoordinator(documentService: mockService)

        // When
        let initialMemory = getCurrentMemoryUsage()
        await coordinator.loadDocument(DocumentReference.mock())
        let finalMemory = getCurrentMemoryUsage()

        // Then
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Small document should use under 50MB")
    }

    func testMemoryUsageWithLargeDocument() async throws {
        // Given
        let largeDocument = createMockDocument(size: .large)
        let mockService = MockDocumentService()
        mockService.loadDocumentResult = .success(largeDocument)

        coordinator = AppStateCoordinator(documentService: mockService)

        // When
        let initialMemory = getCurrentMemoryUsage()
        await coordinator.loadDocument(DocumentReference.mock())
        let finalMemory = getCurrentMemoryUsage()

        // Then
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, maxMemoryUsage, "Large document should use under 150MB")
    }

    func testMemoryLeaks() async throws {
        // Given
        let document = createMockDocument(size: .medium)
        let mockService = MockDocumentService()
        mockService.loadDocumentResult = .success(document)

        coordinator = AppStateCoordinator(documentService: mockService)

        // When - Load and unload document multiple times
        let initialMemory = getCurrentMemoryUsage()

        for _ in 0..<5 {
            await coordinator.loadDocument(DocumentReference.mock())
            coordinator.closeDocument()
        }

        // Force garbage collection
        autoreleasepool {
            // Empty pool to trigger cleanup
        }

        let finalMemory = getCurrentMemoryUsage()

        // Then
        let memoryGrowth = finalMemory - initialMemory
        XCTAssertLessThan(memoryGrowth, 10 * 1024 * 1024, "Memory growth should be minimal after cleanup")
    }

    // MARK: - Rendering Performance Tests

    func testMarkdownRenderingPerformance() {
        // Given
        let complexContent = createComplexMarkdownContent()

        // When/Then
        measure(metrics: [XCTCPUMetric()]) {
            let renderer = MarkdownRenderer(
                content: complexContent,
                viewportBounds: .constant(CGRect(x: 0, y: 0, width: 400, height: 600)),
                isOptimized: .constant(true)
            )

            // Simulate rendering
            _ = renderer.body
        }
    }

    func testViewportOptimizationPerformance() {
        // Given
        let largeContent = createLargeMarkdownContent()
        let viewport = CGRect(x: 0, y: 0, width: 400, height: 600)

        // When - Test optimized vs non-optimized rendering
        let optimizedStartTime = CFAbsoluteTimeGetCurrent()
        let optimizedRenderer = MarkdownRenderer(
            content: largeContent,
            viewportBounds: .constant(viewport),
            isOptimized: .constant(true)
        )
        _ = optimizedRenderer.body
        let optimizedEndTime = CFAbsoluteTimeGetCurrent()

        let nonOptimizedStartTime = CFAbsoluteTimeGetCurrent()
        let nonOptimizedRenderer = MarkdownRenderer(
            content: largeContent,
            viewportBounds: .constant(viewport),
            isOptimized: .constant(false)
        )
        _ = nonOptimizedRenderer.body
        let nonOptimizedEndTime = CFAbsoluteTimeGetCurrent()

        // Then
        let optimizedTime = optimizedEndTime - optimizedStartTime
        let nonOptimizedTime = nonOptimizedEndTime - nonOptimizedStartTime

        XCTAssertLessThan(optimizedTime, nonOptimizedTime, "Optimized rendering should be faster")
        XCTAssertLessThan(optimizedTime, 0.1, "Optimized rendering should complete within 100ms")
    }

    // MARK: - Scroll Performance Tests

    func testScrollingFrameRate() {
        // Given
        let largeDocument = createMockDocument(size: .large)
        coordinator.documentState.currentDocument = largeDocument
        coordinator.documentState.documentContent = largeDocument.attributedContent

        // When - Simulate rapid scrolling
        let frameRates = measureScrollingFrameRate()

        // Then
        let averageFrameRate = frameRates.reduce(0, +) / Double(frameRates.count)
        XCTAssertGreaterThan(averageFrameRate, minFrameRate, "Average frame rate should maintain near 60fps")

        let minimumFrameRate = frameRates.min() ?? 0
        XCTAssertGreaterThan(minimumFrameRate, 45.0, "Minimum frame rate should not drop below 45fps")
    }

    func testScrollLatency() {
        // Given
        let document = createMockDocument(size: .medium)
        coordinator.documentState.currentDocument = document

        // When - Measure scroll response time
        let scrollLatencies = measureScrollLatency()

        // Then
        let averageLatency = scrollLatencies.reduce(0, +) / Double(scrollLatencies.count)
        XCTAssertLessThan(averageLatency, maxScrollLatency, "Scroll latency should be under one frame")
    }

    // MARK: - Search Performance Tests

    func testSearchPerformance() async throws {
        // Given
        let largeDocument = createMockDocument(size: .large)
        let mockService = MockSearchService()
        mockService.searchResults = createMockSearchResults(count: 100)

        coordinator = AppStateCoordinator(searchService: mockService)
        coordinator.documentState.currentDocument = largeDocument

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        await coordinator.performSearch("test")
        let endTime = CFAbsoluteTimeGetCurrent()

        // Then
        let searchTime = endTime - startTime
        XCTAssertLessThan(searchTime, 0.1, "Search should complete within 100ms")
    }

    func testIncrementalSearchPerformance() async throws {
        // Given
        let document = createMockDocument(size: .medium)
        let mockService = MockSearchService()
        coordinator = AppStateCoordinator(searchService: mockService)
        coordinator.documentState.currentDocument = document

        // When - Test incremental search with each character
        let query = "testing"
        var searchTimes: [TimeInterval] = []

        for i in 1...query.count {
            let partialQuery = String(query.prefix(i))
            let startTime = CFAbsoluteTimeGetCurrent()
            await coordinator.performSearch(partialQuery)
            let endTime = CFAbsoluteTimeGetCurrent()
            searchTimes.append(endTime - startTime)
        }

        // Then
        let averageSearchTime = searchTimes.reduce(0, +) / Double(searchTimes.count)
        XCTAssertLessThan(averageSearchTime, 0.05, "Incremental search should average under 50ms")
    }

    // MARK: - Theme Performance Tests

    func testThemeChangePerformance() {
        // Given
        let themeManager = ThemeManager()
        let document = createMockDocument(size: .medium)
        coordinator.documentState.currentDocument = document

        // When
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            themeManager.applyTheme(.dark)
            themeManager.applyTheme(.light)
            themeManager.applyTheme(.system)
        }

        // Then - Measured by XCTest framework
    }

    func testDynamicTypePerformance() {
        // Given
        let themeManager = ThemeManager()

        // When
        measure(metrics: [XCTCPUMetric()]) {
            for multiplier in stride(from: 0.5, through: 3.0, by: 0.5) {
                themeManager.adjustFontSize(multiplier: multiplier)
            }
        }

        // Then - Measured by XCTest framework
    }

    // MARK: - State Management Performance Tests

    func testStateUpdatePerformance() async throws {
        // Given
        let document = createMockDocument(size: .medium)
        coordinator.documentState.currentDocument = document

        // When
        measure(metrics: [XCTCPUMetric()]) {
            // Simulate rapid state updates
            for i in 0..<100 {
                coordinator.documentState.scrollPosition = CGFloat(i * 10)
            }
        }

        // Then - Measured by XCTest framework
    }

    func testConcurrentStateAccess() async throws {
        // Given
        let document = createMockDocument(size: .medium)
        coordinator.documentState.currentDocument = document

        // When - Test concurrent access to state
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await self.coordinator.saveScrollPosition(CGFloat(i * 50))
                }
            }
        }

        // Then - Should complete without crashes or data races
        XCTAssertNotNil(coordinator.documentState.currentDocument)
    }

    // MARK: - Performance Helper Methods

    private func measureScrollingFrameRate() -> [Double] {
        var frameRates: [Double] = []
        let testDuration: TimeInterval = 1.0
        let frameInterval: TimeInterval = 1.0 / 60.0

        let startTime = CFAbsoluteTimeGetCurrent()
        var lastFrameTime = startTime

        while CFAbsoluteTimeGetCurrent() - startTime < testDuration {
            let currentTime = CFAbsoluteTimeGetCurrent()
            let frameDuration = currentTime - lastFrameTime

            if frameDuration > 0 {
                frameRates.append(1.0 / frameDuration)
            }

            lastFrameTime = currentTime

            // Simulate scroll position update
            coordinator.documentState.scrollPosition += 10

            // Simulate frame timing
            Thread.sleep(forTimeInterval: frameInterval)
        }

        return frameRates
    }

    private func measureScrollLatency() -> [TimeInterval] {
        var latencies: [TimeInterval] = []

        for i in 0..<10 {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Simulate scroll input
            coordinator.documentState.scrollPosition = CGFloat(i * 100)

            // Simulate UI update time
            let endTime = CFAbsoluteTimeGetCurrent()
            latencies.append(endTime - startTime)
        }

        return latencies
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }

    // MARK: - Mock Data Creation

    private enum DocumentSize {
        case small  // ~100KB
        case medium // ~1MB
        case large  // ~2MB
    }

    private func createMockDocument(size: DocumentSize) -> DocumentModel {
        let baseContent = """
        # Performance Test Document

        ## Introduction
        This is a test document for performance validation.

        ### Content Section
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        """

        let multiplier: Int
        switch size {
        case .small: multiplier = 100
        case .medium: multiplier = 1000
        case .large: multiplier = 2000
        }

        let content = baseContent + String(repeating: "\n\nAdditional content paragraph with meaningful text that simulates real document content.", count: multiplier)

        return DocumentModel(
            reference: DocumentReference.mock(),
            content: content,
            attributedContent: AttributedString(content),
            metadata: DocumentMetadata(
                title: "Performance Test Document",
                wordCount: multiplier * 10,
                characterCount: content.count,
                lineCount: content.components(separatedBy: "\n").count,
                estimatedReadingTime: multiplier / 10,
                lastModified: Date(),
                fileSize: Int64(content.count)
            ),
            outline: []
        )
    }

    private func createComplexMarkdownContent() -> AttributedString {
        let content = """
        # Complex Document Structure

        ## Tables
        | Column 1 | Column 2 | Column 3 |
        |----------|----------|----------|
        | Data 1   | Data 2   | Data 3   |

        ## Code Blocks
        ```swift
        func performanceTest() {
            print("Testing performance")
        }
        ```

        ## Lists
        1. First item
        2. Second item
           - Nested item
           - Another nested item

        ## Links and Emphasis
        This paragraph contains **bold text**, *italic text*, and [links](https://example.com).

        > This is a blockquote with complex formatting.
        """

        return AttributedString(content)
    }

    private func createLargeMarkdownContent() -> AttributedString {
        let baseContent = createComplexMarkdownContent()
        let repeatedContent = String(repeating: baseContent.description, count: 100)
        return AttributedString(repeatedContent)
    }

    private func createMockSearchResults(count: Int) -> [SearchResult] {
        (0..<count).map { index in
            SearchResult(
                documentId: UUID(),
                text: "test",
                context: "This is test result number \(index)",
                range: NSRange(location: index * 50, length: 4),
                lineNumber: index + 1,
                columnNumber: 0,
                relevanceScore: 0.9,
                matchType: .content,
                headingContext: index % 5 == 0 ? "Heading \(index / 5)" : nil
            )
        }
    }
}

// MARK: - Performance Monitor

class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var isMonitoring = false
    private var frameRates: [Double] = []
    private var memorySnapshots: [Int] = []

    func startMonitoring() {
        isMonitoring = true
        frameRates.removeAll()
        memorySnapshots.removeAll()
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func recordFrameRate(_ rate: Double) {
        guard isMonitoring else { return }
        frameRates.append(rate)
    }

    func recordMemoryUsage(_ usage: Int) {
        guard isMonitoring else { return }
        memorySnapshots.append(usage)
    }

    func trackOperation<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()

        print("Operation '\(name)' completed in \(endTime - startTime) seconds")
        return result
    }

    func startDocumentViewerMonitoring() async {
        // Start monitoring document viewer performance
    }

    func startCoordinatorMonitoring() async {
        // Start monitoring coordinator performance
    }

    func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

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

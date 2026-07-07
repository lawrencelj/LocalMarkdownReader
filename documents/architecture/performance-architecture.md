# Performance Architecture

## Performance Philosophy

The Swift Markdown Reader is designed with **performance-first architecture** to deliver exceptional user experience with 60fps UI responsiveness, sub-100ms file operations, and efficient memory usage across iOS and macOS platforms.

### Core Performance Principles
1. **60fps Target**: Maintain smooth 60fps UI performance under all conditions
2. **Responsive Loading**: Document parsing and rendering within 100ms
3. **Memory Efficiency**: Minimal memory footprint with intelligent resource management
4. **Lazy Operations**: Load and process data only when needed
5. **Background Processing**: Keep UI thread free for user interactions
6. **Predictive Caching**: Anticipate user needs with intelligent caching strategies

## Performance Targets and Requirements

### Primary Performance Metrics

| Metric | Target | Maximum | Measurement |
|--------|--------|---------|-------------|
| Document Loading | <100ms | 200ms | Time to display content |
| Search Response | <50ms | 100ms | Query to results |
| UI Frame Rate | 60fps | 55fps minimum | Core Animation metrics |
| Memory Usage | <50MB | 100MB | Peak memory for 2MB document |
| App Launch Time | <1s | 2s | Cold start to UI ready |
| File Access | <50ms | 100ms | Security scope to data |

### Secondary Performance Metrics

| Metric | Target | Maximum | Measurement |
|--------|--------|---------|-------------|
| Index Building | <200ms | 500ms | Document to searchable index |
| Theme Application | <16ms | 33ms | Theme change to UI update |
| Scroll Performance | 60fps | 55fps | During rapid scrolling |
| Memory Reclamation | <5s | 10s | After document close |
| Battery Impact | Minimal | <5% per hour | Background processing |

## Performance Architecture Layers

### Layer 1: Asynchronous Operations Framework

#### Structured Concurrency Implementation
```swift
@MainActor
class PerformanceOptimizedDocumentLoader {
    private let backgroundQueue = DispatchQueue(
        label: "document-processing",
        qos: .userInitiated,
        attributes: .concurrent
    )

    func loadDocument(_ reference: DocumentReference) async throws -> DocumentModel {
        // Parallel loading with timeout
        async let fileContent = loadFileContent(reference)
        async let metadata = extractMetadata(reference)

        let (content, meta) = try await (fileContent, metadata)

        // Parse on background queue with progress
        return try await withThrowingTaskGroup(of: DocumentComponent.self) { group in
            group.addTask {
                try await self.parseContent(content)
            }
            group.addTask {
                try await self.buildStructure(content)
            }
            group.addTask {
                try await self.generateSearchIndex(content)
            }

            var components: [DocumentComponent] = []
            for try await component in group {
                components.append(component)
            }

            return DocumentModel(components: components, metadata: meta)
        }
    }

    private func parseContent(_ content: String) async throws -> DocumentComponent {
        try await withUnsafeThrowingContinuation { continuation in
            backgroundQueue.async {
                do {
                    let parsed = try self.performParsing(content)
                    continuation.resume(returning: .content(parsed))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

#### Performance-Monitored Task Execution
```swift
class PerformanceMonitoredTask<Result> {
    private let name: String
    private let timeout: TimeInterval
    private let performanceTracker: PerformanceTracker

    init(name: String, timeout: TimeInterval = 1.0) {
        self.name = name
        self.timeout = timeout
        self.performanceTracker = PerformanceTracker.shared
    }

    func execute(_ operation: @escaping () async throws -> Result) async throws -> Result {
        let startTime = CACurrentMediaTime()

        let result = try await withThrowingTaskGroup(of: Result.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw PerformanceError.timeout(operation: name, duration: timeout)
            }

            guard let result = try await group.next() else {
                throw PerformanceError.groupExecutionFailed
            }

            group.cancelAll()
            return result
        }

        let duration = CACurrentMediaTime() - startTime
        performanceTracker.recordOperation(name: name, duration: duration)

        return result
    }
}
```

### Layer 2: Memory Management and Optimization

#### Intelligent Memory Pool
```swift
class MemoryPool {
    private struct Pool<T> {
        var available: [UnsafeMutablePointer<T>] = []
        var inUse: Set<UnsafeMutablePointer<T>> = []
        let capacity: Int
        let elementSize: Int

        init(capacity: Int) {
            self.capacity = capacity
            self.elementSize = MemoryLayout<T>.stride
        }
    }

    private var pools: [ObjectIdentifier: Any] = [:]
    private let lock = NSLock()

    func allocate<T>(_ type: T.Type, count: Int = 1) -> UnsafeMutablePointer<T> {
        lock.withLock {
            let id = ObjectIdentifier(type)

            if var pool = pools[id] as? Pool<T> {
                if let available = pool.available.popLast() {
                    pool.inUse.insert(available)
                    pools[id] = pool
                    return available
                }
            }

            // Allocate new if pool empty
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
            var pool = pools[id] as? Pool<T> ?? Pool<T>(capacity: 100)
            pool.inUse.insert(pointer)
            pools[id] = pool

            return pointer
        }
    }

    func deallocate<T>(_ pointer: UnsafeMutablePointer<T>, type: T.Type) {
        lock.withLock {
            let id = ObjectIdentifier(type)
            guard var pool = pools[id] as? Pool<T> else { return }

            pool.inUse.remove(pointer)

            if pool.available.count < pool.capacity {
                // Zero memory and return to pool
                pointer.initialize(repeating: T.self as! T, count: 1)
                pool.available.append(pointer)
            } else {
                // Pool full, actually deallocate
                pointer.deallocate()
            }

            pools[id] = pool
        }
    }
}
```

#### Automatic Memory Pressure Response
```swift
class MemoryPressureManager {
    private let monitor = DispatchSource.makeMemoryPressureSource(
        eventMask: [.warning, .critical],
        queue: .global(qos: .utility)
    )

    private weak var documentCache: DocumentCache?
    private weak var searchIndex: SearchIndex?
    private weak var imageCache: ImageCache?

    func startMonitoring() {
        monitor.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        monitor.resume()
    }

    private func handleMemoryPressure() {
        Task { @MainActor in
            // Clear non-essential caches
            await documentCache?.clearCache()
            await searchIndex?.compactIndex()
            await imageCache?.evictLeastRecentlyUsed()

            // Force garbage collection
            await performGarbageCollection()

            // Notify views to release unnecessary resources
            NotificationCenter.default.post(name: .memoryPressureDetected, object: nil)
        }
    }

    private func performGarbageCollection() async {
        // Trigger autoreleasepool cleanup
        await withUnsafeContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // Force cleanup of autorelease objects
                }
                continuation.resume()
            }
        }
    }
}
```

### Layer 3: Intelligent Caching System

#### Multi-Level Cache Architecture
```swift
class PerformanceCache<Key: Hashable, Value> {
    private struct CacheEntry {
        let value: Value
        let lastAccessed: Date
        let accessCount: Int
        let cost: Int
    }

    // L1: In-memory cache for immediate access
    private var l1Cache: [Key: CacheEntry] = [:]
    private let l1Capacity: Int = 50

    // L2: Compressed cache for medium-term storage
    private var l2Cache: [Key: Data] = [:]
    private let l2Capacity: Int = 200

    // L3: Disk cache for long-term storage
    private let l3Cache: DiskCache<Key, Value>

    private let lock = NSLock()
    private let compressionQueue = DispatchQueue(label: "cache-compression", qos: .utility)

    init(diskCacheURL: URL) {
        self.l3Cache = DiskCache(url: diskCacheURL)
    }

    func get(_ key: Key) async -> Value? {
        // Try L1 cache first
        if let entry = lock.withLock({ l1Cache[key] }) {
            lock.withLock {
                l1Cache[key] = CacheEntry(
                    value: entry.value,
                    lastAccessed: Date(),
                    accessCount: entry.accessCount + 1,
                    cost: entry.cost
                )
            }
            return entry.value
        }

        // Try L2 cache
        if let compressedData = lock.withLock({ l2Cache[key] }) {
            if let value = await decompress(compressedData) {
                // Promote to L1
                await promoteToL1(key: key, value: value)
                return value
            }
        }

        // Try L3 cache
        if let value = await l3Cache.get(key) {
            // Promote to L1
            await promoteToL1(key: key, value: value)
            return value
        }

        return nil
    }

    func set(_ key: Key, value: Value, cost: Int = 1) async {
        let entry = CacheEntry(
            value: value,
            lastAccessed: Date(),
            accessCount: 1,
            cost: cost
        )

        lock.withLock {
            l1Cache[key] = entry

            // Evict if over capacity
            if l1Cache.count > l1Capacity {
                evictFromL1()
            }
        }
    }

    private func evictFromL1() {
        // Use LFU (Least Frequently Used) eviction
        let sortedEntries = l1Cache.sorted { lhs, rhs in
            if lhs.value.accessCount != rhs.value.accessCount {
                return lhs.value.accessCount < rhs.value.accessCount
            }
            return lhs.value.lastAccessed < rhs.value.lastAccessed
        }

        let toEvict = sortedEntries.prefix(l1Cache.count - l1Capacity + 1)

        for (key, entry) in toEvict {
            l1Cache.removeValue(forKey: key)

            // Move to L2 cache
            Task {
                await moveToL2(key: key, value: entry.value)
            }
        }
    }

    private func moveToL2(key: Key, value: Value) async {
        guard let compressedData = await compress(value) else { return }

        lock.withLock {
            l2Cache[key] = compressedData

            if l2Cache.count > l2Capacity {
                evictFromL2()
            }
        }
    }

    private func evictFromL2() {
        let keysToEvict = Array(l2Cache.keys.prefix(l2Cache.count - l2Capacity + 1))

        for key in keysToEvict {
            if let data = l2Cache.removeValue(forKey: key) {
                // Move to L3 cache
                Task {
                    if let value = await decompress(data) {
                        await l3Cache.set(key, value: value)
                    }
                }
            }
        }
    }
}
```

#### Predictive Caching Strategy
```swift
class PredictiveCacheManager {
    private let cache: PerformanceCache<DocumentReference, DocumentModel>
    private let userBehaviorTracker: UserBehaviorTracker

    func predictAndCacheDocuments() async {
        let predictions = await userBehaviorTracker.predictNextDocuments()

        await withTaskGroup(of: Void.self) { group in
            for prediction in predictions.prefix(3) { // Cache top 3 predictions
                group.addTask {
                    await self.preloadDocument(prediction.reference)
                }
            }
        }
    }

    private func preloadDocument(_ reference: DocumentReference) async {
        guard await cache.get(reference) == nil else { return }

        do {
            let document = try await DocumentLoader.shared.loadDocument(reference)
            await cache.set(reference, value: document, cost: Int(reference.fileSize / 1024))
        } catch {
            // Silent failure for predictive loading
        }
    }
}

class UserBehaviorTracker {
    private var accessPatterns: [DocumentAccess] = []

    struct DocumentAccess {
        let reference: DocumentReference
        let timestamp: Date
        let duration: TimeInterval
    }

    struct Prediction {
        let reference: DocumentReference
        let confidence: Float
    }

    func recordAccess(_ reference: DocumentReference, duration: TimeInterval) {
        accessPatterns.append(DocumentAccess(
            reference: reference,
            timestamp: Date(),
            duration: duration
        ))

        // Keep only recent history
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        accessPatterns.removeAll { $0.timestamp < cutoff }
    }

    func predictNextDocuments() async -> [Prediction] {
        // Simple prediction based on recent access patterns
        let recentAccesses = accessPatterns.suffix(10)
        let frequency = Dictionary(grouping: recentAccesses) { $0.reference }

        return frequency.compactMap { reference, accesses in
            let confidence = Float(accesses.count) / Float(recentAccesses.count)
            return confidence > 0.1 ? Prediction(reference: reference, confidence: confidence) : nil
        }.sorted { $0.confidence > $1.confidence }
    }
}
```

### Layer 4: UI Performance Optimization

#### High-Performance Rendering Pipeline
```swift
class OptimizedMarkdownRenderer {
    private let renderingQueue = DispatchQueue(
        label: "markdown-rendering",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private let textCache = NSCache<NSString, NSAttributedString>()
    private let geometryCache = NSCache<NSString, TextGeometry>()

    func renderDocument(_ document: DocumentModel,
                       in bounds: CGRect,
                       theme: Theme) async -> RenderResult {
        let cacheKey = document.contentHash + theme.identifier + bounds.debugDescription

        // Check cache first
        if let cached = textCache.object(forKey: cacheKey as NSString) {
            return RenderResult(attributedString: cached, fromCache: true)
        }

        // Render on background queue
        let result = try await withThrowingTaskGroup(of: RenderChunk.self) { group in
            let chunks = document.splitIntoChunks(maxSize: 1000) // 1KB chunks

            for (index, chunk) in chunks.enumerated() {
                group.addTask {
                    return try await self.renderChunk(chunk, index: index, theme: theme)
                }
            }

            var renderedChunks: [RenderChunk] = []
            for try await chunk in group {
                renderedChunks.append(chunk)
            }

            return renderedChunks.sorted { $0.index < $1.index }
        }

        // Combine chunks
        let finalAttributedString = combineChunks(result)

        // Cache result
        textCache.setObject(finalAttributedString, forKey: cacheKey as NSString)

        return RenderResult(attributedString: finalAttributedString, fromCache: false)
    }

    private func renderChunk(_ chunk: DocumentChunk,
                           index: Int,
                           theme: Theme) async throws -> RenderChunk {
        return try await withUnsafeThrowingContinuation { continuation in
            renderingQueue.async {
                do {
                    let attributedString = try self.performChunkRendering(chunk, theme: theme)
                    continuation.resume(returning: RenderChunk(
                        index: index,
                        attributedString: attributedString
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

#### Viewport-Based Rendering
```swift
class ViewportRenderer {
    private var visibleRange: NSRange = NSRange(location: 0, length: 0)
    private var renderBuffer: Int = 1000 // characters before/after viewport

    func updateViewport(_ newRange: NSRange, in document: DocumentModel) async {
        guard newRange != visibleRange else { return }

        let oldRange = visibleRange
        visibleRange = newRange

        // Calculate what needs to be rendered
        let bufferedRange = NSRange(
            location: max(0, newRange.location - renderBuffer),
            length: min(document.content.length, newRange.length + 2 * renderBuffer)
        )

        // Only re-render if buffer exceeded
        if !oldRange.contains(bufferedRange) {
            await renderViewport(bufferedRange, in: document)
        }
    }

    private func renderViewport(_ range: NSRange, in document: DocumentModel) async {
        let visibleContent = document.content.substring(range)

        // Render only visible content with high priority
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .high) {
                await self.renderCriticalContent(visibleContent)
            }

            group.addTask(priority: .medium) {
                await self.prerenderAdjacentContent(range, in: document)
            }
        }
    }
}
```

### Layer 5: Performance Monitoring and Optimization

#### Real-Time Performance Metrics
```swift
class PerformanceMetricsCollector {
    private var metrics: [PerformanceMetric] = []
    private let metricsQueue = DispatchQueue(label: "metrics", qos: .utility)

    struct PerformanceMetric {
        let operation: String
        let duration: TimeInterval
        let memoryUsage: Int64
        let timestamp: Date
    }

    func recordMetric(operation: String, duration: TimeInterval, memoryUsage: Int64) {
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            memoryUsage: memoryUsage,
            timestamp: Date()
        )

        metricsQueue.async {
            self.metrics.append(metric)
            self.analyzePerformance(metric)
        }
    }

    private func analyzePerformance(_ metric: PerformanceMetric) {
        // Check for performance regressions
        let recentMetrics = metrics.suffix(10).filter { $0.operation == metric.operation }

        if recentMetrics.count >= 5 {
            let averageDuration = recentMetrics.map { $0.duration }.reduce(0, +) / Double(recentMetrics.count)

            if metric.duration > averageDuration * 2.0 {
                // Performance regression detected
                NotificationCenter.default.post(
                    name: .performanceRegression,
                    object: PerformanceAlert(
                        operation: metric.operation,
                        currentDuration: metric.duration,
                        expectedDuration: averageDuration
                    )
                )
            }
        }
    }

    func generatePerformanceReport() -> PerformanceReport {
        let groupedMetrics = Dictionary(grouping: metrics) { $0.operation }

        let operationStats = groupedMetrics.mapValues { metrics in
            OperationStats(
                averageDuration: metrics.map { $0.duration }.reduce(0, +) / Double(metrics.count),
                maxDuration: metrics.map { $0.duration }.max() ?? 0,
                minDuration: metrics.map { $0.duration }.min() ?? 0,
                averageMemory: metrics.map { $0.memoryUsage }.reduce(0, +) / Int64(metrics.count)
            )
        }

        return PerformanceReport(
            operationStats: operationStats,
            totalOperations: metrics.count,
            reportingPeriod: Date().timeIntervalSince(metrics.first?.timestamp ?? Date())
        )
    }
}
```

#### Automatic Performance Optimization
```swift
class AdaptivePerformanceManager {
    private let metricsCollector: PerformanceMetricsCollector
    private var currentOptimizations: Set<Optimization> = []

    enum Optimization: CaseIterable {
        case reduceAnimations
        case increaseCacheSize
        case enableCompressionCache
        case disableNonEssentialFeatures
        case reduceCacheRetention
    }

    func optimizeBasedOnMetrics() async {
        let report = metricsCollector.generatePerformanceReport()

        // Analyze bottlenecks
        let slowOperations = report.operationStats.filter { $0.value.averageDuration > 0.1 }

        if !slowOperations.isEmpty {
            await applyOptimizations(for: slowOperations)
        }

        // Check memory pressure
        let highMemoryOperations = report.operationStats.filter { $0.value.averageMemory > 50_000_000 }

        if !highMemoryOperations.isEmpty {
            await applyMemoryOptimizations()
        }
    }

    private func applyOptimizations(for operations: [String: OperationStats]) async {
        for optimization in Optimization.allCases {
            if !currentOptimizations.contains(optimization) &&
               shouldApplyOptimization(optimization, for: operations) {
                await enableOptimization(optimization)
                currentOptimizations.insert(optimization)
            }
        }
    }

    private func enableOptimization(_ optimization: Optimization) async {
        switch optimization {
        case .reduceAnimations:
            await UIView.setAnimationsEnabled(false)

        case .increaseCacheSize:
            await CacheManager.shared.increaseCacheSize(by: 2.0)

        case .enableCompressionCache:
            await CacheManager.shared.enableCompression()

        case .disableNonEssentialFeatures:
            await FeatureManager.shared.disableNonEssentialFeatures()

        case .reduceCacheRetention:
            await CacheManager.shared.reduceRetentionTime()
        }
    }
}
```

## Performance Testing Framework

### Automated Performance Tests
```swift
class PerformanceTestSuite: XCTestCase {

    func testDocumentLoadingPerformance() {
        let expectation = XCTestExpectation(description: "Document loading")

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let loader = DocumentLoader()
            let reference = DocumentReference.testReference(fileSize: 2_097_152) // 2MB

            let start = CACurrentMediaTime()
            Task {
                do {
                    let document = try await loader.loadDocument(reference)
                    let duration = CACurrentMediaTime() - start

                    XCTAssertLessThan(duration, 0.1, "Document loading should complete within 100ms")
                    XCTAssertNotNil(document)

                    expectation.fulfill()
                } catch {
                    XCTFail("Document loading failed: \(error)")
                }
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testSearchPerformance() {
        measure(metrics: [XCTClockMetric()]) {
            let searchEngine = MarkdownSearchEngine()
            let query = "test query"

            let start = CACurrentMediaTime()
            Task {
                let results = try await searchEngine.search(query)
                let duration = CACurrentMediaTime() - start

                XCTAssertLessThan(duration, 0.05, "Search should complete within 50ms")
                expectation.fulfill()
            }
        }
    }

    func testMemoryUsageWithLargeDocument() {
        let memoryBefore = getMemoryUsage()

        // Load large document
        let loader = DocumentLoader()
        let largeDocument = createLargeTestDocument(size: 2_097_152) // 2MB

        Task {
            _ = try await loader.loadDocument(largeDocument)

            let memoryAfter = getMemoryUsage()
            let memoryIncrease = memoryAfter - memoryBefore

            XCTAssertLessThan(memoryIncrease, 52_428_800, "Memory increase should be less than 50MB")
        }
    }

    func testUIResponseTimeUnderLoad() {
        // Simulate high load
        for _ in 0..<100 {
            Task.detached {
                // Perform background work
                await performBackgroundProcessing()
            }
        }

        // Test UI responsiveness
        let start = CACurrentMediaTime()
        let view = DocumentViewer()

        DispatchQueue.main.async {
            view.layoutIfNeeded()
            let duration = CACurrentMediaTime() - start

            XCTAssertLessThan(duration, 0.016, "UI update should complete within one frame (16ms)")
        }
    }
}
```

### Performance Benchmarking
```swift
class PerformanceBenchmark {
    static func runComprehensiveBenchmark() async -> BenchmarkResults {
        var results = BenchmarkResults()

        // Document loading benchmark
        results.documentLoading = await benchmarkDocumentLoading()

        // Search performance benchmark
        results.searchPerformance = await benchmarkSearchPerformance()

        // Memory efficiency benchmark
        results.memoryEfficiency = await benchmarkMemoryEfficiency()

        // UI performance benchmark
        results.uiPerformance = await benchmarkUIPerformance()

        return results
    }

    private static func benchmarkDocumentLoading() async -> BenchmarkResult {
        let fileSizes = [1024, 10_240, 102_400, 1_048_576, 2_097_152] // 1KB to 2MB
        var measurements: [FileSizeResult] = []

        for size in fileSizes {
            let document = createTestDocument(size: size)
            let loader = DocumentLoader()

            let durations = try! await (0..<10).asyncMap { _ in
                let start = CACurrentMediaTime()
                _ = try await loader.loadDocument(document)
                return CACurrentMediaTime() - start
            }

            let average = durations.reduce(0, +) / Double(durations.count)
            measurements.append(FileSizeResult(fileSize: size, averageDuration: average))
        }

        return BenchmarkResult(
            testName: "Document Loading",
            measurements: measurements,
            passesTarget: measurements.allSatisfy { $0.averageDuration < 0.1 }
        )
    }
}
```

## Performance Optimization Guidelines

### Development Performance Rules
1. **Always Profile First**: Use Instruments before optimizing
2. **Measure Impact**: Quantify performance improvements
3. **Optimize Hot Paths**: Focus on frequently executed code
4. **Background Processing**: Keep UI thread free
5. **Lazy Loading**: Load resources only when needed
6. **Memory Awareness**: Monitor and optimize memory usage
7. **Cache Strategically**: Cache expensive operations intelligently
8. **Test on Target Hardware**: Verify performance on minimum supported devices

### Performance Review Checklist
- [ ] All operations meet performance targets
- [ ] Memory usage stays within limits
- [ ] UI maintains 60fps under load
- [ ] No blocking operations on main thread
- [ ] Proper use of async/await patterns
- [ ] Efficient data structures chosen
- [ ] Caching strategy implemented where beneficial
- [ ] Performance tests pass consistently
/// AppStateCoordinator - Central state management coordination
///
/// Implements the Observable state management pattern from ADR-005,
/// coordinating between DocumentState, SearchState, UIState, and UserPreferences
/// with actor-based thread safety and performance optimization.

import FileAccess
import MarkdownCore
import Search
import SwiftUI

// Import Settings after MarkdownCore to avoid ambiguity
import Settings

/// Central application state coordinator implementing ADR-005 architecture
@MainActor
@Observable
public class AppStateCoordinator {
    // MARK: - State Objects

    public let documentState = DocumentState()
    public let searchState = SearchState()
    public let uiState = UIState()
    public let userPreferences = UserPreferences()

    // MARK: - Services

    private let documentService: DocumentService
    private let searchService: SearchService
    private let fileService: FileService
    private let preferencesService: PreferencesService

    // MARK: - Additional Services for iOS/macOS Apps

    private var _searchManager: SearchManagerProxy?
    private var _accessibilityManager: AccessibilityManager?
    private var _renderingEngine: RenderingEngine?
    private var _documentCache: DocumentCache?

    public var searchManager: SearchManagerProxy {
        if _searchManager == nil {
            _searchManager = SearchManagerProxy(searchService: searchService)
        }
        return _searchManager!
    }

    public var accessibilityManager: AccessibilityManager {
        if _accessibilityManager == nil {
            _accessibilityManager = AccessibilityManager()
        }
        return _accessibilityManager!
    }

    public var renderingEngine: RenderingEngine {
        if _renderingEngine == nil {
            _renderingEngine = RenderingEngine()
        }
        return _renderingEngine!
    }

    public var documentCache: DocumentCache {
        if _documentCache == nil {
            _documentCache = DocumentCache()
        }
        return _documentCache!
    }

    // MARK: - Performance Monitoring

    private let performanceMonitor = PerformanceMonitor.shared
    private var stateUpdateBatcher = StateUpdateBatcher()

    // MARK: - Initialization

    public init(
        documentService: DocumentService = DocumentService(),
        searchService: SearchService = SearchService(),
        fileService: FileService = FileService(),
        preferencesService: PreferencesService = PreferencesService()
    ) {
        self.documentService = documentService
        self.searchService = searchService
        self.fileService = fileService
        self.preferencesService = preferencesService

        setupStateObservation()
        setupPerformanceMonitoring()
    }

    // MARK: - App Lifecycle

    public func initialize() async {
        // Initialize all services and restore app state
        await performanceMonitor.trackOperation("app_initialization") {
            // Initialize services
            await self.searchManager.initialize()
            await self.accessibilityManager.initialize()
            await self.renderingEngine.initialize()
            await self.documentCache.initialize()

            // Load user preferences
            await self.userPreferences.loadSettings()
        }
    }

    // MARK: - Document Operations

    public func loadDocument(_ reference: DocumentReference) async {
        await self.performanceMonitor.trackOperation("document_load") {
            self.documentState.isLoading = true
            self.documentState.parseError = nil
            self.searchState.results = []
            self.searchState.query = ""

            do {
                let document = try await self.documentService.loadDocument(reference)
                self.documentState.currentDocument = document
                self.documentState.documentContent = document.attributedContent
                self.documentState.documentMetadata = document.metadata
                self.documentState.scrollPosition = 0

                // Update search index in background
                Task.detached { [weak self] in
                    guard let self = self else { return }
                    await self.searchService.indexDocument(document)
                    await self.updateSearchOutline()
                }

                // Add to recent files
                await self.userPreferences.addRecentFile(reference.url)

                // Update UI state
                self.uiState.isDocumentLoaded = true
                self.uiState.hasUnsavedChanges = false
            } catch {
                self.documentState.parseError = error
                self.uiState.isDocumentLoaded = false
            }

            self.documentState.isLoading = false
        }
    }

    public func refreshDocument() async {
        guard let currentDocument = self.documentState.currentDocument else { return }

        await self.loadDocument(currentDocument.reference)
    }

    public func retryDocumentLoad() async {
        guard let currentDocument = self.documentState.currentDocument else { return }

        await self.loadDocument(currentDocument.reference)
    }

    public func closeDocument() {
        documentState.currentDocument = nil
        documentState.documentContent = AttributedString()
        documentState.documentMetadata = nil
        documentState.scrollPosition = 0
        documentState.parseError = nil

        searchState.query = ""
        searchState.results = []
        searchState.outline = []
        searchState.currentResultIndex = 0

        uiState.isDocumentLoaded = false
        uiState.hasUnsavedChanges = false
    }

    // MARK: - Search Operations

    public func performSearch(_ query: String, options: SearchOptions = SearchOptions()) async {
        await self.performanceMonitor.trackOperation("search") {
            self.searchState.query = query
            self.searchState.isSearching = true
            self.searchState.searchError = nil

            guard !query.isEmpty else {
                self.searchState.results = []
                self.searchState.currentResultIndex = 0
                self.searchState.isSearching = false
                return
            }

            do {
                let results = try await self.searchService.search(
                    query,
                    options: options,
                    in: self.documentState.currentDocument
                )

                self.searchState.results = results
                self.searchState.currentResultIndex = 0

                // Update document highlighting
                if let document = self.documentState.currentDocument {
                    let highlightedContent = await self.highlightSearchResults(
                        in: document.attributedContent,
                        for: results
                    )
                    self.documentState.documentContent = highlightedContent
                }
            } catch {
                self.searchState.searchError = error
                self.searchState.results = []
            }

            self.searchState.isSearching = false
        }
    }

    public func jumpToSearchResult(at index: Int) async {
        guard index >= 0 && index < self.searchState.results.count else { return }

        self.searchState.currentResultIndex = index
        let result = self.searchState.results[index]

        // Calculate scroll position for result
        let targetPosition = await self.calculateScrollPosition(for: result)
        self.documentState.scrollPosition = targetPosition
        self.documentState.selectedRange = result.range

        // Update highlighting
        await self.updateSearchHighlighting()
    }

    public func highlightAllSearchResults() async {
        guard !self.searchState.results.isEmpty else { return }

        // Implement highlighting for all results
        if let document = self.documentState.currentDocument {
            let highlightedContent = await self.highlightSearchResults(
                in: document.attributedContent,
                for: self.searchState.results
            )
            self.documentState.documentContent = highlightedContent
        }
    }

    // MARK: - Navigation Operations

    public func jumpToHeading(_ headingId: String) async {
        guard let outline = self.searchState.outline.first(where: { $0.id == headingId }) else { return }

        let targetPosition = await self.calculateScrollPosition(for: outline)
        self.documentState.scrollPosition = targetPosition

        // Update selection
        self.documentState.selectedRange = outline.range
    }

    public func getCurrentHeading() async -> OutlineItem? {
        let currentPosition = self.documentState.scrollPosition

        // Find the heading closest to current scroll position
        return self.searchState.outline.last { outline in
            outline.position <= currentPosition
        }
    }

    public func saveScrollPosition(_ position: CGFloat) async {
        self.documentState.scrollPosition = position

        // Debounced save to user preferences
        self.stateUpdateBatcher.batchUpdate { [weak self] in
            Task {
                guard let self = self else { return }
                await self.userPreferences.saveScrollPosition(
                    position,
                    for: self.documentState.currentDocument?.reference.url
                )
            }
        }
    }

    /// Validate document access (for iOS refresh functionality)
    public func validateDocumentAccess(for reference: DocumentReference) async {
        // Check if document is still accessible
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: reference.url.path) else {
            // Document no longer exists, clear it
            closeDocument()
            return
        }

        // Check if document was modified externally
        do {
            let attributes = try fileManager.attributesOfItem(atPath: reference.url.path)
            if let modificationDate = attributes[.modificationDate] as? Date,
               modificationDate > reference.lastModified {
                // Document was modified, offer to reload
                await refreshDocument()
            }
        } catch {
            print("Failed to check document attributes: \(error)")
        }
    }

    // MARK: - State Restoration

    public func restoreState() async {
        await self.performanceMonitor.trackOperation("state_restoration") {
            // Load user preferences
            await self.userPreferences.loadSettings()

            // Restore last document if available
            if let lastDocumentURL = await self.userPreferences.getLastDocument() {
                let lastDocumentRef = DocumentReference(url: lastDocumentURL)
                await self.loadDocument(lastDocumentRef)

                // Restore scroll position
                if let scrollPosition = await self.userPreferences.getScrollPosition(for: lastDocumentURL) {
                    self.documentState.scrollPosition = scrollPosition
                }
            }

            // Restore UI state
            self.uiState.sidebarVisible = await self.userPreferences.getSidebarVisibility()
            self.uiState.searchVisible = await self.userPreferences.getSearchVisibility()
        }
    }

    public func saveState() async {
        await self.performanceMonitor.trackOperation("state_persistence") {
            // Save current document reference
            if let currentDocument = self.documentState.currentDocument {
                await self.userPreferences.setLastDocument(currentDocument.reference.url)
                await self.userPreferences.saveScrollPosition(
                    self.documentState.scrollPosition,
                    for: currentDocument.reference.url
                )
            }

            // Save UI state
            await self.userPreferences.setSidebarVisibility(self.uiState.sidebarVisible)
            await self.userPreferences.setSearchVisibility(self.uiState.searchVisible)

            // Save preferences
            await self.userPreferences.saveSettings()
        }
    }

    // MARK: - Private Methods

    private func setupStateObservation() {
        // Monitor state changes for validation and synchronization
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                await self.validateStateConsistency()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func setupPerformanceMonitoring() {
        Task { [weak self] in
            guard let self = self else { return }
            await self.performanceMonitor.startCoordinatorMonitoring()
        }
    }

    private func validateStateConsistency() async {
        // Validate search state consistency
        if self.searchState.results.isEmpty {
            self.documentState.selectedRange = nil
        } else if self.searchState.currentResultIndex < self.searchState.results.count {
            let currentResult = self.searchState.results[self.searchState.currentResultIndex]
            self.documentState.selectedRange = currentResult.range
        }

        // Validate UI state consistency
        self.uiState.isDocumentLoaded = self.documentState.currentDocument != nil
        self.uiState.hasSearchResults = !self.searchState.results.isEmpty
    }

    private func updateSearchOutline() async {
        guard let document = self.documentState.currentDocument else { return }

        do {
            let outline = try await self.searchService.generateOutline(for: document)
            self.searchState.outline = outline
        } catch {
            self.searchState.outline = []
        }
    }

    private func highlightSearchResults(
        in content: AttributedString,
        for results: [SearchResult]
    ) async -> AttributedString {
        // Implement search result highlighting
        var highlightedContent = content

        for result in results {
            if let nsRange = result.attributedRange,
               let range = Range(nsRange, in: highlightedContent) {
                highlightedContent[range].backgroundColor = .yellow.opacity(0.3)
                highlightedContent[range].foregroundColor = .black
            }
        }

        return highlightedContent
    }

    private func updateSearchHighlighting() async {
        guard !self.searchState.results.isEmpty,
              self.searchState.currentResultIndex < self.searchState.results.count else { return }

        // Update highlighting to emphasize current result
        if let document = self.documentState.currentDocument {
            let highlightedContent = await self.highlightSearchResults(
                in: document.attributedContent,
                for: self.searchState.results
            )

            // Emphasize current result
            let currentResult = self.searchState.results[self.searchState.currentResultIndex]
            if let nsRange = currentResult.attributedRange {
                var emphasized = highlightedContent
                // Convert NSRange to Range<AttributedString.Index>
                if let range = Range(nsRange, in: emphasized) {
                    emphasized[range].backgroundColor = .orange.opacity(0.6)
                    emphasized[range].font = emphasized[range].font?.bold()
                    self.documentState.documentContent = emphasized
                }
            }
        }
    }

    private func calculateScrollPosition(for result: SearchResult) async -> CGFloat {
        // Calculate scroll position to show result
        // This would integrate with the document layout system
        CGFloat(result.lineNumber) * 20.0 // Simplified calculation
    }

    private func calculateScrollPosition(for outline: OutlineItem) async -> CGFloat {
        // Calculate scroll position for heading
        outline.position
    }
}

// MARK: - State Objects

@Observable
public class DocumentState {
    public var currentDocument: DocumentModel?
    public var isLoading: Bool = false
    public var parseError: Error?
    public var documentContent = AttributedString()
    public var documentMetadata: DocumentMetadata?
    public var scrollPosition: CGFloat = 0
    public var selectedRange: NSRange?
    public var zoomLevel: Double = 1.0

    public init() {}
}

@Observable
public class SearchState {
    public var query: String = ""
    public var results: [SearchResult] = []
    public var isSearching: Bool = false
    public var currentResultIndex: Int = 0
    public var searchError: Error?
    public var outline: [OutlineItem] = []

    public init() {}
}

@Observable
public class UIState {
    public var isDocumentLoaded: Bool = false
    public var sidebarVisible: Bool = true
    public var searchVisible: Bool = false
    public var hasUnsavedChanges: Bool = false
    public var hasSearchResults: Bool = false
    public var currentModalPresentation: ModalPresentation?
    public var showingDocumentPicker: Bool = false

    public init() {}
}

public enum ModalPresentation: Identifiable {
    case documentPicker
    case settings
    case themeSelection
    case about

    public var id: String {
        switch self {
        case .documentPicker: return "documentPicker"
        case .settings: return "settings"
        case .themeSelection: return "themeSelection"
        case .about: return "about"
        }
    }
}

// MARK: - Supporting Types

// DocumentReference is now imported from MarkdownCore

// DocumentMetadata is now imported from MarkdownCore

// MARK: - Performance Support

private final class StateUpdateBatcher: @unchecked Sendable {
    private var pendingUpdates: [() -> Void] = []
    private var updateTimer: Timer?
    private let lock = NSLock()

    func batchUpdate(_ update: @escaping () -> Void) {
        self.lock.withLock {
            self.pendingUpdates.append(update)
        }
        self.scheduleFlush()
    }

    private func scheduleFlush() {
        self.updateTimer?.invalidate()
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                self.flushUpdates()
            }
        }
    }

    private func flushUpdates() {
        let updates = self.lock.withLock {
            let current = self.pendingUpdates
            self.pendingUpdates.removeAll()
            return current
        }

        for update in updates {
            update()
        }
    }
}

// MARK: - Preview Support

extension AppStateCoordinator {
    public static var preview: AppStateCoordinator {
        let coordinator = AppStateCoordinator()
        // Setup preview state
        return coordinator
    }

    public static var previewLoading: AppStateCoordinator {
        let coordinator = AppStateCoordinator()
        coordinator.documentState.isLoading = true
        return coordinator
    }

    public static var previewEmpty: AppStateCoordinator {
        let coordinator = AppStateCoordinator()
        // Empty state for preview
        return coordinator
    }

    public static var previewWithSearch: AppStateCoordinator {
        let coordinator = AppStateCoordinator()
        coordinator.searchState.query = "example"
        coordinator.searchState.results = SearchResult.previewResults
        return coordinator
    }
}

// MARK: - Placeholder Service Classes

/// Search manager proxy to provide compatibility with iOS/macOS apps
public class SearchManagerProxy {
    private let searchService: SearchService

    init(searchService: SearchService) {
        self.searchService = searchService
    }

    public func initialize() async {
        // Initialize search indexing
    }

    public func initializeIndex() async {
        // Initialize search index
    }

    public func updateIndex() async {
        // Update search index
    }

    public func clearInMemoryIndex() {
        // Clear in-memory search index
    }
}

/// Accessibility manager for platform-specific accessibility features
public class AccessibilityManager {
    public func initialize() async {
        // Initialize accessibility features
    }

    public func updateVoiceOverStatus() {
        // Update VoiceOver status
    }
}

/// Rendering engine for platform-specific rendering optimizations
public class RenderingEngine {
    public func initialize() async {
        // Initialize rendering engine
    }

    public func enableMetalAcceleration() {
        // Enable Metal acceleration on supported platforms
    }

    public func reduceCacheSize() async {
        // Reduce rendering cache size for memory pressure
    }
}

/// Document cache for performance optimization
public class DocumentCache {
    public func initialize() async {
        // Initialize document cache
    }

    public func clearCache() async {
        // Clear document cache
    }
}

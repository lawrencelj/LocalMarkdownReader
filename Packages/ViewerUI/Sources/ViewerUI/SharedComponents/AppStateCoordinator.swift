/// AppStateCoordinator - Central state management coordination
///
/// Implements the Observable state management pattern from ADR-005,
/// coordinating between DocumentState, SearchState, UIState, and UserPreferences
/// with actor-based thread safety and performance optimization.

import SwiftUI
import MarkdownCore
import Search
import Settings
import FileAccess

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

    // MARK: - Document Operations

    public func loadDocument(_ reference: DocumentReference) async {
        await performanceMonitor.trackOperation("document_load") {
            documentState.isLoading = true
            documentState.parseError = nil
            searchState.results = []
            searchState.query = ""

            do {
                let document = try await documentService.loadDocument(reference)
                documentState.currentDocument = document
                documentState.documentContent = document.attributedContent
                documentState.documentMetadata = document.metadata
                documentState.scrollPosition = 0

                // Update search index in background
                Task.detached {
                    await self.searchService.indexDocument(document)
                    await self.updateSearchOutline()
                }

                // Add to recent files
                await userPreferences.addRecentFile(reference)

                // Update UI state
                uiState.isDocumentLoaded = true
                uiState.hasUnsavedChanges = false

            } catch {
                documentState.parseError = error
                uiState.isDocumentLoaded = false
            }

            documentState.isLoading = false
        }
    }

    public func refreshDocument() async {
        guard let currentDocument = documentState.currentDocument else { return }

        await loadDocument(currentDocument.reference)
    }

    public func retryDocumentLoad() async {
        guard let currentDocument = documentState.currentDocument else { return }

        await loadDocument(currentDocument.reference)
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
        await performanceMonitor.trackOperation("search") {
            searchState.query = query
            searchState.isSearching = true
            searchState.searchError = nil

            guard !query.isEmpty else {
                searchState.results = []
                searchState.currentResultIndex = 0
                searchState.isSearching = false
                return
            }

            do {
                let results = try await searchService.search(
                    query,
                    options: options,
                    in: documentState.currentDocument
                )

                searchState.results = results
                searchState.currentResultIndex = 0

                // Update document highlighting
                if let document = documentState.currentDocument {
                    let highlightedContent = await highlightSearchResults(
                        in: document.attributedContent,
                        for: results
                    )
                    documentState.documentContent = highlightedContent
                }

            } catch {
                searchState.searchError = error
                searchState.results = []
            }

            searchState.isSearching = false
        }
    }

    public func jumpToSearchResult(at index: Int) async {
        guard index >= 0 && index < searchState.results.count else { return }

        searchState.currentResultIndex = index
        let result = searchState.results[index]

        // Calculate scroll position for result
        let targetPosition = await calculateScrollPosition(for: result)
        documentState.scrollPosition = targetPosition
        documentState.selectedRange = result.range

        // Update highlighting
        await updateSearchHighlighting()
    }

    public func highlightAllSearchResults() async {
        guard !searchState.results.isEmpty else { return }

        // Implement highlighting for all results
        if let document = documentState.currentDocument {
            let highlightedContent = await highlightSearchResults(
                in: document.attributedContent,
                for: searchState.results
            )
            documentState.documentContent = highlightedContent
        }
    }

    // MARK: - Navigation Operations

    public func jumpToHeading(_ headingId: String) async {
        guard let outline = searchState.outline.first(where: { $0.id == headingId }) else { return }

        let targetPosition = await calculateScrollPosition(for: outline)
        documentState.scrollPosition = targetPosition

        // Update selection
        documentState.selectedRange = outline.range
    }

    public func getCurrentHeading() async -> OutlineItem? {
        let currentPosition = documentState.scrollPosition

        // Find the heading closest to current scroll position
        return searchState.outline.last { outline in
            outline.position <= currentPosition
        }
    }

    public func saveScrollPosition(_ position: CGFloat) async {
        documentState.scrollPosition = position

        // Debounced save to user preferences
        stateUpdateBatcher.batchUpdate {
            Task {
                await self.userPreferences.saveScrollPosition(
                    position,
                    for: self.documentState.currentDocument?.reference
                )
            }
        }
    }

    // MARK: - State Restoration

    public func restoreState() async {
        await performanceMonitor.trackOperation("state_restoration") {
            // Load user preferences
            await userPreferences.loadSettings()

            // Restore last document if available
            if let lastDocumentRef = await userPreferences.getLastDocument() {
                await loadDocument(lastDocumentRef)

                // Restore scroll position
                if let scrollPosition = await userPreferences.getScrollPosition(for: lastDocumentRef) {
                    documentState.scrollPosition = scrollPosition
                }
            }

            // Restore UI state
            uiState.sidebarVisible = await userPreferences.getSidebarVisibility()
            uiState.searchVisible = await userPreferences.getSearchVisibility()
        }
    }

    public func saveState() async {
        await performanceMonitor.trackOperation("state_persistence") {
            // Save current document reference
            if let currentDocument = documentState.currentDocument {
                await userPreferences.setLastDocument(currentDocument.reference)
                await userPreferences.saveScrollPosition(
                    documentState.scrollPosition,
                    for: currentDocument.reference
                )
            }

            // Save UI state
            await userPreferences.setSidebarVisibility(uiState.sidebarVisible)
            await userPreferences.setSearchVisibility(uiState.searchVisible)

            // Save preferences
            await userPreferences.saveSettings()
        }
    }

    // MARK: - Private Methods

    private func setupStateObservation() {
        // Monitor state changes for validation and synchronization
        Task {
            while !Task.isCancelled {
                await validateStateConsistency()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func setupPerformanceMonitoring() {
        Task {
            await performanceMonitor.startCoordinatorMonitoring()
        }
    }

    private func validateStateConsistency() async {
        // Validate search state consistency
        if searchState.results.isEmpty {
            documentState.selectedRange = nil
        } else if searchState.currentResultIndex < searchState.results.count {
            let currentResult = searchState.results[searchState.currentResultIndex]
            documentState.selectedRange = currentResult.range
        }

        // Validate UI state consistency
        uiState.isDocumentLoaded = documentState.currentDocument != nil
        uiState.hasSearchResults = !searchState.results.isEmpty
    }

    private func updateSearchOutline() async {
        guard let document = documentState.currentDocument else { return }

        do {
            let outline = try await searchService.generateOutline(for: document)
            searchState.outline = outline
        } catch {
            searchState.outline = []
        }
    }

    private func highlightSearchResults(
        in content: AttributedString,
        for results: [SearchResult]
    ) async -> AttributedString {
        // Implement search result highlighting
        var highlightedContent = content

        for result in results {
            if let range = result.attributedRange {
                highlightedContent[range].backgroundColor = .yellow.opacity(0.3)
                highlightedContent[range].foregroundColor = .black
            }
        }

        return highlightedContent
    }

    private func updateSearchHighlighting() async {
        guard !searchState.results.isEmpty,
              searchState.currentResultIndex < searchState.results.count else { return }

        // Update highlighting to emphasize current result
        if let document = documentState.currentDocument {
            let highlightedContent = await highlightSearchResults(
                in: document.attributedContent,
                for: searchState.results
            )

            // Emphasize current result
            let currentResult = searchState.results[searchState.currentResultIndex]
            if let nsRange = currentResult.attributedRange {
                var emphasized = highlightedContent
                // Convert NSRange to Range<AttributedString.Index>
                if let range = Range(nsRange, in: emphasized) {
                    emphasized[range].backgroundColor = .orange.opacity(0.6)
                    emphasized[range].font = emphasized[range].font?.bold()
                    documentState.documentContent = emphasized
                }
            }
        }
    }

    private func calculateScrollPosition(for result: SearchResult) async -> CGFloat {
        // Calculate scroll position to show result
        // This would integrate with the document layout system
        return CGFloat(result.lineNumber) * 20.0 // Simplified calculation
    }

    private func calculateScrollPosition(for outline: OutlineItem) async -> CGFloat {
        // Calculate scroll position for heading
        return outline.position
    }
}

// MARK: - State Objects

@Observable
public class DocumentState {
    public var currentDocument: DocumentModel?
    public var isLoading: Bool = false
    public var parseError: Error?
    public var documentContent: AttributedString = AttributedString()
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

public struct DocumentReference: Codable, Hashable {
    public let url: URL
    public let bookmark: Data?
    public let lastModified: Date

    public init(url: URL, bookmark: Data? = nil, lastModified: Date = Date()) {
        self.url = url
        self.bookmark = bookmark
        self.lastModified = lastModified
    }
}

public struct DocumentMetadata {
    public let title: String?
    public let wordCount: Int
    public let estimatedReadingTime: Int
    public let lastModified: Date
    public let fileSize: Int64

    public init(title: String?, wordCount: Int, estimatedReadingTime: Int, lastModified: Date, fileSize: Int64) {
        self.title = title
        self.wordCount = wordCount
        self.estimatedReadingTime = estimatedReadingTime
        self.lastModified = lastModified
        self.fileSize = fileSize
    }
}

// MARK: - Performance Support

private final class StateUpdateBatcher: @unchecked Sendable {
    private var pendingUpdates: [() -> Void] = []
    private var updateTimer: Timer?
    private let lock = NSLock()

    func batchUpdate(_ update: @escaping () -> Void) {
        lock.withLock {
            pendingUpdates.append(update)
        }
        scheduleFlush()
    }

    private func scheduleFlush() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                self.flushUpdates()
            }
        }
    }

    private func flushUpdates() {
        let updates = lock.withLock {
            let current = pendingUpdates
            pendingUpdates.removeAll()
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
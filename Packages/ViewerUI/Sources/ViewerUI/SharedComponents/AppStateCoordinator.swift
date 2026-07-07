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
    public let userPreferences = CoordinatorUserPreferences()

    // MARK: - Per-Pane Find Bars

    /// Find bar state for the source (raw text) pane. Independent of `contentFind`.
    public let sourceFind = FindState()
    /// Find bar state for the rendered content pane. Independent of `sourceFind`.
    public let contentFind = FindState()
    /// Pane that most recently held keyboard focus; Cmd-F opens this pane's find bar.
    public var lastFocusedPane: FindPane = .content

    /// Opens the find bar for whichever pane last had focus (Cmd-F handler).
    public func showFindForFocusedPane() {
        switch lastFocusedPane {
        case .source: sourceFind.show()
        case .content: contentFind.show()
        }
    }

    /// The find state for the pane that last had focus (Find Next/Previous target).
    public var focusedFind: FindState {
        lastFocusedPane == .source ? sourceFind : contentFind
    }

    // MARK: - Services

    private let documentService: DocumentService
    public let searchService: SearchService
    private let fileService: FileService
    private let preferencesService: PreferencesService

    // MARK: - Managers (referenced by app entry points)

    public let searchManager = SearchManager()
    public let documentCache = DocumentCache()
    public let renderingEngine = RenderingEngine()
    public let accessibilityManager = AccessibilityManager()
    public let themeManager = ThemeManager()

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

    // MARK: - Initialization

    /// Initialize the coordinator and its services
    public func initialize() async {
        await PerformanceMonitor.shared.initialize()
    }

    // MARK: - Document Operations

    public var currentDocumentRequiresSaveAs: Bool {
        guard let document = documentState.currentDocument else { return false }
        return documentState.untitledDocumentIDs.contains(document.id)
    }

    public func createNewDocument() async {
        let reference = DocumentReference(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("MarkdownReader-\(UUID().uuidString)")
                .appendingPathComponent("Untitled.md"),
            fileSize: 0
        )

        do {
            let document = try await documentService.parseMarkdown("", reference: reference)
            documentState.currentDocument = document
            documentState.documentContent = document.attributedContent
            documentState.documentMetadata = document.metadata
            documentState.scrollPosition = 0
            documentState.scrollToHeadingID = nil
            documentState.parseError = nil
            documentState.openDocuments.append(document)
            documentState.activeDocumentIndex = documentState.openDocuments.count - 1
            documentState.untitledDocumentIDs.insert(document.id)

            searchState.query = ""
            searchState.results = []
            searchState.outline = []
            uiState.editorContent = ""
            uiState.isDocumentLoaded = true
            uiState.hasUnsavedChanges = false
        } catch {
            documentState.parseError = error
        }
    }

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
                documentState.scrollToHeadingID = nil

                // Populate editor with raw source
                uiState.editorContent = document.content

                // Add to open documents (or switch if already open)
                if let existingIndex = documentState.openDocuments.firstIndex(where: {
                    isSameDocumentURL($0.reference.url, reference.url)
                }) {
                    documentState.openDocuments[existingIndex] = document
                    documentState.activeDocumentIndex = existingIndex
                } else {
                    documentState.openDocuments.append(document)
                    documentState.activeDocumentIndex = documentState.openDocuments.count - 1
                }

                // Keep search state consistent when loading returns.
                await searchService.indexDocument(document)
                await updateSearchOutline()

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
        let closingDocumentID = documentState.currentDocument?.id
        documentState.currentDocument = nil
        documentState.documentContent = AttributedString()
        documentState.documentMetadata = nil
        documentState.scrollPosition = 0
        documentState.parseError = nil
        documentState.scrollToHeadingID = nil
        documentState.compareDocument = nil
        documentState.isCompareMode = false

        // Remove from open documents
        if !documentState.openDocuments.isEmpty {
            documentState.openDocuments.remove(at: documentState.activeDocumentIndex)
            if documentState.openDocuments.isEmpty {
                documentState.activeDocumentIndex = 0
            } else {
                documentState.activeDocumentIndex = min(documentState.activeDocumentIndex, documentState.openDocuments.count - 1)
                let doc = documentState.openDocuments[documentState.activeDocumentIndex]
                documentState.currentDocument = doc
                documentState.documentContent = doc.attributedContent
                documentState.documentMetadata = doc.metadata
            }
        }

        if let closingDocumentID {
            documentState.untitledDocumentIDs.remove(closingDocumentID)
        }

        searchState.query = ""
        searchState.results = []
        searchState.outline = []
        searchState.currentResultIndex = 0

        uiState.isDocumentLoaded = documentState.currentDocument != nil
        uiState.hasUnsavedChanges = false
        uiState.editorContent = documentState.currentDocument?.content ?? ""
    }

    // MARK: - Multi-Document Operations

    /// Switch to a specific open document by index
    public func switchToDocument(at index: Int) async {
        guard index >= 0 && index < documentState.openDocuments.count else { return }
        documentState.activeDocumentIndex = index
        let doc = documentState.openDocuments[index]
        documentState.currentDocument = doc
        documentState.documentContent = doc.attributedContent
        documentState.documentMetadata = doc.metadata
        documentState.scrollPosition = 0
        documentState.scrollToHeadingID = nil

        uiState.isDocumentLoaded = true
        uiState.editorContent = doc.content
        uiState.hasUnsavedChanges = false

        // Keep search state consistent when switching returns.
        await searchService.indexDocument(doc)
        await updateSearchOutline()
    }

    /// Close a specific document tab
    public func closeDocument(at index: Int) {
        guard index >= 0 && index < documentState.openDocuments.count else { return }

        if documentState.openDocuments.count == 1 {
            closeDocument()
            return
        }

        let closingDocument = documentState.openDocuments.remove(at: index)
        documentState.untitledDocumentIDs.remove(closingDocument.id)

        let newIndex = min(index, documentState.openDocuments.count - 1)
        documentState.activeDocumentIndex = newIndex
        Task { await switchToDocument(at: newIndex) }
    }

    // MARK: - Compare Mode

    /// Open a second document for comparison
    public func openForCompare(_ reference: DocumentReference) async {
        do {
            let document = try await documentService.loadDocument(reference)
            documentState.compareDocument = document
            documentState.isCompareMode = true
        } catch {
            documentState.parseError = error
        }
    }

    /// Exit compare mode
    public func exitCompareMode() {
        documentState.compareDocument = nil
        documentState.isCompareMode = false
    }

    // MARK: - Editor Operations

    /// Save edited content back to file and refresh the rendered view
    public func saveEditedContent(_ content: String) async {
        guard let currentDocument = documentState.currentDocument else { return }

        guard !currentDocumentRequiresSaveAs else {
            uiState.hasUnsavedChanges = true
            return
        }

        await saveEditedContent(content, to: currentDocument.reference.url)
    }

    /// Save the active document to a new destination and continue editing it there.
    public func saveEditedContent(_ content: String, to destinationURL: URL) async {
        guard let currentDocument = documentState.currentDocument else { return }
        let oldDocumentID = currentDocument.id
        let destinationURL = destinationURL.standardizedFileURL

        do {
            try content.write(to: destinationURL, atomically: true, encoding: .utf8)

            // Re-parse and update the rendered view
            let reference = DocumentReference(
                url: destinationURL,
                fileSize: Int64(content.utf8.count)
            )
            let document = try await documentService.loadDocument(reference)
            documentState.currentDocument = document
            documentState.documentContent = document.attributedContent
            documentState.documentMetadata = document.metadata
            documentState.parseError = nil
            documentState.untitledDocumentIDs.remove(oldDocumentID)

            // Update in open documents list
            if let idx = documentState.openDocuments.firstIndex(where: { $0.id == oldDocumentID }) {
                documentState.openDocuments[idx] = document
            }

            uiState.editorContent = content
            uiState.hasUnsavedChanges = false

            await userPreferences.addRecentFile(reference)

            // Keep search state consistent when saving returns.
            await searchService.indexDocument(document)
            await updateSearchOutline()
        } catch {
            documentState.parseError = error
        }
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
        // Return content as-is; highlighting is handled by the renderer
        return content
    }

    private func updateSearchHighlighting() async {
        // Highlighting is handled at the view layer
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

    private func isSameDocumentURL(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath() ==
            rhs.standardizedFileURL.resolvingSymlinksInPath()
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
    public var scrollToHeadingID: String?

    // Multi-document support
    public var openDocuments: [DocumentModel] = []
    public var activeDocumentIndex: Int = 0
    public var untitledDocumentIDs: Set<UUID> = []

    // Compare mode
    public var compareDocument: DocumentModel?
    public var isCompareMode: Bool = false

    // Line sync between source and content
    public var focusedLine: Int? = nil

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
    public var showLineNumbers: Bool = false
    public var editorContent: String = ""

    /// Global docking edge for both find bars. Persisted across launches.
    public var findBarPosition: FindBarPosition = UIState.loadFindBarPosition() {
        didSet {
            UserDefaults.standard.set(findBarPosition.rawValue, forKey: UIState.findBarPositionKey)
        }
    }

    public init() {}

    private static let findBarPositionKey = "findBarPosition"

    private static func loadFindBarPosition() -> FindBarPosition {
        let raw = UserDefaults.standard.string(forKey: findBarPositionKey) ?? ""
        return FindBarPosition(rawValue: raw) ?? .top
    }
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

// MARK: - Supporting Types (re-exported from MarkdownCore)

// DocumentReference and DocumentMetadata are defined in MarkdownCore
// and imported via the MarkdownCore dependency

// MARK: - Performance Support

private class StateUpdateBatcher {
    private var pendingUpdates: [() -> Void] = []
    private var updateTimer: Timer?

    func batchUpdate(_ update: @escaping () -> Void) {
        pendingUpdates.append(update)
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
        let updates = pendingUpdates
        pendingUpdates.removeAll()

        for update in updates {
            update()
        }
    }
}

// MARK: - Coordinator User Preferences

/// User preferences state managed by the coordinator
@MainActor
@Observable
public class CoordinatorUserPreferences {
    public var recentFiles: [DocumentReference] = []

    private let userDefaults = UserDefaults.standard
    private let recentFilesKey = "MarkdownReader.CoordinatorRecentFiles"

    public init() {
        loadRecentFiles()
    }

    public func addRecentFile(_ reference: DocumentReference) async {
        recentFiles.removeAll { $0.url == reference.url }
        recentFiles.insert(reference, at: 0)
        if recentFiles.count > 20 {
            recentFiles = Array(recentFiles.prefix(20))
        }
        saveRecentFiles()
    }

    public func refreshRecentFiles() async {
        loadRecentFiles()
    }

    public func updateRecentFiles(_ files: [DocumentReference]) async {
        recentFiles = files
        saveRecentFiles()
    }

    public func clearRecentFiles() async {
        recentFiles.removeAll()
        saveRecentFiles()
    }

    public func loadSettings() async {
        loadRecentFiles()
    }

    public func saveSettings() async {
        saveRecentFiles()
    }

    public func getLastDocument() async -> DocumentReference? {
        if let data = userDefaults.data(forKey: "MarkdownReader.LastDocument"),
           let ref = try? JSONDecoder().decode(DocumentReference.self, from: data) {
            return ref
        }
        return nil
    }

    public func setLastDocument(_ reference: DocumentReference) async {
        if let data = try? JSONEncoder().encode(reference) {
            userDefaults.set(data, forKey: "MarkdownReader.LastDocument")
        }
    }

    public func saveScrollPosition(_ position: CGFloat, for reference: DocumentReference?) async {
        guard let reference = reference else { return }
        userDefaults.set(Double(position), forKey: "MarkdownReader.Scroll.\(reference.url.absoluteString)")
    }

    public func getScrollPosition(for reference: DocumentReference) async -> CGFloat? {
        let value = userDefaults.double(forKey: "MarkdownReader.Scroll.\(reference.url.absoluteString)")
        return value == 0 ? nil : CGFloat(value)
    }

    public func getSidebarVisibility() async -> Bool {
        return userDefaults.object(forKey: "MarkdownReader.SidebarVisible") as? Bool ?? true
    }

    public func setSidebarVisibility(_ visible: Bool) async {
        userDefaults.set(visible, forKey: "MarkdownReader.SidebarVisible")
    }

    public func getSearchVisibility() async -> Bool {
        return userDefaults.bool(forKey: "MarkdownReader.SearchVisible")
    }

    public func setSearchVisibility(_ visible: Bool) async {
        userDefaults.set(visible, forKey: "MarkdownReader.SearchVisible")
    }

    private func loadRecentFiles() {
        if let data = userDefaults.data(forKey: recentFilesKey),
           let files = try? JSONDecoder().decode([DocumentReference].self, from: data) {
            recentFiles = files
        }
    }

    private func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            userDefaults.set(data, forKey: recentFilesKey)
        }
    }
}

// MARK: - Supporting Managers

/// Search manager for background indexing
@MainActor
public class SearchManager {
    private let searchService = SearchService()

    public init() {}

    public func initializeIndex() async {
        // Initialize search index
    }

    public func updateIndex() async {
        // Update search index
    }

    public func clearInMemoryIndex() {
        // Clear in-memory search index to free memory
    }
}

/// Document cache for performance
@MainActor
public class DocumentCache {
    private var cache: [URL: DocumentModel] = [:]

    public init() {}

    public func clearCache() async {
        cache.removeAll()
    }

    public func get(_ url: URL) -> DocumentModel? {
        return cache[url]
    }

    public func set(_ document: DocumentModel, for url: URL) {
        cache[url] = document
    }
}

/// Rendering engine for performance optimization
@MainActor
public class RenderingEngine {
    public init() {}

    public func enableMetalAcceleration() {
        // Enable Metal-based rendering acceleration
    }

    public func reduceCacheSize() async {
        // Reduce rendering cache size under memory pressure
    }
}

/// Accessibility manager
@MainActor
public class AccessibilityManager {
    public init() {}

    public func updateVoiceOverStatus() {
        // Update VoiceOver status tracking
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

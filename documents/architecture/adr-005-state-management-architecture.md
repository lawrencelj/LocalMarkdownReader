# ADR-005: State Management Architecture

## Status
**APPROVED** - 2025-01-23

## Context

The Swift Markdown Reader requires efficient state management to handle document loading, user preferences, search state, navigation state, and UI interactions while maintaining 60fps performance and providing a responsive user experience across iOS and macOS platforms.

### Requirements
- **Performance**: State updates must not impact 60fps UI performance
- **Consistency**: State synchronization across multiple views and platforms
- **Persistence**: User preferences and app state preservation across launches
- **Testability**: State management must be easily testable and debuggable
- **Scalability**: Architecture should support future feature additions
- **Cross-Platform**: Unified state management for iOS and macOS
- **Memory Efficiency**: Minimal memory overhead for state tracking

### State Management Concerns
1. **Document State**: Current document, parsing status, content, metadata
2. **Search State**: Search queries, results, highlighting, navigation
3. **UI State**: Navigation state, sidebar visibility, theme selection
4. **User Preferences**: Settings, feature toggles, recent files
5. **File Access State**: Security scopes, file permissions, bookmarks
6. **Performance State**: Loading states, error conditions, progress tracking

### Options Considered

#### Option 1: SwiftUI @Observable with Actor-Based State Management (SELECTED)
- **Pros**:
  - Native SwiftUI integration with automatic UI updates
  - Modern Swift concurrency with actor-based thread safety
  - Minimal performance overhead with granular UI updates
  - Easy testing with dependency injection
  - Clean separation of concerns with observable objects
  - Built-in SwiftUI optimization for view invalidation
- **Cons**:
  - Requires iOS 17.0+ and macOS 14.0+ for @Observable
  - Learning curve for actor-based patterns
  - Manual state coordination across complex workflows

#### Option 2: The Composable Architecture (TCA)
- **Pros**:
  - Comprehensive state management with built-in effects
  - Excellent testability with deterministic state changes
  - Strong developer tooling and debugging capabilities
  - Proven architecture for complex SwiftUI applications
- **Cons**:
  - External dependency adding complexity and bundle size
  - Steeper learning curve and development overhead
  - May be overkill for single-document application scope
  - Performance overhead for simple state changes

#### Option 3: Traditional @StateObject and @ObservableObject
- **Pros**:
  - Wide platform compatibility (iOS 14.0+, macOS 11.0+)
  - Well-understood patterns and extensive documentation
  - Simple implementation for basic state management
- **Cons**:
  - Manual Combine integration for complex state flows
  - Potential performance issues with large state objects
  - Thread safety requires manual implementation
  - Less efficient UI updates compared to @Observable

#### Option 4: Redux-Style State Management
- **Pros**:
  - Predictable state changes with single source of truth
  - Excellent debugging and time-travel capabilities
  - Clear separation between state and business logic
- **Cons**:
  - Significant boilerplate code and complexity
  - Performance overhead for frequent state updates
  - Doesn't leverage SwiftUI's native state management optimizations

## Decision

**Selected: SwiftUI @Observable with Actor-Based State Management**

### Implementation Strategy

#### 1. Observable State Objects
```swift
@Observable
class DocumentState {
    var currentDocument: DocumentModel?
    var isLoading: Bool = false
    var parseError: Error?
    var documentContent: AttributedString = AttributedString()
    var documentMetadata: DocumentMetadata?

    // Document-specific state
    var scrollPosition: CGFloat = 0
    var selectedRange: NSRange?
    var zoomLevel: Double = 1.0
}

@Observable
class SearchState {
    var query: String = ""
    var results: [SearchResult] = []
    var isSearching: Bool = false
    var currentResultIndex: Int = 0
    var searchError: Error?
}
```

#### 2. Actor-Based State Coordination
```swift
@MainActor
class AppStateCoordinator: ObservableObject {
    let documentState = DocumentState()
    let searchState = SearchState()
    let uiState = UIState()
    let userPreferences = UserPreferences()

    private let documentService: DocumentService
    private let searchService: SearchService

    func loadDocument(_ reference: DocumentReference) async {
        documentState.isLoading = true
        documentState.parseError = nil

        do {
            let document = try await documentService.loadDocument(reference)
            documentState.currentDocument = document
            documentState.documentContent = document.attributedContent
            documentState.documentMetadata = document.metadata

            // Update search index
            await searchService.indexDocument(document)
        } catch {
            documentState.parseError = error
        }

        documentState.isLoading = false
    }
}
```

#### 3. State Persistence Layer
```swift
actor UserPreferences {
    private let storage: UserDefaultsStorage

    private(set) var theme: Theme = .system
    private(set) var fontSize: CGFloat = 16
    private(set) var lineSpacing: CGFloat = 1.2
    private(set) var recentFiles: [DocumentReference] = []

    func updateTheme(_ newTheme: Theme) async {
        theme = newTheme
        await storage.save(theme, for: .theme)
    }

    func addRecentFile(_ reference: DocumentReference) async {
        recentFiles.insert(reference, at: 0)
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }
        await storage.save(recentFiles, for: .recentFiles)
    }
}
```

### State Architecture Components

#### Core State Objects
- **DocumentState**: Current document, content, and document-specific UI state
- **SearchState**: Search queries, results, and search UI state
- **UIState**: Navigation, sidebar, modal presentations, and view state
- **UserPreferences**: Persistent user settings and preferences
- **FileAccessState**: File permissions, bookmarks, and security scopes

#### State Coordination Layer
- **AppStateCoordinator**: Main actor coordinating state across objects
- **StateUpdater**: Handles complex state update workflows
- **StatePersistence**: Manages state persistence and restoration
- **StateValidator**: Validates state consistency and integrity

#### Service Integration Layer
- **DocumentService**: Document loading and parsing operations
- **SearchService**: Search indexing and query operations
- **FileService**: File access and bookmark management
- **PreferencesService**: Settings persistence and synchronization

### State Update Patterns

#### Async State Updates
```swift
extension AppStateCoordinator {
    func performSearch(_ query: String) async {
        searchState.query = query
        searchState.isSearching = true
        searchState.searchError = nil

        do {
            let results = try await searchService.search(query)
            searchState.results = results
            searchState.currentResultIndex = 0

            // Update document highlighting
            if let document = documentState.currentDocument {
                let highlightedContent = highlightSearchResults(
                    in: document.attributedContent,
                    for: results
                )
                documentState.documentContent = highlightedContent
            }
        } catch {
            searchState.searchError = error
        }

        searchState.isSearching = false
    }
}
```

#### State Synchronization
```swift
class StateSynchronizer {
    private let coordinator: AppStateCoordinator

    func synchronizeStates() {
        // Sync search state with document state
        if coordinator.searchState.results.isEmpty {
            coordinator.documentState.selectedRange = nil
        } else {
            let currentResult = coordinator.searchState.results[
                coordinator.searchState.currentResultIndex
            ]
            coordinator.documentState.selectedRange = currentResult.range
        }

        // Sync UI state with document state
        coordinator.uiState.isDocumentLoaded = coordinator.documentState.currentDocument != nil
    }
}
```

### UI Integration Patterns

#### SwiftUI View Integration
```swift
struct DocumentView: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    var body: some View {
        VStack {
            if coordinator.documentState.isLoading {
                ProgressView("Loading document...")
            } else if let error = coordinator.documentState.parseError {
                ErrorView(error: error)
            } else {
                MarkdownContentView(
                    content: coordinator.documentState.documentContent,
                    scrollPosition: coordinator.documentState.scrollPosition
                )
            }
        }
        .searchable(
            text: Binding(
                get: { coordinator.searchState.query },
                set: { query in
                    Task {
                        await coordinator.performSearch(query)
                    }
                }
            )
        )
    }
}
```

#### Environment Setup
```swift
@main
struct MarkdownReaderApp: App {
    @State private var coordinator = AppStateCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .task {
                    await coordinator.restoreState()
                }
        }
    }
}
```

## Consequences

### Positive Consequences
- **Performance**: @Observable provides optimal SwiftUI integration with minimal UI updates
- **Thread Safety**: Actor-based state management ensures thread-safe operations
- **Maintainability**: Clear separation of concerns with observable state objects
- **Testability**: Easy unit testing with injectable dependencies
- **Modern Swift**: Leverages latest Swift concurrency and SwiftUI features
- **Scalability**: Architecture supports adding new state objects and features

### Negative Consequences
- **Platform Requirements**: Requires iOS 17.0+ and macOS 14.0+ for @Observable
- **Learning Curve**: Team must learn actor-based patterns and @Observable
- **State Coordination**: Manual coordination required for complex state interactions
- **Debugging**: Actor-based debugging can be more complex than traditional approaches

### Risk Mitigation
- **Platform Compatibility**: Target platforms support required iOS/macOS versions
- **Team Training**: Provide comprehensive training on Swift concurrency and @Observable
- **State Testing**: Comprehensive unit testing for all state objects and coordination
- **Performance Monitoring**: Monitor state update performance and UI responsiveness
- **Documentation**: Detailed documentation of state management patterns and conventions

### State Persistence Strategy

#### Automatic Persistence
```swift
class StatePersistenceManager {
    private let coordinator: AppStateCoordinator

    func enableAutomaticPersistence() {
        // Observe state changes and persist automatically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.persistCurrentState()
            }
        }
    }

    private func persistCurrentState() async {
        let appState = AppPersistedState(
            documentState: coordinator.documentState.persistableState,
            uiState: coordinator.uiState.persistableState,
            searchState: coordinator.searchState.persistableState
        )

        try? await UserDefaults.standard.save(appState, for: .appState)
    }
}
```

#### State Restoration
```swift
extension AppStateCoordinator {
    func restoreState() async {
        guard let persistedState = try? await UserDefaults.standard.load(
            AppPersistedState.self,
            for: .appState
        ) else { return }

        documentState.restore(from: persistedState.documentState)
        uiState.restore(from: persistedState.uiState)
        searchState.restore(from: persistedState.searchState)

        // Restore document if reference is available
        if let documentRef = persistedState.documentState.lastDocument {
            await loadDocument(documentRef)
        }
    }
}
```

### Performance Optimization

#### Granular State Updates
```swift
@Observable
class DocumentState {
    var content: AttributedString = AttributedString() {
        didSet {
            // Only notify views that depend on content
            notifyContentObservers()
        }
    }

    var scrollPosition: CGFloat = 0 {
        didSet {
            // Only notify scroll-dependent views
            notifyScrollObservers()
        }
    }
}
```

#### State Update Batching
```swift
class StateUpdateBatcher {
    private var pendingUpdates: [StateUpdate] = []
    private var updateTimer: Timer?

    func batchUpdate(_ update: StateUpdate) {
        pendingUpdates.append(update)
        scheduleFlush()
    }

    private func scheduleFlush() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { _ in
            self.flushUpdates()
        }
    }

    private func flushUpdates() {
        let updates = pendingUpdates
        pendingUpdates.removeAll()

        Task { @MainActor in
            for update in updates {
                await update.apply()
            }
        }
    }
}
```

## Technical Implementation

### State Object Protocols
```swift
protocol StateObject: Observable {
    associatedtype PersistableState: Codable

    var persistableState: PersistableState { get }
    func restore(from state: PersistableState)
}

protocol StateCoordination {
    func coordinate<T: StateObject>(_ stateObject: T) async
    func validateConsistency() -> StateValidationResult
}
```

### Error Handling in State Management
```swift
enum StateError: LocalizedError {
    case invalidStateTransition
    case persistenceFailure(Error)
    case coordinationFailure
    case validationFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidStateTransition:
            return "Invalid state transition attempted"
        case .persistenceFailure(let error):
            return "Failed to persist state: \(error.localizedDescription)"
        case .coordinationFailure:
            return "State coordination failed"
        case .validationFailure(let message):
            return "State validation failed: \(message)"
        }
    }
}
```

## Validation Criteria
- [ ] All state updates maintain 60fps UI performance
- [ ] State synchronization works correctly across views
- [ ] State persistence and restoration function properly
- [ ] Unit tests cover all state objects and coordination logic
- [ ] Error handling provides graceful degradation
- [ ] Memory usage remains efficient with state tracking
- [ ] Cross-platform state management works identically
- [ ] State management supports concurrent operations safely
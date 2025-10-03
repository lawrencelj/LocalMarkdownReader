/// DocumentViewer - Main markdown content display component
///
/// Enterprise-grade document viewer with performance optimization, accessibility support,
/// and cross-platform adaptation. Implements viewport-based rendering for large documents
/// while maintaining 60fps performance.

import MarkdownCore
import Settings
import SwiftUI

/// Main document viewer component with performance optimization
public struct DocumentViewer: View {
    // MARK: - State Management

    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.platform) private var platform
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Accessibility

    @AccessibilityFocusState private var isContentFocused: Bool
    @State private var accessibilityAnnouncementQueue: [String] = []

    // MARK: - Performance Tracking

    @State private var lastScrollPosition: CGFloat = 0
    @State private var viewportBounds: CGRect = .zero
    @State private var isPerformanceOptimized = true

    // MARK: - Initialization

    public init() {}

    // MARK: - View Body

    public var body: some View {
        Group {
            if coordinator.uiState.isEditing {
                MarkdownEditorView(coordinator: coordinator)
            } else {
                GeometryReader { geometry in
                    content(in: geometry)
                        .onAppear {
                            coordinator.uiState.viewportHeight = geometry.size.height
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            coordinator.uiState.viewportHeight = newSize.height
                        }
                }
                .background(Color.systemBackground)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Markdown Document Content")
                .accessibilityValue(accessibilityValue)
                .accessibilityAction(.default) {
                    isContentFocused = true
                }
                .onAppear {
                    setupPerformanceMonitoring()
                    announceDocumentLoaded()
                }
                .onChange(of: coordinator.documentState.currentDocument) { _, _ in
                    handleDocumentChange()
                }
                .task {
                    await monitorPerformanceMetrics()
                }
            }
        }
    }

    // MARK: - Content Builder

    @ViewBuilder
    private func content(in geometry: GeometryProxy) -> some View {
        if coordinator.documentState.isLoading {
            loadingView
        } else if let error = coordinator.documentState.parseError {
            ErrorView(
                error: error
            )                {
                    Task {
                        await coordinator.retryDocumentLoad()
                    }
                }
        } else if coordinator.documentState.currentDocument != nil {
            documentContentView(in: geometry)
        } else {
            EmptyStateView(
                title: "No Document Selected",
                message: "Choose a markdown file to begin reading",
                systemImage: "doc.text"
            )
        }
    }

    // MARK: - Document Content View

    @ViewBuilder
    private func documentContentView(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            if let document = coordinator.documentState.currentDocument,
               !document.syntaxErrors.isEmpty {
                SyntaxErrorBanner(errors: document.syntaxErrors) { error in
                    Task { await coordinator.jumpToSyntaxError(error) }
                }
                .padding(.horizontal, horizontalPadding)
            }

            // Document Content with inline syntax error highlighting
            ScrollView(.vertical) {
                MarkdownRenderer(
                    content: coordinator.documentState.documentContent,
                    syntaxErrors: coordinator.documentState.currentDocument?.syntaxErrors ?? [],
                    showLineNumbers: coordinator.editorSettings.lineNumbers,
                    viewportBounds: $viewportBounds,
                    isOptimized: $isPerformanceOptimized
                )
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // ScrollPosition is handled via onScrollGeometryChange below
            .scrollIndicators(platform.supportsCursor ? .visible : .hidden)
            .coordinateSpace(name: "documentScroll")
            // Handle scroll position tracking with platform compatibility
            .modifier(ScrollTrackingModifier(onScrollChange: handleScrollChange))
            .refreshable {
                await coordinator.refreshDocument()
            }
            .searchable(
                text: searchBinding,
                placement: {
                    #if os(iOS)
                    return platform.isIOS ? .navigationBarDrawer(displayMode: .always) : .automatic
                    #else
                    return .automatic
                    #endif
                }()
            )
            .platformConditional(.macOS) { view in
                view
                    .focusable()
                    .focusEffectDisabled()
                    .onKeyPress(.space) {
                        scrollToNextPage()
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        scrollUp()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        scrollDown()
                        return .handled
                    }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .accessibilityLabel("Loading document")

            Text("Loading document...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemBackground)
    }

    // MARK: - Computed Properties

    private var horizontalPadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            return platform.isTouch ? 20 : 40
        case .large, .xLarge:
            return platform.isTouch ? 24 : 48
        case .xxLarge, .xxxLarge:
            return platform.isTouch ? 28 : 56
        default: // Accessibility sizes
            return platform.isTouch ? 32 : 64
        }
    }

    private var accessibilityValue: String {
        guard let document = coordinator.documentState.currentDocument else {
            return "No document loaded"
        }

        let wordCount = document.metadata.wordCount
        let readingTime = document.metadata.estimatedReadingTime

        return "Document with \(wordCount) words, estimated reading time \(readingTime) minutes"
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { coordinator.searchState.query },
            set: { query in
                Task {
                    await coordinator.performSearch(query)
                }
            }
        )
    }

    // MARK: - Performance Methods

    private func setupPerformanceMonitoring() {
        // Configure performance tracking
        isPerformanceOptimized = true

        // Monitor memory usage
        Task {
            await PerformanceMonitor.shared.startDocumentViewerMonitoring()
        }
    }

    private func handleScrollChange(from oldValue: CGFloat, to newValue: CGFloat) {
        // Update viewport bounds for performance optimization
        let scrollDelta = abs(newValue - oldValue)

        // Enable performance optimization for fast scrolling
        isPerformanceOptimized = scrollDelta > 100

        // Update scroll position for persistence
        coordinator.documentState.scrollPosition = newValue

        // Debounced position saving
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await coordinator.saveScrollPosition(newValue)
        }
    }

    private func handleDocumentChange() {
        // Reset scroll position for new document
        coordinator.documentState.scrollPosition = 0
        lastScrollPosition = 0

        // Clear search state
        coordinator.searchState.query = ""
        coordinator.searchState.results = []

        // Announce document loaded
        announceDocumentLoaded()
    }

    private func announceDocumentLoaded() {
        guard let document = coordinator.documentState.currentDocument else { return }

        let announcement = "Document loaded: \(document.metadata.title ?? "Untitled"), \(document.metadata.wordCount) words"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AccessibilityNotification.Announcement(announcement)
                .post()
        }
    }

    // MARK: - Navigation Methods

    private func scrollToNextPage() {
        // Scroll by viewport height
        let scrollAmount = viewportBounds.height * 0.8
        let newPosition = coordinator.documentState.scrollPosition + scrollAmount

        withAnimation(.easeInOut(duration: 0.3)) {
            coordinator.documentState.scrollPosition = newPosition
        }
    }

    private func scrollUp() {
        let scrollAmount: CGFloat = 50
        let newPosition = max(0, coordinator.documentState.scrollPosition - scrollAmount)

        withAnimation(.easeOut(duration: 0.2)) {
            coordinator.documentState.scrollPosition = newPosition
        }
    }

    private func scrollDown() {
        let scrollAmount: CGFloat = 50
        let newPosition = coordinator.documentState.scrollPosition + scrollAmount

        withAnimation(.easeOut(duration: 0.2)) {
            coordinator.documentState.scrollPosition = newPosition
        }
    }

    private func scrollToLine(_ line: Int) {
        // Approximate scroll position based on line number
        // Assume average line height of 20pt
        let estimatedLineHeight: CGFloat = 20
        let targetPosition = CGFloat(line) * estimatedLineHeight

        withAnimation(.easeInOut(duration: 0.4)) {
            coordinator.documentState.scrollPosition = targetPosition
        }

        // Announce navigation for accessibility
        let announcement = "Jumped to line \(line)"
        AccessibilityNotification.Announcement(announcement).post()
    }

    // MARK: - Performance Monitoring

    private func monitorPerformanceMetrics() async {
        while !Task.isCancelled {
            // Monitor frame rate and memory usage
            await PerformanceMetrics.shared.recordFrameRate()
            await PerformanceMetrics.shared.recordMemoryUsage()

            try? await Task.sleep(for: .seconds(1))
        }
    }
}

// MARK: - Platform-Specific Scroll Tracking

struct ScrollTrackingModifier: ViewModifier {
    let onScrollChange: (CGFloat, CGFloat) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                onScrollChange(oldValue, newValue)
            }
        } else {
            content
        }
        #elseif os(macOS)
        if #available(macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                onScrollChange(oldValue, newValue)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

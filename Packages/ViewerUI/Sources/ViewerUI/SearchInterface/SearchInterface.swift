/// SearchInterface - Real-time search with highlighting and navigation
///
/// Provides comprehensive search functionality with instant results,
/// content highlighting, search history, and keyboard navigation support.
/// Integrates with the Search module for backend functionality.

import MarkdownCore
import Search
import SwiftUI

/// Main search interface component with real-time filtering
public struct SearchInterface: View {
    // MARK: - State Management

    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.platform) private var platform
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Search State

    @State private var searchHistory: [String] = []
    @State private var showingHistory = false

    // Search options state
    @State private var caseSensitive = false
    @State private var wholeWords = false
    @State private var useRegex = false

    // Computed search options
    private var searchOptions: SearchOptions {
        SearchOptions(
            caseSensitive: caseSensitive,
            wholeWords: wholeWords,
            useRegex: useRegex
        )
    }

    // MARK: - Accessibility

    @FocusState private var isSearchFocused: Bool
    @AccessibilityFocusState private var isSearchFieldFocused: Bool

    // MARK: - Initialization

    public init() {}

    // MARK: - View Body

    public var body: some View {
        VStack(spacing: 0) {
            searchHeaderView

            if coordinator.searchState.isSearching {
                searchingView
            } else if !coordinator.searchState.query.isEmpty {
                searchResultsView
            } else if showingHistory && !searchHistory.isEmpty {
                searchHistoryView
            } else {
                searchPromptView
            }
        }
        .background(Color.systemBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search Interface")
        .onAppear {
            loadSearchHistory()
        }
        .onChange(of: coordinator.searchState.query) { _, newQuery in
            handleSearchQueryChange(newQuery)
        }
    }

    // MARK: - Search Header

    private var searchHeaderView: some View {
        VStack(spacing: 12) {
            searchFieldView

            if !coordinator.searchState.query.isEmpty {
                searchOptionsView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemGroupedBackground)
    }

    // MARK: - Search Field

    private var searchFieldView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))

                TextField("Search document...", text: searchBinding)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .accessibilityFocused($isSearchFieldFocused)
                    .accessibilityLabel("Search document")
                    .accessibilityValue(searchAccessibilityValue)
                    .onSubmit {
                        performSearch()
                    }
                    .platformConditional(.macOS) { field in
                        field.onKeyPress(.downArrow) {
                            focusNextResult()
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            focusPreviousResult()
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            clearSearch()
                            return .handled
                        }
                    }

                if !coordinator.searchState.query.isEmpty {
                    Button("Clear") {
                        clearSearch()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !coordinator.searchState.query.isEmpty {
                searchNavigationControls
            }
        }
    }

    // MARK: - Search Navigation Controls

    private var searchNavigationControls: some View {
        HStack(spacing: 4) {
            Button(action: previousResult) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .medium))
            }
            .disabled(coordinator.searchState.results.isEmpty || coordinator.searchState.currentResultIndex == 0)
            .accessibilityLabel("Previous result")

            Text(resultCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 40)

            Button(action: nextResult) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
            }
            .disabled(coordinator.searchState.results.isEmpty ||
                     coordinator.searchState.currentResultIndex >= coordinator.searchState.results.count - 1)
            .accessibilityLabel("Next result")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.systemGray5)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Search Options

    private var searchOptionsView: some View {
        HStack(spacing: 16) {
            Toggle("Case Sensitive", isOn: $caseSensitive)
                .toggleStyle(.button)
                .font(.caption)
                .accessibilityLabel("Case sensitive search")

            Toggle("Whole Words", isOn: $wholeWords)
                .toggleStyle(.button)
                .font(.caption)
                .accessibilityLabel("Whole words only")

            Toggle("Regex", isOn: $useRegex)
                .toggleStyle(.button)
                .font(.caption)
                .accessibilityLabel("Regular expression search")

            Spacer()

            Button("Options") {
                // Show advanced search options
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onChange(of: caseSensitive) { _, _ in performSearchWithOptions() }
        .onChange(of: wholeWords) { _, _ in performSearchWithOptions() }
        .onChange(of: useRegex) { _, _ in performSearchWithOptions() }
    }

    // MARK: - Search States

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Searching...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Searching document")
    }

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            // Results summary
            HStack {
                Text(resultsSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if coordinator.searchState.results.count > 1 {
                    Button("Jump to All") {
                        jumpToAllResults()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.systemGray6)

            // Results list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(coordinator.searchState.results.indices, id: \.self) { index in
                        SearchResultView(
                            result: coordinator.searchState.results[index],
                            index: index,
                            isSelected: index == coordinator.searchState.currentResultIndex
                        )                            {
                                selectResult(at: index)
                            }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(index == coordinator.searchState.currentResultIndex ? [.isSelected] : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var searchHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Searches")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    clearSearchHistory()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.systemGray6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchHistory, id: \.self) { query in
                        Button(action: {
                            coordinator.searchState.query = query
                            showingHistory = false
                            performSearch()
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.tertiary)
                                    .font(.system(size: 14))

                                Text(query)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.tertiary)
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.systemBackground)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search for \(query)")

                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
    }

    private var searchPromptView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text("Search Document")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Find text, headings, and content within the document")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if platform.supportsCursor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcuts:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        shortcutRow("⌘F", "Open search")
                        shortcutRow("↓", "Next result")
                        shortcutRow("↑", "Previous result")
                        shortcutRow("Esc", "Clear search")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    @ViewBuilder
    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text(description)
        }
    }

    // MARK: - Computed Properties

    private var searchBinding: Binding<String> {
        Binding(
            get: { coordinator.searchState.query },
            set: { newValue in
                coordinator.searchState.query = newValue
                showingHistory = newValue.isEmpty && isSearchFocused
            }
        )
    }

    private var searchAccessibilityValue: String {
        if coordinator.searchState.isSearching {
            return "Searching"
        } else if !coordinator.searchState.results.isEmpty {
            return "\(coordinator.searchState.results.count) results found"
        } else if !coordinator.searchState.query.isEmpty {
            return "No results found"
        } else {
            return "Enter search term"
        }
    }

    private var resultCountText: String {
        guard !coordinator.searchState.results.isEmpty else { return "0/0" }
        return "\(coordinator.searchState.currentResultIndex + 1)/\(coordinator.searchState.results.count)"
    }

    private var resultsSummaryText: String {
        let count = coordinator.searchState.results.count
        if count == 0 {
            return "No results found"
        } else if count == 1 {
            return "1 result found"
        } else {
            return "\(count) results found"
        }
    }

    // MARK: - Search Actions

    private func performSearch() {
        guard !coordinator.searchState.query.isEmpty else { return }

        addToSearchHistory(coordinator.searchState.query)
        showingHistory = false

        Task {
            await coordinator.performSearch(
                coordinator.searchState.query,
                options: searchOptions
            )
        }
    }

    private func performSearchWithOptions() {
        guard !coordinator.searchState.query.isEmpty else { return }

        Task {
            await coordinator.performSearch(
                coordinator.searchState.query,
                options: searchOptions
            )
        }
    }

    private func clearSearch() {
        coordinator.searchState.query = ""
        coordinator.searchState.results = []
        coordinator.searchState.currentResultIndex = 0
        showingHistory = false
        isSearchFocused = false
    }

    private func nextResult() {
        guard !coordinator.searchState.results.isEmpty else { return }

        let nextIndex = min(
            coordinator.searchState.currentResultIndex + 1,
            coordinator.searchState.results.count - 1
        )

        selectResult(at: nextIndex)
    }

    private func previousResult() {
        guard !coordinator.searchState.results.isEmpty else { return }

        let previousIndex = max(
            coordinator.searchState.currentResultIndex - 1,
            0
        )

        selectResult(at: previousIndex)
    }

    private func focusNextResult() {
        nextResult()
    }

    private func focusPreviousResult() {
        previousResult()
    }

    private func selectResult(at index: Int) {
        guard index >= 0 && index < coordinator.searchState.results.count else { return }

        coordinator.searchState.currentResultIndex = index

        Task {
            await coordinator.jumpToSearchResult(at: index)
        }

        // Announce selection for accessibility
        let announcement = "Result \(index + 1) of \(coordinator.searchState.results.count)"
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func jumpToAllResults() {
        // Implementation for jumping through all results
        Task {
            await coordinator.highlightAllSearchResults()
        }
    }

    // MARK: - Search History

    private func loadSearchHistory() {
        // Load from UserDefaults or similar storage
        searchHistory = UserDefaults.standard.stringArray(forKey: "SearchHistory") ?? []
    }

    private func addToSearchHistory(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Remove if already exists
        searchHistory.removeAll { $0 == query }

        // Add to beginning
        searchHistory.insert(query, at: 0)

        // Limit to 10 recent searches
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }

        // Save to UserDefaults
        UserDefaults.standard.set(searchHistory, forKey: "SearchHistory")
    }

    private func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "SearchHistory")
    }

    private func handleSearchQueryChange(_ newQuery: String) {
        if newQuery.isEmpty {
            coordinator.searchState.results = []
            coordinator.searchState.currentResultIndex = 0
        } else {
            // Debounced search
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                if coordinator.searchState.query == newQuery {
                    await coordinator.performSearch(newQuery, options: searchOptions)
                }
            }
        }
    }
}

// SearchOptions is now imported from Search module

// MARK: - Preview

#if DEBUG
struct SearchInterface_Previews: PreviewProvider {
    static var previews: some View {
        SearchInterface()
            .environment(AppStateCoordinator())
            .previewDisplayName("Search Interface")
    }
}
#endif

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

    @Bindable var coordinator: AppStateCoordinator
    @Environment(\.platform) private var platform
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Search State

    @State private var searchHistory: [String] = []
    @State private var showingHistory = false
    @State private var queryText: String = ""

    // Search options state
    @State private var caseSensitive = false
    @State private var wholeWords = false
    @State private var useRegex = false
    @State private var searchScope: SearchScope = .currentDocument

    // Computed search options
    private var searchOptions: SearchOptions {
        SearchOptions(
            caseSensitive: caseSensitive,
            wholeWords: wholeWords,
            useRegex: useRegex
        )
    }

    // MARK: - Accessibility

    private enum FocusTarget: Hashable {
        case searchField
    }

    @FocusState private var focusedField: FocusTarget?
    @AccessibilityFocusState private var isSearchFieldFocused: Bool

    // MARK: - Initialization

    public init(coordinator: AppStateCoordinator) {
        self.coordinator = coordinator
    }

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
            queryText = coordinator.searchState.query
            searchScope = coordinator.searchState.searchScope
            focusSearchField()
        }
        .onChange(of: queryText) { _, newValue in
            handleLocalQueryChange(newValue)
        }
        .onChange(of: coordinator.searchState.query) { _, newQuery in
            syncQueryFromCoordinator(newQuery)
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
            searchFieldInput

            if !coordinator.searchState.query.isEmpty {
                searchNavigationControls
            }
        }
    }

    @ViewBuilder
    private var searchFieldInput: some View {
#if os(macOS)
        MacSearchField(
            text: $queryText,
            isFocused: macSearchFocusBinding,
            placeholder: "Search document...",
            onSubmit: { performSearch() },
            onMoveUp: { focusPreviousResult() },
            onMoveDown: { focusNextResult() },
            onEscape: { clearSearch() }
        )
        .frame(minHeight: 32)
#else
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))

            TextField("Search document...", text: $queryText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .searchField)
                .accessibilityFocused($isSearchFieldFocused)
                .accessibilityLabel("Search document")
                .accessibilityValue(searchAccessibilityValue)
                .onSubmit {
                    performSearch()
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
#endif
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
        VStack(spacing: 12) {
            // Search scope picker
            if coordinator.tabState.tabs.count > 1 {
                Picker("Search Scope", selection: $searchScope) {
                    ForEach(SearchScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Search scope")
                .onChange(of: searchScope) { _, newScope in
                    coordinator.searchState.searchScope = newScope
                    performSearchWithOptions()
                }
            }

            // Search options
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
        queryText = ""
        coordinator.searchState.query = ""
        coordinator.searchState.results = []
        coordinator.searchState.currentResultIndex = 0
        showingHistory = false
        focusSearchField()
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

    private func handleLocalQueryChange(_ newValue: String) {
        coordinator.searchState.query = newValue
        showingHistory = newValue.isEmpty && focusedField == .searchField

        guard !newValue.isEmpty else {
            coordinator.searchState.results = []
            coordinator.searchState.currentResultIndex = 0
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard coordinator.searchState.query == newValue else { return }
            await coordinator.performSearch(newValue, options: searchOptions)
        }
    }

    private func syncQueryFromCoordinator(_ newQuery: String) {
        guard newQuery != queryText else { return }
        queryText = newQuery
    }

    private func focusSearchField() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            focusedField = .searchField
        }
    }

#if os(macOS)
    private var macSearchFocusBinding: Binding<Bool> {
        Binding(
            get: { focusedField == .searchField },
            set: { value in
                focusedField = value ? .searchField : nil
            }
        )
    }
#endif
}

// SearchOptions is now imported from Search module

// MARK: - Preview

#if DEBUG
struct SearchInterface_Previews: PreviewProvider {
    static var previews: some View {
        SearchInterface(coordinator: AppStateCoordinator())
            .previewDisplayName("Search Interface")
    }
}
#endif

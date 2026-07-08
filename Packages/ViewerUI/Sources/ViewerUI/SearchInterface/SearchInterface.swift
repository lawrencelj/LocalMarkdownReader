// SearchInterface - Real-time search with highlighting and navigation

import MarkdownCore
import Search
import SwiftUI

/// Main search interface component with real-time filtering
public struct SearchInterface: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            searchFieldView
                .padding(12)
                .background(Color(uiColor: .systemGroupedBackground))

            Divider()

            resultsContent
        }
    }

    private var searchFieldView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search document...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit { performSearch() }
                .onChange(of: searchText) { _, newValue in
                    if newValue.isEmpty {
                        coordinator.searchState.query = ""
                        coordinator.searchState.results = []
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    coordinator.searchState.query = ""
                    coordinator.searchState.results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var resultsContent: some View {
        if coordinator.searchState.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !coordinator.searchState.results.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("\(coordinator.searchState.results.count) results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(coordinator.searchState.results.indices, id: \.self) { index in
                            SearchResultView(
                                result: coordinator.searchState.results[index],
                                index: index,
                                isSelected: index == coordinator.searchState.currentResultIndex
                            ) { selectResult(at: index) }
                            if index < coordinator.searchState.results.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        } else if !searchText.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No results")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Search Document")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Type to find text in the document")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        Task {
            await coordinator.performSearch(searchText)
        }
    }

    private func selectResult(at index: Int) {
        coordinator.searchState.currentResultIndex = index
        Task {
            await coordinator.jumpToSearchResult(at: index)
        }
    }
}

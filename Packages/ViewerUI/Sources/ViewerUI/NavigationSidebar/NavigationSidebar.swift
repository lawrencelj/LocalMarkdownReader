/// NavigationSidebar - Document outline and navigation component
///
/// Provides hierarchical navigation through markdown document structure
/// with collapsible sections, jump-to-content functionality, and full
/// accessibility support including VoiceOver rotor integration.

import SwiftUI
import MarkdownCore
import Search

/// Main navigation sidebar component with outline generation
public struct NavigationSidebar: View {
    // MARK: - State Management

    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.platform) private var platform
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Local State

    @State private var expandedSections: Set<String> = []
    @State private var selectedHeading: String?
    @State private var searchText: String = ""
    @State private var filteredOutline: [OutlineItem] = []

    // MARK: - Accessibility

    @AccessibilityFocusState private var focusedHeading: String?

    // MARK: - View Body

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            if coordinator.documentState.currentDocument != nil {
                outlineContent
            } else {
                emptyStateView
            }
        }
        .background(Color.systemGroupedBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document Outline")
        .accessibilityRotor("Headings") {
            ForEach(coordinator.searchState.outline, id: \.id) { item in
                AccessibilityRotorEntry(item.title, id: item.id) {
                    jumpToHeading(item)
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: coordinator.documentState.currentDocument) { _, _ in
            handleDocumentChange()
        }
        .onChange(of: searchText) { _, newValue in
            filterOutline(with: newValue)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Outline")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !coordinator.searchState.outline.isEmpty {
                    Menu {
                        Button("Expand All") {
                            expandAllSections()
                        }

                        Button("Collapse All") {
                            collapseAllSections()
                        }

                        Divider()

                        Button("Jump to Current") {
                            jumpToCurrentPosition()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Outline Options")
                }
            }

            if !coordinator.searchState.outline.isEmpty {
                SearchBar(
                    text: $searchText,
                    placeholder: "Filter outline..."
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Outline Content

    @ViewBuilder
    private var outlineContent: some View {
        if coordinator.searchState.outline.isEmpty {
            noOutlineView
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredOutline, id: \.id) { item in
                        OutlineItemView(
                            item: item,
                            isExpanded: expandedSections.contains(item.id),
                            isSelected: selectedHeading == item.id,
                            onToggleExpansion: {
                                toggleExpansion(for: item.id)
                            },
                            onSelect: {
                                selectHeading(item)
                            }
                        )
                        .accessibilityFocused($focusedHeading, equals: item.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No Document")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Open a markdown file to see its outline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var noOutlineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No Outline Available")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("This document doesn't contain any headings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - State Management

    private func setupInitialState() {
        // Expand top-level sections by default
        expandedSections = Set(
            coordinator.searchState.outline
                .filter { $0.level <= 2 }
                .map { $0.id }
        )

        filteredOutline = coordinator.searchState.outline
    }

    private func handleDocumentChange() {
        // Reset state for new document
        expandedSections.removeAll()
        selectedHeading = nil
        searchText = ""

        // Setup for new document
        Task {
            // Allow time for search index to update
            try? await Task.sleep(for: .milliseconds(100))
            setupInitialState()
        }
    }

    private func filterOutline(with searchText: String) {
        if searchText.isEmpty {
            filteredOutline = coordinator.searchState.outline
        } else {
            filteredOutline = coordinator.searchState.outline.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }

            // Auto-expand sections containing search results
            for item in filteredOutline {
                expandedSections.insert(item.id)
                // Also expand parent sections
                expandParentSections(for: item)
            }
        }
    }

    private func expandParentSections(for item: OutlineItem) {
        let allItems = coordinator.searchState.outline
        var currentLevel = item.level

        // Find and expand all parent sections
        for i in stride(from: allItems.firstIndex(where: { $0.id == item.id }) ?? 0, through: 0, by: -1) {
            let potentialParent = allItems[i]
            if potentialParent.level < currentLevel {
                expandedSections.insert(potentialParent.id)
                currentLevel = potentialParent.level
            }
        }
    }

    // MARK: - Navigation Actions

    private func selectHeading(_ item: OutlineItem) {
        selectedHeading = item.id
        focusedHeading = item.id

        // Jump to heading in document
        Task {
            await coordinator.jumpToHeading(item.id)
        }

        // Announce selection for accessibility
        let announcement = "Navigated to \(item.title)"
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func jumpToHeading(_ item: OutlineItem) {
        selectHeading(item)
    }

    private func jumpToCurrentPosition() {
        // Find the heading closest to current scroll position
        Task {
            if let currentHeading = await coordinator.getCurrentHeading() {
                selectedHeading = currentHeading.id
                focusedHeading = currentHeading.id

                // Ensure the heading is visible in outline
                expandParentSections(for: currentHeading)
            }
        }
    }

    // MARK: - Expansion Management

    private func toggleExpansion(for id: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
                // Also collapse child sections
                collapseChildSections(of: id)
            } else {
                expandedSections.insert(id)
            }
        }
    }

    private func expandAllSections() {
        withAnimation(.easeInOut(duration: 0.5)) {
            expandedSections = Set(coordinator.searchState.outline.map { $0.id })
        }

        AccessibilityNotification.Announcement("All sections expanded").post()
    }

    private func collapseAllSections() {
        withAnimation(.easeInOut(duration: 0.5)) {
            expandedSections.removeAll()
        }

        AccessibilityNotification.Announcement("All sections collapsed").post()
    }

    private func collapseChildSections(of parentId: String) {
        let allItems = coordinator.searchState.outline

        guard let parentIndex = allItems.firstIndex(where: { $0.id == parentId }),
              parentIndex < allItems.count - 1 else { return }

        let parentLevel = allItems[parentIndex].level

        // Collapse all child sections
        for i in (parentIndex + 1)..<allItems.count {
            let item = allItems[i]
            if item.level <= parentLevel {
                break // Reached next sibling or higher level
            }
            expandedSections.remove(item.id)
        }
    }
}

// MARK: - Search Bar Component

private struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .accessibilityLabel("Filter outline")

            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Navigation Sidebar") {
    NavigationSidebar()
        .frame(width: 280)
        .environment(AppStateCoordinator.preview)
}

#Preview("Navigation Sidebar - Empty") {
    NavigationSidebar()
        .frame(width: 280)
        .environment(AppStateCoordinator.previewEmpty)
}
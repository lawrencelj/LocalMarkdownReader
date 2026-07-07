/// NavigationSidebar - Document outline and navigation component

import SwiftUI
import MarkdownCore
import Search

/// Main navigation sidebar component with outline generation
public struct NavigationSidebar: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    @State private var expandedSections: Set<String> = []
    @State private var selectedHeading: String?
    @State private var filterText: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            outlineContent
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear { setupInitialState() }
        .onChange(of: coordinator.documentState.currentDocument) { _, _ in
            setupInitialState()
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Outline")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(coordinator.searchState.outline.count) \(outlineItemNoun)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !coordinator.searchState.outline.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var outlineContent: some View {
        if coordinator.documentState.currentDocument == nil {
            emptyDocumentView
        } else if coordinator.searchState.outline.isEmpty {
            noOutlineView
        } else {
            outlineList
        }
    }

    private var outlineList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredOutline, id: \.id) { item in
                    outlineRow(item)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
    }

    private func outlineRow(_ item: OutlineItem) -> some View {
        Button {
            selectedHeading = item.id
            // Scroll the document viewer to this heading
            let headingAnchor = "heading-\(item.title)"
            coordinator.documentState.scrollToHeadingID = headingAnchor
        } label: {
            HStack(spacing: 8) {
                // Indentation
                Spacer()
                    .frame(width: CGFloat(max(0, item.level - 1)) * 14)

                // Level indicator
                Circle()
                    .fill(levelColor(item.level))
                    .frame(width: 8, height: 8)

                // Title
                Text(item.title)
                    .font(item.level == 1 ? .body.weight(.semibold) : (item.level == 2 ? .callout.weight(.medium) : .callout))
                    .foregroundStyle(selectedHeading == item.id ? .white : .primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(selectedHeading == item.id ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Outline level \(item.level): \(item.title)")
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        default: return .gray
        }
    }

    private var emptyDocumentView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No Document")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Open a file to see its outline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var noOutlineView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(isStructuredDocument ? "No Structure" : "No Headings")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(
                isStructuredDocument
                    ? "No JSON or XML structure could be extracted"
                    : "This document has no headings"
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var filteredOutline: [OutlineItem] {
        if filterText.isEmpty {
            return coordinator.searchState.outline
        }
        return coordinator.searchState.outline.filter {
            $0.title.localizedCaseInsensitiveContains(filterText)
        }
    }

    private var isStructuredDocument: Bool {
        coordinator.documentState.currentDocument?.format.isStructuredText == true
    }

    private var outlineItemNoun: String {
        isStructuredDocument ? "items" : "headings"
    }

    private func setupInitialState() {
        selectedHeading = nil
        filterText = ""
        expandedSections = Set(
            coordinator.searchState.outline
                .filter { $0.level <= 2 }
                .map { $0.id }
        )
    }
}

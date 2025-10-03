/// SearchResultView - Individual search result with context preview
///
/// Displays individual search results with surrounding context,
/// highlighting the matched text, and providing navigation to
/// the result location in the document.

import Search
@preconcurrency import SwiftUI

/// Individual search result view with context and highlighting
struct SearchResultView: View {
    // MARK: - Properties

    let result: SearchResult
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    // MARK: - Environment

    @Environment(\.platform) private var platform
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var isHovered = false

    // MARK: - Constants

    private let maxContextLength = 120
    private let highlightPadding = 20

    // MARK: - View Body

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                resultHeader

                contextPreview

                if let heading = result.headingContext {
                    headingContext(heading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundFill)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction(.default) {
            onSelect()
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        HStack(spacing: 8) {
            // Result index
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.3) : Color.accentColor)
                )

            // Match type indicator
            matchTypeIndicator

            Spacer()

            // Location information
            if let location = result.locationDescription {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Match Type Indicator

    @ViewBuilder
    private var matchTypeIndicator: some View {
        switch result.matchType {
        case .heading:
            Label("Heading", systemImage: "text.format")
                .font(.caption2)
                .foregroundStyle(.blue)

        case .content:
            Label("Content", systemImage: "text.alignleft")
                .font(.caption2)
                .foregroundStyle(.green)

        case .codeBlock:
            Label("Code", systemImage: "curlybraces")
                .font(.caption2)
                .foregroundStyle(.purple)

        case .link:
            Label("Link", systemImage: "link")
                .font(.caption2)
                .foregroundStyle(.orange)

        case .emphasis:
            Label("Emphasis", systemImage: "italic")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Context Preview

    private var contextPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main matched text with highlighting
            highlightedText

            // Additional context if available
            if !result.context.isEmpty {
                Text(result.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Highlighted Text

    @ViewBuilder
    private var highlightedText: some View {
        let attributedText = createHighlightedAttributedString()

        Text(attributedText)
            .font(.body)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Search result: \(result.text)")
    }

    // MARK: - Heading Context

    @ViewBuilder
    private func headingContext(_ heading: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(heading)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Text Highlighting

    private func createHighlightedAttributedString() -> AttributedString {
        let fullText = result.contextWithMatch
        var attributedString = AttributedString(fullText)

        // Find all occurrences of the matched text
        let searchText = result.text.lowercased()
        let fullTextLower = fullText.lowercased()

        var searchStartIndex = fullTextLower.startIndex
        while let range = fullTextLower.range(of: searchText, range: searchStartIndex..<fullTextLower.endIndex) {
            // Convert String.Index to AttributedString.Index
            if let attributedRange = attributedString.range(of: String(fullText[range])) {
                // Apply highlighting
                var highlightAttributes = AttributeContainer()
                highlightAttributes.backgroundColor = highlightColor
                highlightAttributes.foregroundColor = highlightTextColor
                attributedString[attributedRange].mergeAttributes(highlightAttributes)

                // Bold the matched text
                let existingFont = attributedString[attributedRange].font ?? Font.body
                var fontAttributes = AttributeContainer()
                fontAttributes.font = existingFont.bold()
                attributedString[attributedRange].mergeAttributes(fontAttributes)
            }

            searchStartIndex = range.upperBound
        }

        return attributedString
    }

    // MARK: - Computed Properties

    private var backgroundFill: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.15))
        } else if isHovered && platform.supportsCursor {
            return AnyShapeStyle(Color.systemGray6)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    private var highlightColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.8)
        } else {
            return Color.yellow.opacity(colorScheme == .dark ? 0.6 : 0.4)
        }
    }

    private var highlightTextColor: Color {
        if isSelected && colorScheme == .dark {
            return .white
        } else if isSelected {
            return .black
        } else {
            return colorScheme == .dark ? .black : .black
        }
    }

    private var accessibilityLabel: String {
        "Search result \(index + 1): \(result.text)"
    }

    private var accessibilityValue: String {
        var value = ""

        if let heading = result.headingContext {
            value += "In section: \(heading)"
        }

        if let location = result.locationDescription {
            if !value.isEmpty { value += ", " }
            value += "Location: \(location)"
        }

        return value.isEmpty ? "Tap to navigate" : value + ", Tap to navigate"
    }
}

// MARK: - Supporting Extensions

extension SearchResult {
    var contextWithMatch: String {
        // Combine surrounding context with matched text
        let beforeContext = context.prefix(60)
        let afterContext = context.suffix(60)

        if context.isEmpty {
            return text
        } else {
            return "\(beforeContext)...\(text)...\(afterContext)"
        }
    }

    var locationDescription: String? {
        // Generate human-readable location description
        if lineNumber > 0 {
            return "Line \(lineNumber)"
        } else if let heading = headingContext {
            return "In \(heading)"
        } else {
            return nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SearchResultView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 1) {
                // Preview content would go here if SearchResult.preview* existed
                Text("Search result previews")
                    .padding()
            }
        }
        .background(Color.systemBackground)
        .previewDisplayName("Search Result View")
    }
}
#endif

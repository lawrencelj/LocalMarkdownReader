/// MarkdownRenderer - Performance-optimized markdown content renderer
///
/// Implements viewport-based rendering with lazy loading for large documents,
/// maintaining 60fps performance while providing rich markdown formatting
/// and accessibility support.

import MarkdownCore
import SwiftUI

/// High-performance markdown content renderer with viewport optimization
public struct MarkdownRenderer: View {
    // MARK: - Properties

    let content: AttributedString
    let syntaxErrors: [SyntaxError]
    @Binding var viewportBounds: CGRect
    @Binding var isOptimized: Bool

    // MARK: - State

    @State private var renderedSections: [RenderedSection] = []
    @State private var visibleSectionIndices: Set<Int> = []
    @State private var renderingTask: Task<Void, Never>?

    // MARK: - Environment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.platform) private var platform

    // MARK: - View Body

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(renderedSections.indices, id: \.self) { index in
                sectionView(at: index)
                    .id("section-\(index)")
                    .onAppear {
                        sectionDidAppear(at: index)
                    }
                    .onDisappear {
                        sectionDidDisappear(at: index)
                    }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        viewportBounds = geometry.frame(in: .named("documentScroll"))
                    }
                    .onChange(of: geometry.frame(in: .named("documentScroll"))) { _, newFrame in
                        viewportBounds = newFrame
                        optimizeVisibleContent()
                    }
            }
        )
        .onAppear {
            prepareContent()
        }
        .onChange(of: content) { _, _ in
            prepareContent()
        }
        .onDisappear {
            cleanupRendering()
        }
    }

    // MARK: - Section View Builder

    @ViewBuilder
    private func sectionView(at index: Int) -> some View {
        if index < renderedSections.count {
            sectionContentView(at: index)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func sectionContentView(at index: Int) -> some View {
        let section = renderedSections[index]

        if isOptimized && !visibleSectionIndices.contains(index) {
            // Placeholder for non-visible sections during fast scrolling
            Rectangle()
                .fill(Color.clear)
                .frame(height: section.estimatedHeight)
                .accessibility(hidden: true)
        } else {
            // Full rendered content with inline error indicators
            VStack(alignment: .leading, spacing: 4) {
                // Show any errors for this section's lines
                if let lineErrors = errorsForSection(index) {
                    HStack(spacing: 8) {
                        ForEach(lineErrors) { error in
                            InlineErrorIndicator(error: error)
                            Text(error.message)
                                .font(.caption)
                                .foregroundColor(errorColor(for: error))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(errorBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(section.content)
                    .font(bodyFont)
                    .lineSpacing(lineSpacing)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Content section")
            }
        }
    }

    // MARK: - Element Rendering

    private func renderElement(_ element: MarkdownElement) -> AnyView {
        switch element.type {
        case .heading(let level):
            return AnyView(headingView(element, level: level))

        case .paragraph:
            return AnyView(paragraphView(element))

        case .codeBlock(let language):
            return AnyView(codeBlockView(element, language: language))

        case .list(let style):
            return AnyView(listView(element, style: convertListStyle(style)))

        case .blockquote:
            return AnyView(blockquoteView(element))

        case .table:
            return AnyView(tableView(element))

        case .horizontalRule:
            return AnyView(Divider()
                .padding(.vertical, 8))

        case .image:
            return AnyView(imageView(element))

        case .text:
            return AnyView(Text(element.content)
                .font(bodyFont))

        case .listItem:
            return AnyView(Text(element.content)
                .font(bodyFont))

        case .inlineCode:
            return AnyView(Text(element.content)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 4)
                .background(Color.systemGray6)
                .clipShape(RoundedRectangle(cornerRadius: 4)))

        case .tableRow, .tableCell:
            return AnyView(Text(element.content)
                .font(bodyFont))

        case .link(let url):
            if let url = url {
                return AnyView(Link(element.content, destination: URL(string: url) ?? URL(string: "about:blank")!)
                    .font(bodyFont))
            } else {
                return AnyView(Text(element.content)
                    .font(bodyFont))
            }

        case .emphasis:
            return AnyView(Text(element.content)
                .font(bodyFont)
                .italic())

        case .strong:
            return AnyView(Text(element.content)
                .font(bodyFont)
                .bold())

        case .lineBreak:
            return AnyView(Text("\n"))

        case .custom:
            return AnyView(Text(element.content)
                .font(bodyFont))
        }
    }

    // MARK: - Heading View

    @ViewBuilder
    private func headingView(_ element: MarkdownElement, level: Int) -> some View {
        Text(AttributedString(element.content))
            .font(headingFont(for: level))
            .fontWeight(headingWeight(for: level))
            .foregroundStyle(headingColor(for: level))
            .padding(.top, headingTopPadding(for: level))
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Heading level \(level): \(element.content)")
            .id("heading-\(element.id)")
    }

    // MARK: - Paragraph View

    private func paragraphView(_ element: MarkdownElement) -> some View {
        Text(AttributedString(element.content))
            .font(bodyFont)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(element.content)
    }

    // MARK: - Code Block View

    private func codeBlockView(_ element: MarkdownElement, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language, !language.isEmpty {
                codeBlockHeader(language: language, content: element.content)
            }

            codeBlockContent(element)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Code block" + (language.map { " in \($0)" } ?? ""))
        .accessibilityValue(element.content)
    }

    @ViewBuilder
    private func codeBlockHeader(language: String, content: String) -> some View {
        HStack {
            Text(language.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            Spacer()

            #if os(macOS)
            Button("Copy") {
                copyToClipboard(content)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            #endif
        }
        .background(Color.secondarySystemBackground)
    }

    @ViewBuilder
    private func codeBlockContent(_ element: MarkdownElement) -> some View {
        ScrollView(.horizontal, showsIndicators: platform.supportsCursor) {
            Text(AttributedString(element.content))
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.systemGray6)
    }

    // MARK: - List View

    private func listView(_ element: MarkdownElement, style: RendererListStyle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array((element.children ?? []).enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    listMarker(for: style, index: index)
                    renderElement(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 16)
    }

    @ViewBuilder
    private func listMarker(for style: RendererListStyle, index: Int) -> some View {
        switch style {
        case .bullet:
            Text("•")
                .font(bodyFont)
                .foregroundStyle(.secondary)

        case .ordered:
            Text("\(index + 1).")
                .font(bodyFont)
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
        }
    }

    // MARK: - Blockquote View

    private func blockquoteView(_ element: MarkdownElement) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(element.children ?? [], id: \.id) { child in
                    renderElement(child)
                }
            }
            .padding(.leading, 16)
            .padding(.vertical, 8)
        }
        .background(
            Color.secondarySystemBackground
                .opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Blockquote")
    }

    // MARK: - Table View

    private func tableView(_ element: MarkdownElement) -> some View {
        // Simplified table implementation - can be enhanced
        VStack(alignment: .leading, spacing: 8) {
            ForEach(element.children ?? [], id: \.id) { row in
                tableRowView(row)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table")
    }

    @ViewBuilder
    private func tableRowView(_ row: MarkdownElement) -> some View {
        HStack {
            ForEach(row.children ?? [], id: \.id) { cell in
                tableCellView(cell)
            }
        }
    }

    @ViewBuilder
    private func tableCellView(_ cell: MarkdownElement) -> some View {
        Text(cell.content)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondarySystemBackground)
    }

    // MARK: - Image View

    private func imageView(_ element: MarkdownElement) -> some View {
        // Placeholder for image rendering
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.systemGray5)
            .frame(height: 200)
            .overlay(
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    if !element.content.isEmpty {
                        Text(element.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            )
            .accessibilityLabel("Image: \(element.content)")
    }

    // MARK: - Content Preparation

    private func prepareContent() {
        renderingTask?.cancel()
        renderingTask = Task {
            let sections = await MarkdownContentProcessor.process(content)

            await MainActor.run {
                renderedSections = sections
                optimizeVisibleContent()
            }
        }
    }

    private func optimizeVisibleContent() {
        guard isOptimized else {
            visibleSectionIndices = Set(renderedSections.indices)
            return
        }

        // Calculate visible sections based on viewport
        let visibleIndices = renderedSections.enumerated().compactMap { index, _ in
            let sectionFrame = estimatedFrame(for: index)
            return viewportBounds.intersects(sectionFrame) ? index : nil
        }

        // Add buffer sections for smooth scrolling
        let bufferedIndices = Set(visibleIndices.flatMap { index in
            [max(0, index - 1), index, min(renderedSections.count - 1, index + 1)]
        })

        visibleSectionIndices = bufferedIndices
    }

    private func estimatedFrame(for index: Int) -> CGRect {
        let sectionHeight = renderedSections[index].estimatedHeight
        let yOffset = renderedSections[0..<index].reduce(0) { $0 + $1.estimatedHeight }

        return CGRect(
            x: 0,
            y: yOffset,
            width: viewportBounds.width,
            height: sectionHeight
        )
    }

    // MARK: - Section Lifecycle

    private func sectionDidAppear(at index: Int) {
        visibleSectionIndices.insert(index)
    }

    private func sectionDidDisappear(at index: Int) {
        if isOptimized {
            visibleSectionIndices.remove(index)
        }
    }

    private func cleanupRendering() {
        renderingTask?.cancel()
        renderingTask = nil
    }

    // MARK: - Typography

    private var bodyFont: Font {
        .system(.body, design: .default)
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }

    private func headingWeight(for level: Int) -> Font.Weight {
        level <= 2 ? .bold : .semibold
    }

    private func headingColor(for level: Int) -> Color {
        level == 1 ? .primary : .primary
    }

    private func headingTopPadding(for level: Int) -> CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 16
        default: return 12
        }
    }

    private var lineSpacing: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 4
        case .medium, .large: return 6
        case .xLarge, .xxLarge: return 8
        default: return 10
        }
    }

    // MARK: - Utilities

    /// Converts ListStyle to RendererListStyle
    private func convertListStyle(_ style: ListStyle) -> RendererListStyle {
        switch style {
        case .unordered:
            return .bullet
        case .ordered:
            return .ordered
        }
    }

    #if os(macOS)
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    #endif

    // MARK: - Error Handling

    /// Get errors for a specific section index
    private func errorsForSection(_ index: Int) -> [SyntaxError]? {
        guard index < renderedSections.count else { return nil }

        let section = renderedSections[index]

        let errors = syntaxErrors.filter { error in
            section.lineRange.contains(error.line)
        }

        return errors.isEmpty ? nil : errors
    }

    /// Get color for error severity
    private func errorColor(for error: SyntaxError) -> Color {
        switch error.severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    /// Background color for error indicators
    private var errorBackgroundColor: Color {
        Color.red.opacity(0.1)
    }
}

// MARK: - Supporting Types

private enum RendererListStyle {
    case bullet
    case ordered
}

// MARK: - Content Processor

/// Simple content processor for converting AttributedString to RenderedSections
struct MarkdownContentProcessor {
    static func process(_ content: AttributedString) async -> [RenderedSection] {
        let maxLinesPerSection = 25
        var sections: [RenderedSection] = []
        var lineEndIndices: [AttributedString.Index] = []
        lineEndIndices.reserveCapacity(content.characters.count / 40 + 1)

        var index = content.startIndex
        while index < content.endIndex {
            if content.characters[index] == "\n" {
                lineEndIndices.append(content.index(afterCharacter: index))
            }
            index = content.index(afterCharacter: index)
        }
        // Ensure the final boundary is included
        lineEndIndices.append(content.endIndex)

        var sectionStart = content.startIndex
        var boundaryIndex = 0
        var sectionIndex = 0
        var currentLine = 1

        while boundaryIndex < lineEndIndices.count {
            let nextBoundaryIndex = min(boundaryIndex + maxLinesPerSection, lineEndIndices.count)
            let sectionEnd = lineEndIndices[nextBoundaryIndex - 1]

            let range = sectionStart..<sectionEnd
            let attributedSlice = AttributedString(content[range])
            let nsRange = NSRange(range, in: content)

            let lineCount = max(nextBoundaryIndex - boundaryIndex, 1)
            let lineRange = currentLine..<(currentLine + lineCount)

            sections.append(
                RenderedSection(
                    id: "section-\(sectionIndex)",
                    range: nsRange,
                    content: attributedSlice,
                    estimatedHeight: CGFloat(lineCount * 18),
                    renderingPriority: sectionIndex == 0 ? .high : .normal,
                    lineRange: lineRange
                )
            )

            currentLine += lineCount
            sectionIndex += 1
            boundaryIndex = nextBoundaryIndex
            sectionStart = sectionEnd
        }

        return sections.isEmpty
            ? [RenderedSection(id: "section-0", range: NSRange(location: 0, length: content.characters.count), content: content, estimatedHeight: 200, renderingPriority: .normal, lineRange: 0..<1)]
            : sections
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownRenderer_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MarkdownRenderer(
                content: AttributedString("# Sample Content\n\nThis is a paragraph."),
                syntaxErrors: [],
                viewportBounds: .constant(.zero),
                isOptimized: .constant(false)
            )
        }
        .padding()
    }
}
#endif

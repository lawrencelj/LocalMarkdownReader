/// MarkdownRenderer - Performance-optimized markdown content renderer
///
/// Implements viewport-based rendering with lazy loading for large documents,
/// maintaining 60fps performance while providing rich markdown formatting
/// and accessibility support.

import SwiftUI
import MarkdownCore

/// High-performance markdown content renderer with viewport optimization
public struct MarkdownRenderer: View {
    // MARK: - Properties

    let content: AttributedString
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
        guard index < renderedSections.count else {
            EmptyView()
        }

        let section = renderedSections[index]

        if isOptimized && !visibleSectionIndices.contains(index) {
            // Placeholder for non-visible sections during fast scrolling
            Rectangle()
                .fill(Color.clear)
                .frame(height: section.estimatedHeight)
                .accessibility(hidden: true)
        } else {
            // Full rendered content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.elements, id: \.id) { element in
                    renderElement(element)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(section.accessibilityLabel)
        }
    }

    // MARK: - Element Rendering

    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element.type {
        case .heading(let level):
            headingView(element, level: level)

        case .paragraph:
            paragraphView(element)

        case .codeBlock(let language):
            codeBlockView(element, language: language)

        case .list(let style):
            listView(element, style: convertListStyle(style))

        case .blockquote:
            blockquoteView(element)

        case .table:
            tableView(element)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 8)

        case .image:
            imageView(element)
        }
    }

    // MARK: - Heading View

    @ViewBuilder
    private func headingView(_ element: MarkdownElement, level: Int) -> some View {
        Text(element.attributedText)
            .font(headingFont(for: level))
            .fontWeight(headingWeight(for: level))
            .foregroundStyle(headingColor(for: level))
            .padding(.top, headingTopPadding(for: level))
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Heading level \(level): \(element.plainText)")
            .id("heading-\(element.id)")
    }

    // MARK: - Paragraph View

    private func paragraphView(_ element: MarkdownElement) -> some View {
        Text(element.attributedText)
            .font(bodyFont)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(element.plainText)
    }

    // MARK: - Code Block View

    private func codeBlockView(_ element: MarkdownElement, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = language, !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)

                    Spacer()

                    #if os(macOS)
                    Button("Copy") {
                        copyToClipboard(element.plainText)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    #endif
                }
                .background(Color(uiColor: .secondarySystemBackground))
            }

            ScrollView(.horizontal, showsIndicators: platform.supportsCursor) {
                Text(element.attributedText)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .systemGray6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Code block" + (language.map { " in \($0)" } ?? ""))
        .accessibilityValue(element.plainText)
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
            Color(uiColor: .secondarySystemBackground)
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
                HStack {
                    ForEach(row.children ?? [], id: \.id) { cell in
                        Text(cell.plainText)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table")
    }

    // MARK: - Image View

    private func imageView(_ element: MarkdownElement) -> some View {
        // Placeholder for image rendering
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(uiColor: .systemGray5))
            .frame(height: 200)
            .overlay(
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    if !element.plainText.isEmpty {
                        Text(element.plainText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            )
            .accessibilityLabel("Image: \(element.plainText)")
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
        let visibleIndices = renderedSections.enumerated().compactMap { index, section in
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

    /// Converts MarkdownElement.ListStyle to RendererListStyle
    private func convertListStyle(_ style: MarkdownElement.ListStyle) -> RendererListStyle {
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
}

// MARK: - Supporting Types

private enum RendererListStyle {
    case bullet
    case ordered
}


// MARK: - Preview

#if DEBUG
struct MarkdownRenderer_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MarkdownRenderer(
                content: AttributedString("# Sample Content\n\nThis is a paragraph."),
                viewportBounds: .constant(.zero),
                isOptimized: .constant(false)
            )
        }
        .padding()
    }
}
#endif
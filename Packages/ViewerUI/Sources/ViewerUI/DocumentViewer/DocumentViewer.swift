/// DocumentViewer - Main markdown content display component
///
/// Renders parsed markdown with proper formatting: headings, bold, italic,
/// code blocks, lists, blockquotes, and links. Supports line numbers,
/// alternating line shading, and scroll-to-heading navigation.

import SwiftUI
import MarkdownCore
import Settings

#if os(macOS)
import Translation
import _Translation_SwiftUI
#endif

/// Main document viewer component
public struct DocumentViewer: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.themeManager) private var themeManager

    #if os(macOS)
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var translationState = DocumentTranslationState()
    #endif

    // MARK: - Content Find State

    /// A rendered leaf (block, list item, or table cell) that contains find matches.
    private struct FindSegment {
        let id: String        // stable segment ID, matching the leaf's `segID`
        let anchorID: String  // scroll target (the block's anchor)
        let start: Int        // global index of this segment's first match
        let count: Int        // number of matches in this segment
    }

    /// Segments (with matches) in document order, for count + navigation + scroll.
    @State private var findSegments: [FindSegment] = []
    /// Segment ID of the current match's leaf, so that leaf can emphasize it.
    @State private var findCurrentSegID: String?
    /// Index of the current match within its segment.
    @State private var findCurrentLocal: Int = 0
    /// Anchor to scroll to for the current match.
    @State private var findScrollAnchor: String?

    public init() {}

    public var body: some View {
        Group {
            if coordinator.documentState.isLoading {
                loadingView
            } else if let error = coordinator.documentState.parseError {
                errorView(error)
            } else if coordinator.documentState.isCompareMode {
                compareView
            } else if coordinator.documentState.currentDocument != nil {
                documentContentView
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Loading document...").font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 48)).foregroundStyle(.red)
            Text("Failed to Load Document").font(.title2).fontWeight(.semibold)
            Text(error.localizedDescription).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Try Again") { Task { await coordinator.refreshDocument() } }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Document Content

    @ViewBuilder
    private var documentContentView: some View {
        if let document = coordinator.documentState.currentDocument {
            switch document.format {
            case .html:
                #if os(macOS)
                HTMLPreviewView(
                    html: document.content,
                    baseURL: document.reference.url.deletingLastPathComponent()
                )
                #else
                structuredTextContentView(document.content)
                #endif
            case .json, .xml:
                structuredTextContentView(document.content)
            case .latex:
                LaTeXPreviewView(content: document.content)
            case .markdown, .plainText:
                markdownDocumentContent
            }
        }
    }

    private var markdownDocumentContent: some View {
        withContentFindBar {
        VStack(spacing: 0) {
            #if os(macOS)
            translationToolbar
            Divider()
            #endif

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    formattedContent
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                }
                .background(themeManager.color(for: .background))
                .onChange(of: coordinator.documentState.scrollToHeadingID) { _, headingID in
                    if let headingID = headingID {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(headingID, anchor: .top)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            coordinator.documentState.scrollToHeadingID = nil
                        }
                    }
                }
                .onChange(of: coordinator.documentState.focusedLine) { _, line in
                    if let line = line {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("content-line-\(line)", anchor: .center)
                        }
                    }
                }
                .onChange(of: findScrollAnchor) { _, anchor in
                    if let anchor {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(anchor, anchor: .center)
                        }
                    }
                }
            }
        }
        }
        #if os(macOS)
        .translationTask(translationConfiguration) { session in
            await translateDocument(using: session)
        }
        .onChange(of: coordinator.documentState.currentDocument?.id) { _, _ in
            resetTranslation()
        }
        #endif
    }

    private func structuredTextContentView(_ content: String) -> some View {
        withContentFindBar {
            ScrollView([.horizontal, .vertical]) {
                Text(findHighlightedPlain(content, segID: "structured"))
                    .font(.system(
                        size: 13 * themeManager.fontSizeMultiplier,
                        design: .monospaced
                    ))
                    .foregroundStyle(themeManager.color(for: .primary))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
            .background(themeManager.color(for: .background))
        }
    }

    #if os(macOS)
    private var translationToolbar: some View {
        HStack(spacing: 10) {
            Label(
                translationState.isShowingChinese ? "Chinese Translation" : "English",
                systemImage: translationState.isShowingChinese ? "character.bubble.fill" : "doc.text"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if translationState.isTranslating {
                ProgressView()
                    .controlSize(.small)
                Text("Translating whole document...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let translationError = translationState.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(translationError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(translationError)
            }

            Spacer()

            Button {
                toggleTranslation()
            } label: {
                Label(
                    translationState.isShowingChinese ? "Show English" : "Translate to Chinese",
                    systemImage: translationState.isShowingChinese ? "arrow.uturn.backward" : "character.bubble"
                )
            }
            .buttonStyle(.bordered)
            .disabled(translationState.isTranslating)
            .help(translationState.isShowingChinese ? "Turn off translation and show the English document" : "Translate the whole document to Simplified Chinese")
            .accessibilityLabel(translationState.isShowingChinese ? "Turn off translation and show English" : "Translate whole document to Chinese")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toggleTranslation() {
        if translationState.toggle() == .startTranslation {
            if translationConfiguration == nil {
                translationConfiguration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "zh-Hans")
                )
            } else {
                translationConfiguration?.invalidate()
            }
        }
    }

    @MainActor
    private func translateDocument(using session: TranslationSession) async {
        guard let content = coordinator.documentState.currentDocument?.content else {
            translationState.fail(with: "No document is available to translate.")
            return
        }

        let requests = parseBlocks(content).compactMap { block -> TranslationSession.Request? in
            guard block.shouldTranslate else { return nil }
            return TranslationSession.Request(
                sourceText: block.text,
                clientIdentifier: String(block.startLine)
            )
        }

        do {
            let responses = try await session.translations(from: requests)
            let translatedBlocks = Dictionary<Int, String>(
                uniqueKeysWithValues: responses.compactMap { response -> (Int, String)? in
                    guard let identifier = response.clientIdentifier,
                          let line = Int(identifier) else {
                        return nil
                    }
                    return (line, response.targetText)
                }
            )
            translationState.complete(with: translatedBlocks)
        } catch {
            translationState.fail(with: error.localizedDescription)
        }
    }

    private func resetTranslation() {
        translationConfiguration = nil
        translationState.reset()
    }
    #endif

    private func displayedBlock(_ block: ContentBlock) -> ContentBlock {
        #if os(macOS)
        if translationState.isShowingChinese,
           let translatedText = translationState.translatedBlocks[block.startLine] {
            return ContentBlock(
                type: block.type,
                text: translatedText,
                startLine: block.startLine,
                anchorID: block.anchorID
            )
        }
        #endif

        return block
    }

    /// Renders the markdown content with proper formatting
    private var formattedContent: some View {
        let rawContent = coordinator.documentState.currentDocument?.content ?? ""
        let blocks = parseBlocks(rawContent)
        let showNumbers = coordinator.uiState.showLineNumbers

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(displayedBlock(block), index: index, showNumbers: showNumbers)
                    .id(block.anchorID)
            }
        }
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func blockView(_ block: ContentBlock, index: Int, showNumbers: Bool) -> some View {
        switch block.type {
        case .unorderedList:
            listBlockView(block, index: index, showNumbers: showNumbers, ordered: false)
        case .orderedList:
            listBlockView(block, index: index, showNumbers: showNumbers, ordered: true)
        case .table:
            tableBlockView(block, index: index, showNumbers: showNumbers)
        default:
            singleBlockRow(block, index: index, showNumbers: showNumbers)
        }
    }

    private func singleBlockRow(_ block: ContentBlock, index: Int, showNumbers: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if showNumbers {
                Text("\(block.startLine)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(coordinator.documentState.focusedLine == block.startLine ? Color.accentColor : Color.gray.opacity(0.4))
                    .frame(width: 36, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            blockContent(block, blockIndex: index)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            coordinator.documentState.focusedLine == block.startLine
                ? Color.accentColor.opacity(0.12)
                : (index % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
        )
        .overlay {
            Color.clear
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    coordinator.documentState.focusedLine = block.startLine
                })
        }
        .id("content-line-\(block.startLine)")
    }

    /// Renders each list item as its own row with individual line shading
    private func listBlockView(_ block: ContentBlock, index: Int, showNumbers: Bool, ordered: Bool) -> some View {
        let items = block.text.components(separatedBy: "\n").filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { itemIdx, item in
                let lineNum = block.startLine + itemIdx
                let rowIndex = index + itemIdx
                HStack(alignment: .top, spacing: 0) {
                    if showNumbers {
                        Text("\(lineNum)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .frame(width: 36, alignment: .trailing)
                            .padding(.trailing, 8)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        if ordered {
                            Text("\(itemIdx + 1).")
                                .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                        } else {
                            Text("•")
                                .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .center)
                        }
                        Text(inlineFormatted(item, segID: "seg-\(index)-\(itemIdx)"))
                            .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                            .foregroundStyle(themeManager.color(for: .primary))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(rowIndex % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
            }
        }
    }

    @ViewBuilder
    private func blockContent(_ block: ContentBlock, blockIndex: Int) -> some View {
        let segID = "seg-\(blockIndex)"
        switch block.type {
        case .heading(let level):
            headingView(block.text, level: level, segID: segID)
        case .codeBlock(let language):
            codeBlockView(block.text, language: language, segID: segID)
        case .blockquote:
            blockquoteView(block.text, segID: segID)
        case .unorderedList:
            listView(block.text, ordered: false)
        case .orderedList:
            listView(block.text, ordered: true)
        case .table:
            tableView(block.text)
        case .horizontalRule:
            Divider().padding(.vertical, 12)
        case .paragraph:
            paragraphView(block.text, segID: segID)
        case .empty:
            Spacer().frame(height: 8)
        }
    }

    // MARK: - Heading

    private func headingView(_ text: String, level: Int, segID: String? = nil) -> some View {
        let fontSize: CGFloat = switch level {
            case 1: 28
            case 2: 24
            case 3: 20
            case 4: 17
            case 5: 15
            default: 14
        }
        let weight: Font.Weight = level <= 2 ? .bold : .semibold
        let topPad: CGFloat = level == 1 ? 20 : (level == 2 ? 16 : 12)

        return Text(inlineFormatted(text, segID: segID))
            .font(.system(size: fontSize * themeManager.fontSizeMultiplier, weight: weight))
            .foregroundStyle(themeManager.color(for: .primary))
            .padding(.top, topPad)
            .padding(.bottom, 6)
            .textSelection(.enabled)
    }

    // MARK: - Paragraph

    private func paragraphView(_ text: String, segID: String? = nil) -> some View {
        // Rendered as a single Text (newlines preserved) so the whole paragraph is one
        // find segment; per-line splitting would fragment match indexing.
        Text(inlineFormatted(text, segID: segID))
            .font(.system(size: 15 * themeManager.fontSizeMultiplier))
            .lineSpacing(4 * themeManager.lineSpacingMultiplier)
            .foregroundStyle(themeManager.color(for: .primary))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    // MARK: - Code Block

    private func codeBlockView(_ text: String, language: String?, segID: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = language, !lang.isEmpty {
                Text(lang)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            Text(segID.map { findHighlightedPlain(text, segID: $0) } ?? AttributedString(text))
                .font(.system(size: 13 * themeManager.fontSizeMultiplier, design: .monospaced))
                .foregroundStyle(themeManager.color(for: .primary))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.15), lineWidth: 1))
        .padding(.vertical, 6)
    }

    // MARK: - Blockquote

    private func blockquoteView(_ text: String, segID: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 4)

            Text(inlineFormatted(text, segID: segID))
                .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                .italic()
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .padding(.vertical, 4)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    // MARK: - List

    // Lists are rendered by listBlockView above — this is kept for the blockContent switch
    private func listView(_ text: String, ordered: Bool) -> some View {
        let items = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 8) {
                    if ordered {
                        Text("\(idx + 1).")
                            .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    } else {
                        Text("•")
                            .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .center)
                    }
                    Text(inlineFormatted(item))
                        .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                        .foregroundStyle(themeManager.color(for: .primary))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
    }

    // MARK: - Table

    /// Renders each table row as its own line with individual shading
    private func tableBlockView(_ block: ContentBlock, index: Int, showNumbers: Bool) -> some View {
        let rows = parseTableRows(block.text)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                if rowIdx == 1 && isSeperatorRow(row) {
                    // Render separator as a thin divider line
                    HStack(spacing: 0) {
                        if showNumbers {
                            Text("\(block.startLine + rowIdx)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.gray.opacity(0.4))
                                .frame(width: 36, alignment: .trailing)
                                .padding(.trailing, 8)
                        }
                        Divider().frame(height: 1)
                    }
                    .padding(.horizontal, 8)
                } else {
                    let lineNum = block.startLine + rowIdx
                    let rowIndex = index + rowIdx
                    HStack(alignment: .top, spacing: 0) {
                        if showNumbers {
                            Text("\(lineNum)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.gray.opacity(0.4))
                                .frame(width: 36, alignment: .trailing)
                                .padding(.trailing, 8)
                        }

                        tableRowCells(row, isHeader: rowIdx == 0, segIDPrefix: "seg-\(index)-r\(rowIdx)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(rowIndex % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
                }
            }
        }
    }

    private func tableRowCells(_ cells: [String], isHeader: Bool, segIDPrefix: String? = nil) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { colIdx, cell in
                Text(inlineFormatted(cell.trimmingCharacters(in: .whitespaces), segID: segIDPrefix.map { "\($0)-c\(colIdx)" }))
                    .font(.system(size: 14 * themeManager.fontSizeMultiplier, weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(themeManager.color(for: .primary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if colIdx < cells.count - 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1)
                }
            }
        }
        .background(isHeader ? Color.gray.opacity(0.08) : Color.clear)
    }

    /// tableView kept for blockContent switch (used in compare view)
    private func tableView(_ text: String) -> some View {
        let rows = parseTableRows(text)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                if rowIdx == 1 && isSeperatorRow(row) {
                    Divider()
                } else {
                    tableRowCells(row, isHeader: rowIdx == 0)
                        .padding(.vertical, 2)
                        .background(rowIdx % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .padding(.vertical, 4)
    }

    private func parseTableRows(_ text: String) -> [[String]] {
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let inner: String
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                inner = String(trimmed.dropFirst().dropLast())
            } else if trimmed.hasPrefix("|") {
                inner = String(trimmed.dropFirst())
            } else {
                inner = trimmed
            }
            return inner.components(separatedBy: "|")
        }
    }

    private func isSeperatorRow(_ cells: [String]) -> Bool {
        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } && !trimmed.isEmpty
        }
    }

    // MARK: - Inline Formatting

    /// Parses inline markdown (bold, italic, code, links) into AttributedString.
    /// When `segID` is provided and the content find bar is active, find matches in the
    /// rendered text are highlighted (the current match emphasized).
    private func inlineFormatted(_ text: String, segID: String? = nil) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                let marker = String(remaining.prefix(2))
                remaining = remaining.dropFirst(2)
                if let endIdx = remaining.range(of: marker) {
                    var bold = AttributedString(String(remaining[..<endIdx.lowerBound]))
                    bold.font = .body.bold()
                    result.append(bold)
                    remaining = remaining[endIdx.upperBound...]
                } else {
                    result.append(AttributedString(marker))
                }
            } else if remaining.hasPrefix("*") || remaining.hasPrefix("_") {
                let marker = String(remaining.prefix(1))
                remaining = remaining.dropFirst(1)
                if let endIdx = remaining.range(of: marker) {
                    var italic = AttributedString(String(remaining[..<endIdx.lowerBound]))
                    italic.font = .body.italic()
                    result.append(italic)
                    remaining = remaining[endIdx.upperBound...]
                } else {
                    result.append(AttributedString(marker))
                }
            } else if remaining.hasPrefix("`") {
                remaining = remaining.dropFirst(1)
                if let endIdx = remaining.firstIndex(of: "`") {
                    var code = AttributedString(String(remaining[..<endIdx]))
                    code.font = .system(size: 13, design: .monospaced)
                    code.backgroundColor = Color.gray.opacity(0.12)
                    result.append(code)
                    remaining = remaining[remaining.index(after: endIdx)...]
                } else {
                    result.append(AttributedString("`"))
                }
            } else if remaining.hasPrefix("[") {
                // Try to parse [text](url)
                if let closeBracket = remaining.firstIndex(of: "]"),
                   remaining[remaining.index(after: closeBracket)...].hasPrefix("("),
                   let closeParen = remaining[remaining.index(after: closeBracket)...].firstIndex(of: ")") {
                    let linkText = String(remaining[remaining.index(after: remaining.startIndex)..<closeBracket])
                    let urlStr = String(remaining[remaining.index(closeBracket, offsetBy: 2)..<closeParen])
                    var link = AttributedString(linkText)
                    link.foregroundColor = .blue
                    link.underlineStyle = .single
                    if let url = URL(string: urlStr) {
                        link.link = url
                    }
                    result.append(link)
                    remaining = remaining[remaining.index(after: closeParen)...]
                } else {
                    result.append(AttributedString(String(remaining.prefix(1))))
                    remaining = remaining.dropFirst(1)
                }
            } else {
                // Regular character
                result.append(AttributedString(String(remaining.prefix(1))))
                remaining = remaining.dropFirst(1)
            }
        }

        if let segID {
            applyContentFindHighlight(&result, segID: segID)
        }
        return result
    }

    // MARK: - Content Find Support

    /// The content find bar bound to `coordinator.contentFind`.
    private var contentFindBar: some View {
        FindBarView(
            state: coordinator.contentFind,
            placeholder: "Find in document",
            onNext: { coordinator.contentFind.goToNextMatch() },
            onPrevious: { coordinator.contentFind.goToPreviousMatch() },
            onClose: { coordinator.contentFind.close() }
        )
    }

    /// Stacks the content find bar above/below `content` at the configured edge and
    /// wires recompute triggers. Used by the markdown and structured-text branches.
    @ViewBuilder
    private func withContentFindBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            if coordinator.contentFind.isVisible && coordinator.uiState.findBarPosition == .top {
                contentFindBar
                Divider()
            }
            content()
            if coordinator.contentFind.isVisible && coordinator.uiState.findBarPosition == .bottom {
                Divider()
                contentFindBar
            }
        }
        .onChange(of: coordinator.contentFind.isVisible) { _, visible in
            if visible { recomputeContentFind() } else { clearContentFind() }
        }
        .onChange(of: coordinator.contentFind.query) { _, _ in recomputeContentFind() }
        .onChange(of: coordinator.contentFind.options) { _, _ in recomputeContentFind() }
        .onChange(of: coordinator.contentFind.currentIndex) { _, _ in updateContentFindCurrent() }
        .onChange(of: coordinator.documentState.currentDocument?.content) { _, _ in
            if coordinator.contentFind.isVisible { recomputeContentFind() }
        }
    }

    /// Highlights find matches within a rendered leaf's `AttributedString`.
    /// All matches get a faint background; the current match (when in this leaf) is emphasized.
    private func applyContentFindHighlight(_ attr: inout AttributedString, segID: String) {
        let find = coordinator.contentFind
        guard find.isVisible, !find.query.isEmpty, !find.regexInvalid else { return }

        let currentOccurrence = (segID == findCurrentSegID) ? findCurrentLocal : nil
        attr = ContentFindHighlighter.highlight(
            attr,
            query: find.query,
            options: find.options,
            currentOccurrence: currentOccurrence
        )
    }

    /// Convenience for plain (non-inline-markdown) leaves — code blocks and structured text.
    private func findHighlightedPlain(_ text: String, segID: String) -> AttributedString {
        var attr = AttributedString(text)
        applyContentFindHighlight(&attr, segID: segID)
        return attr
    }

    /// Recomputes the content-pane match set (count, per-segment offsets, current match)
    /// from the current document and query. Called when the query/options/content change.
    private func recomputeContentFind() {
        let find = coordinator.contentFind
        guard find.isVisible, !find.query.isEmpty else {
            find.matchCount = 0
            find.regexInvalid = false
            findSegments = []
            findCurrentSegID = nil
            findScrollAnchor = nil
            return
        }

        let options = find.options
        if options.useRegex, !FindMatching.isValidRegex(find.query, options: options) {
            find.regexInvalid = true
            find.matchCount = 0
            findSegments = []
            findCurrentSegID = nil
            findScrollAnchor = nil
            return
        }
        find.regexInvalid = false

        let content = coordinator.documentState.currentDocument?.content ?? ""
        var segments: [FindSegment] = []
        var running = 0
        for segment in contentFindSegments(content) {
            let count = FindMatching.matchRanges(in: segment.plain, query: find.query, options: options).count
            guard count > 0 else { continue }
            segments.append(FindSegment(id: segment.id, anchorID: segment.anchorID, start: running, count: count))
            running += count
        }

        findSegments = segments
        find.matchCount = running
        find.clampCurrentIndex()
        updateContentFindCurrent()
    }

    /// Maps the current global match index to its owning segment (for emphasis + scroll).
    private func updateContentFindCurrent() {
        let current = coordinator.contentFind.currentIndex
        for segment in findSegments where current >= segment.start && current < segment.start + segment.count {
            findCurrentSegID = segment.id
            findCurrentLocal = current - segment.start
            findScrollAnchor = segment.anchorID
            return
        }
        findCurrentSegID = nil
        findCurrentLocal = 0
        findScrollAnchor = nil
    }

    /// Clears all content-find bookkeeping (on close).
    private func clearContentFind() {
        coordinator.contentFind.matchCount = 0
        coordinator.contentFind.regexInvalid = false
        findSegments = []
        findCurrentSegID = nil
        findCurrentLocal = 0
        findScrollAnchor = nil
    }

    /// Enumerates rendered leaves (in render order) as `(segID, anchorID, plainText)`,
    /// mirroring the renderer so match counts and highlight offsets align.
    private func contentFindSegments(_ content: String) -> [(id: String, anchorID: String, plain: String)] {
        let format = coordinator.documentState.currentDocument?.format
        if format == .json || format == .xml {
            return [(id: "structured", anchorID: "structured", plain: content)]
        }

        var segments: [(id: String, anchorID: String, plain: String)] = []
        for (index, block) in parseBlocks(content).enumerated() {
            switch block.type {
            case .heading, .paragraph, .blockquote:
                segments.append((id: "seg-\(index)", anchorID: block.anchorID, plain: plainInline(block.text)))
            case .codeBlock:
                segments.append((id: "seg-\(index)", anchorID: block.anchorID, plain: block.text))
            case .unorderedList, .orderedList:
                let items = block.text.components(separatedBy: "\n").filter { !$0.isEmpty }
                for (itemIdx, item) in items.enumerated() {
                    segments.append((id: "seg-\(index)-\(itemIdx)", anchorID: block.anchorID, plain: plainInline(item)))
                }
            case .table:
                let rows = parseTableRows(block.text)
                for (rowIdx, row) in rows.enumerated() {
                    if rowIdx == 1 && isSeperatorRow(row) { continue }
                    for (colIdx, cell) in row.enumerated() {
                        segments.append((
                            id: "seg-\(index)-r\(rowIdx)-c\(colIdx)",
                            anchorID: block.anchorID,
                            plain: plainInline(cell.trimmingCharacters(in: .whitespaces))
                        ))
                    }
                }
            case .horizontalRule, .empty:
                break
            }
        }
        return segments
    }

    /// Rendered plain text of an inline-markdown string (markers stripped), matching
    /// what `inlineFormatted` displays so find offsets line up.
    private func plainInline(_ text: String) -> String {
        String(inlineFormatted(text).characters)
    }

    // MARK: - Block Parser

    /// Parses raw markdown into structured blocks for rendering
    private func parseBlocks(_ content: String) -> [ContentBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [ContentBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                blocks.append(ContentBlock(type: .empty, text: "", startLine: i + 1, anchorID: "line-\(i)"))
                i += 1
            } else if trimmed.hasPrefix("```") {
                // Code block
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing ```
                let startLine = i - codeLines.count - 1
                blocks.append(ContentBlock(
                    type: .codeBlock(language: language.isEmpty ? nil : language),
                    text: codeLines.joined(separator: "\n"),
                    startLine: startLine,
                    anchorID: "line-\(startLine)"
                ))
            } else if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let headingText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(ContentBlock(
                    type: .heading(level: min(level, 6)),
                    text: headingText,
                    startLine: i + 1,
                    anchorID: "heading-\(headingText)"
                ))
                i += 1
            } else if trimmed.hasPrefix(">") {
                // Blockquote - collect consecutive > lines
                var quoteLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let qLine = lines[i].trimmingCharacters(in: .whitespaces)
                    quoteLines.append(String(qLine.dropFirst(1)).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                let startLine = i - quoteLines.count + 1
                blocks.append(ContentBlock(
                    type: .blockquote,
                    text: quoteLines.joined(separator: "\n"),
                    startLine: startLine,
                    anchorID: "line-\(startLine)"
                ))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                // Unordered list
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("- ") || l.hasPrefix("* ") || l.hasPrefix("+ ") {
                        items.append(String(l.dropFirst(2)))
                        i += 1
                    } else { break }
                }
                let startLine = i - items.count + 1
                blocks.append(ContentBlock(
                    type: .unorderedList,
                    text: items.joined(separator: "\n"),
                    startLine: startLine,
                    anchorID: "line-\(startLine)"
                ))
            } else if let _ = trimmed.first, trimmed.first!.isNumber,
                      trimmed.contains(". ") {
                // Ordered list
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if let dotIdx = l.firstIndex(of: "."), l[..<dotIdx].allSatisfy({ $0.isNumber }),
                       l[l.index(after: dotIdx)...].hasPrefix(" ") {
                        items.append(String(l[l.index(dotIdx, offsetBy: 2)...]))
                        i += 1
                    } else { break }
                }
                let startLine = i - items.count + 1
                blocks.append(ContentBlock(
                    type: .orderedList,
                    text: items.joined(separator: "\n"),
                    startLine: startLine,
                    anchorID: "line-\(startLine)"
                ))
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(ContentBlock(type: .horizontalRule, text: "", startLine: i + 1, anchorID: "line-\(i)"))
                i += 1
            } else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                // Table - collect consecutive | lines
                var tableLines: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("|") && l.hasSuffix("|") {
                        tableLines.append(l)
                        i += 1
                    } else if l.hasPrefix("|") && l.contains("|") {
                        // Handle lines like "| cell | cell |" that might not end with |
                        tableLines.append(l)
                        i += 1
                    } else {
                        break
                    }
                }
                let startLine = i - tableLines.count + 1
                blocks.append(ContentBlock(
                    type: .table,
                    text: tableLines.joined(separator: "\n"),
                    startLine: startLine,
                    anchorID: "line-\(startLine)"
                ))
            } else {
                // Paragraph - collect consecutive non-empty, non-special lines
                var paraLines: [String] = []
                while i < lines.count {
                    let l = lines[i]
                    let t = l.trimmingCharacters(in: .whitespaces)
                    if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix(">") ||
                       t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") ||
                       t == "---" || t == "***" || t == "___" ||
                       (t.hasPrefix("|") && t.contains("|")) {
                        break
                    }
                    if let first = t.first, first.isNumber, t.contains(". ") {
                        let dotIdx = t.firstIndex(of: ".")!
                        if t[..<dotIdx].allSatisfy({ $0.isNumber }) { break }
                    }
                    paraLines.append(l)
                    i += 1
                }
                let startLine = i - paraLines.count + 1
                blocks.append(ContentBlock(
                    type: .paragraph,
                    text: paraLines.joined(separator: "\n"),
                    startLine: startLine,
                    anchorID: "line-\(startLine)"
                ))
            }
        }

        return blocks
    }

    // MARK: - Compare View

    private var compareView: some View {
        HSplitView {
            VStack(spacing: 0) {
                compareHeader(title: coordinator.documentState.currentDocument?.title ?? "Document 1")
                ScrollView {
                    compareRendered(coordinator.documentState.currentDocument?.content ?? "")
                }
            }
            VStack(spacing: 0) {
                compareHeader(title: coordinator.documentState.compareDocument?.title ?? "Document 2")
                ScrollView {
                    compareRendered(coordinator.documentState.compareDocument?.content ?? "")
                }
            }
        }
    }

    private func compareHeader(title: String) -> some View {
        HStack {
            Text(title).font(.headline).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }

    private func compareRendered(_ content: String) -> some View {
        let blocks = parseBlocks(content)
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block, index: index, showNumbers: false)
            }
        }
        .padding(12)
    }

    // MARK: - Empty

    private var emptyView: some View {
        EmptyStateView(
            title: "No Document Selected",
            message: "Choose a supported document to begin reading",
            systemImage: "doc.text"
        )
    }
}

// MARK: - Content Block Model

private struct ContentBlock {
    enum BlockType {
        case heading(level: Int)
        case paragraph
        case codeBlock(language: String?)
        case blockquote
        case unorderedList
        case orderedList
        case horizontalRule
        case table
        case empty
    }

    let type: BlockType
    let text: String
    let startLine: Int
    let anchorID: String

    var shouldTranslate: Bool {
        switch type {
        case .codeBlock, .horizontalRule, .empty:
            return false
        default:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

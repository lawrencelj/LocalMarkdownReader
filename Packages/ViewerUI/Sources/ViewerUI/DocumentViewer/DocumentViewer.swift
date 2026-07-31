// DocumentViewer - Main markdown content display component
//
// Renders parsed markdown with proper formatting: headings, bold, italic,
// code blocks, lists, blockquotes, and links. Supports line numbers,
// alternating line shading, and scroll-to-heading navigation.
//
// Parsing is delegated to `MarkdownCore.MarkdownBlockParser` (swift-markdown),
// so this viewer and the core engine share one parser rather than each carrying
// their own. The view converts the resulting `MarkdownBlock`/`InlineRun` model
// into SwiftUI text, and layers per-pane find highlighting, line numbers,
// scroll anchors, and whole-document translation on top of it.

import MarkdownCore
import Settings
import SwiftUI

#if os(macOS)
    import CryptoKit
    import _Translation_SwiftUI
    import Translation
#endif

/// Main document viewer component
public struct DocumentViewer: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.themeManager) private var themeManager

    #if os(macOS)
        @State private var translationConfiguration: TranslationSession.Configuration?
        @State private var translationState = DocumentTranslationState()
        @State private var translationCache = TranslationCache()
        @State private var activeTranslationSession: TranslationSession?
        @State private var translationRequestID = UUID()
    #endif

    // MARK: - Content Find State

    /// A rendered leaf (block, list item, or table cell) that contains find matches.
    private struct FindSegment {
        let id: String // stable segment ID, matching the leaf's `segID`
        let anchorID: String // scroll target (the block's anchor)
        let start: Int // global index of this segment's first match
        let count: Int // number of matches in this segment
    }

    /// Segments (with matches) in document order, for count + navigation + scroll.
    @State private var findSegments: [FindSegment] = []
    /// Segment ID of the current match's leaf, so that leaf can emphasize it.
    @State private var findCurrentSegID: String?
    /// Index of the current match within its segment.
    @State private var findCurrentLocal = 0
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
        #if os(macOS)
        .onChange(of: coordinator.documentState.currentDocument?.id) { _, _ in
            resetTranslation()
        }
        #endif
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
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") { Task { await coordinator.refreshDocument() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Document Content

    @ViewBuilder private var documentContentView: some View {
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
                // TranslationSession is lifecycle-bound to this subtree. A document
                // identity prevents SwiftUI from reusing the completed first session
                // when a second document is opened.
                markdownDocumentContent
                    .id("translation-document-\(document.id.uuidString)")
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
                        if let headingID {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(headingID, anchor: .top)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                coordinator.documentState.scrollToHeadingID = nil
                            }
                        }
                    }
                    .onChange(of: coordinator.documentState.focusedLine) { _, line in
                        if let line {
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
                    Text(translationState.progressText ?? "Preparing translation…")
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
                    if translationState.isTranslating {
                        cancelTranslation()
                    } else {
                        toggleTranslation()
                    }
                } label: {
                    Label(
                        translationState.isTranslating
                            ? "Cancel"
                            : (translationState.isShowingChinese ? "Show English" : "Translate to Chinese"),
                        systemImage: translationState.isTranslating
                            ? "xmark"
                            : (translationState.isShowingChinese ? "arrow.uturn.backward" : "character.bubble")
                    )
                }
                .buttonStyle(.bordered)
                .help(translationState.isShowingChinese
                    ? "Turn off translation and show the English document"
                    : "Translate the whole document to Simplified Chinese")
                .accessibilityLabel(translationState.isShowingChinese
                    ? "Turn off translation and show English"
                    : "Translate whole document to Chinese")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }

        private func toggleTranslation() {
            guard translationState.toggle() == .startTranslation else { return }
            guard let content = coordinator.documentState.currentDocument?.content else {
                translationState.fail(with: "No document is available to translate.")
                return
            }

            let cacheKey = translationCacheKey(for: content)
            if let cached = translationCache.load(for: cacheKey) {
                translationState.showCachedTranslation(cached)
                return
            }

            let requestID = UUID()
            translationRequestID = requestID
            Task { @MainActor in
                let availability = LanguageAvailability()
                let source = Locale.Language(identifier: "en")
                let target = Locale.Language(identifier: "zh-Hans")
                let status = await availability.status(from: source, to: target)

                guard requestID == translationRequestID else { return }

                guard status != .unsupported else {
                    translationState.fail(with: "English to Simplified Chinese is not available on this Mac.")
                    return
                }

                if #available(macOS 26.4, *) {
                    translationConfiguration = TranslationSession.Configuration(
                        source: source,
                        target: target,
                        preferredStrategy: .lowLatency
                    )
                } else {
                    translationConfiguration = TranslationSession.Configuration(
                        source: source,
                        target: target
                    )
                }
            }
        }

        private func cancelTranslation() {
            translationRequestID = UUID()
            if #available(macOS 26.0, *) {
                activeTranslationSession?.cancel()
            }
            translationConfiguration?.invalidate()
            translationConfiguration = nil
            activeTranslationSession = nil
            translationState.cancel()
        }

        @MainActor
        private func translateDocument(using session: TranslationSession) async {
            let requestID = translationRequestID
            guard let content = coordinator.documentState.currentDocument?.content else {
                translationState.fail(with: "No document is available to translate.")
                return
            }

            let requests = MarkdownBlockParser.parse(content).compactMap { block -> TranslationSession.Request? in
                guard block.isTranslatable, let text = translatableText(block) else { return nil }
                return TranslationSession.Request(
                    sourceText: text,
                    clientIdentifier: String(block.sourceLine)
                )
            }

            guard !requests.isEmpty else {
                translationState.fail(with: "There is no translatable text in this document.")
                return
            }

            translationState.beginTranslation(totalBlockCount: requests.count)
            activeTranslationSession = session
            defer {
                if requestID == translationRequestID {
                    activeTranslationSession = nil
                }
            }

            do {
                var translatedBlocks: [Int: String] = [:]
                for try await response in session.translate(batch: requests) {
                    guard requestID == translationRequestID else { return }
                    guard let identifier = response.clientIdentifier,
                          let line = Int(identifier) else { continue }
                    translatedBlocks[line] = response.targetText
                    translationState.translatedBlockArrived(line: line, text: response.targetText)
                }

                guard requestID == translationRequestID else { return }

                guard !translatedBlocks.isEmpty else {
                    translationState.fail(with: "The translation returned no results.")
                    return
                }

                translationCache.save(translatedBlocks, for: translationCacheKey(for: content))
                translationState.complete(with: translatedBlocks)
            } catch is CancellationError {
                if requestID == translationRequestID {
                    translationState.cancel()
                }
            } catch {
                if requestID == translationRequestID {
                    translationState.fail(with: error.localizedDescription)
                }
            }
        }

        private func resetTranslation() {
            translationRequestID = UUID()
            if #available(macOS 26.0, *) {
                activeTranslationSession?.cancel()
            }
            translationConfiguration = nil
            activeTranslationSession = nil
            translationState.reset()
        }

        private func translationCacheKey(for content: String) -> String {
            let input = "en\u{1F}zh-Hans\u{1F}\(content)"
            return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
        }

        /// The plain text offered to the translator for a block (nil if nothing to translate).
        private func translatableText(_ block: MarkdownBlock) -> String? {
            switch block.kind {
            case .unorderedList, .orderedList:
                return block.listItems.map { $0.plainText }.joined(separator: "\n")
            case .table, .codeBlock, .thematicBreak:
                return nil
            default:
                let text = block.plainText
                return text.isEmpty ? nil : text
            }
        }
    #endif

    /// Applies an active Chinese translation to a block by substituting its text.
    /// Only heading/paragraph/blockquote and lists are substituted (tables/code
    /// are left in the source language, matching what is offered to the translator).
    private func displayedBlock(_ block: MarkdownBlock) -> MarkdownBlock {
        #if os(macOS)
            if translationState.isShowingChinese,
               let translated = translationState.translatedBlocks[block.sourceLine] {
                switch block.kind {
                case .unorderedList, .orderedList:
                    let items = translated.components(separatedBy: "\n").map { [InlineRun(text: $0)] }
                    return MarkdownBlock(
                        id: block.id,
                        kind: block.kind,
                        sourceLine: block.sourceLine,
                        listItems: items
                    )
                case .table, .codeBlock, .thematicBreak:
                    return block
                default:
                    return MarkdownBlock(
                        id: block.id,
                        kind: block.kind,
                        sourceLine: block.sourceLine,
                        runs: [InlineRun(text: translated)]
                    )
                }
            }
        #endif
        return block
    }

    /// Renders the markdown content with proper formatting
    private var formattedContent: some View {
        let rawContent = coordinator.documentState.currentDocument?.content ?? ""
        let blocks = MarkdownBlockParser.parse(rawContent)
        let showNumbers = coordinator.uiState.showLineNumbers

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                blockView(displayedBlock(block), showNumbers: showNumbers)
                    .id(block.anchorID)
            }
        }
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock, showNumbers: Bool) -> some View {
        switch block.kind {
        case .unorderedList:
            listBlockView(block, showNumbers: showNumbers, ordered: false)
        case .orderedList:
            listBlockView(block, showNumbers: showNumbers, ordered: true)
        case .table:
            tableBlockView(block, showNumbers: showNumbers)
        default:
            singleBlockRow(block, showNumbers: showNumbers)
        }
    }

    private func singleBlockRow(_ block: MarkdownBlock, showNumbers: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if showNumbers {
                Text("\(block.sourceLine)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(coordinator.documentState.focusedLine == block.sourceLine
                        ? Color.accentColor
                        : Color.gray.opacity(0.4))
                    .frame(width: 36, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            blockContent(block)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            coordinator.documentState.focusedLine == block.sourceLine
                ? Color.accentColor.opacity(0.12)
                : (block.id % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
        )
        .overlay {
            Color.clear
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    coordinator.documentState.focusedLine = block.sourceLine
                })
        }
        .id("content-line-\(block.sourceLine)")
    }

    /// Renders each list item as its own row with individual line shading
    private func listBlockView(_ block: MarkdownBlock, showNumbers: Bool, ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(block.listItems.enumerated()), id: \.offset) { itemIdx, item in
                let lineNum = block.sourceLine + itemIdx
                let rowIndex = block.id + itemIdx
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
                        Text(attributed(item, segID: "seg-\(block.id)-\(itemIdx)"))
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
    private func blockContent(_ block: MarkdownBlock) -> some View {
        let segID = "seg-\(block.id)"
        switch block.kind {
        case let .heading(level):
            headingView(block.runs, level: level, segID: segID)
        case let .codeBlock(language):
            codeBlockView(block.code, language: language, segID: segID)
        case .blockquote:
            blockquoteView(block.runs, segID: segID)
        case .thematicBreak:
            Divider().padding(.vertical, 12)
        case .paragraph:
            paragraphView(block.runs, segID: segID)
        default:
            // Lists and tables are routed to their own multi-row renderers in
            // `blockView`; this branch is unreachable for them.
            EmptyView()
        }
    }

    // MARK: - Heading

    private func headingView(_ runs: [InlineRun], level: Int, segID: String? = nil) -> some View {
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

        return Text(attributed(runs, segID: segID))
            .font(.system(size: fontSize * themeManager.fontSizeMultiplier, weight: weight))
            .foregroundStyle(themeManager.color(for: .primary))
            .padding(.top, topPad)
            .padding(.bottom, 6)
            .textSelection(.enabled)
    }

    // MARK: - Paragraph

    private func paragraphView(_ runs: [InlineRun], segID: String? = nil) -> some View {
        // Rendered as a single Text (newlines preserved) so the whole paragraph is one
        // find segment; per-line splitting would fragment match indexing.
        Text(attributed(runs, segID: segID))
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

    private func blockquoteView(_ runs: [InlineRun], segID: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 4)

            Text(attributed(runs, segID: segID))
                .font(.system(size: 15 * themeManager.fontSizeMultiplier))
                .italic()
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .padding(.vertical, 4)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Table

    /// Renders each table row as its own line with individual shading. Row 0 is
    /// the header row, followed by a divider and the body rows.
    private func tableBlockView(_ block: MarkdownBlock, showNumbers: Bool) -> some View {
        let rows = block.tableRows

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                // Header line maps to the source line; body rows skip the
                // separator line that sits between header and body in source.
                let lineNum = rowIdx == 0 ? block.sourceLine : block.sourceLine + rowIdx + 1
                let rowIndex = block.id + rowIdx
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        if showNumbers {
                            Text("\(lineNum)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.gray.opacity(0.4))
                                .frame(width: 36, alignment: .trailing)
                                .padding(.trailing, 8)
                        }

                        tableRowCells(row, isHeader: rowIdx == 0, segIDPrefix: "seg-\(block.id)-r\(rowIdx)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(rowIndex % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))

                    if rowIdx == 0 {
                        Divider()
                    }
                }
            }
        }
    }

    private func tableRowCells(_ cells: [[InlineRun]], isHeader: Bool, segIDPrefix: String? = nil) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { colIdx, cell in
                Text(attributed(cell, segID: segIDPrefix.map { "\($0)-c\(colIdx)" }))
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

    // MARK: - Inline Rendering

    /// Builds an `AttributedString` from styled inline runs, matching the styling
    /// the previous hand-rolled renderer produced (bold/italic/code/link) and
    /// adding strikethrough. When `segID` is provided and the content find bar is
    /// active, find matches are highlighted (the current match emphasized).
    private func attributed(_ runs: [InlineRun], segID: String? = nil) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var piece = AttributedString(run.text)
            if run.isCode {
                piece.font = .system(size: 13, design: .monospaced)
                piece.backgroundColor = Color.gray.opacity(0.12)
            } else if run.isBold, run.isItalic {
                piece.font = .body.bold().italic()
            } else if run.isBold {
                piece.font = .body.bold()
            } else if run.isItalic {
                piece.font = .body.italic()
            }
            if run.isStrikethrough {
                piece.strikethroughStyle = .single
            }
            if let link = run.link, let url = URL(string: link) {
                piece.foregroundColor = .blue
                piece.underlineStyle = .single
                piece.link = url
            }
            result.append(piece)
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
    private func withContentFindBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            if coordinator.contentFind.isVisible, coordinator.uiState.findBarPosition == .top {
                contentFindBar
                Divider()
            }
            content()
            if coordinator.contentFind.isVisible, coordinator.uiState.findBarPosition == .bottom {
                Divider()
                contentFindBar
            }
        }
        .onChange(of: coordinator.contentFind.isVisible) { _, visible in
            if visible {
                recomputeContentFind()
            } else {
                clearContentFind()
            }
        }
        .onChange(of: coordinator.contentFind.query) { _, _ in recomputeContentFind() }
        .onChange(of: coordinator.contentFind.options) { _, _ in recomputeContentFind() }
        .onChange(of: coordinator.contentFind.currentIndex) { _, _ in updateContentFindCurrent() }
        .onChange(of: coordinator.documentState.currentDocument?.content) { _, _ in
            if coordinator.contentFind.isVisible {
                recomputeContentFind()
            }
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
        for block in MarkdownBlockParser.parse(content) {
            switch block.kind {
            case .heading, .paragraph, .blockquote:
                segments.append((id: "seg-\(block.id)", anchorID: block.anchorID, plain: block.plainText))
            case .codeBlock:
                segments.append((id: "seg-\(block.id)", anchorID: block.anchorID, plain: block.code))
            case .unorderedList, .orderedList:
                for (itemIdx, item) in block.listItems.enumerated() {
                    segments.append((id: "seg-\(block.id)-\(itemIdx)", anchorID: block.anchorID, plain: item.plainText))
                }
            case .table:
                for (rowIdx, row) in block.tableRows.enumerated() {
                    for (colIdx, cell) in row.enumerated() {
                        segments.append((
                            id: "seg-\(block.id)-r\(rowIdx)-c\(colIdx)",
                            anchorID: block.anchorID,
                            plain: cell.plainText
                        ))
                    }
                }
            case .thematicBreak:
                break
            }
        }
        return segments
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
        let blocks = MarkdownBlockParser.parse(content)
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                blockView(block, showNumbers: false)
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

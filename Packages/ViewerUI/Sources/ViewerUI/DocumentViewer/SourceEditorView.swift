/// SourceEditorView - Editable markdown source with spell checking

import SwiftUI
import AppKit
import FileAccess
import MarkdownCore
import UniformTypeIdentifiers

/// Editable source view with line numbers and spell checking
public struct SourceEditorView: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.themeManager) private var themeManager

    @State private var editedContent: String = ""
    @State private var hasLocalChanges: Bool = false
    @State private var currentDocumentID: UUID?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()

            if coordinator.documentState.currentDocument != nil {
                editorArea
            } else {
                emptyState
            }
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(.secondary)
            Text("Source")
                .font(.headline)

            if let line = coordinator.documentState.focusedLine {
                Text("Ln \(line)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.gray.opacity(0.12)))
            }

            Spacer()

            if hasLocalChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text("Modified")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                saveChanges()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(!hasLocalChanges && !coordinator.currentDocumentRequiresSaveAs)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.06))
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        VStack(spacing: 0) {
            if coordinator.sourceFind.isVisible && coordinator.uiState.findBarPosition == .top {
                findBar
                Divider()
            }

            editorTextView

            if coordinator.sourceFind.isVisible && coordinator.uiState.findBarPosition == .bottom {
                Divider()
                findBar
            }
        }
    }

    private var findBar: some View {
        FindBarView(
            state: coordinator.sourceFind,
            placeholder: "Find in source",
            onNext: { coordinator.sourceFind.goToNextMatch() },
            onPrevious: { coordinator.sourceFind.goToPreviousMatch() },
            onClose: { coordinator.sourceFind.close() }
        )
    }

    private var editorTextView: some View {
        LineNumberEditorWrapper(
            text: $editedContent,
            focusedLine: Binding(
                get: { coordinator.documentState.focusedLine },
                set: { coordinator.documentState.focusedLine = $0 }
            ),
            fontSize: 13 * themeManager.fontSizeMultiplier,
            spellCheckingEnabled: coordinator.documentState.currentDocument?.format != .latex,
            showLineNumbers: coordinator.uiState.showLineNumbers,
            lineNumberFontSize: 11 * themeManager.fontSizeMultiplier,
            findActive: coordinator.sourceFind.isVisible,
            findQuery: coordinator.sourceFind.query,
            findOptions: coordinator.sourceFind.options,
            findCurrentIndex: coordinator.sourceFind.currentIndex,
            onFindResult: { count, invalid in
                coordinator.sourceFind.matchCount = count
                coordinator.sourceFind.regexInvalid = invalid
                coordinator.sourceFind.clampCurrentIndex()
            },
            onFocused: { coordinator.lastFocusedPane = .source }
        )
        .onAppear { syncFromCurrentDocument() }
        .onChange(of: coordinator.documentState.currentDocument?.id) { _, _ in
            syncFromCurrentDocument()
        }
        .onChange(of: editedContent) { _, _ in
            let originalContent = coordinator.documentState.currentDocument?.content ?? ""
            hasLocalChanges = (editedContent != originalContent)
            coordinator.uiState.editorContent = editedContent
            coordinator.uiState.hasUnsavedChanges = hasLocalChanges
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No Document Open")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Open a supported text file to edit its source")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func syncFromCurrentDocument() {
        let docID = coordinator.documentState.currentDocument?.id
        // Always sync when document changes (different ID or after save/reload)
        currentDocumentID = docID
        let content = coordinator.documentState.currentDocument?.content ?? ""
        editedContent = content
        coordinator.uiState.editorContent = content
        hasLocalChanges = false
    }

    private func saveChanges() {
        Task { @MainActor in
            if coordinator.currentDocumentRequiresSaveAs {
                guard let url = selectSaveDestination() else { return }
                await coordinator.saveEditedContent(editedContent, to: url)
            } else {
                await coordinator.saveEditedContent(editedContent)
            }

            if coordinator.documentState.parseError == nil {
                hasLocalChanges = false
            }
        }
    }

    @MainActor
    private func selectSaveDestination() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Document"
        panel.nameFieldStringValue = coordinator.documentState.currentDocument?
            .reference.url.lastPathComponent ?? "Untitled.md"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = FileAccessConfiguration.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}

// MARK: - Combined Editor with Line Numbers

/// A single NSViewRepresentable wrapping a `LineNumberTextView`, which draws its own
/// line-number gutter inside the text view. The gutter shares the text view's surface and
/// coordinate space, so text and numbers are always both visible and scroll together.
/// (An `NSRulerView` gutter is not viable here: ruler tiling breaks inside NSHostingView
/// and blanks the document view.)
struct LineNumberEditorWrapper: NSViewRepresentable {
    @Binding var text: String
    @Binding var focusedLine: Int?
    var fontSize: CGFloat
    var spellCheckingEnabled: Bool
    var showLineNumbers: Bool
    var lineNumberFontSize: CGFloat

    // Find bar inputs (source pane). Highlighting is non-destructive (temporary attributes).
    var findActive: Bool = false
    var findQuery: String = ""
    var findOptions: FindOptions = FindOptions()
    var findCurrentIndex: Int = 0
    /// Reports `(matchCount, regexInvalid)` back to the find state after a highlight pass.
    var onFindResult: (Int, Bool) -> Void = { _, _ in }
    /// Called when the editor gains focus, so Cmd-F targets the source pane.
    var onFocused: () -> Void = {}

    func makeNSView(context: Context) -> NSScrollView {
        // Build the TextKit 1 stack explicitly so the layout-manager-based gutter
        // drawing in LineNumberTextView is guaranteed to be available.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = LineNumberTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.isContinuousSpellCheckingEnabled = spellCheckingEnabled
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.lastSetText = text

        // Configure the built-in line-number gutter
        textView.lineNumberFont = NSFont.monospacedSystemFont(ofSize: lineNumberFontSize, weight: .regular)
        textView.lineNumberColor = NSColor.gray.withAlphaComponent(0.4)
        textView.currentLineColor = NSColor.controlAccentColor
        textView.separatorColor = NSColor.separatorColor
        textView.showsLineNumbers = showLineNumbers
        textView.onBecomeFirstResponder = onFocused

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! LineNumberTextView

        // Text sync
        if !context.coordinator.isEditing {
            let currentText = textView.string
            if currentText != text && context.coordinator.lastSetText != text {
                context.coordinator.lastSetText = text
                textView.string = text
            }
        }

        // Font
        let newFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if textView.font?.pointSize != newFont.pointSize {
            textView.font = newFont
        }
        textView.isContinuousSpellCheckingEnabled = spellCheckingEnabled

        // Line-number gutter state
        textView.showsLineNumbers = showLineNumbers
        if textView.lineNumberFont.pointSize != lineNumberFontSize {
            textView.updateLineNumberFontSize(lineNumberFontSize)
        }
        textView.updateCurrentLine(focusedLine)
        textView.onBecomeFirstResponder = onFocused

        // Scroll to focused line if changed externally
        if let line = focusedLine, !context.coordinator.isEditing, context.coordinator.lastSyncedLine != line {
            context.coordinator.lastSyncedLine = line
            scrollToLine(line, in: textView)
        }

        // Find highlighting — only re-apply when a find-relevant input (or the text) changed,
        // so unrelated updates don't re-scroll or thrash the layout manager.
        var findHasher = Hasher()
        findHasher.combine(findActive)
        findHasher.combine(findQuery)
        findHasher.combine(findOptions)
        findHasher.combine(findCurrentIndex)
        findHasher.combine(textView.string)
        let signature = findHasher.finalize()

        if signature != context.coordinator.lastFindSignature {
            context.coordinator.lastFindSignature = signature
            let result = textView.applyFindHighlights(
                query: findQuery,
                options: findOptions,
                currentIndex: findCurrentIndex,
                active: findActive
            )
            let report = onFindResult
            DispatchQueue.main.async {
                report(result.count, result.regexInvalid)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func scrollToLine(_ lineNumber: Int, in textView: NSTextView) {
        let content = textView.string
        let lines = content.components(separatedBy: "\n")
        guard lineNumber > 0 && lineNumber <= lines.count else { return }

        var charIndex = 0
        for i in 0..<(lineNumber - 1) {
            charIndex += lines[i].count + 1
        }

        let range = NSRange(location: min(charIndex, content.count), length: 0)
        textView.scrollRangeToVisible(range)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberEditorWrapper
        var isEditing = false
        var lastSyncedLine: Int? = nil
        var lastSetText: String = ""
        var lastFindSignature: Int = 0

        init(_ parent: LineNumberEditorWrapper) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.text = textView.string
            isEditing = false
            updateFocusedLine(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateFocusedLine(textView)
        }

        private func updateFocusedLine(_ textView: NSTextView) {
            let cursorLocation = textView.selectedRange().location
            let content = textView.string
            let prefix = String(content.prefix(cursorLocation))
            let lineNumber = prefix.components(separatedBy: "\n").count
            if parent.focusedLine != lineNumber {
                lastSyncedLine = lineNumber
                parent.focusedLine = lineNumber
            }
            (textView as? LineNumberTextView)?.updateCurrentLine(lineNumber)
        }
    }
}

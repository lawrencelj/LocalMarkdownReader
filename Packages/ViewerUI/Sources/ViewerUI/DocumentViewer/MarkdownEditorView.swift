/// MarkdownEditorView - Markdown editing interface
///
/// Provides markdown text editing with real-time preview toggle,
/// save functionality, and unsaved changes detection.

import MarkdownCore
import Settings
import SwiftUI

/// Markdown editor with save/discard functionality
public struct MarkdownEditorView: View {
    @Bindable var coordinator: AppStateCoordinator
    @State private var editedContent: String = ""
    @State private var originalContent: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    @State private var showingDiscardConfirmation: Bool = false
    @State private var saveError: Error?
    @State private var lines: [String] = []
    private enum FocusTarget: Hashable {
        case editor
        case line(Int)
    }

    @FocusState private var focusedField: FocusTarget?

    public init(coordinator: AppStateCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Editor Toolbar
            HStack {
                Text("Editing: \(documentName)")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if hasUnsavedChanges {
                    Text("● Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Button("Discard") {
                    if hasUnsavedChanges {
                        showingDiscardConfirmation = true
                    } else {
                        exitEditMode()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    Task {
                        await saveDocument()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasUnsavedChanges)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            Divider()

            // Text Editor
            editorView
                .accessibilityLabel("Markdown Editor")
                .accessibilityHint("Edit markdown content. Press Command+S to save.")
        }
        .onAppear {
            loadContent()
            requestEditorFocus()
        }
        .onChange(of: coordinator.uiState.isEditing) { _, isEditing in
            guard isEditing else { return }
            requestEditorFocus()
        }
        .onChange(of: editedContent) { oldValue, newValue in
            // Sync editedContent to lines array
            lines = newValue.components(separatedBy: .newlines)
            checkForUnsavedChanges()
        }
        .confirmationDialog(
            "Discard Changes",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                exitEditMode()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Save Error", isPresented: .constant(saveError != nil)) {
            Button("OK") {
                saveError = nil
            }
        } message: {
            if let error = saveError {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Helpers

    private var documentName: String {
        coordinator.documentState.currentDocument?.reference.url.lastPathComponent ?? "Untitled"
    }

    private func loadContent() {
        guard let document = coordinator.documentState.currentDocument else { return }

        // Load the raw markdown content
        do {
            let url = document.reference.url

            // Direct file read - NSOpenPanel already granted access
            editedContent = try String(contentsOf: url, encoding: .utf8)

            originalContent = editedContent
            hasUnsavedChanges = false
            coordinator.uiState.hasUnsavedChanges = false
        } catch {
            saveError = error
        }
    }

    private func checkForUnsavedChanges() {
        hasUnsavedChanges = (editedContent != originalContent)
        coordinator.uiState.hasUnsavedChanges = hasUnsavedChanges
    }

    private func saveDocument() async {
        guard let document = coordinator.documentState.currentDocument else { return }

        do {
            let url = document.reference.url

            // Use coordinator's security-scoped save method
            try await coordinator.saveDocument(content: editedContent, to: url)

            // Reload the document to reflect changes
            await coordinator.loadDocument(document.reference)

            originalContent = editedContent
            hasUnsavedChanges = false
            coordinator.uiState.hasUnsavedChanges = false

            // Exit edit mode after successful save
            exitEditMode()

        } catch {
            saveError = error
        }
    }

    private func exitEditMode() {
        coordinator.uiState.isEditing = false
        coordinator.uiState.hasUnsavedChanges = false
    }

    private func requestEditorFocus() {
        Task { @MainActor in
            // Delay ensures view hierarchy has appeared before requesting focus
            try? await Task.sleep(for: .milliseconds(120))
            focusedField = .editor
        }
    }

    @ViewBuilder
    private var editorView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, lineContent in
                    lineEditorPane(lineNumber: lineIndex + 1, lineIndex: lineIndex, isEvenRow: lineIndex % 2 == 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func lineEditorPane(lineNumber: Int, lineIndex: Int, isEvenRow: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Line number pane (left side, 40pt width, non-editable)
            if coordinator.editorSettings.lineNumbers {
                Text("\(lineNumber)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            // Content pane (right side, editable)
            TextField("", text: lineBinding(for: lineIndex), axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .line(lineIndex))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .onSubmit {
                    // Move to next line on Enter
                    if lineIndex < lines.count - 1 {
                        focusedField = .line(lineIndex + 1)
                    }
                }
        }
        .background(
            // Alternating shade with 5-degree difference (0.014 opacity)
            Color.primary.opacity(isEvenRow ? 0.03 : 0.044)
        )
    }

    private func lineBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < lines.count else { return "" }
                return lines[index]
            },
            set: { newValue in
                guard index < lines.count else { return }
                lines[index] = newValue
                // Sync back to editedContent
                editedContent = lines.joined(separator: "\n")
            }
        )
    }
}

#Preview {
    MarkdownEditorView(coordinator: AppStateCoordinator())
}

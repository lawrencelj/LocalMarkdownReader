// macOS Application Entry Point - Markdown Reader
//
// Main entry point for the macOS Markdown Reader application.
// Implements platform-specific initialization, menu bar integration,
// window management, and macOS-specific features.

import AppKit
import FileAccess
import MarkdownCore
import Search
import Settings
import SwiftUI
import UniformTypeIdentifiers
import ViewerUI

/// macOS Application Main Entry Point
@main
struct MarkdownReaderApp: App {
    // MARK: - App State Management

    @State private var coordinator = AppStateCoordinator()
    @State private var themeManager = ThemeManager()
    @State private var fileAccessManager = FileAccessManager()

    // MARK: - Scene Configuration

    var body: some Scene {
        // A single reader window prevents Finder open-file events from
        // creating another scene for the same document.
        Window("Markdown Reader", id: "main") {
            ContentView()
                .environment(coordinator)
                .environment(\.themeManager, themeManager)
                .environment(\.fileAccessManager, fileAccessManager)
                .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 900)
                .onAppear {
                    setupApplication()
                }
                .task {
                    await initializeAppState()
                }
        }
        .defaultSize(width: 1200, height: 900)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            macOSMenuCommands
        }
    }

    // MARK: - Application Setup

    private func setupApplication() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    private func initializeAppState() async {
        await coordinator.initialize()
        await fileAccessManager.requestPermissionsIfNeeded()
        await coordinator.restoreState()
    }

    // MARK: - Menu Commands

    @CommandsBuilder private var macOSMenuCommands: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("New Markdown Document") {
                Task {
                    await coordinator.createNewDocument()
                    NotificationCenter.default.post(name: .showSourceEditor, object: nil)
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Document...") {
                openDocument()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Save") {
                saveCurrentDocument()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)

            Button("Save As...") {
                saveCurrentDocument(forceSaveAs: true)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(coordinator.documentState.currentDocument == nil)

            Divider()

            Button("Close Document") {
                coordinator.closeDocument()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)
        }

        // Edit menu enhancements
        CommandGroup(after: .textEditing) {
            Divider()

            Button("Find in Document...") {
                coordinator.showFindForFocusedPane()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)

            Button("Find Next") {
                coordinator.focusedFind.goToNextMatch()
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(coordinator.focusedFind.matchCount == 0)

            Button("Find Previous") {
                coordinator.focusedFind.goToPreviousMatch()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(coordinator.focusedFind.matchCount == 0)

            Divider()

            Button("Compare with File...") {
                compareDocument()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(coordinator.documentState.currentDocument == nil)

            if coordinator.documentState.isCompareMode {
                Button("Exit Compare Mode") {
                    coordinator.exitCompareMode()
                }
            }
        }

        // View menu commands
        CommandGroup(after: .toolbar) {
            Divider()

            Toggle("Show Line Numbers", isOn: Binding(
                get: { coordinator.uiState.showLineNumbers },
                set: { coordinator.uiState.showLineNumbers = $0 }
            ))
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Divider()

            Button("Zoom In") {
                coordinator.documentState.zoomLevel = min(3.0, coordinator.documentState.zoomLevel + 0.1)
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)

            Button("Zoom Out") {
                coordinator.documentState.zoomLevel = max(0.5, coordinator.documentState.zoomLevel - 0.1)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)

            Button("Actual Size") {
                coordinator.documentState.zoomLevel = 1.0
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)
        }

        // Format menu
        CommandMenu("Format") {
            Button("Increase Font Size") {
                themeManager.increaseFontSize()
            }
            .keyboardShortcut("=", modifiers: [.command, .shift])

            Button("Decrease Font Size") {
                themeManager.decreaseFontSize()
            }
            .keyboardShortcut("-", modifiers: [.command, .shift])

            Button("Reset Font Size") {
                themeManager.resetFontSize()
            }

            Divider()

            Menu("Theme") {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button(theme.displayName) {
                        themeManager.setTheme(theme)
                    }
                }
            }
        }

        // Help menu
        CommandGroup(replacing: .help) {
            Button("About Markdown Reader") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }
        }
    }

    // MARK: - Actions

    private func openDocument() {
        Task { @MainActor in
            await Task.yield()
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.treatsFilePackagesAsDirectories = false
            panel.allowedContentTypes = supportedDocumentTypes
            panel.title = "Open"
            let response = panel.runModal()
            if response == .OK {
                for url in panel.urls {
                    let reference = DocumentReference(url: url)
                    await coordinator.loadDocument(reference)
                }
            }
        }
    }

    private func compareDocument() {
        Task { @MainActor in
            await Task.yield()
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.treatsFilePackagesAsDirectories = false
            panel.allowedContentTypes = supportedDocumentTypes
            panel.title = "Compare With"
            let response = panel.runModal()
            if response == .OK, let url = panel.url {
                let reference = DocumentReference(url: url)
                await coordinator.openForCompare(reference)
            }
        }
    }

    private func saveCurrentDocument(forceSaveAs: Bool = false) {
        Task { @MainActor in
            guard let document = coordinator.documentState.currentDocument else { return }
            let content = coordinator.uiState.editorContent

            if forceSaveAs || coordinator.currentDocumentRequiresSaveAs {
                guard let url = DocumentSavePanel.selectDestination(
                    suggestedName: document.reference.url.lastPathComponent
                ) else { return }
                await coordinator.saveEditedContent(content, to: url)
            } else {
                await coordinator.saveEditedContent(content)
            }
        }
    }

    private var supportedDocumentTypes: [UTType] {
        FileAccessConfiguration.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let findNext = Notification.Name("findNext")
    static let findPrevious = Notification.Name("findPrevious")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleOutline = Notification.Name("toggleOutline")
    static let showSourceEditor = Notification.Name("showSourceEditor")
}

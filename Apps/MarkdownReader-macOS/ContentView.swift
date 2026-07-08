// ContentView - macOS main application interface

import AppKit
import FileAccess
import MarkdownCore
import SwiftUI
import UniformTypeIdentifiers
import ViewerUI

/// Main macOS application interface with three-column layout
struct ContentView: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    @State private var sidebarSelection: SidebarItem? = .outline
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var splitRatio: CGFloat = 0.5

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            ResizableSplitView(ratio: $splitRatio) {
                contentView
            } right: {
                detailView
            }
        }
        .toolbar { mainToolbar }
        .onOpenURL { url in
            loadSelectedURLs([url])
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSourceEditor)) { _ in
            sidebarSelection = .source
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $sidebarSelection) {
            Section("Navigation") {
                Label("Outline", systemImage: "list.bullet").tag(SidebarItem.outline)
                Label("Source", systemImage: "chevron.left.forwardslash.chevron.right").tag(SidebarItem.source)
            }

            Section("Files") {
                Label("Open Documents", systemImage: "doc.on.doc").tag(SidebarItem.openDocs)
                Label("Recent Files", systemImage: "clock").tag(SidebarItem.recent)
            }

            Section("Tools") {
                Label("Themes", systemImage: "paintbrush").tag(SidebarItem.themes)
                Label("Settings", systemImage: "gear").tag(SidebarItem.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Markdown Reader")
        .frame(minWidth: 180, idealWidth: 220)
    }

    // MARK: - Content Column

    @ViewBuilder private var contentView: some View {
        switch sidebarSelection {
        case .outline:
            NavigationSidebar()
        case .source:
            SourceEditorView()
        case .openDocs:
            openDocumentsView
        case .recent:
            recentFilesView
        case .themes:
            ThemeSelectionView()
        case .settings:
            MacOSSettingsView()
        case .none:
            Text("Select an item")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Detail (Document) View

    private var detailView: some View {
        VStack(spacing: 0) {
            // Document tabs
            if !coordinator.documentState.openDocuments.isEmpty {
                documentTabBar
            }

            // Compare mode banner
            if coordinator.documentState.isCompareMode {
                compareBanner
            }

            if coordinator.documentState.currentDocument == nil {
                welcomeView
            } else {
                DocumentViewer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDocumentDrop(providers)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Markdown Reader")
                    .font(.largeTitle.weight(.semibold))
                Text("Open Markdown, LaTeX, text, JSON, XML, or HTML to read, search, edit, or compare.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("New Document") {
                    createNewDocument()
                }
                .buttonStyle(.bordered)

                Button("Open Document...") {
                    openDocumentPanel()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            Text("You can also drag a file into this window.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    // MARK: - Document Tab Bar

    private var documentTabBar: some View {
        HStack(spacing: 0) {
            // Left scroll button
            Button {
                scrollTabsLeft()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(coordinator.documentState.activeDocumentIndex == 0)

            // Scrollable tabs
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(
                            Array(coordinator.documentState.openDocuments.enumerated()),
                            id: \.element.id
                        ) { index, doc in
                            documentTab(doc, index: index)
                                .id("tab-\(index)")
                        }
                    }
                }
                .onChange(of: coordinator.documentState.activeDocumentIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("tab-\(newIndex)", anchor: .center)
                    }
                }
            }

            // Right scroll button
            Button {
                scrollTabsRight()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(
                coordinator.documentState.activeDocumentIndex >=
                    coordinator.documentState.openDocuments.count - 1
            )

            Divider().frame(height: 16).padding(.horizontal, 4)

            // Tab count indicator
            Text(
                "\(coordinator.documentState.activeDocumentIndex + 1)/\(coordinator.documentState.openDocuments.count)"
            )
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.trailing, 8)
        }
        .frame(height: 32)
        .background(Color.gray.opacity(0.08))
    }

    private func scrollTabsLeft() {
        let newIndex = max(0, coordinator.documentState.activeDocumentIndex - 1)
        Task { await coordinator.switchToDocument(at: newIndex) }
    }

    private func scrollTabsRight() {
        let maxIndex = coordinator.documentState.openDocuments.count - 1
        let newIndex = min(maxIndex, coordinator.documentState.activeDocumentIndex + 1)
        Task { await coordinator.switchToDocument(at: newIndex) }
    }

    private func documentTab(_ doc: DocumentModel, index: Int) -> some View {
        let isActive = index == coordinator.documentState.activeDocumentIndex
        return HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(doc.title ?? doc.reference.url.lastPathComponent)
                .font(.caption)
                .lineLimit(1)

            Button {
                coordinator.closeDocument(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close \(doc.reference.url.lastPathComponent)")
            .accessibilityLabel("Close document \(doc.reference.url.lastPathComponent)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle().fill(Color.accentColor).frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await coordinator.switchToDocument(at: index) }
        }
    }

    // MARK: - Compare Banner

    private var compareBanner: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(.orange)
            Text("Compare Mode")
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
            Button("Exit Compare") {
                coordinator.exitCompareMode()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
    }

    // MARK: - Open Documents View

    private var openDocumentsView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open Documents")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.documentState.openDocuments.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.gray.opacity(0.2)))
            }
            .padding(12)

            Divider()

            if coordinator.documentState.openDocuments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No open documents")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(
                        Array(coordinator.documentState.openDocuments.enumerated()),
                        id: \.element.id
                    ) { index, doc in
                        openDocRow(doc, index: index)
                    }
                }
            }
        }
    }

    private func openDocRow(_ doc: DocumentModel, index: Int) -> some View {
        let isActive = index == coordinator.documentState.activeDocumentIndex
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title ?? "Untitled")
                    .font(.body)
                    .fontWeight(isActive ? .semibold : .regular)
                Text(doc.reference.url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(doc.metadata.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await coordinator.switchToDocument(at: index) }
        }
        .contextMenu {
            Button("Compare with another file...") {
                Task { await coordinator.switchToDocument(at: index) }
                openComparePanel()
            }
            Divider()
            Button("Close") {
                coordinator.closeDocument(at: index)
            }
        }
    }

    // MARK: - Recent Files View

    private var recentFilesView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Files")
                    .font(.headline)
                Spacer()
            }
            .padding(12)
            Divider()

            if coordinator.userPreferences.recentFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No recent files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(coordinator.userPreferences.recentFiles, id: \.url) { ref in
                        Button {
                            Task { await coordinator.loadDocument(ref) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ref.url.lastPathComponent)
                                    .font(.body)
                                Text(ref.url.deletingLastPathComponent().path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                withAnimation {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                createNewDocument()
            } label: {
                Label("New", systemImage: "doc.badge.plus")
            }
            .help("New Markdown Document (⌘N)")

            Button {
                openDocumentPanel()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open Document (⌘O)")

            if coordinator.documentState.currentDocument != nil {
                Button {
                    saveCurrentDocument()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help(coordinator.currentDocumentRequiresSaveAs ? "Save Document As..." : "Save Document (⌘S)")

                Button {
                    openComparePanel()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .help("Compare with another file")
            }
        }
    }

    // MARK: - Actions

    private func createNewDocument() {
        Task {
            await coordinator.createNewDocument()
            sidebarSelection = .source
        }
    }

    private func saveCurrentDocument() {
        Task { @MainActor in
            guard let document = coordinator.documentState.currentDocument else { return }
            let content = coordinator.uiState.editorContent

            if coordinator.currentDocumentRequiresSaveAs {
                guard let url = DocumentSavePanel.selectDestination(
                    suggestedName: document.reference.url.lastPathComponent
                ) else { return }
                await coordinator.saveEditedContent(content, to: url)
            } else {
                await coordinator.saveEditedContent(content)
            }
        }
    }

    private func openDocumentPanel() {
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
                loadSelectedURLs(panel.urls)
            }
        }
    }

    private func openComparePanel() {
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

    private func loadSelectedURLs(_ urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                let reference = DocumentReference(url: url)
                await coordinator.loadDocument(reference)
            }
        }
    }

    private func handleDocumentDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url else { return }
            DispatchQueue.main.async {
                Task {
                    let reference = DocumentReference(url: url)
                    await coordinator.loadDocument(reference)
                }
            }
        }
        return true
    }

    private var supportedDocumentTypes: [UTType] {
        FileAccessConfiguration.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
    }
}

// MARK: - Sidebar Items

enum SidebarItem: String, CaseIterable {
    case outline, source, openDocs, recent, themes, settings
}

// MARK: - Settings View

private struct MacOSSettingsView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(AppStateCoordinator.self) private var coordinator
    @State private var selectedTheme: Theme = .system
    @State private var fontSizeValue = 1.0
    @State private var highContrast = false
    @State private var reduceMotion = false
    @State private var showLineNumbers = false
    @State private var findBarPosition: FindBarPosition = .top

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .onChange(of: selectedTheme) { _, newValue in
                    themeManager.applyTheme(newValue)
                }

                HStack {
                    Text("Font Size: \(Int(fontSizeValue * 100))%")
                    Spacer()
                    Slider(value: $fontSizeValue, in: 0.5 ... 3.0, step: 0.1)
                        .frame(width: 200)
                        .onChange(of: fontSizeValue) { _, newValue in
                            themeManager.adjustFontSize(multiplier: newValue)
                        }
                }
            }

            Section("Editor") {
                Toggle("Show line numbers", isOn: $showLineNumbers)
                    .onChange(of: showLineNumbers) { _, newValue in
                        coordinator.uiState.showLineNumbers = newValue
                    }
            }

            Section("Find") {
                Picker("Find bar position", selection: $findBarPosition) {
                    ForEach(FindBarPosition.allCases, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .onChange(of: findBarPosition) { _, newValue in
                    coordinator.uiState.findBarPosition = newValue
                }
            }

            Section("Accessibility") {
                Toggle("High contrast", isOn: $highContrast)
                    .onChange(of: highContrast) { _, newValue in
                        themeManager.enableHighContrast(newValue)
                    }
                Toggle("Reduce motion", isOn: $reduceMotion)
                    .onChange(of: reduceMotion) { _, newValue in
                        themeManager.isReduceMotionEnabled = newValue
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedTheme = themeManager.currentTheme
            fontSizeValue = Double(themeManager.fontSizeMultiplier)
            highContrast = themeManager.isHighContrastEnabled
            reduceMotion = themeManager.isReduceMotionEnabled
            showLineNumbers = coordinator.uiState.showLineNumbers
            findBarPosition = coordinator.uiState.findBarPosition
        }
    }
}

// MARK: - Resizable Split View

/// A custom horizontal split view with a draggable divider that shows a resize cursor.
private struct ResizableSplitView<Left: View, Right: View>: View {
    @Binding var ratio: CGFloat
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    @State private var isDragging = false

    private let dividerWidth: CGFloat = 8
    private let minRatio: CGFloat = 0.15
    private let maxRatio: CGFloat = 0.85

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let leftWidth = max(totalWidth * ratio - dividerWidth / 2, 0)
            let rightWidth = max(totalWidth * (1 - ratio) - dividerWidth / 2, 0)

            HStack(spacing: 0) {
                left()
                    .frame(width: leftWidth)
                    .clipped()

                // Draggable divider
                dividerView(totalWidth: totalWidth)

                right()
                    .frame(width: rightWidth)
                    .clipped()
            }
        }
    }

    private func dividerView(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15))
            .frame(width: dividerWidth)
            .overlay(
                // Grip indicator (two vertical stripes)
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(isDragging ? 0.8 : 0.4))
                        .frame(width: 2, height: 24)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(isDragging ? 0.8 : 0.4))
                        .frame(width: 2, height: 24)
                }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        let newRatio = value.location.x / totalWidth + ratio - 0.5 * dividerWidth / totalWidth
                        ratio = min(max(newRatio, minRatio), maxRatio)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .contentShape(Rectangle())
    }
}

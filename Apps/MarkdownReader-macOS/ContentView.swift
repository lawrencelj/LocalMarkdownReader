/// ContentView - macOS main application interface
///
/// Implements the primary macOS user interface with three-column layout,
/// menu bar integration, keyboard shortcuts, and platform-specific features.
/// Follows macOS Human Interface Guidelines and ADR-002 specifications.

import FileAccess
import MarkdownCore
import Settings
import SwiftUI
import UniformTypeIdentifiers
import ViewerUI

/// Main macOS application interface with three-column layout
struct ContentView: View {
    // MARK: - State Management

    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    // MARK: - Navigation State

    @State private var sidebarSelection: SidebarItem? = .outline
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingDocumentPicker = false
    @State private var showingSettings = false

    // MARK: - Drag and Drop

    @State private var draggedDocument: DocumentReference?

    // MARK: - View Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } content: {
            contentView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            mainToolbar
        }
        .onAppear {
            setupInitialState()
        }
        .task {
            await coordinator.restoreState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            Task {
                await coordinator.saveState()
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsWindow()
        }
    }

    // MARK: - Sidebar View

    private var sidebarView: some View {
        List(selection: $sidebarSelection) {
            Section("Navigation") {
                SidebarRow(
                    item: .outline,
                    title: "Outline",
                    systemImage: "list.bullet",
                    isSelected: sidebarSelection == .outline
                )

                SidebarRow(
                    item: .search,
                    title: "Search",
                    systemImage: "magnifyingglass",
                    isSelected: sidebarSelection == .search
                )
            }

            Section("Files") {
                SidebarRow(
                    item: .recent,
                    title: "Recent Files",
                    systemImage: "clock",
                    isSelected: sidebarSelection == .recent
                )

                if coordinator.documentState.currentDocument != nil {
                    SidebarRow(
                        item: .bookmarks,
                        title: "Bookmarks",
                        systemImage: "bookmark",
                        isSelected: sidebarSelection == .bookmarks
                    )
                }
            }

            Section("Tools") {
                SidebarRow(
                    item: .themes,
                    title: "Themes",
                    systemImage: "paintbrush",
                    isSelected: sidebarSelection == .themes
                )

                SidebarRow(
                    item: .settings,
                    title: "Settings",
                    systemImage: "gear",
                    isSelected: sidebarSelection == .settings
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Markdown Reader")
        .frame(minWidth: 200, idealWidth: 250)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar Navigation")
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch sidebarSelection {
        case .outline:
            NavigationSidebar()
                .navigationTitle("Outline")
                .frame(minWidth: 250, idealWidth: 300)

        case .search:
            SearchInterface(coordinator: coordinator)
                .navigationTitle("Search")
                .frame(minWidth: 300, idealWidth: 350)

        case .recent:
            RecentFilesView()
                .navigationTitle("Recent Files")
                .frame(minWidth: 300, idealWidth: 400)

        case .bookmarks:
            BookmarksView()
                .navigationTitle("Bookmarks")
                .frame(minWidth: 300, idealWidth: 350)

        case .themes:
            ThemeSelectionView()
                .navigationTitle("Themes")
                .frame(minWidth: 350, idealWidth: 400)

        case .settings:
            MacOSSettingsView()
                .navigationTitle("Settings")
                .frame(minWidth: 400, idealWidth: 500)

        case .none:
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Detail View

    private var detailView: some View {
        VStack(spacing: 0) {
            // Tab bar (only show if there are open tabs)
            if !coordinator.tabState.tabs.isEmpty {
                TabBarView(
                    tabState: coordinator.tabState,
                    onNewTab: {
                        showingDocumentPicker = true
                    }
                )
                .onChange(of: coordinator.tabState.activeTabId) { _, newActiveId in
                    if let newActiveId = newActiveId {
                        coordinator.switchToTab(newActiveId)
                    }
                }
            }

            // Document viewer or empty state
            Group {
                if coordinator.documentState.currentDocument != nil {
                    DocumentViewer()
                        .navigationTitle(documentTitle)
                        .navigationSubtitle(documentSubtitle)
                        .toolbar {
                            documentToolbar
                        }
                } else {
                    EmptyStateView.noDocument(
                        onOpenDocument: {
                            showingDocumentPicker = true
                        },
                        onBrowseRecent: {
                            sidebarSelection = .recent
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 800)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDocumentDrop(providers)
        }
    }

    // MARK: - Main Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                withAnimation {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar")
            .keyboardShortcut("s", modifiers: [.command, .control])
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button("New") {
                Task {
                    await createNewDocument()
                }
            }
            .help("Create New Document")
            .keyboardShortcut("n", modifiers: .command)

            Button("Open") {
                showingDocumentPicker = true
            }
            .help("Open Document")
            .keyboardShortcut("o", modifiers: .command)

            if coordinator.documentState.currentDocument != nil {
                Divider()

                Button {
                    coordinator.uiState.isEditing.toggle()
                } label: {
                    Image(systemName: coordinator.uiState.isEditing ? "doc.text.fill" : "pencil")
                }
                .help(coordinator.uiState.isEditing ? "View Mode" : "Edit Mode")
                .keyboardShortcut("e", modifiers: .command)

                Button {
                    coordinator.uiState.searchVisible.toggle()
                } label: {
                    Image(systemName: coordinator.uiState.searchVisible ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .help("Toggle Search")
                .keyboardShortcut("f", modifiers: .command)

                Button {
                    shareDocument()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share Document")
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Document Toolbar

    @ToolbarContentBuilder
    private var documentToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if coordinator.documentState.currentDocument != nil {
                Menu {
                    Button("Zoom In") {
                        coordinator.documentState.zoomLevel = min(3.0, coordinator.documentState.zoomLevel + 0.1)
                    }
                    .keyboardShortcut("+", modifiers: .command)

                    Button("Zoom Out") {
                        coordinator.documentState.zoomLevel = max(0.5, coordinator.documentState.zoomLevel - 0.1)
                    }
                    .keyboardShortcut("-", modifiers: .command)

                    Button("Actual Size") {
                        coordinator.documentState.zoomLevel = 1.0
                    }
                    .keyboardShortcut("0", modifiers: .command)

                    Divider()

                    Button("Print") {
                        printDocument()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Document Options")
            }
        }
    }

    // MARK: - Computed Properties

    private var documentTitle: String {
        coordinator.documentState.currentDocument?.reference.url.lastPathComponent ?? "Untitled"
    }

    private var documentSubtitle: String {
        guard let document = coordinator.documentState.currentDocument else {
            return ""
        }

        let wordCount = document.metadata.wordCount
        let readingTime = document.metadata.estimatedReadingTime

        return "\(wordCount) words • \(readingTime) min read"
    }

    // MARK: - Actions

    private func setupInitialState() {
        // Set initial sidebar selection
        if sidebarSelection == nil {
            sidebarSelection = .outline
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                // Load all selected documents
                for url in urls {
                    await loadDocument(from: url)
                }
            }
        case .failure(let error):
            // Handle error
            print("File import failed: \(error)")
        }
    }

    private func handleDocumentDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        // Load all dropped files
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }

                DispatchQueue.main.async {
                    Task {
                        await self.loadDocument(from: url)
                    }
                }
            }
        }

        return true
    }

    private func loadDocument(from url: URL) async {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // Get file metadata
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fileSize = Int64(resourceValues?.fileSize ?? 0)
        let lastModified = resourceValues?.contentModificationDate ?? Date()

        // Create security-scoped bookmark
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let reference = DocumentReference(
            url: url,
            bookmark: bookmark,
            lastModified: lastModified,
            fileSize: fileSize
        )

        await coordinator.loadDocument(reference)
    }

    private func shareDocument() {
        guard let document = coordinator.documentState.currentDocument else { return }

        let sharingPicker = NSSharingServicePicker(items: [document.reference.url])

        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            sharingPicker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    private func printDocument() {
        guard coordinator.documentState.currentDocument != nil else { return }

        let printInfo = NSPrintInfo()
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72

        let printOperation = NSPrintOperation(view: NSView(), printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true

        printOperation.runModal(for: NSApplication.shared.keyWindow ?? NSWindow(),
                               delegate: nil,
                               didRun: nil,
                               contextInfo: nil)
    }

    private func createNewDocument() async {
        do {
            // Access FileService through coordinator
            let fileService = FileService()
            let url = try await fileService.createNewDocument()
            
            // Load the newly created document
            await loadDocument(from: url)
        } catch {
            // Handle error appropriately
            print("Failed to create new document: \(error)")
        }
    }
}

// MARK: - Sidebar Item

enum SidebarItem: String, CaseIterable {
    case outline = "outline"
    case search = "search"
    case recent = "recent"
    case bookmarks = "bookmarks"
    case themes = "themes"
    case settings = "settings"

    var title: String {
        switch self {
        case .outline: return "Outline"
        case .search: return "Search"
        case .recent: return "Recent Files"
        case .bookmarks: return "Bookmarks"
        case .themes: return "Themes"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .outline: return "list.bullet"
        case .search: return "magnifyingglass"
        case .recent: return "clock"
        case .bookmarks: return "bookmark"
        case .themes: return "paintbrush"
        case .settings: return "gear"
        }
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let item: SidebarItem
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .tag(item)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Recent Files View

private struct RecentFilesView: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    var body: some View {
        List {
            ForEach(coordinator.userPreferences.recentFiles, id: \.url) { reference in
                RecentFileRow(reference: reference) {
                    Task {
                        let docRef = DocumentReference(
                            url: reference.url,
                            lastModified: reference.lastModified
                        )
                        await coordinator.loadDocument(docRef)
                    }
                }
            }
            .onDelete { indexSet in
                var recentFiles = coordinator.userPreferences.recentFiles
                recentFiles.remove(atOffsets: indexSet)
                Task {
                    await coordinator.userPreferences.updateRecentFiles(recentFiles)
                }
            }
        }
        .contextMenu {
            Button("Clear All") {
                Task {
                    await coordinator.userPreferences.clearRecentFiles()
                }
            }
        }
    }
}

private struct RecentFileRow: View {
    let reference: FileReference
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reference.url.lastPathComponent)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(reference.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("Modified \(reference.lastModified, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(reference.url.lastPathComponent)")
    }
}

// MARK: - Bookmarks View

private struct BookmarksView: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    var body: some View {
        List {
            // Placeholder for bookmarks functionality
            Text("Bookmarks feature coming soon")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - macOS Settings View

private struct MacOSSettingsView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: .constant(themeManager.currentTheme)) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(
                        value: .constant(Double(themeManager.fontSizeMultiplier)),
                        in: 0.5...3.0,
                        step: 0.1
                    ) {
                        Text("Font Size")
                    } minimumValueLabel: {
                        Text("A").font(.caption2)
                    } maximumValueLabel: {
                        Text("A").font(.title2)
                    }
                    .frame(width: 200)
                }
            }

            Section("Editor") {
                Toggle("Show line numbers", isOn: .constant(false))
                Toggle("Word wrap", isOn: .constant(true))
                Toggle("Syntax highlighting", isOn: .constant(true))
            }

            Section("Performance") {
                Toggle("Enable viewport optimization", isOn: .constant(true))
                Toggle("Lazy loading for large documents", isOn: .constant(true))

                HStack {
                    Text("Memory usage limit")
                    Spacer()
                    Text("150 MB")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Accessibility") {
                Toggle("High contrast", isOn: .constant(themeManager.isHighContrastEnabled))
                Toggle("Reduce motion", isOn: .constant(themeManager.isReduceMotionEnabled))
                Toggle("VoiceOver optimizations", isOn: .constant(themeManager.voiceOverEnabled))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Settings Window

private struct SettingsWindow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            AccessibilitySettingsView()
                .tabItem {
                    Label("Accessibility", systemImage: "accessibility")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 600, height: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct GeneralSettingsView: View {
    @State private var restoreLastSession = UserDefaults.standard.bool(forKey: "restoreLastSession")
    @State private var openRecentOnLaunch = UserDefaults.standard.bool(forKey: "openRecentOnLaunch")
    @State private var autoSaveScrollPosition = UserDefaults.standard.bool(forKey: "autoSaveScrollPosition")
    @State private var rememberWindowSize = UserDefaults.standard.bool(forKey: "rememberWindowSize")
    @State private var recentFilesLimit = UserDefaults.standard.integer(forKey: "recentFilesLimit") == 0 ? 10 : UserDefaults.standard.integer(forKey: "recentFilesLimit")

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Restore last session", isOn: $restoreLastSession)
                    .onChange(of: restoreLastSession) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "restoreLastSession")
                    }
                Toggle("Open recent file on launch", isOn: $openRecentOnLaunch)
                    .onChange(of: openRecentOnLaunch) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "openRecentOnLaunch")
                    }
            }

            Section("Files") {
                Toggle("Auto-save scroll position", isOn: $autoSaveScrollPosition)
                    .onChange(of: autoSaveScrollPosition) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoSaveScrollPosition")
                    }
                Toggle("Remember window size", isOn: $rememberWindowSize)
                    .onChange(of: rememberWindowSize) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "rememberWindowSize")
                    }

                HStack {
                    Text("Recent files limit")
                    Spacer()
                    Stepper("\(recentFilesLimit)", value: $recentFilesLimit, in: 5...50)
                        .onChange(of: recentFilesLimit) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "recentFilesLimit")
                        }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

private struct AppearanceSettingsView: View {
    var body: some View {
        ThemeSelectionView()
    }
}

private struct AccessibilitySettingsView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var highContrast = UserDefaults.standard.bool(forKey: "highContrast")
    @State private var reduceTransparency = UserDefaults.standard.bool(forKey: "reduceTransparency")
    @State private var increaseContrast = UserDefaults.standard.bool(forKey: "increaseContrast")
    @State private var reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")
    @State private var autoPlayAnimations = UserDefaults.standard.bool(forKey: "autoPlayAnimations")
    @State private var fullKeyboardAccess = UserDefaults.standard.bool(forKey: "fullKeyboardAccess")
    @State private var stickyKeys = UserDefaults.standard.bool(forKey: "stickyKeys")

    var body: some View {
        Form {
            Section("Visual") {
                Toggle("High contrast", isOn: $highContrast)
                    .onChange(of: highContrast) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "highContrast")
                        themeManager.isHighContrastEnabled = newValue
                    }
                Toggle("Reduce transparency", isOn: $reduceTransparency)
                    .onChange(of: reduceTransparency) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "reduceTransparency")
                    }
                Toggle("Increase contrast", isOn: $increaseContrast)
                    .onChange(of: increaseContrast) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "increaseContrast")
                    }
            }

            Section("Motion") {
                Toggle("Reduce motion", isOn: $reduceMotion)
                    .onChange(of: reduceMotion) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "reduceMotion")
                        themeManager.isReduceMotionEnabled = newValue
                    }
                Toggle("Auto-play animations", isOn: $autoPlayAnimations)
                    .onChange(of: autoPlayAnimations) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoPlayAnimations")
                    }
            }

            Section("Navigation") {
                Toggle("Full keyboard access", isOn: $fullKeyboardAccess)
                    .onChange(of: fullKeyboardAccess) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "fullKeyboardAccess")
                    }
                Toggle("Sticky keys", isOn: $stickyKeys)
                    .onChange(of: stickyKeys) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "stickyKeys")
                    }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Accessibility")
    }
}

private struct AdvancedSettingsView: View {
    @State private var enablePerformanceMonitoring = UserDefaults.standard.bool(forKey: "enablePerformanceMonitoring")
    @State private var viewportOptimization = UserDefaults.standard.bool(forKey: "viewportOptimization")
    @State private var memoryOptimization = UserDefaults.standard.bool(forKey: "memoryOptimization")
    @State private var cacheSize = UserDefaults.standard.integer(forKey: "cacheSize") == 0 ? 100 : UserDefaults.standard.integer(forKey: "cacheSize")
    @State private var enableDebugMode = UserDefaults.standard.bool(forKey: "enableDebugMode")
    @State private var showPerformanceMetrics = UserDefaults.standard.bool(forKey: "showPerformanceMetrics")
    @State private var logToConsole = UserDefaults.standard.bool(forKey: "logToConsole")

    var body: some View {
        Form {
            Section("Performance") {
                Toggle("Enable performance monitoring", isOn: $enablePerformanceMonitoring)
                    .onChange(of: enablePerformanceMonitoring) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "enablePerformanceMonitoring")
                    }
                Toggle("Viewport optimization", isOn: $viewportOptimization)
                    .onChange(of: viewportOptimization) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "viewportOptimization")
                    }
                Toggle("Memory optimization", isOn: $memoryOptimization)
                    .onChange(of: memoryOptimization) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "memoryOptimization")
                    }

                HStack {
                    Text("Cache size limit")
                    Spacer()
                    Stepper("\(cacheSize) MB", value: $cacheSize, in: 50...500, step: 50)
                        .onChange(of: cacheSize) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "cacheSize")
                        }
                }
            }

            Section("Developer") {
                Toggle("Enable debug mode", isOn: $enableDebugMode)
                    .onChange(of: enableDebugMode) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "enableDebugMode")
                    }
                Toggle("Show performance metrics", isOn: $showPerformanceMetrics)
                    .onChange(of: showPerformanceMetrics) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showPerformanceMetrics")
                    }
                Toggle("Log to console", isOn: $logToConsole)
                    .onChange(of: logToConsole) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "logToConsole")
                    }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }
}

// MARK: - Preview

#Preview("macOS Main Window") {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
        .frame(width: 1200, height: 800)
}

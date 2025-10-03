/// ContentView - iOS main application interface
///
/// Implements the primary iOS user interface with adaptive navigation,
/// platform-specific interactions, and full ViewerUI integration.
/// Follows iOS Human Interface Guidelines and ADR-002 specifications.

import FileAccess
import MarkdownCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
import ViewerUI

/// Main iOS application interface with adaptive layout
struct ContentView: View {
    // MARK: - State Management

    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Navigation State

    @State private var navigationPath = NavigationPath()
    @State private var selectedNavigation: NavigationDestination? = .document
    @State private var showingDocumentPicker = false
    @State private var showingSettings = false

    // MARK: - Adaptive Layout

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var useTabNavigation: Bool {
        isCompactLayout && verticalSizeClass == .regular
    }

    // MARK: - View Body

    var body: some View {
        Group {
            if useTabNavigation {
                tabNavigationView
            } else {
                splitNavigationView
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .task {
            await coordinator.restoreState()
        }
        .sheet(isPresented: $showingDocumentPicker) {
            #if canImport(UIKit)
            DocumentPickerView { urls in
                Task {
                    // Load all selected documents
                    for url in urls {
                        await loadDocument(from: url)
                    }
                }
            }
            #else
            Text("Document picker not available on this platform")
            #endif
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Tab Navigation (iPhone Portrait)

    private var tabNavigationView: some View {
        TabView(selection: $selectedNavigation) {
            NavigationStack(path: $navigationPath) {
                documentContentView
                    .navigationTitle("Document")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        documentToolbar
                    }
            }
            .tabItem {
                Label("Document", systemImage: "doc.text")
            }
            .tag(NavigationDestination.document)

            NavigationStack {
                NavigationSidebar()
                    .navigationTitle("Outline")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .tabItem {
                Label("Outline", systemImage: "list.bullet")
            }
            .tag(NavigationDestination.outline)

            NavigationStack {
                SearchInterface(coordinator: coordinator)
                    .navigationTitle("Search")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(NavigationDestination.search)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main Navigation")
    }

    // MARK: - Split Navigation (iPad, iPhone Landscape)

    private var splitNavigationView: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            if horizontalSizeClass == .regular {
                contentColumnView
            } else {
                EmptyView()
            }
        } detail: {
            documentContentView
        }
        .navigationSplitViewStyle(.balanced)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Split View Navigation")
    }

    // MARK: - Sidebar View

    private var sidebarView: some View {
        List(selection: $selectedNavigation) {
            Section {
                NavigationLink(value: NavigationDestination.document) {
                    Label("Document", systemImage: "doc.text")
                }

                NavigationLink(value: NavigationDestination.outline) {
                    Label("Outline", systemImage: "list.bullet")
                }

                NavigationLink(value: NavigationDestination.search) {
                    Label("Search", systemImage: "magnifyingglass")
                }
            } header: {
                Text("Navigation")
            }

            Section {
                Button("New Document") {
                    Task {
                        await createNewDocument()
                    }
                }
                .accessibilityLabel("Create a new markdown document")

                Button("Open Document") {
                    showingDocumentPicker = true
                }
                .accessibilityLabel("Open an existing markdown document")

                if !coordinator.userPreferences.recentFiles.isEmpty {
                    NavigationLink("Recent Files", value: NavigationDestination.recent)
                }
            } header: {
                Text("Files")
            }

            Section {
                NavigationLink("Settings", value: NavigationDestination.settings)
            }
        }
        .navigationTitle("Markdown Reader")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Settings") {
                    showingSettings = true
                }
                .accessibilityLabel("Open settings")
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    showingSettings = true
                }
                .accessibilityLabel("Open settings")
            }
            #endif
        }
    }

    // MARK: - Content Column (iPad Three-Column)

    @ViewBuilder
    private var contentColumnView: some View {
        switch selectedNavigation {
        case .outline:
            NavigationSidebar()
                .navigationTitle("Outline")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif

        case .search:
            SearchInterface(coordinator: coordinator)
                .navigationTitle("Search")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif

        case .recent:
            RecentFilesView()
                .navigationTitle("Recent Files")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif

        case .settings:
            SettingsView()
                .navigationTitle("Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif

        default:
            Text("Select a section from the sidebar")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Document Content

    private var documentContentView: some View {
        Group {
            if coordinator.documentState.currentDocument != nil {
                DocumentViewer()
                    .navigationTitle(documentTitle)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        if !useTabNavigation {
                            documentToolbar
                        }
                    }
            } else {
                EmptyStateView.noDocument(
                    onOpenDocument: {
                        showingDocumentPicker = true
                    },
                    onBrowseRecent: {
                        selectedNavigation = .recent
                    }
                )
                .navigationTitle("Markdown Reader")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
            }
        }
    }

    // MARK: - Document Toolbar

    @ToolbarContentBuilder
    private var documentToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarPlacement) {
            if coordinator.documentState.currentDocument != nil {
                Button {
                    // Toggle search
                    coordinator.uiState.searchVisible.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Toggle search")

                Menu {
                    Button("New Document") {
                        Task {
                            await createNewDocument()
                        }
                    }

                    Button("Open Document") {
                        showingDocumentPicker = true
                    }

                    Button("Share") {
                        shareDocument()
                    }

                    Divider()

                    Button("Settings") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Document options")
            } else {
                Button("Open") {
                    showingDocumentPicker = true
                }
                .accessibilityLabel("Open document")
            }
        }
    }

    // MARK: - Computed Properties

    private var documentTitle: String {
        coordinator.documentState.currentDocument?.reference.url.lastPathComponent ?? "Document"
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    // MARK: - Actions

    private func loadDocument(from url: URL) async {
        let reference = DocumentReference(url: url)
        await coordinator.loadDocument(reference)
    }

    private func shareDocument() {
        guard let document = coordinator.documentState.currentDocument else { return }

        #if canImport(UIKit) && os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: [document.reference.url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #elseif canImport(AppKit) && os(macOS)
        let sharingPicker = NSSharingServicePicker(items: [document.reference.url])
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            sharingPicker.show(relativeTo: NSRect.zero, of: contentView, preferredEdge: NSRectEdge.minY)
        }
        #else
        // Fallback for other platforms - just print for now
        print("Share not implemented for this platform")
        #endif
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

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            Task {
                await coordinator.saveState()
            }
        case .inactive:
            // Prepare for background
            break
        case .active:
            // App became active
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Navigation Destinations

enum NavigationDestination: String, CaseIterable {
    case document = "document"
    case outline = "outline"
    case search = "search"
    case recent = "recent"
    case settings = "settings"

    var title: String {
        switch self {
        case .document: return "Document"
        case .outline: return "Outline"
        case .search: return "Search"
        case .recent: return "Recent"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .document: return "doc.text"
        case .outline: return "list.bullet"
        case .search: return "magnifyingglass"
        case .recent: return "clock"
        case .settings: return "gear"
        }
    }
}

// MARK: - Document Picker

#if canImport(UIKit)
private struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentsSelected: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsSelected: onDocumentsSelected)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentsSelected: ([URL]) -> Void

        init(onDocumentsSelected: @escaping ([URL]) -> Void) {
            self.onDocumentsSelected = onDocumentsSelected
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !urls.isEmpty else { return }
            onDocumentsSelected(urls)
        }
    }
}
#endif

// MARK: - Recent Files View

private struct RecentFilesView: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    var body: some View {
        List {
            ForEach(coordinator.userPreferences.recentFiles, id: \.url) { reference in
                Button {
                    Task {
                        let docRef = DocumentReference(
                            url: reference.url,
                            lastModified: reference.lastModified
                        )
                        await coordinator.loadDocument(docRef)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
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
                }
                .accessibilityLabel("Open \(reference.url.lastPathComponent)")
            }
            .onDelete { indexSet in
                // Remove from recent files
                var recentFiles = coordinator.userPreferences.recentFiles
                recentFiles.remove(atOffsets: indexSet)
                Task {
                    await coordinator.userPreferences.updateRecentFiles(recentFiles)
                }
            }
        }
        .refreshable {
            // Refresh recent files
            await coordinator.userPreferences.loadSettings()
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Picker("Theme", selection: .constant(themeManager.currentTheme)) {
                            ForEach(Theme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    NavigationLink("Advanced Appearance") {
                        ThemeSelectionView()
                    }
                }

                Section("Accessibility") {
                    Toggle("High Contrast", isOn: .constant(themeManager.isHighContrastEnabled))
                    Toggle("Reduce Motion", isOn: .constant(themeManager.isReduceMotionEnabled))
                }

                Section("About") {
                    NavigationLink("About Markdown Reader") {
                        AboutView()
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - About View

private struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    VStack(spacing: 8) {
                        Text("Markdown Reader")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("Features") {
                Label("Fast Markdown Rendering", systemImage: "bolt")
                Label("Cross-Platform Support", systemImage: "laptopcomputer.and.iphone")
                Label("Full Accessibility", systemImage: "accessibility")
                Label("Advanced Search", systemImage: "magnifyingglass")
                Label("Beautiful Themes", systemImage: "paintbrush")
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Preview

#Preview("iPhone - Portrait") {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
}

#Preview("iPhone - Landscape", traits: .landscapeLeft) {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
}

#Preview("iPad") {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
}

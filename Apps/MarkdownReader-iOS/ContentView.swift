/// ContentView - iOS main application interface
///
/// Implements the primary iOS user interface with adaptive navigation,
/// platform-specific interactions, and full ViewerUI integration.
/// Follows iOS Human Interface Guidelines and ADR-002 specifications.

import SwiftUI
import ViewerUI
import MarkdownCore
import FileAccess

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
            DocumentPickerView { url in
                Task {
                    await loadDocument(from: url)
                }
            }
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
                    .navigationBarTitleDisplayMode(.inline)
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
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Outline", systemImage: "list.bullet")
            }
            .tag(NavigationDestination.outline)

            NavigationStack {
                SearchInterface()
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.inline)
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
                Button("Open Document") {
                    showingDocumentPicker = true
                }
                .accessibilityLabel("Open a new markdown document")

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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Settings") {
                    showingSettings = true
                }
                .accessibilityLabel("Open settings")
            }
        }
    }

    // MARK: - Content Column (iPad Three-Column)

    @ViewBuilder
    private var contentColumnView: some View {
        switch selectedNavigation {
        case .outline:
            NavigationSidebar()
                .navigationTitle("Outline")
                .navigationBarTitleDisplayMode(.inline)

        case .search:
            SearchInterface()
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)

        case .recent:
            RecentFilesView()
                .navigationTitle("Recent Files")
                .navigationBarTitleDisplayMode(.inline)

        case .settings:
            SettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)

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
                    .navigationBarTitleDisplayMode(.inline)
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
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    // MARK: - Document Toolbar

    @ToolbarContentBuilder
    private var documentToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if coordinator.documentState.currentDocument != nil {
                Button {
                    // Toggle search
                    coordinator.uiState.searchVisible.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Toggle search")

                Menu {
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
        coordinator.documentState.currentDocument?.title ?? "Document"
    }

    // MARK: - Actions

    private func loadDocument(from url: URL) async {
        let reference = DocumentReference(url: url)
        await coordinator.loadDocument(reference)
    }

    private func shareDocument() {
        guard let document = coordinator.documentState.currentDocument else { return }

        let activityVC = UIActivityViewController(
            activityItems: [document.reference.url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
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

private struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentSelected: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentSelected: onDocumentSelected)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentSelected: (URL) -> Void

        init(onDocumentSelected: @escaping (URL) -> Void) {
            self.onDocumentSelected = onDocumentSelected
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentSelected(url)
        }
    }
}

// MARK: - Recent Files View

private struct RecentFilesView: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    var body: some View {
        List {
            ForEach(coordinator.userPreferences.recentFiles, id: \.url) { reference in
                Button {
                    Task {
                        await coordinator.loadDocument(reference)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("iPhone - Portrait") {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 15"))
        .previewDisplayName("iPhone Portrait")
}

#Preview("iPhone - Landscape") {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 15"))
        .previewInterfaceOrientation(.landscapeLeft)
        .previewDisplayName("iPhone Landscape")
}

#Preview("iPad") {
    ContentView()
        .environment(AppStateCoordinator.preview)
        .environment(\.themeManager, ThemeManager())
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
        .previewDisplayName("iPad")
}
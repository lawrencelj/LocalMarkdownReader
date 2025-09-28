/// macOS Application Entry Point - Markdown Reader
///
/// Main entry point for the macOS Markdown Reader application.
/// Implements platform-specific initialization, menu bar integration,
/// window management, and macOS-specific features following ADR-002.

import SwiftUI
import ViewerUI
import MarkdownCore
import FileAccess
import Settings
import AppKit
import UniformTypeIdentifiers

/// macOS Application Main Entry Point
@main
struct MarkdownReaderApp: App {
    // MARK: - App State Management

    @StateObject private var coordinator = AppStateCoordinator()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var fileAccessManager = FileAccessManager()

    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Scene Configuration

    var body: some Scene {
        // Main window group
        WindowGroup(id: "main") {
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
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            macOSMenuCommands
        }

        // Settings window
        WindowGroup(id: "settings") {
            SettingsWindow()
                .environment(coordinator)
                .environment(\.themeManager, themeManager)
                .frame(width: 600, height: 500)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)

        // About window
        WindowGroup(id: "about") {
            AboutWindow()
                .environment(coordinator)
                .frame(width: 400, height: 300)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }

    // MARK: - Application Setup

    private func setupApplication() {
        // Configure macOS-specific settings
        configureAppearance()
        configureWindowBehavior()
        configurePerformanceOptimizations()
        configureAccessibility()
        setupDragAndDropSupport()
    }

    private func initializeAppState() async {
        // Initialize core app state
        await coordinator.initialize()
        await themeManager.loadUserPreferences()
        await fileAccessManager.requestPermissionsIfNeeded()

        // Load user settings and restore session
        await coordinator.restoreState()

        // Initialize search indexing in background
        Task.detached(priority: .background) {
            await coordinator.searchManager.initializeIndex()
        }
    }

    private func configureAppearance() {
        // Set up macOS-specific UI appearance
        NSWindow.allowsAutomaticWindowTabbing = true

        // Configure app icon and dock behavior
        if let appIconImage = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = appIconImage
        }
    }

    private func configureWindowBehavior() {
        // Configure default window behavior
        NSWindow.allowsAutomaticWindowTabbing = true

        // Set up window restoration
        NSApplication.shared.registerForRemoteNotifications()
    }

    private func configurePerformanceOptimizations() {
        // macOS-specific performance optimizations

        // Enable Core Animation layer backing for better performance
        NSApplication.shared.windows.forEach { window in
            window.contentView?.wantsLayer = true
        }

        // Configure memory pressure handling
        NotificationCenter.default.addObserver(
            forName: NSApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await coordinator.handleMemoryPressure()
            }
        }
    }

    private func configureAccessibility() {
        // Configure accessibility features
        NSApplication.shared.accessibilitySetOverrideValue(true, forAttribute: .accessibilityEnabled)

        // Monitor accessibility status changes
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await coordinator.updateAccessibilitySettings()
            }
        }
    }

    private func setupDragAndDropSupport() {
        // Configure system-wide drag and drop
        NSApplication.shared.delegate = appDelegate
    }

    // MARK: - Menu Commands

    @CommandsBuilder
    private var macOSMenuCommands: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("Open Document...") {
                NSApplication.shared.sendAction(#selector(AppDelegate.openDocument(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Open Recent") {
                // This will show the recent files submenu
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Close Document") {
                coordinator.closeCurrentDocument()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)
        }

        // Edit menu enhancements
        CommandGroup(after: .textEditing) {
            Divider()

            Button("Find in Document...") {
                coordinator.uiState.searchVisible = true
                NSApplication.shared.sendAction(#selector(AppDelegate.showSearch(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil)

            Button("Find Next") {
                NSApplication.shared.sendAction(#selector(AppDelegate.findNext(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(coordinator.documentState.currentDocument == nil || !coordinator.uiState.searchVisible)

            Button("Find Previous") {
                NSApplication.shared.sendAction(#selector(AppDelegate.findPrevious(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(coordinator.documentState.currentDocument == nil || !coordinator.uiState.searchVisible)
        }

        // View menu commands
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Toggle Sidebar") {
                NSApplication.shared.sendAction(#selector(AppDelegate.toggleSidebar(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button("Toggle Outline") {
                NSApplication.shared.sendAction(#selector(AppDelegate.toggleOutline(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("1", modifiers: [.command, .control])

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
                    .keyboardShortcut(theme.keyboardShortcut ?? .init(.space), modifiers: [])
                }
            }
        }

        // Window menu enhancements
        CommandGroup(after: .windowArrangement) {
            Divider()

            Button("Bring All to Front") {
                NSApplication.shared.arrangeInFront(nil)
            }
        }

        // Help menu replacement
        CommandGroup(replacing: .help) {
            Button("Markdown Reader Help") {
                if let helpURL = Bundle.main.url(forResource: "Help", withExtension: "md") {
                    Task {
                        let reference = DocumentReference(url: helpURL)
                        await coordinator.loadDocument(reference)
                    }
                }
            }

            Button("Keyboard Shortcuts") {
                NSApplication.shared.sendAction(#selector(AppDelegate.showKeyboardShortcuts(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("?", modifiers: .command)

            Divider()

            Button("About Markdown Reader") {
                NSApplication.shared.sendAction(#selector(AppDelegate.showAbout(_:)), to: nil, from: nil)
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure dock behavior
        NSApplication.shared.setActivationPolicy(.regular)

        // Set up file associations
        setupFileAssociations()

        // Configure services
        setupServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Perform cleanup
        Task {
            if let coordinator = getAppStateCoordinator() {
                await coordinator.saveState()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)

        Task { @MainActor in
            if let coordinator = getAppStateCoordinator() {
                let reference = DocumentReference(url: url)
                await coordinator.loadDocument(reference)
            }
        }

        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else { return }
        _ = application(sender, openFile: filename)
    }

    // MARK: - Menu Actions

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            guard let url = panel.url else { return }

            Task { @MainActor in
                if let coordinator = getAppStateCoordinator() {
                    let reference = DocumentReference(url: url)
                    await coordinator.loadDocument(reference)
                }
            }
        }
    }

    @objc func showSearch(_ sender: Any?) {
        if let coordinator = getAppStateCoordinator() {
            coordinator.uiState.searchVisible = true
        }
    }

    @objc func findNext(_ sender: Any?) {
        // Implement find next functionality
        NotificationCenter.default.post(name: .findNext, object: nil)
    }

    @objc func findPrevious(_ sender: Any?) {
        // Implement find previous functionality
        NotificationCenter.default.post(name: .findPrevious, object: nil)
    }

    @objc func toggleSidebar(_ sender: Any?) {
        NotificationCenter.default.post(name: .toggleSidebar, object: nil)
    }

    @objc func toggleOutline(_ sender: Any?) {
        NotificationCenter.default.post(name: .toggleOutline, object: nil)
    }

    @objc func showKeyboardShortcuts(_ sender: Any?) {
        // Show keyboard shortcuts help
        if let shortcutsURL = Bundle.main.url(forResource: "KeyboardShortcuts", withExtension: "md") {
            Task { @MainActor in
                if let coordinator = getAppStateCoordinator() {
                    let reference = DocumentReference(url: shortcutsURL)
                    await coordinator.loadDocument(reference)
                }
            }
        }
    }

    @objc func showAbout(_ sender: Any?) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(sender)
    }

    // MARK: - Private Methods

    private func setupFileAssociations() {
        // Register file type associations
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: "/dev/null"))
    }

    private func setupServices() {
        // Register text services
        NSApplication.shared.servicesProvider = self
    }

    private func getAppStateCoordinator() -> AppStateCoordinator? {
        // Get the coordinator from the current scene
        guard let window = NSApplication.shared.keyWindow,
              let hostingController = window.contentViewController as? NSHostingController<ContentView> else {
            return nil
        }

        // This is a simplified approach - in a real implementation,
        // you might need a more robust way to access the coordinator
        return nil // TODO: Implement proper coordinator access
    }
}

// MARK: - Services Provider

extension AppDelegate: NSServicesMenuRequestor {
    func readSelectionFromPasteboard(_ pboard: NSPasteboard) -> Bool {
        // Handle reading text from pasteboard
        return false
    }

    func writeSelectionToPasteboard(_ pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        // Handle writing text to pasteboard
        return false
    }
}

// MARK: - Environment Extensions

extension EnvironmentValues {
    @Entry var themeManager: ThemeManager = ThemeManager()
    @Entry var fileAccessManager: FileAccessManager = FileAccessManager()
}

// MARK: - Notification Names

extension Notification.Name {
    static let findNext = Notification.Name("findNext")
    static let findPrevious = Notification.Name("findPrevious")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleOutline = Notification.Name("toggleOutline")
}

// MARK: - macOS-Specific Extensions

@MainActor
extension AppStateCoordinator {
    /// Handle macOS-specific memory pressure
    func handleMemoryPressure() async {
        // Clear caches and reduce memory footprint
        await documentCache.clearCache()
        await renderingEngine.reduceCacheSize()
        searchManager.clearInMemoryIndex()

        // Force garbage collection
        await Task.yield()
    }

    /// Update accessibility settings for macOS
    func updateAccessibilitySettings() async {
        let workspace = NSWorkspace.shared

        // Update settings based on system accessibility preferences
        let highContrastEnabled = workspace.accessibilityDisplayShouldIncreaseContrast
        let reduceMotionEnabled = workspace.accessibilityDisplayShouldReduceMotion

        await themeManager.updateAccessibilitySettings(
            highContrast: highContrastEnabled,
            reduceMotion: reduceMotionEnabled
        )
    }

    /// Close the current document with macOS-specific behavior
    func closeCurrentDocument() {
        guard let document = documentState.currentDocument else { return }

        // Perform any macOS-specific cleanup
        Task {
            await saveState()
            documentState.currentDocument = nil
        }
    }
}

// MARK: - Theme Keyboard Shortcuts

extension Theme {
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .system: return KeyEquivalent("1")
        case .light: return KeyEquivalent("2")
        case .dark: return KeyEquivalent("3")
        default: return nil
        }
    }
}

// MARK: - About Window

struct AboutWindow: View {
    @Environment(AppStateCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Markdown Reader")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("© 2024 Markdown Reader Team")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Built with:")
                    .font(.headline)

                Text("• SwiftUI and Swift Markdown")
                Text("• Optimized for macOS 14+")
                Text("• Accessibility-first design")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(30)
        .frame(width: 400, height: 300)
        .background(.regularMaterial)
    }
}

// MARK: - Performance Monitoring

#if DEBUG
struct PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private init() {}

    func startMonitoring() {
        // Add performance monitoring for development builds
        Task.detached(priority: .background) {
            await monitorRenderingPerformance()
        }
    }

    private func monitorRenderingPerformance() async {
        // Monitor for 60fps target compliance
        // This is a placeholder for actual performance monitoring
        print("📊 Performance monitoring active - targeting 60fps")
    }
}
#endif
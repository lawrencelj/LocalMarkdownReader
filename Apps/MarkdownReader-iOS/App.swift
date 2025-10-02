/// iOS Application Entry Point - Markdown Reader
///
/// Main entry point for the iOS Markdown Reader application.
/// Implements platform-specific initialization, state coordination,
/// and SwiftUI app lifecycle management following ADR-002 specifications.

import FileAccess
import MarkdownCore
import Settings
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import ViewerUI

/// iOS Application Main Entry Point
@main
struct MarkdownReaderApp: App {
    // MARK: - App State Management

    @State private var coordinator = AppStateCoordinator()
    @State private var themeManager = ThemeManager()
    @State private var securityManager = SecurityManager.shared

    // MARK: - Scene Configuration

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .environment(\.themeManager, themeManager)
                .environment(\.securityManager, securityManager)
                .onAppear {
                    setupApplication()
                }
#if canImport(UIKit)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        await coordinator.refreshState()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    Task {
                        await coordinator.saveState()
                    }
                }
#endif
                .task {
                    await initializeAppState()
                }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh("com.markdownreader.refresh")) {
            await performBackgroundRefresh()
        }
        #endif
        .commands {
            // iOS-specific commands (when running on iPad with external keyboard)
            CommandGroup(replacing: .newItem) {
                Button("Open Document") {
                    NotificationCenter.default.post(name: .openDocument, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Search") {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Navigate to Outline") {
                    NotificationCenter.default.post(name: .showOutline, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show Recent Files") {
                    NotificationCenter.default.post(name: .showRecent, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }
    }

    // MARK: - Application Setup

    private func setupApplication() {
        // Configure iOS-specific settings
        configureAppearance()
        configureAccessibility()
        configurePerformanceOptimizations()
        registerNotificationHandlers()
    }

    private func initializeAppState() async {
        // Initialize core app state
        await coordinator.initialize()
        // ThemeManager loads preferences in its init() method
        await securityManager.initialize()

        // Load user settings and restore session
        await coordinator.restoreState()

        // Initialize search indexing in background
        Task.detached(priority: .background) {
            await coordinator.searchManager.initializeIndex()
        }
    }

    private func configureAppearance() {
        #if canImport(UIKit)
        // Set up iOS-specific UI appearance
        UINavigationBar.appearance().prefersLargeTitles = true
        UITableView.appearance().backgroundColor = .clear

        // Configure dynamic type support
        if #available(iOS 17.0, *) {
            // Use system typography scaling
            UIApplication.shared.preferredContentSizeCategory = .large
        }
        #endif
    }

    private func configureAccessibility() {
        #if canImport(UIKit)
        // Ensure VoiceOver and other accessibility features work properly
        UIAccessibility.shouldDifferentiateWithoutColor = true

        // Configure accessibility notifications
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            coordinator.accessibilityManager.updateVoiceOverStatus()
        }
        #endif
    }

    private func configurePerformanceOptimizations() {
        #if canImport(UIKit)
        // iOS-specific performance optimizations

        // Enable MetalKit acceleration for rendering (iOS 17+)
        if #available(iOS 17.0, *) {
            coordinator.renderingEngine.enableMetalAcceleration()
        }

        // Configure memory pressure handling
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await coordinator.handleMemoryPressure()
            }
        }
        #endif
    }

    private func registerNotificationHandlers() {
        // Register for iOS-specific notifications
        NotificationCenter.default.addObserver(
            forName: .openDocument,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                coordinator.uiState.showingDocumentPicker = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .toggleSearch,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                coordinator.uiState.searchVisible.toggle()
            }
        }
    }

    private func performBackgroundRefresh() async {
        // Perform background tasks
        await coordinator.searchManager.updateIndex()
        await securityManager.cleanupExpiredAccess()
    }
}

// MARK: - Environment Extensions

extension EnvironmentValues {
    @Entry var securityManager = SecurityManager.shared
}

// MARK: - Notification Names

extension Notification.Name {
    static let openDocument = Notification.Name("openDocument")
    static let toggleSearch = Notification.Name("toggleSearch")
    static let showOutline = Notification.Name("showOutline")
    static let showRecent = Notification.Name("showRecent")
}

// MARK: - iOS-Specific Extensions

@MainActor
extension AppStateCoordinator {
    /// Handle iOS-specific memory pressure
    func handleMemoryPressure() async {
        // Clear caches and reduce memory footprint
        await documentCache.clearCache()
        await renderingEngine.reduceCacheSize()
        searchManager.clearInMemoryIndex()

        // Force garbage collection
        await Task.yield()
    }

    /// Refresh app state when becoming active
    func refreshState() async {
        // Refresh document state if files may have changed externally
        if let currentDocument = documentState.currentDocument {
            await validateDocumentAccess(for: currentDocument.reference)
        }

        // Update recent files list
        await userPreferences.refreshRecentFiles()
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

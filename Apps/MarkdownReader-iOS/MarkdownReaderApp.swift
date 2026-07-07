/// iOS Application Entry Point - Markdown Reader
///
/// Main entry point for the iOS Markdown Reader application.
/// Implements platform-specific initialization, state coordination,
/// and SwiftUI app lifecycle management.

import SwiftUI
import ViewerUI
import MarkdownCore
import FileAccess
import Search
import Settings

/// iOS Application Main Entry Point
@main
struct MarkdownReaderApp: App {
    // MARK: - App State Management

    @State private var coordinator = AppStateCoordinator()
    @State private var themeManager = ThemeManager()
    @State private var fileAccessManager = FileAccessManager()

    // MARK: - Scene Configuration

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .environment(\.themeManager, themeManager)
                .environment(\.fileAccessManager, fileAccessManager)
                .onAppear {
                    setupApplication()
                }
                .task {
                    await initializeAppState()
                }
        }
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
            }
        }
    }

    // MARK: - Application Setup

    private func setupApplication() {
        configureAccessibility()
        registerNotificationHandlers()
    }

    private func initializeAppState() async {
        await coordinator.initialize()
        await fileAccessManager.requestPermissionsIfNeeded()
        await coordinator.restoreState()
    }

    private func configureAccessibility() {
        UIAccessibility.shouldDifferentiateWithoutColor = true
    }

    private func registerNotificationHandlers() {
        NotificationCenter.default.addObserver(
            forName: .openDocument,
            object: nil,
            queue: .main
        ) { _ in
            coordinator.uiState.showingDocumentPicker = true
        }

        NotificationCenter.default.addObserver(
            forName: .toggleSearch,
            object: nil,
            queue: .main
        ) { _ in
            coordinator.contentFind.isVisible.toggle()
        }

        // Handle memory pressure
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await coordinator.documentCache.clearCache()
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openDocument = Notification.Name("openDocument")
    static let toggleSearch = Notification.Name("toggleSearch")
    static let showOutline = Notification.Name("showOutline")
    static let showRecent = Notification.Name("showRecent")
}

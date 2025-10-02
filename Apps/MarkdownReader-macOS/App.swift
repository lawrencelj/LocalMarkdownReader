import AppKit
import FileAccess
import MarkdownCore
import Settings
import SwiftUI
import UniformTypeIdentifiers
import ViewerUI

@main
struct MarkdownReaderApp: App {
    @State private var coordinator = AppStateCoordinator()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(coordinator)
                .environment(\.themeManager, themeManager)
                .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 900)
                .task {
                    await initializeAppState()
                }
        }
        .commands {
            AppCommands()
        }

        Settings {
            Text("Settings placeholder")
                .frame(width: 600, height: 500)
        }
    }

    private func initializeAppState() async {
        // Initialize basic app state
        await SecurityManager.shared.initialize()
    }
}

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Document") {
                // Handle open document
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}


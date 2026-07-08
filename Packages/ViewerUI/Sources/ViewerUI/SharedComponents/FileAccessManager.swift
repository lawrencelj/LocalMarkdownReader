// FileAccessManager - Cross-platform file access coordination

import FileAccess
import SwiftUI

/// Cross-platform file access manager for the application layer
@MainActor
@Observable
public class FileAccessManager: ObservableObject {
    public var hasFileAccess = false

    private let fileService: FileService

    public init() {
        fileService = FileService()
    }

    public func requestPermissionsIfNeeded() async {
        await SecurityManager.shared.initialize()
        hasFileAccess = true
    }

    public func refreshSecurityScopedResources() async {
        await SecurityManager.shared.cleanupExpiredAccess()
    }

    public func openDocument() async throws -> URL {
        try await fileService.openDocument()
    }

    public func loadContent(from url: URL) async throws -> String {
        try await fileService.loadDocument(from: url)
    }

    public func isAccessible(_ url: URL) async -> Bool {
        await fileService.isDocumentAccessible(url)
    }
}

// MARK: - Environment Key

private struct FileAccessManagerKey: EnvironmentKey {
    @MainActor static let defaultValue = FileAccessManager()
}

public extension EnvironmentValues {
    var fileAccessManager: FileAccessManager {
        get { self[FileAccessManagerKey.self] }
        set { self[FileAccessManagerKey.self] = newValue }
    }
}

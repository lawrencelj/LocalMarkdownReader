/// FileAccessManager - Cross-platform file access coordination

import SwiftUI
import FileAccess

/// Cross-platform file access manager for the application layer
@MainActor
@Observable
public class FileAccessManager: ObservableObject {
    public var hasFileAccess: Bool = false

    private let fileService: FileService

    public init() {
        self.fileService = FileService()
    }

    public func requestPermissionsIfNeeded() async {
        await SecurityManager.shared.initialize()
        hasFileAccess = true
    }

    public func refreshSecurityScopedResources() async {
        await SecurityManager.shared.cleanupExpiredAccess()
    }

    public func openDocument() async throws -> URL {
        return try await fileService.openDocument()
    }

    public func loadContent(from url: URL) async throws -> String {
        return try await fileService.loadDocument(from: url)
    }

    public func isAccessible(_ url: URL) async -> Bool {
        return await fileService.isDocumentAccessible(url)
    }
}

// MARK: - Environment Key

private struct FileAccessManagerKey: EnvironmentKey {
    @MainActor static let defaultValue = FileAccessManager()
}

extension EnvironmentValues {
    public var fileAccessManager: FileAccessManager {
        get { self[FileAccessManagerKey.self] }
        set { self[FileAccessManagerKey.self] = newValue }
    }
}

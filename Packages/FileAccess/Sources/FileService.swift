// FileService - Main file access service interface
//
// Provides the primary interface for file operations expected by the
// frontend AppStateCoordinator, with security-scoped access and
// cross-platform compatibility.

import Foundation
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Main file service interface expected by frontend
@MainActor
public class FileService: ObservableObject {
    private let documentPicker: DocumentPicker
    private let recentDocuments: RecentDocuments
    private let securityManager: SecurityManager

    public init() {
        documentPicker = DocumentPicker()
        recentDocuments = RecentDocuments()
        securityManager = SecurityManager.shared
    }

    // MARK: - Frontend Interface Methods

    /// Present document picker and return selected document URL
    public func openDocument() async throws -> URL {
        try await documentPicker.selectDocument()
    }

    /// Load document content from URL
    public func loadDocument(from url: URL) async throws -> String {
        try await loadDocumentContent(from: url)
    }

    /// Get list of recent documents
    public func getRecentDocuments() -> [URL] {
        recentDocuments.getRecentDocuments()
    }

    /// Save document to recent documents list
    public func saveRecentDocument(_ url: URL) {
        recentDocuments.addRecentDocument(url)
    }

    // MARK: - Additional Service Methods

    /// Check if file is accessible
    public func isDocumentAccessible(_ url: URL) async -> Bool {
        await securityManager.canAccessFile(url)
    }

    /// Get file metadata
    public func getFileMetadata(_ url: URL) async throws -> FileMetadata {
        try await FileMetadata.from(url: url)
    }

    /// Remove from recent documents
    public func removeRecentDocument(_ url: URL) {
        recentDocuments.removeRecentDocument(url)
    }

    /// Clear all recent documents
    public func clearRecentDocuments() {
        recentDocuments.clearRecentDocuments()
    }

    /// Create security-scoped bookmark for file
    public func createBookmark(for url: URL) async throws -> Data {
        try await securityManager.createBookmark(for: url)
    }

    /// Resolve security-scoped bookmark
    public func resolveBookmark(_ bookmark: Data) async throws -> URL {
        try await securityManager.resolveBookmark(bookmark)
    }

    // MARK: - Private Implementation

    private func loadDocumentContent(from url: URL) async throws -> String {
        // Validate file access
        guard await securityManager.canAccessFile(url) else {
            throw FileAccessError.accessDenied
        }

        // Start security-scoped access if needed
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileAccessError.fileNotFound
        }

        // Check file size
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize,
           fileSize > FileAccessConfiguration.maxFileSize {
            throw FileAccessError.fileTooLarge(maxSize: FileAccessConfiguration.maxFileSize)
        }

        // Read file content
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch let error as NSError {
            throw FileAccessError.readFailed(underlying: error)
        }
    }
}

// MARK: - Supporting Types

/// File metadata information
public struct FileMetadata: Sendable {
    public let url: URL
    public let name: String
    public let size: Int64
    public let lastModified: Date
    public let isDirectory: Bool
    public let isReadable: Bool
    public let isWritable: Bool

    public init(
        url: URL,
        name: String,
        size: Int64,
        lastModified: Date,
        isDirectory: Bool,
        isReadable: Bool,
        isWritable: Bool
    ) {
        self.url = url
        self.name = name
        self.size = size
        self.lastModified = lastModified
        self.isDirectory = isDirectory
        self.isReadable = isReadable
        self.isWritable = isWritable
    }

    /// Create metadata from URL
    public static func from(url: URL) async throws -> FileMetadata {
        let resourceValues = try url.resourceValues(forKeys: [
            .nameKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isDirectoryKey,
            .isReadableKey,
            .isWritableKey
        ])

        return FileMetadata(
            url: url,
            name: resourceValues.name ?? url.lastPathComponent,
            size: Int64(resourceValues.fileSize ?? 0),
            lastModified: resourceValues.contentModificationDate ?? Date(),
            isDirectory: resourceValues.isDirectory ?? false,
            isReadable: resourceValues.isReadable ?? false,
            isWritable: resourceValues.isWritable ?? false
        )
    }
}

/// File access configuration
public enum FileAccessConfiguration {
    /// Maximum file size in bytes (2MB)
    public static let maxFileSize: Int64 = 2 * 1024 * 1024

    /// Supported file extensions
    public static let supportedExtensions = [
        "md", "markdown", "txt", "text",
        "json", "xml", "html", "htm", "tex", "latex"
    ]

    /// Maximum number of recent documents
    public static let maxRecentDocuments = 20
}

/// File access errors
public enum FileAccessError: Error, LocalizedError, Sendable {
    case fileNotFound
    case accessDenied
    case fileTooLarge(maxSize: Int64)
    case unsupportedFileType
    case readFailed(underlying: Error)
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case securityScopeFailure

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The requested file could not be found"
        case .accessDenied:
            return "Access to the file was denied"
        case let .fileTooLarge(maxSize):
            return "File is too large (maximum size: \(ByteCountFormatter().string(fromByteCount: maxSize)))"
        case .unsupportedFileType:
            return "The file type is not supported"
        case let .readFailed(underlying):
            return "Failed to read file: \(underlying.localizedDescription)"
        case .bookmarkCreationFailed:
            return "Failed to create security-scoped bookmark"
        case .bookmarkResolutionFailed:
            return "Failed to resolve security-scoped bookmark"
        case .securityScopeFailure:
            return "Security-scoped resource access failed"
        }
    }
}

// MARK: - Preview Support

public extension FileService {
    /// Create a preview service for development
    static var preview: FileService {
        FileService()
    }
}

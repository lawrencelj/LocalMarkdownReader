/// FileService - Main file access service interface
///
/// Provides the primary interface for file operations expected by the
/// frontend AppStateCoordinator, with security-scoped access and
/// cross-platform compatibility.

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
        self.documentPicker = DocumentPicker(configuration: .multipleSelection)
        self.recentDocuments = RecentDocuments()
        self.securityManager = SecurityManager.shared
    }

    // MARK: - Frontend Interface Methods

    /// Present document picker and return selected document URL
    public func openDocument() async throws -> URL {
        try await documentPicker.selectDocument()
    }

    /// Present document picker and return multiple selected document URLs
    public func openDocuments() async throws -> [URL] {
        try await documentPicker.selectDocuments()
    }

    /// Create a new document with save dialog
    public func createNewDocument(fileName: String = "Untitled.md", initialContent: String = "# New Document\n\n") async throws -> URL {
        let url = try await documentPicker.saveDocument(fileName: fileName, initialContent: initialContent)
        
        // Validate the created file
        guard await isDocumentAccessible(url) else {
            throw FileAccessError.accessDenied
        }
        
        // Add to recent documents
        saveRecentDocument(url)
        
        return url
    }

    /// Load document content from URL
    public func loadDocument(from url: URL) async throws -> String {
        try await loadDocumentContent(from: url)
    }

    /// Save document content to URL with security-scoped access
    public func saveDocument(content: String, to url: URL) async throws {
        try await saveDocumentContent(content, to: url)
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

    /// Check if file is accessible with comprehensive validation
    public func isDocumentAccessible(_ url: URL) async -> Bool {
        // Input validation
        guard url.isFileURL,
              !url.path.isEmpty,
              !url.path.contains("../"), // Path traversal protection
              !url.path.hasPrefix("/System/"), // System protection
              !url.path.hasPrefix("/private/") else { // Private area protection
            return false
        }

        return await securityManager.canAccessFile(url)
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

    /// Create security-scoped bookmark for file with validation
    public func createBookmark(for url: URL) async throws -> Data {
        // Validate input
        guard url.isFileURL,
              await isDocumentAccessible(url) else {
            throw FileAccessError.accessDenied
        }

        return try await securityManager.createBookmark(for: url)
    }

    /// Resolve security-scoped bookmark with validation
    public func resolveBookmark(_ bookmark: Data) async throws -> URL {
        // Validate bookmark data
        guard !bookmark.isEmpty,
              bookmark.count < 10_000 else { // Reasonable size limit for bookmarks
            throw FileAccessError.bookmarkResolutionFailed
        }

        let url = try await securityManager.resolveBookmark(bookmark)

        // Validate resolved URL
        guard await isDocumentAccessible(url) else {
            throw FileAccessError.accessDenied
        }

        return url
    }

    // MARK: - Private Implementation

    private func loadDocumentContent(from url: URL) async throws -> String {
        // Use SecurityManager's safe scoped access method to prevent resource leaks
        try await securityManager.withSecurityScopedAccess(to: url) {
            // Validate file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw FileAccessError.fileNotFound
            }

            // Enhanced input validation
            guard url.isFileURL,
                  !url.path.contains("../"), // Prevent path traversal
                  !url.path.hasPrefix("/System/"), // Prevent system file access
                  !url.path.hasPrefix("/private/") else { // Prevent private file access
                throw FileAccessError.accessDenied
            }

            // Validate file type
            let fileExtension = url.pathExtension.lowercased()
            guard fileExtension.isEmpty || FileAccessConfiguration.supportedExtensions.contains(fileExtension) else {
                throw FileAccessError.unsupportedFileType
            }

            // Check file size with enhanced validation
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isReadableKey,
                .contentModificationDateKey
            ])

            // Ensure it's a regular file and readable
            guard resourceValues.isRegularFile == true,
                  resourceValues.isReadable == true else {
                throw FileAccessError.accessDenied
            }

            // Check file size
            if let fileSize = resourceValues.fileSize {
                guard fileSize > 0 else {
                    throw FileAccessError.readFailed(underlying: NSError(domain: "FileAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is empty"]))
                }
                guard fileSize <= FileAccessConfiguration.maxFileSize else {
                    throw FileAccessError.fileTooLarge(maxSize: FileAccessConfiguration.maxFileSize)
                }
            }

            // Read file content with encoding detection
            do {
                let content = try String(contentsOf: url, encoding: .utf8)

                // Basic content validation
                guard content.count < 10_000_000 else { // 10MB character limit
                    throw FileAccessError.fileTooLarge(maxSize: FileAccessConfiguration.maxFileSize)
                }

                return content
            } catch let error as NSError {
                // Try alternative encodings if UTF-8 fails
                if error.code == 1 { // UTF-8 decoding error
                    for encoding in [String.Encoding.utf16, .ascii, .isoLatin1] {
                        if let content = try? String(contentsOf: url, encoding: encoding) {
                            return content
                        }
                    }
                }
                throw FileAccessError.readFailed(underlying: error)
            }
        }
    }

    private func saveDocumentContent(_ content: String, to url: URL) async throws {
        // Use SecurityManager's safe scoped access method to prevent resource leaks
        try await securityManager.withSecurityScopedAccess(to: url) {
            // Enhanced input validation
            guard url.isFileURL,
                  !url.path.contains("../"), // Prevent path traversal
                  !url.path.hasPrefix("/System/"), // Prevent system file access
                  !url.path.hasPrefix("/private/") else { // Prevent private file access
                throw FileAccessError.accessDenied
            }

            // Validate file type
            let fileExtension = url.pathExtension.lowercased()
            guard fileExtension.isEmpty || FileAccessConfiguration.supportedExtensions.contains(fileExtension) else {
                throw FileAccessError.unsupportedFileType
            }

            // Validate content size
            let contentSize = content.utf8.count
            guard contentSize <= FileAccessConfiguration.maxFileSize else {
                throw FileAccessError.fileTooLarge(maxSize: FileAccessConfiguration.maxFileSize)
            }

            // Check file is writable
            if FileManager.default.fileExists(atPath: url.path) {
                let resourceValues = try url.resourceValues(forKeys: [.isWritableKey])
                guard resourceValues.isWritable == true else {
                    throw FileAccessError.accessDenied
                }
            }

            // Write content atomically with UTF-8 encoding
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw FileAccessError.writeFailed(underlying: error)
            }
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
public struct FileAccessConfiguration {
    /// Maximum file size in bytes (2MB)
    public static let maxFileSize: Int64 = 2 * 1024 * 1024

    /// Supported file extensions
    public static let supportedExtensions = ["md", "markdown", "txt", "text"]

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
    case writeFailed(underlying: Error)
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case securityScopeFailure

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The requested file could not be found"
        case .accessDenied:
            return "Access to the file was denied"
        case .fileTooLarge(let maxSize):
            return "File is too large (maximum size: \(ByteCountFormatter().string(fromByteCount: maxSize)))"
        case .unsupportedFileType:
            return "The file type is not supported"
        case .readFailed(let underlying):
            return "Failed to read file: \(underlying.localizedDescription)"
        case .writeFailed(let underlying):
            return "Failed to write file: \(underlying.localizedDescription)"
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

extension FileService {
    /// Create a preview service for development
    public static var preview: FileService {
        FileService()
    }
}

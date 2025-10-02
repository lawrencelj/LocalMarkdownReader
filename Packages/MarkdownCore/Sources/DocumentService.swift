/// DocumentService - Main service interface for document operations
///
/// Provides the primary interface for document parsing, loading, and rendering
/// operations expected by the frontend AppStateCoordinator.

import Foundation

/// Main document service interface expected by frontend
@MainActor
public class DocumentService: ObservableObject {
    private let parser: MarkdownParser
    private let performanceMonitor: PerformanceMonitor

    public init(configuration: MarkdownParser.Configuration = .default) {
        self.parser = MarkdownParser(configuration: configuration)
        self.performanceMonitor = PerformanceMonitor.shared
    }

    // MARK: - Frontend Interface Methods

    /// Load and parse a document from reference
    public func loadDocument(_ reference: DocumentReference) async throws -> DocumentModel {
        try await performanceMonitor.trackOperation("load_document") {
            // Read file content
            let content = try await loadFileContent(from: reference)

            // Parse the document
            let document = try await parser.parseDocument(content: content, reference: reference)

            return document
        }
    }

    /// Parse markdown content to DocumentModel
    public func parseMarkdown(_ content: String) async throws -> DocumentModel {
        let reference = DocumentReference(
            url: URL(fileURLWithPath: "/tmp/inline.md"),
            lastModified: Date(),
            fileSize: Int64(content.count)
        )

        return try await parser.parseDocument(content: content, reference: reference)
    }

    /// Render document to AttributedString
    public func renderToAttributedString(_ document: DocumentModel) -> NSAttributedString {
        // Convert AttributedString to NSAttributedString
        NSAttributedString(document.attributedContent)
    }

    /// Extract outline from document
    public func extractOutline(_ document: DocumentModel) -> [HeadingItem] {
        document.outline
    }

    // MARK: - Additional Service Methods

    /// Refresh document from its source
    public func refreshDocument(_ document: DocumentModel) async throws -> DocumentModel {
        try await loadDocument(document.reference)
    }

    /// Validate document can be parsed
    public func validateDocument(_ reference: DocumentReference) async throws -> Bool {
        do {
            let content = try await loadFileContent(from: reference)
            let validator = ValidationEngine(configuration: MarkdownParser.Configuration.default)
            try await validator.validateContent(content)
            return true
        } catch {
            return false
        }
    }

    /// Get document statistics
    public func getDocumentStatistics(_ document: DocumentModel) -> DocumentStatistics {
        DocumentStatistics(
            wordCount: document.metadata.wordCount,
            characterCount: document.metadata.characterCount,
            lineCount: document.metadata.lineCount,
            headingCount: document.outline.count,
            estimatedReadingTime: document.metadata.estimatedReadingTime,
            hasImages: document.metadata.hasImages,
            hasTables: document.metadata.hasTables,
            hasCodeBlocks: document.metadata.hasCodeBlocks,
            languageHints: Array(document.metadata.languageHints)
        )
    }

    // MARK: - Private Implementation

    private func loadFileContent(from reference: DocumentReference) async throws -> String {
        // Handle security-scoped resources
        var shouldStopAccessing = false

        if let bookmark = reference.bookmark {
            // Resolve security-scoped bookmark
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                throw DocumentError.securityScopeAccessFailed
            }

            guard resolvedURL.startAccessingSecurityScopedResource() else {
                throw DocumentError.accessDenied
            }

            shouldStopAccessing = true

            defer {
                if shouldStopAccessing {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            }

            return try await loadContentFromURL(resolvedURL)
        } else {
            return try await loadContentFromURL(reference.url)
        }
    }

    private func loadContentFromURL(_ url: URL) async throws -> String {
        // Validate file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentError.fileNotFound
        }

        // Check file size
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize,
           fileSize > MarkdownParser.maxDocumentSize {
            throw DocumentError.fileTooLarge(maxSize: MarkdownParser.maxDocumentSize)
        }

        // Read file content
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return content
        } catch let error as NSError {
            if error.code == NSFileReadNoSuchFileError {
                throw DocumentError.fileNotFound
            } else if error.code == NSFileReadNoPermissionError {
                throw DocumentError.accessDenied
            } else {
                throw DocumentError.parseFailure(error.localizedDescription)
            }
        }
    }
}

// MARK: - Supporting Types

/// Document statistics for frontend display
public struct DocumentStatistics: Sendable {
    public let wordCount: Int
    public let characterCount: Int
    public let lineCount: Int
    public let headingCount: Int
    public let estimatedReadingTime: Int
    public let hasImages: Bool
    public let hasTables: Bool
    public let hasCodeBlocks: Bool
    public let languageHints: [String]

    public init(
        wordCount: Int,
        characterCount: Int,
        lineCount: Int,
        headingCount: Int,
        estimatedReadingTime: Int,
        hasImages: Bool,
        hasTables: Bool,
        hasCodeBlocks: Bool,
        languageHints: [String]
    ) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.lineCount = lineCount
        self.headingCount = headingCount
        self.estimatedReadingTime = estimatedReadingTime
        self.hasImages = hasImages
        self.hasTables = hasTables
        self.hasCodeBlocks = hasCodeBlocks
        self.languageHints = languageHints
    }
}

// MARK: - Preview Support

extension DocumentService {
    /// Create a preview service for development
    public static var preview: DocumentService {
        DocumentService(configuration: .default)
    }
}

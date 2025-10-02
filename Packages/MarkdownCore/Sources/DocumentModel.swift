/// DocumentModel - Core document representation
///
/// Represents a parsed markdown document with metadata, content,
/// and performance optimizations for large documents.

import Foundation
import Markdown

/// Core document model representing a parsed markdown document
public struct DocumentModel: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public let reference: DocumentReference
    public let content: String
    public let attributedContent: AttributedString
    public let metadata: DocumentMetadata
    public let outline: [HeadingItem]
    public let parseDate: Date
    public let formatVersion: String

    public init(
        reference: DocumentReference,
        content: String,
        attributedContent: AttributedString,
        metadata: DocumentMetadata,
        outline: [HeadingItem]
    ) {
        self.id = UUID()
        self.reference = reference
        self.content = content
        self.attributedContent = attributedContent
        self.metadata = metadata
        self.outline = outline
        self.parseDate = Date()
        self.formatVersion = "1.0.0"
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case id, reference, content, metadata, outline, parseDate, formatVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        reference = try container.decode(DocumentReference.self, forKey: .reference)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decode(DocumentMetadata.self, forKey: .metadata)
        outline = try container.decode([HeadingItem].self, forKey: .outline)
        parseDate = try container.decode(Date.self, forKey: .parseDate)
        formatVersion = try container.decode(String.self, forKey: .formatVersion)

        // Re-parse attributed content (not serializable) - use fallback for sync context
        self.attributedContent = AttributedString(content)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(reference, forKey: .reference)
        try container.encode(content, forKey: .content)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(outline, forKey: .outline)
        try container.encode(parseDate, forKey: .parseDate)
        try container.encode(formatVersion, forKey: .formatVersion)
    }

    // MARK: - Hashable Implementation

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(reference)
        hasher.combine(parseDate)
    }

    public static func == (lhs: DocumentModel, rhs: DocumentModel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Document reference with security-scoped access
public struct DocumentReference: Sendable, Codable, Hashable {
    public let url: URL
    public let bookmark: Data?
    public let lastModified: Date
    public let fileSize: Int64
    public let securityScope: SecurityScope?

    public init(
        url: URL,
        bookmark: Data? = nil,
        lastModified: Date = Date(),
        fileSize: Int64 = 0,
        securityScope: SecurityScope? = nil
    ) {
        self.url = url
        self.bookmark = bookmark
        self.lastModified = lastModified
        self.fileSize = fileSize
        self.securityScope = securityScope
    }

    /// Create reference with security-scoped bookmark
    public static func withSecurityScope(
        url: URL,
        accessing: Bool = true
    ) throws -> DocumentReference {
        var bookmark: Data?

        if accessing {
            guard url.startAccessingSecurityScopedResource() else {
                throw DocumentError.securityScopeAccessFailed
            }
            bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        let resourceValues = try url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey
        ])

        return DocumentReference(
            url: url,
            bookmark: bookmark,
            lastModified: resourceValues.contentModificationDate ?? Date(),
            fileSize: Int64(resourceValues.fileSize ?? 0),
            securityScope: accessing ? .active : nil
        )
    }
}

/// Security scope state for sandboxed file access
public enum SecurityScope: Sendable, Codable {
    case active
    case inactive
    case expired
}

/// Document metadata extracted during parsing
public struct DocumentMetadata: Sendable, Codable, Hashable {
    public let title: String?
    public let wordCount: Int
    public let characterCount: Int
    public let lineCount: Int
    public let estimatedReadingTime: Int
    public let lastModified: Date
    public let fileSize: Int64
    public let encodingName: String
    public let hasImages: Bool
    public let hasTables: Bool
    public let hasCodeBlocks: Bool
    public let languageHints: Set<String>

    public init(
        title: String?,
        wordCount: Int,
        characterCount: Int,
        lineCount: Int,
        estimatedReadingTime: Int,
        lastModified: Date,
        fileSize: Int64,
        encodingName: String = "UTF-8",
        hasImages: Bool = false,
        hasTables: Bool = false,
        hasCodeBlocks: Bool = false,
        languageHints: Set<String> = []
    ) {
        self.title = title
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.lineCount = lineCount
        self.estimatedReadingTime = estimatedReadingTime
        self.lastModified = lastModified
        self.fileSize = fileSize
        self.encodingName = encodingName
        self.hasImages = hasImages
        self.hasTables = hasTables
        self.hasCodeBlocks = hasCodeBlocks
        self.languageHints = languageHints
    }

    /// Calculate reading time at 200 words per minute
    public static func calculateReadingTime(wordCount: Int) -> Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }
}

/// Heading item for document outline
public struct HeadingItem: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let level: Int
    public let title: String
    public let range: NSRange
    public let position: CGFloat
    public let children: [HeadingItem]

    public init(
        level: Int,
        title: String,
        range: NSRange,
        position: CGFloat = 0,
        children: [HeadingItem] = []
    ) {
        self.id = UUID().uuidString
        self.level = level
        self.title = title
        self.range = range
        self.position = position
        self.children = children
    }
}

/// Document parsing and processing errors
public enum DocumentError: Error, LocalizedError, Sendable {
    case invalidContent
    case parseFailure(String)
    case fileNotFound
    case accessDenied
    case securityScopeAccessFailed
    case fileTooLarge(maxSize: Int64)
    case unsupportedEncoding
    case corruptedContent
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidContent:
            return "The document content is invalid or corrupted"
        case .parseFailure(let reason):
            return "Failed to parse document: \(reason)"
        case .fileNotFound:
            return "The requested file could not be found"
        case .accessDenied:
            return "Access to the file was denied"
        case .securityScopeAccessFailed:
            return "Failed to access security-scoped resource"
        case .fileTooLarge(let maxSize):
            return "File is too large (maximum size: \(ByteCountFormatter().string(fromByteCount: maxSize)))"
        case .unsupportedEncoding:
            return "The file encoding is not supported"
        case .corruptedContent:
            return "The file content appears to be corrupted"
        case .networkUnavailable:
            return "Network connection is unavailable"
        }
    }
}

// MARK: - Preview Support

extension DocumentModel {
    /// Create a preview document for development and testing
    public static var preview: DocumentModel {
        let content = """
        # Sample Document

        This is a **sample markdown document** for preview purposes.

        ## Features

        - *Italic text*
        - **Bold text**
        - `Code snippets`

        ### Code Block

        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```

        ## Table

        | Column 1 | Column 2 |
        |----------|----------|
        | Value 1  | Value 2  |
        """

        let reference = DocumentReference(
            url: URL(fileURLWithPath: "/tmp/preview.md"),
            lastModified: Date(),
            fileSize: Int64(content.count)
        )

        let attributedContent = AttributedString(content)
        let metadata = DocumentMetadata(
            title: "Sample Document",
            wordCount: 25,
            characterCount: content.count,
            lineCount: content.components(separatedBy: .newlines).count,
            estimatedReadingTime: 1,
            lastModified: Date(),
            fileSize: Int64(content.count),
            hasTables: true,
            hasCodeBlocks: true
        )
        let outline = [
            HeadingItem(level: 1, title: "Sample Document", range: NSRange(location: 0, length: 16)),
            HeadingItem(level: 2, title: "Features", range: NSRange(location: 85, length: 8)),
            HeadingItem(level: 3, title: "Code Block", range: NSRange(location: 160, length: 10)),
            HeadingItem(level: 2, title: "Table", range: NSRange(location: 235, length: 5))
        ]

        return DocumentModel(
            reference: reference,
            content: content,
            attributedContent: attributedContent,
            metadata: metadata,
            outline: outline
        )
    }
}

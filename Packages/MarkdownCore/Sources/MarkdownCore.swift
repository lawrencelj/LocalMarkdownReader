/// MarkdownCore - Core markdown parsing and rendering engine
///
/// This module provides the foundational markdown processing capabilities
/// including CommonMark parsing with GitHub Flavored Markdown extensions,
/// performance optimization for large documents, and security validation.

// Re-export public interfaces
@_exported import Foundation
@_exported import Markdown
@_exported import OrderedCollections

public struct MarkdownCore {
    /// Library version
    public static let version = "1.0.0"

    /// Initialize the MarkdownCore library
    public static func initialize() async {
        // Perform any necessary initialization
        await PerformanceMonitor.shared.initialize()
    }
}
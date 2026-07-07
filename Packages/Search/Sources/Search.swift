/// Search - Document search and indexing engine
///
/// Provides high-performance full-text search capabilities with
/// in-memory indexing for sub-100ms response times.

// Re-export public interfaces
@_exported import Foundation
@_exported import OrderedCollections

public struct Search {
    /// Library version
    public static let version = "1.0.0"

    /// Initialize the Search library
    public static func initialize() async {
        // Perform any necessary initialization
        await SearchPerformanceMonitor.shared.initialize()
    }
}
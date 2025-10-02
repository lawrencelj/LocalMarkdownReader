/// FileAccess - Cross-platform file access and management
///
/// Provides secure file access capabilities with sandboxing support,
/// recent files management, and cross-platform compatibility.

// Re-export public interfaces
@_exported import Foundation

#if os(macOS)
@_exported import AppKit
#else
@_exported import UIKit
#endif

public struct FileAccess {
    /// Library version
    public static let version = "1.0.0"

    /// Initialize the FileAccess library
    public static func initialize() async {
        // Perform any necessary initialization
        await SecurityManager.shared.initialize()
    }
}

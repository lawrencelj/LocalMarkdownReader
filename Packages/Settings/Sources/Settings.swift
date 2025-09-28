/// Settings - Configuration and preferences management
///
/// Provides comprehensive settings management with privacy-by-design,
/// iCloud sync capabilities, and feature toggle support.

// Re-export public interfaces
@_exported import Foundation

public struct Settings {
    /// Library version
    public static let version = "1.0.0"

    /// Initialize the Settings library
    public static func initialize() async {
        // Perform any necessary initialization
        await SettingsManager.shared.initialize()
    }
}
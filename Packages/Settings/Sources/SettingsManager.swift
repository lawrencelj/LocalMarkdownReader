/// SettingsManager - Settings coordination and management
///
/// Provides centralized settings management, import/export functionality,
/// and iCloud synchronization coordination.

import Foundation

/// Centralized settings manager
public actor SettingsManager {
    public static let shared = SettingsManager()

    private var isInitialized = false
    private var iCloudSyncEnabled = false

    private init() {}

    // MARK: - Initialization

    /// Initialize settings manager
    public func initialize() {
        isInitialized = true
    }

    // MARK: - Settings Import/Export

    /// Export settings to data
    @MainActor
    public func exportSettings(_ preferences: UserPreferences) throws -> Data {
        let preferencesData = UserPreferencesData(
            theme: preferences.theme,
            accessibilitySettings: preferences.accessibilitySettings,
            privacySettings: preferences.privacySettings,
            featureToggles: preferences.featureToggles,
            editorSettings: preferences.editorSettings,
            performanceSettings: preferences.performanceSettings
        )

        let exportData = SettingsExportData(
            version: "1.0.0",
            exportDate: Date(),
            preferences: preferencesData
        )

        return try JSONEncoder().encode(exportData)
    }

    /// Import settings from data
    public func importSettings(from data: Data) throws -> UserPreferencesData {
        let exportData = try JSONDecoder().decode(SettingsExportData.self, from: data)

        // Validate version compatibility
        guard validateSettingsVersion(exportData.version) else {
            throw SettingsError.incompatibleVersion(exportData.version)
        }

        // Validate settings integrity
        try validateSettingsIntegrity(exportData.preferences)

        return exportData.preferences
    }

    /// Validate settings file
    public func validateSettingsFile(_ data: Data) throws -> SettingsValidationResult {
        do {
            let exportData = try JSONDecoder().decode(SettingsExportData.self, from: data)

            let versionCompatible = validateSettingsVersion(exportData.version)
            let integrityValid = (try? validateSettingsIntegrity(exportData.preferences)) != nil

            return SettingsValidationResult(
                isValid: versionCompatible && integrityValid,
                version: exportData.version,
                exportDate: exportData.exportDate,
                versionCompatible: versionCompatible,
                integrityValid: integrityValid,
                warnings: generateValidationWarnings(exportData)
            )
        } catch {
            throw SettingsError.invalidFormat(underlying: error)
        }
    }

    // MARK: - iCloud Sync Management

    /// Check if iCloud sync is available
    public func isICloudSyncAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Enable iCloud sync
    public func enableICloudSync() {
        guard isICloudSyncAvailable() else { return }
        iCloudSyncEnabled = true
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// Disable iCloud sync
    public func disableICloudSync() {
        iCloudSyncEnabled = false
    }

    /// Get iCloud sync status
    public func getICloudSyncStatus() -> ICloudSyncStatus {
        guard isICloudSyncAvailable() else {
            return .unavailable
        }

        if iCloudSyncEnabled {
            return .enabled
        } else {
            return .disabled
        }
    }

    // MARK: - Settings Migration

    /// Migrate settings from older version
    public func migrateSettings(from version: String, preferences: UserPreferencesData) throws -> UserPreferencesData {
        switch version {
        case "0.9.0"..<"1.0.0":
            return try migrateFromV0_9(preferences)
        default:
            // No migration needed
            return preferences
        }
    }

    /// Check if migration is needed
    public func migrationNeeded(from version: String) -> Bool {
        version != "1.0.0"
    }

    // MARK: - Settings Validation

    private func validateSettingsVersion(_ version: String) -> Bool {
        let supportedVersions = ["1.0.0"]
        return supportedVersions.contains(version)
    }

    private func validateSettingsIntegrity(_ preferences: UserPreferencesData) throws {
        // Validate theme
        guard !preferences.theme.name.isEmpty else {
            throw SettingsError.invalidTheme
        }

        // Validate performance settings
        guard preferences.performanceSettings.maxCacheSize > 0 else {
            throw SettingsError.invalidPerformanceSettings
        }

        // Validate editor settings
        guard preferences.editorSettings.tabSize > 0 && preferences.editorSettings.tabSize <= 16 else {
            throw SettingsError.invalidEditorSettings
        }

        // Validate privacy settings
        guard preferences.privacySettings.dataRetentionDays > 0 else {
            throw SettingsError.invalidPrivacySettings
        }
    }

    private func generateValidationWarnings(_ exportData: SettingsExportData) -> [String] {
        var warnings: [String] = []

        // Check export age
        let daysSinceExport = Calendar.current.dateComponents([.day], from: exportData.exportDate, to: Date()).day ?? 0
        if daysSinceExport > 30 {
            warnings.append("Settings export is \(daysSinceExport) days old")
        }

        // Check for experimental features
        if exportData.preferences.featureToggles.experimentalFeatures {
            warnings.append("Experimental features are enabled")
        }

        return warnings
    }

    // MARK: - Settings Migration Implementation

    private func migrateFromV0_9(_ preferences: UserPreferencesData) throws -> UserPreferencesData {
        // Example migration logic
        var migratedPreferences = preferences

        // Update performance settings defaults
        if preferences.performanceSettings.maxCacheSize < 50 * 1024 * 1024 {
            migratedPreferences = UserPreferencesData(
                theme: preferences.theme,
                accessibilitySettings: preferences.accessibilitySettings,
                privacySettings: preferences.privacySettings,
                featureToggles: preferences.featureToggles,
                editorSettings: preferences.editorSettings,
                performanceSettings: PerformanceSettings.default
            )
        }

        return migratedPreferences
    }

    // MARK: - Settings Templates

    /// Get predefined settings templates
    public func getSettingsTemplates() -> [SettingsTemplate] {
        [
            SettingsTemplate(
                name: "Default",
                description: "Balanced settings for general use",
                preferences: .default
            ),
            SettingsTemplate(
                name: "High Performance",
                description: "Optimized for speed and responsiveness",
                preferences: UserPreferencesData(
                    theme: .default,
                    accessibilitySettings: .default,
                    privacySettings: .default,
                    featureToggles: .default,
                    editorSettings: .default,
                    performanceSettings: .highPerformance
                )
            ),
            SettingsTemplate(
                name: "Privacy Focused",
                description: "Maximum privacy protection",
                preferences: UserPreferencesData(
                    theme: .default,
                    accessibilitySettings: .default,
                    privacySettings: .maxPrivacy,
                    featureToggles: .default,
                    editorSettings: .default,
                    performanceSettings: .default
                )
            ),
            SettingsTemplate(
                name: "Accessibility",
                description: "Enhanced accessibility features",
                preferences: UserPreferencesData(
                    theme: .highContrast,
                    accessibilitySettings: .highAccessibility,
                    privacySettings: .default,
                    featureToggles: .default,
                    editorSettings: .default,
                    performanceSettings: .default
                )
            )
        ]
    }
}

// MARK: - Supporting Types

/// Settings export data structure
private struct SettingsExportData: Codable {
    let version: String
    let exportDate: Date
    let preferences: UserPreferencesData
}

/// Settings validation result
public struct SettingsValidationResult: Sendable {
    public let isValid: Bool
    public let version: String
    public let exportDate: Date
    public let versionCompatible: Bool
    public let integrityValid: Bool
    public let warnings: [String]

    public init(
        isValid: Bool,
        version: String,
        exportDate: Date,
        versionCompatible: Bool,
        integrityValid: Bool,
        warnings: [String]
    ) {
        self.isValid = isValid
        self.version = version
        self.exportDate = exportDate
        self.versionCompatible = versionCompatible
        self.integrityValid = integrityValid
        self.warnings = warnings
    }
}

/// iCloud sync status
public enum ICloudSyncStatus: Sendable {
    case unavailable
    case disabled
    case enabled
    case syncing
    case error(String)

    public var displayName: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .disabled:
            return "Disabled"
        case .enabled:
            return "Enabled"
        case .syncing:
            return "Syncing"
        case .error:
            return "Error"
        }
    }
}

/// Settings template
public struct SettingsTemplate: Sendable, Identifiable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let preferences: UserPreferencesData

    public init(name: String, description: String, preferences: UserPreferencesData) {
        self.name = name
        self.description = description
        self.preferences = preferences
    }
}

/// Settings errors
public enum SettingsError: Error, LocalizedError, Sendable {
    case incompatibleVersion(String)
    case invalidFormat(underlying: Error)
    case invalidTheme
    case invalidPerformanceSettings
    case invalidEditorSettings
    case invalidPrivacySettings
    case iCloudUnavailable
    case exportFailed(underlying: Error)
    case importFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let version):
            return "Settings version \(version) is not compatible with this app version"
        case .invalidFormat(let underlying):
            return "Invalid settings file format: \(underlying.localizedDescription)"
        case .invalidTheme:
            return "Theme settings are invalid"
        case .invalidPerformanceSettings:
            return "Performance settings are invalid"
        case .invalidEditorSettings:
            return "Editor settings are invalid"
        case .invalidPrivacySettings:
            return "Privacy settings are invalid"
        case .iCloudUnavailable:
            return "iCloud is not available"
        case .exportFailed(let underlying):
            return "Failed to export settings: \(underlying.localizedDescription)"
        case .importFailed(let underlying):
            return "Failed to import settings: \(underlying.localizedDescription)"
        }
    }
}

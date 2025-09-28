/// PreferencesService - Main preferences service interface
///
/// Provides the primary interface for settings management expected by the
/// frontend AppStateCoordinator, with privacy protection and iCloud sync.

import Foundation

/// Main preferences service interface expected by frontend
@MainActor
public class PreferencesService: ObservableObject {
    private let userPreferences: UserPreferences
    private let settingsManager: SettingsManager

    public init(userDefaults: UserDefaults = .standard) {
        self.userPreferences = UserPreferences(userDefaults: userDefaults)
        self.settingsManager = SettingsManager.shared
    }

    // MARK: - Frontend Interface Methods

    /// Get current theme
    public func getTheme() -> AppTheme {
        return userPreferences.theme
    }

    /// Set theme
    public func setTheme(_ theme: AppTheme) {
        userPreferences.theme = theme
    }

    /// Get accessibility settings
    public func getAccessibilitySettings() -> AccessibilitySettings {
        return userPreferences.accessibilitySettings
    }

    /// Set accessibility settings
    public func setAccessibilitySettings(_ settings: AccessibilitySettings) {
        userPreferences.accessibilitySettings = settings
    }

    // MARK: - Extended Preferences Interface

    /// Get all user preferences
    public func getAllPreferences() -> UserPreferencesData {
        return UserPreferencesData(
            theme: userPreferences.theme,
            accessibilitySettings: userPreferences.accessibilitySettings,
            privacySettings: userPreferences.privacySettings,
            featureToggles: userPreferences.featureToggles,
            editorSettings: userPreferences.editorSettings,
            performanceSettings: userPreferences.performanceSettings
        )
    }

    /// Update preferences in batch
    public func updatePreferences(_ preferences: UserPreferencesData) {
        userPreferences.theme = preferences.theme
        userPreferences.accessibilitySettings = preferences.accessibilitySettings
        userPreferences.privacySettings = preferences.privacySettings
        userPreferences.featureToggles = preferences.featureToggles
        userPreferences.editorSettings = preferences.editorSettings
        userPreferences.performanceSettings = preferences.performanceSettings
    }

    /// Reset to default settings
    public func resetToDefaults() {
        userPreferences.resetToDefaults()
    }

    /// Export settings
    public func exportSettings() throws -> Data {
        return try settingsManager.exportSettings(userPreferences)
    }

    /// Import settings
    public func importSettings(from data: Data) async throws {
        let importedPreferences = try await settingsManager.importSettings(from: data)
        updatePreferences(importedPreferences)
    }

    /// Check if iCloud sync is available
    public func isICloudSyncAvailable() async -> Bool {
        return await settingsManager.isICloudSyncAvailable()
    }

    /// Enable/disable iCloud sync
    public func setICloudSyncEnabled(_ enabled: Bool) async {
        userPreferences.iCloudSyncEnabled = enabled
        if enabled {
            await settingsManager.enableICloudSync()
        } else {
            await settingsManager.disableICloudSync()
        }
    }
}

// MARK: - App Theme

/// Application theme configuration
public struct AppTheme: Codable, Sendable, Hashable {
    public let name: String
    public let appearance: Appearance
    public let accentColor: ThemeColor
    public let fontSize: FontSize
    public let fontFamily: FontFamily
    public let lineSpacing: LineSpacing
    public let codeHighlighting: CodeHighlightingTheme

    public init(
        name: String,
        appearance: Appearance = .system,
        accentColor: ThemeColor = .blue,
        fontSize: FontSize = .medium,
        fontFamily: FontFamily = .system,
        lineSpacing: LineSpacing = .normal,
        codeHighlighting: CodeHighlightingTheme = .default
    ) {
        self.name = name
        self.appearance = appearance
        self.accentColor = accentColor
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.lineSpacing = lineSpacing
        self.codeHighlighting = codeHighlighting
    }

    // MARK: - Predefined Themes

    public static let `default` = AppTheme(name: "Default")
    public static let dark = AppTheme(name: "Dark", appearance: .dark)
    public static let light = AppTheme(name: "Light", appearance: .light)
    public static let highContrast = AppTheme(
        name: "High Contrast",
        appearance: .dark,
        accentColor: .yellow,
        fontSize: .large
    )
}

/// Appearance mode
public enum Appearance: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Theme colors
public enum ThemeColor: String, Codable, CaseIterable, Sendable {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case red = "red"
    case purple = "purple"
    case yellow = "yellow"
    case pink = "pink"

    public var displayName: String {
        rawValue.capitalized
    }
}

/// Font sizes
public enum FontSize: String, Codable, CaseIterable, Sendable {
    case extraSmall = "extraSmall"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"

    public var pointSize: CGFloat {
        switch self {
        case .extraSmall: return 12
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        case .extraLarge: return 20
        }
    }

    public var displayName: String {
        switch self {
        case .extraSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

/// Font families
public enum FontFamily: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case monospace = "monospace"
    case serif = "serif"
    case sansSerif = "sansSerif"

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .monospace: return "Monospace"
        case .serif: return "Serif"
        case .sansSerif: return "Sans Serif"
        }
    }
}

/// Line spacing options
public enum LineSpacing: String, Codable, CaseIterable, Sendable {
    case compact = "compact"
    case normal = "normal"
    case relaxed = "relaxed"

    public var multiplier: CGFloat {
        switch self {
        case .compact: return 1.2
        case .normal: return 1.4
        case .relaxed: return 1.6
        }
    }

    public var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .normal: return "Normal"
        case .relaxed: return "Relaxed"
        }
    }
}

/// Code highlighting themes
public enum CodeHighlightingTheme: String, Codable, CaseIterable, Sendable {
    case `default` = "default"
    case github = "github"
    case xcode = "xcode"
    case solarized = "solarized"
    case monokai = "monokai"

    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .github: return "GitHub"
        case .xcode: return "Xcode"
        case .solarized: return "Solarized"
        case .monokai: return "Monokai"
        }
    }
}

// MARK: - Accessibility Settings

/// Accessibility configuration
public struct AccessibilitySettings: Codable, Sendable, Hashable {
    public let reduceMotion: Bool
    public let increaseContrast: Bool
    public let largerText: Bool
    public let boldText: Bool
    public let buttonShapes: Bool
    public let reduceTransparency: Bool
    public let voiceOverEnabled: Bool
    public let speakSelection: Bool
    public let speakScreen: Bool

    public init(
        reduceMotion: Bool = false,
        increaseContrast: Bool = false,
        largerText: Bool = false,
        boldText: Bool = false,
        buttonShapes: Bool = false,
        reduceTransparency: Bool = false,
        voiceOverEnabled: Bool = false,
        speakSelection: Bool = false,
        speakScreen: Bool = false
    ) {
        self.reduceMotion = reduceMotion
        self.increaseContrast = increaseContrast
        self.largerText = largerText
        self.boldText = boldText
        self.buttonShapes = buttonShapes
        self.reduceTransparency = reduceTransparency
        self.voiceOverEnabled = voiceOverEnabled
        self.speakSelection = speakSelection
        self.speakScreen = speakScreen
    }

    public static let `default` = AccessibilitySettings()

    /// High accessibility configuration
    public static let highAccessibility = AccessibilitySettings(
        reduceMotion: true,
        increaseContrast: true,
        largerText: true,
        boldText: true,
        buttonShapes: true,
        reduceTransparency: true
    )
}

// MARK: - Privacy Settings

/// Privacy configuration
public struct PrivacySettings: Codable, Sendable, Hashable {
    public let analyticsEnabled: Bool
    public let crashReportingEnabled: Bool
    public let usageDataCollection: Bool
    public let personalizedAds: Bool
    public let locationServicesEnabled: Bool
    public let dataRetentionDays: Int

    public init(
        analyticsEnabled: Bool = false,
        crashReportingEnabled: Bool = true,
        usageDataCollection: Bool = false,
        personalizedAds: Bool = false,
        locationServicesEnabled: Bool = false,
        dataRetentionDays: Int = 30
    ) {
        self.analyticsEnabled = analyticsEnabled
        self.crashReportingEnabled = crashReportingEnabled
        self.usageDataCollection = usageDataCollection
        self.personalizedAds = personalizedAds
        self.locationServicesEnabled = locationServicesEnabled
        self.dataRetentionDays = dataRetentionDays
    }

    /// Privacy-by-design defaults
    public static let `default` = PrivacySettings()

    /// Maximum privacy configuration
    public static let maxPrivacy = PrivacySettings(
        analyticsEnabled: false,
        crashReportingEnabled: false,
        usageDataCollection: false,
        personalizedAds: false,
        locationServicesEnabled: false,
        dataRetentionDays: 1
    )
}

// MARK: - Feature Toggles

/// Feature toggle configuration
public struct FeatureToggles: Codable, Sendable, Hashable {
    public let experimentalFeatures: Bool
    public let betaSearch: Bool
    public let advancedFormatting: Bool
    public let cloudSync: Bool
    public let collaborativeEditing: Bool
    public let aiAssistance: Bool

    public init(
        experimentalFeatures: Bool = false,
        betaSearch: Bool = false,
        advancedFormatting: Bool = true,
        cloudSync: Bool = true,
        collaborativeEditing: Bool = false,
        aiAssistance: Bool = false
    ) {
        self.experimentalFeatures = experimentalFeatures
        self.betaSearch = betaSearch
        self.advancedFormatting = advancedFormatting
        self.cloudSync = cloudSync
        self.collaborativeEditing = collaborativeEditing
        self.aiAssistance = aiAssistance
    }

    public static let `default` = FeatureToggles()

    /// All features enabled (for testing)
    public static let allEnabled = FeatureToggles(
        experimentalFeatures: true,
        betaSearch: true,
        advancedFormatting: true,
        cloudSync: true,
        collaborativeEditing: true,
        aiAssistance: true
    )
}

// MARK: - Editor Settings

/// Editor-specific configuration
public struct EditorSettings: Codable, Sendable, Hashable {
    public let wordWrap: Bool
    public let lineNumbers: Bool
    public let highlightCurrentLine: Bool
    public let autoIndent: Bool
    public let tabSize: Int
    public let insertSpaces: Bool
    public let trimTrailingWhitespace: Bool
    public let autoSave: Bool
    public let autoSaveDelay: TimeInterval

    public init(
        wordWrap: Bool = true,
        lineNumbers: Bool = false,
        highlightCurrentLine: Bool = true,
        autoIndent: Bool = true,
        tabSize: Int = 4,
        insertSpaces: Bool = true,
        trimTrailingWhitespace: Bool = true,
        autoSave: Bool = true,
        autoSaveDelay: TimeInterval = 2.0
    ) {
        self.wordWrap = wordWrap
        self.lineNumbers = lineNumbers
        self.highlightCurrentLine = highlightCurrentLine
        self.autoIndent = autoIndent
        self.tabSize = tabSize
        self.insertSpaces = insertSpaces
        self.trimTrailingWhitespace = trimTrailingWhitespace
        self.autoSave = autoSave
        self.autoSaveDelay = autoSaveDelay
    }

    public static let `default` = EditorSettings()
}

// MARK: - Performance Settings

/// Performance optimization configuration
public struct PerformanceSettings: Codable, Sendable, Hashable {
    public let enableHardwareAcceleration: Bool
    public let maxCacheSize: Int64
    public let backgroundProcessing: Bool
    public let preloadImages: Bool
    public let animationsEnabled: Bool
    public let maxRecentFiles: Int

    public init(
        enableHardwareAcceleration: Bool = true,
        maxCacheSize: Int64 = 100 * 1024 * 1024, // 100MB
        backgroundProcessing: Bool = true,
        preloadImages: Bool = true,
        animationsEnabled: Bool = true,
        maxRecentFiles: Int = 20
    ) {
        self.enableHardwareAcceleration = enableHardwareAcceleration
        self.maxCacheSize = maxCacheSize
        self.backgroundProcessing = backgroundProcessing
        self.preloadImages = preloadImages
        self.animationsEnabled = animationsEnabled
        self.maxRecentFiles = maxRecentFiles
    }

    public static let `default` = PerformanceSettings()

    /// High performance configuration
    public static let highPerformance = PerformanceSettings(
        enableHardwareAcceleration: true,
        maxCacheSize: 200 * 1024 * 1024, // 200MB
        backgroundProcessing: true,
        preloadImages: true,
        animationsEnabled: false,
        maxRecentFiles: 50
    )

    /// Low resource configuration
    public static let lowResource = PerformanceSettings(
        enableHardwareAcceleration: false,
        maxCacheSize: 50 * 1024 * 1024, // 50MB
        backgroundProcessing: false,
        preloadImages: false,
        animationsEnabled: false,
        maxRecentFiles: 10
    )
}

// MARK: - User Preferences Data

/// Complete user preferences data structure
public struct UserPreferencesData: Codable, Sendable {
    public let theme: AppTheme
    public let accessibilitySettings: AccessibilitySettings
    public let privacySettings: PrivacySettings
    public let featureToggles: FeatureToggles
    public let editorSettings: EditorSettings
    public let performanceSettings: PerformanceSettings

    public init(
        theme: AppTheme,
        accessibilitySettings: AccessibilitySettings,
        privacySettings: PrivacySettings,
        featureToggles: FeatureToggles,
        editorSettings: EditorSettings,
        performanceSettings: PerformanceSettings
    ) {
        self.theme = theme
        self.accessibilitySettings = accessibilitySettings
        self.privacySettings = privacySettings
        self.featureToggles = featureToggles
        self.editorSettings = editorSettings
        self.performanceSettings = performanceSettings
    }

    /// Default preferences
    public static let `default` = UserPreferencesData(
        theme: .default,
        accessibilitySettings: .default,
        privacySettings: .default,
        featureToggles: .default,
        editorSettings: .default,
        performanceSettings: .default
    )
}

// MARK: - Preview Support

extension PreferencesService {
    /// Create a preview service for development
    public static var preview: PreferencesService {
        return PreferencesService(userDefaults: UserDefaults())
    }
}
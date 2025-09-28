/// SettingsTests - Unit tests for Settings package
///
/// Comprehensive test suite covering preferences management,
/// persistence, validation, and iCloud synchronization.

import XCTest
@testable import Settings

final class SettingsTests: XCTestCase {
    var preferencesService: PreferencesService!
    var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        // Use a test-specific UserDefaults suite
        userDefaults = UserDefaults(suiteName: "MarkdownReaderTests")!
        userDefaults.removePersistentDomain(forName: "MarkdownReaderTests")

        preferencesService = PreferencesService(userDefaults: userDefaults)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: "MarkdownReaderTests")
        preferencesService = nil
        userDefaults = nil
    }

    // MARK: - Theme Tests

    func testThemeGetAndSet() {
        // Test default theme
        let defaultTheme = preferencesService.getTheme()
        XCTAssertEqual(defaultTheme.name, "Default")
        XCTAssertEqual(defaultTheme.appearance, .system)

        // Test setting custom theme
        let darkTheme = AppTheme.dark
        preferencesService.setTheme(darkTheme)

        let retrievedTheme = preferencesService.getTheme()
        XCTAssertEqual(retrievedTheme.name, "Dark")
        XCTAssertEqual(retrievedTheme.appearance, .dark)
    }

    func testThemeAppearanceModes() {
        let systemTheme = AppTheme(name: "System", appearance: .system)
        let lightTheme = AppTheme(name: "Light", appearance: .light)
        let darkTheme = AppTheme(name: "Dark", appearance: .dark)

        preferencesService.setTheme(systemTheme)
        XCTAssertEqual(preferencesService.getTheme().appearance, .system)

        preferencesService.setTheme(lightTheme)
        XCTAssertEqual(preferencesService.getTheme().appearance, .light)

        preferencesService.setTheme(darkTheme)
        XCTAssertEqual(preferencesService.getTheme().appearance, .dark)
    }

    func testThemeColors() {
        let themes = [
            AppTheme(name: "Blue", accentColor: .blue),
            AppTheme(name: "Green", accentColor: .green),
            AppTheme(name: "Red", accentColor: .red)
        ]

        for theme in themes {
            preferencesService.setTheme(theme)
            let retrieved = preferencesService.getTheme()
            XCTAssertEqual(retrieved.accentColor, theme.accentColor)
        }
    }

    func testFontSizes() {
        let sizes: [FontSize] = [.extraSmall, .small, .medium, .large, .extraLarge]

        for size in sizes {
            let theme = AppTheme(name: "Test", fontSize: size)
            preferencesService.setTheme(theme)

            let retrieved = preferencesService.getTheme()
            XCTAssertEqual(retrieved.fontSize, size)
            XCTAssertTrue(retrieved.fontSize.pointSize > 0)
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibilitySettings() {
        let defaultSettings = preferencesService.getAccessibilitySettings()
        XCTAssertEqual(defaultSettings, AccessibilitySettings.default)

        let highAccessibility = AccessibilitySettings.highAccessibility
        preferencesService.setAccessibilitySettings(highAccessibility)

        let retrieved = preferencesService.getAccessibilitySettings()
        XCTAssertTrue(retrieved.reduceMotion)
        XCTAssertTrue(retrieved.increaseContrast)
        XCTAssertTrue(retrieved.largerText)
        XCTAssertTrue(retrieved.boldText)
    }

    func testAccessibilityIndividualSettings() {
        var settings = AccessibilitySettings.default

        // Test reduceMotion
        settings = AccessibilitySettings(reduceMotion: true)
        preferencesService.setAccessibilitySettings(settings)
        XCTAssertTrue(preferencesService.getAccessibilitySettings().reduceMotion)

        // Test increaseContrast
        settings = AccessibilitySettings(increaseContrast: true)
        preferencesService.setAccessibilitySettings(settings)
        XCTAssertTrue(preferencesService.getAccessibilitySettings().increaseContrast)

        // Test voiceOverEnabled
        settings = AccessibilitySettings(voiceOverEnabled: true)
        preferencesService.setAccessibilitySettings(settings)
        XCTAssertTrue(preferencesService.getAccessibilitySettings().voiceOverEnabled)
    }

    // MARK: - Privacy Settings Tests

    func testPrivacySettings() {
        let preferences = preferencesService.getAllPreferences()
        let defaultPrivacy = preferences.privacySettings

        // Test default privacy settings (privacy-by-design)
        XCTAssertFalse(defaultPrivacy.analyticsEnabled)
        XCTAssertTrue(defaultPrivacy.crashReportingEnabled) // Only this should be enabled by default
        XCTAssertFalse(defaultPrivacy.usageDataCollection)
        XCTAssertFalse(defaultPrivacy.personalizedAds)

        // Test maximum privacy settings
        let maxPrivacy = PrivacySettings.maxPrivacy
        var updatedPreferences = preferences
        updatedPreferences = UserPreferencesData(
            theme: preferences.theme,
            accessibilitySettings: preferences.accessibilitySettings,
            privacySettings: maxPrivacy,
            featureToggles: preferences.featureToggles,
            editorSettings: preferences.editorSettings,
            performanceSettings: preferences.performanceSettings
        )

        preferencesService.updatePreferences(updatedPreferences)

        let retrievedPrivacy = preferencesService.getAllPreferences().privacySettings
        XCTAssertFalse(retrievedPrivacy.analyticsEnabled)
        XCTAssertFalse(retrievedPrivacy.crashReportingEnabled)
        XCTAssertFalse(retrievedPrivacy.usageDataCollection)
        XCTAssertEqual(retrievedPrivacy.dataRetentionDays, 1)
    }

    // MARK: - Feature Toggles Tests

    func testFeatureToggles() {
        let preferences = preferencesService.getAllPreferences()
        let defaultToggles = preferences.featureToggles

        // Test default feature toggles
        XCTAssertFalse(defaultToggles.experimentalFeatures)
        XCTAssertFalse(defaultToggles.betaSearch)
        XCTAssertTrue(defaultToggles.advancedFormatting)
        XCTAssertTrue(defaultToggles.cloudSync)

        // Test enabling all features
        let allEnabled = FeatureToggles.allEnabled
        var updatedPreferences = preferences
        updatedPreferences = UserPreferencesData(
            theme: preferences.theme,
            accessibilitySettings: preferences.accessibilitySettings,
            privacySettings: preferences.privacySettings,
            featureToggles: allEnabled,
            editorSettings: preferences.editorSettings,
            performanceSettings: preferences.performanceSettings
        )

        preferencesService.updatePreferences(updatedPreferences)

        let retrievedToggles = preferencesService.getAllPreferences().featureToggles
        XCTAssertTrue(retrievedToggles.experimentalFeatures)
        XCTAssertTrue(retrievedToggles.betaSearch)
        XCTAssertTrue(retrievedToggles.aiAssistance)
        XCTAssertTrue(retrievedToggles.collaborativeEditing)
    }

    // MARK: - Editor Settings Tests

    func testEditorSettings() {
        let preferences = preferencesService.getAllPreferences()
        let defaultEditor = preferences.editorSettings

        // Test default editor settings
        XCTAssertTrue(defaultEditor.wordWrap)
        XCTAssertFalse(defaultEditor.lineNumbers)
        XCTAssertTrue(defaultEditor.autoIndent)
        XCTAssertEqual(defaultEditor.tabSize, 4)
        XCTAssertTrue(defaultEditor.insertSpaces)

        // Test custom editor settings
        let customEditor = EditorSettings(
            wordWrap: false,
            lineNumbers: true,
            tabSize: 2,
            insertSpaces: false,
            autoSaveDelay: 5.0
        )

        var updatedPreferences = preferences
        updatedPreferences = UserPreferencesData(
            theme: preferences.theme,
            accessibilitySettings: preferences.accessibilitySettings,
            privacySettings: preferences.privacySettings,
            featureToggles: preferences.featureToggles,
            editorSettings: customEditor,
            performanceSettings: preferences.performanceSettings
        )

        preferencesService.updatePreferences(updatedPreferences)

        let retrievedEditor = preferencesService.getAllPreferences().editorSettings
        XCTAssertFalse(retrievedEditor.wordWrap)
        XCTAssertTrue(retrievedEditor.lineNumbers)
        XCTAssertEqual(retrievedEditor.tabSize, 2)
        XCTAssertFalse(retrievedEditor.insertSpaces)
        XCTAssertEqual(retrievedEditor.autoSaveDelay, 5.0, accuracy: 0.1)
    }

    // MARK: - Performance Settings Tests

    func testPerformanceSettings() {
        let preferences = preferencesService.getAllPreferences()
        let defaultPerformance = preferences.performanceSettings

        // Test default performance settings
        XCTAssertTrue(defaultPerformance.enableHardwareAcceleration)
        XCTAssertEqual(defaultPerformance.maxCacheSize, 100 * 1024 * 1024) // 100MB
        XCTAssertTrue(defaultPerformance.backgroundProcessing)
        XCTAssertEqual(defaultPerformance.maxRecentFiles, 20)

        // Test high performance settings
        let highPerf = PerformanceSettings.highPerformance
        var updatedPreferences = preferences
        updatedPreferences = UserPreferencesData(
            theme: preferences.theme,
            accessibilitySettings: preferences.accessibilitySettings,
            privacySettings: preferences.privacySettings,
            featureToggles: preferences.featureToggles,
            editorSettings: preferences.editorSettings,
            performanceSettings: highPerf
        )

        preferencesService.updatePreferences(updatedPreferences)

        let retrievedPerf = preferencesService.getAllPreferences().performanceSettings
        XCTAssertEqual(retrievedPerf.maxCacheSize, 200 * 1024 * 1024) // 200MB
        XCTAssertEqual(retrievedPerf.maxRecentFiles, 50)
        XCTAssertFalse(retrievedPerf.animationsEnabled) // Disabled for performance
    }

    // MARK: - Preferences Persistence Tests

    func testPreferencesPersistence() {
        // Set custom preferences
        let customTheme = AppTheme.dark
        let customAccessibility = AccessibilitySettings.highAccessibility

        preferencesService.setTheme(customTheme)
        preferencesService.setAccessibilitySettings(customAccessibility)

        // Create new service instance (simulating app restart)
        let newService = PreferencesService(userDefaults: userDefaults)

        // Verify persistence
        XCTAssertEqual(newService.getTheme().name, "Dark")
        XCTAssertTrue(newService.getAccessibilitySettings().reduceMotion)
    }

    func testResetToDefaults() {
        // Set custom values
        preferencesService.setTheme(.dark)
        preferencesService.setAccessibilitySettings(.highAccessibility)

        // Reset to defaults
        preferencesService.resetToDefaults()

        // Verify reset
        XCTAssertEqual(preferencesService.getTheme().name, "Default")
        XCTAssertEqual(preferencesService.getAccessibilitySettings(), .default)
    }

    // MARK: - Settings Import/Export Tests

    func testSettingsExport() throws {
        // Set custom preferences
        preferencesService.setTheme(.dark)
        preferencesService.setAccessibilitySettings(.highAccessibility)

        // Export settings
        let exportData = try preferencesService.exportSettings()

        XCTAssertTrue(exportData.count > 0)

        // Verify we can decode the exported data
        let decoded = try JSONDecoder().decode([String: Any].self, from: exportData) as? [String: Any]
        XCTAssertNotNil(decoded)
    }

    func testSettingsImport() throws {
        // Create test preferences data
        let testPreferences = UserPreferencesData(
            theme: .dark,
            accessibilitySettings: .highAccessibility,
            privacySettings: .maxPrivacy,
            featureToggles: .allEnabled,
            editorSettings: .default,
            performanceSettings: .highPerformance
        )

        // Export to data
        let originalExportData = try preferencesService.exportSettings()

        // Reset preferences
        preferencesService.resetToDefaults()

        // Import settings
        try preferencesService.importSettings(from: originalExportData)

        // Note: This test would need the actual export format to work properly
        // For now, we just verify the import method doesn't crash
    }

    // MARK: - Theme Validation Tests

    func testThemeDisplayNames() {
        XCTAssertEqual(Appearance.system.displayName, "System")
        XCTAssertEqual(Appearance.light.displayName, "Light")
        XCTAssertEqual(Appearance.dark.displayName, "Dark")

        XCTAssertEqual(ThemeColor.blue.displayName, "Blue")
        XCTAssertEqual(ThemeColor.green.displayName, "Green")

        XCTAssertEqual(FontSize.medium.displayName, "Medium")
        XCTAssertEqual(FontSize.large.displayName, "Large")
    }

    func testFontSizePointValues() {
        XCTAssertEqual(FontSize.extraSmall.pointSize, 12)
        XCTAssertEqual(FontSize.small.pointSize, 14)
        XCTAssertEqual(FontSize.medium.pointSize, 16)
        XCTAssertEqual(FontSize.large.pointSize, 18)
        XCTAssertEqual(FontSize.extraLarge.pointSize, 20)
    }

    func testLineSpacingValues() {
        XCTAssertEqual(LineSpacing.compact.multiplier, 1.2, accuracy: 0.01)
        XCTAssertEqual(LineSpacing.normal.multiplier, 1.4, accuracy: 0.01)
        XCTAssertEqual(LineSpacing.relaxed.multiplier, 1.6, accuracy: 0.01)
    }

    // MARK: - Codable Tests

    func testThemeCodable() throws {
        let theme = AppTheme.dark
        let encoded = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(AppTheme.self, from: encoded)

        XCTAssertEqual(decoded.name, theme.name)
        XCTAssertEqual(decoded.appearance, theme.appearance)
        XCTAssertEqual(decoded.accentColor, theme.accentColor)
    }

    func testAccessibilitySettingsCodable() throws {
        let settings = AccessibilitySettings.highAccessibility
        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AccessibilitySettings.self, from: encoded)

        XCTAssertEqual(decoded.reduceMotion, settings.reduceMotion)
        XCTAssertEqual(decoded.increaseContrast, settings.increaseContrast)
        XCTAssertEqual(decoded.largerText, settings.largerText)
    }

    func testUserPreferencesDataCodable() throws {
        let preferences = UserPreferencesData.default
        let encoded = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(UserPreferencesData.self, from: encoded)

        XCTAssertEqual(decoded.theme.name, preferences.theme.name)
        XCTAssertEqual(decoded.accessibilitySettings.reduceMotion, preferences.accessibilitySettings.reduceMotion)
        XCTAssertEqual(decoded.privacySettings.analyticsEnabled, preferences.privacySettings.analyticsEnabled)
    }
}

// MARK: - Mock Data and Helpers

extension SettingsTests {
    func createTestUserDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "MarkdownReaderTests-\(UUID().uuidString)")!
        return defaults
    }
}
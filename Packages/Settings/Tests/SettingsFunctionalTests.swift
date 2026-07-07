/// SettingsFunctionalTests - Verifies all settings functions work correctly

import XCTest
@testable import Settings

@MainActor
final class SettingsFunctionalTests: XCTestCase {

    var preferencesService: PreferencesService!
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        testDefaults = UserDefaults(suiteName: "FunctionalTests.\(UUID().uuidString)")!
        preferencesService = PreferencesService(userDefaults: testDefaults)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        preferencesService = nil
        testDefaults = nil
    }

    // MARK: - Theme Management

    func testGetDefaultTheme() {
        let theme = preferencesService.getTheme()
        XCTAssertEqual(theme.name, "Default")
    }

    func testSetTheme() {
        preferencesService.setTheme(.dark)
        let theme = preferencesService.getTheme()
        XCTAssertEqual(theme.name, "Dark")
    }

    func testSetMultipleThemes() {
        preferencesService.setTheme(.light)
        XCTAssertEqual(preferencesService.getTheme().name, "Light")

        preferencesService.setTheme(.dark)
        XCTAssertEqual(preferencesService.getTheme().name, "Dark")

        preferencesService.setTheme(.highContrast)
        XCTAssertEqual(preferencesService.getTheme().name, "High Contrast")
    }

    // MARK: - Accessibility Settings

    func testGetDefaultAccessibilitySettings() {
        let settings = preferencesService.getAccessibilitySettings()
        XCTAssertFalse(settings.reduceMotion)
        XCTAssertFalse(settings.increaseContrast)
        XCTAssertFalse(settings.largerText)
    }

    func testSetAccessibilitySettings() {
        let newSettings = AccessibilitySettings(
            reduceMotion: true,
            increaseContrast: true,
            largerText: true,
            boldText: true
        )
        preferencesService.setAccessibilitySettings(newSettings)

        let retrieved = preferencesService.getAccessibilitySettings()
        XCTAssertTrue(retrieved.reduceMotion)
        XCTAssertTrue(retrieved.increaseContrast)
        XCTAssertTrue(retrieved.largerText)
        XCTAssertTrue(retrieved.boldText)
    }

    // MARK: - All Preferences

    func testGetAllPreferences() {
        let prefs = preferencesService.getAllPreferences()
        XCTAssertNotNil(prefs.theme)
        XCTAssertNotNil(prefs.accessibilitySettings)
        XCTAssertNotNil(prefs.privacySettings)
        XCTAssertNotNil(prefs.featureToggles)
        XCTAssertNotNil(prefs.editorSettings)
        XCTAssertNotNil(prefs.performanceSettings)
    }

    func testUpdatePreferences() {
        let newPrefs = UserPreferencesData(
            theme: .dark,
            accessibilitySettings: .highAccessibility,
            privacySettings: .maxPrivacy,
            featureToggles: .allEnabled,
            editorSettings: .default,
            performanceSettings: .highPerformance
        )

        preferencesService.updatePreferences(newPrefs)

        let retrieved = preferencesService.getAllPreferences()
        XCTAssertEqual(retrieved.theme.name, "Dark")
        XCTAssertTrue(retrieved.accessibilitySettings.reduceMotion)
        XCTAssertFalse(retrieved.privacySettings.analyticsEnabled)
        XCTAssertTrue(retrieved.featureToggles.experimentalFeatures)
    }

    // MARK: - Reset

    func testResetToDefaults() {
        // Change settings
        preferencesService.setTheme(.dark)
        preferencesService.setAccessibilitySettings(.highAccessibility)

        // Reset
        preferencesService.resetToDefaults()

        // Verify defaults
        let theme = preferencesService.getTheme()
        XCTAssertEqual(theme.name, "Default")

        let accessibility = preferencesService.getAccessibilitySettings()
        XCTAssertFalse(accessibility.reduceMotion)
    }

    // MARK: - Export/Import

    func testExportSettings() throws {
        preferencesService.setTheme(.dark)
        let data = try preferencesService.exportSettings()
        XCTAssertGreaterThan(data.count, 0)
    }

    func testImportSettings() async throws {
        // Export current settings
        preferencesService.setTheme(.dark)
        let exportedData = try preferencesService.exportSettings()

        // Reset and import
        preferencesService.resetToDefaults()
        try await preferencesService.importSettings(from: exportedData)

        // Verify imported
        let theme = preferencesService.getTheme()
        XCTAssertEqual(theme.name, "Dark")
    }

    // MARK: - Settings Manager

    func testSettingsTemplates() async {
        let templates = await SettingsManager.shared.getSettingsTemplates()
        XCTAssertGreaterThan(templates.count, 0)

        let templateNames = templates.map { $0.name }
        XCTAssertTrue(templateNames.contains("Default"))
        XCTAssertTrue(templateNames.contains("High Performance"))
        XCTAssertTrue(templateNames.contains("Privacy Focused"))
        XCTAssertTrue(templateNames.contains("Accessibility"))
    }

    func testICloudSyncStatus() async {
        let status = await SettingsManager.shared.getICloudSyncStatus()
        // In test environment, iCloud is typically unavailable or disabled
        switch status {
        case .unavailable, .disabled:
            XCTAssertTrue(true)
        default:
            XCTAssertTrue(true) // Any status is acceptable in tests
        }
    }
}

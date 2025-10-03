import Foundation

/// Immutable snapshot of `UserPreferences` values for cross-actor usage.
public struct UserPreferencesSnapshot: Sendable {
    public let theme: AppTheme
    public let accessibilitySettings: AccessibilitySettings
    public let privacySettings: PrivacySettings
    public let featureToggles: FeatureToggles
    public let editorSettings: EditorSettings
    public let performanceSettings: PerformanceSettings

    private init(
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

    @MainActor
    public static func capture(from preferences: UserPreferences) -> UserPreferencesSnapshot {
        UserPreferencesSnapshot(
            theme: preferences.theme,
            accessibilitySettings: preferences.accessibilitySettings,
            privacySettings: preferences.privacySettings,
            featureToggles: preferences.featureToggles,
            editorSettings: preferences.editorSettings,
            performanceSettings: preferences.performanceSettings
        )
    }
}

/// UserPreferences - User preference management and persistence
///
/// Manages user preferences with automatic persistence, validation,
/// and optional iCloud synchronization.

import Foundation

/// User preferences manager with automatic persistence
@MainActor
public class UserPreferences: ObservableObject {
    private let userDefaults: UserDefaults
    private let iCloudStore: NSUbiquitousKeyValueStore?

    // MARK: - Published Properties

    @Published public var theme: AppTheme {
        didSet { saveTheme() }
    }

    @Published public var accessibilitySettings: AccessibilitySettings {
        didSet { saveAccessibilitySettings() }
    }

    @Published public var privacySettings: PrivacySettings {
        didSet { savePrivacySettings() }
    }

    @Published public var featureToggles: FeatureToggles {
        didSet { saveFeatureToggles() }
    }

    @Published public var editorSettings: EditorSettings {
        didSet { saveEditorSettings() }
    }

    @Published public var performanceSettings: PerformanceSettings {
        didSet { savePerformanceSettings() }
    }

    @Published public var iCloudSyncEnabled: Bool {
        didSet { saveICloudSyncEnabled() }
    }

    // MARK: - Recent Files and State

    private var recentFiles: [URL] = []
    private var lastDocument: URL?
    private var scrollPositions: [URL: CGFloat] = [:]
    private var sidebarVisibility: Bool = true
    private var searchVisibility: Bool = false

    // MARK: - Storage Keys

    private struct StorageKeys {
        static let theme = "MarkdownReader.Theme"
        static let accessibilitySettings = "MarkdownReader.AccessibilitySettings"
        static let privacySettings = "MarkdownReader.PrivacySettings"
        static let featureToggles = "MarkdownReader.FeatureToggles"
        static let editorSettings = "MarkdownReader.EditorSettings"
        static let performanceSettings = "MarkdownReader.PerformanceSettings"
        static let iCloudSyncEnabled = "MarkdownReader.iCloudSyncEnabled"
        static let recentFiles = "MarkdownReader.RecentFiles"
        static let lastDocument = "MarkdownReader.LastDocument"
        static let scrollPositions = "MarkdownReader.ScrollPositions"
        static let sidebarVisibility = "MarkdownReader.SidebarVisibility"
        static let searchVisibility = "MarkdownReader.SearchVisibility"
    }

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.iCloudStore = NSUbiquitousKeyValueStore.default

        // Initialize with defaults, then load saved values
        self.theme = .default
        self.accessibilitySettings = .default
        self.privacySettings = .default
        self.featureToggles = .default
        self.editorSettings = .default
        self.performanceSettings = .default
        self.iCloudSyncEnabled = false

        loadAllSettings()
        setupICloudObserver()
    }

    // MARK: - Public Interface

    /// Load all settings from storage
    public func loadSettings() async {
        loadAllSettings()
    }

    /// Save all settings to storage
    public func saveSettings() async {
        saveAllSettings()
    }

    /// Reset all settings to defaults
    public func resetToDefaults() {
        theme = .default
        accessibilitySettings = .default
        privacySettings = .default
        featureToggles = .default
        editorSettings = .default
        performanceSettings = .default
        iCloudSyncEnabled = false

        // Clear recent files and state
        recentFiles.removeAll()
        lastDocument = nil
        scrollPositions.removeAll()
        sidebarVisibility = true
        searchVisibility = false

        saveAllSettings()
    }

    // MARK: - Recent Files Management

    /// Add file to recent files list
    public func addRecentFile(_ url: URL) async {
        if let index = recentFiles.firstIndex(of: url) {
            recentFiles.remove(at: index)
        }
        recentFiles.insert(url, at: 0)

        // Limit to maximum count
        let maxCount = performanceSettings.maxRecentFiles
        if recentFiles.count > maxCount {
            recentFiles = Array(recentFiles.prefix(maxCount))
        }

        saveRecentFiles()
    }

    /// Get recent files list
    public func getRecentFiles() -> [URL] {
        return recentFiles
    }

    /// Remove file from recent files
    public func removeRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        saveRecentFiles()
    }

    /// Clear all recent files
    public func clearRecentFiles() {
        recentFiles.removeAll()
        saveRecentFiles()
    }

    // MARK: - Document State Management

    /// Set last opened document
    public func setLastDocument(_ url: URL) async {
        lastDocument = url
        saveLastDocument()
    }

    /// Get last opened document
    public func getLastDocument() async -> URL? {
        return lastDocument
    }

    /// Save scroll position for document
    public func saveScrollPosition(_ position: CGFloat, for url: URL?) async {
        guard let url = url else { return }
        scrollPositions[url] = position
        saveScrollPositions()
    }

    /// Get scroll position for document
    public func getScrollPosition(for url: URL) async -> CGFloat? {
        return scrollPositions[url]
    }

    /// Set sidebar visibility
    public func setSidebarVisibility(_ visible: Bool) async {
        sidebarVisibility = visible
        saveSidebarVisibility()
    }

    /// Get sidebar visibility
    public func getSidebarVisibility() async -> Bool {
        return sidebarVisibility
    }

    /// Set search visibility
    public func setSearchVisibility(_ visible: Bool) async {
        searchVisibility = visible
        saveSearchVisibility()
    }

    /// Get search visibility
    public func getSearchVisibility() async -> Bool {
        return searchVisibility
    }

    // MARK: - Private Implementation

    private func loadAllSettings() {
        loadTheme()
        loadAccessibilitySettings()
        loadPrivacySettings()
        loadFeatureToggles()
        loadEditorSettings()
        loadPerformanceSettings()
        loadICloudSyncEnabled()
        loadRecentFiles()
        loadLastDocument()
        loadScrollPositions()
        loadSidebarVisibility()
        loadSearchVisibility()
    }

    private func saveAllSettings() {
        saveTheme()
        saveAccessibilitySettings()
        savePrivacySettings()
        saveFeatureToggles()
        saveEditorSettings()
        savePerformanceSettings()
        saveICloudSyncEnabled()
        saveRecentFiles()
        saveLastDocument()
        saveScrollPositions()
        saveSidebarVisibility()
        saveSearchVisibility()
    }

    // MARK: - Individual Setting Persistence

    private func loadTheme() {
        if let data = getData(for: StorageKeys.theme),
           let decoded = try? JSONDecoder().decode(AppTheme.self, from: data) {
            theme = decoded
        }
    }

    private func saveTheme() {
        if let encoded = try? JSONEncoder().encode(theme) {
            setData(encoded, for: StorageKeys.theme)
        }
    }

    private func loadAccessibilitySettings() {
        if let data = getData(for: StorageKeys.accessibilitySettings),
           let decoded = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            accessibilitySettings = decoded
        }
    }

    private func saveAccessibilitySettings() {
        if let encoded = try? JSONEncoder().encode(accessibilitySettings) {
            setData(encoded, for: StorageKeys.accessibilitySettings)
        }
    }

    private func loadPrivacySettings() {
        if let data = getData(for: StorageKeys.privacySettings),
           let decoded = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            privacySettings = decoded
        }
    }

    private func savePrivacySettings() {
        if let encoded = try? JSONEncoder().encode(privacySettings) {
            setData(encoded, for: StorageKeys.privacySettings)
        }
    }

    private func loadFeatureToggles() {
        if let data = getData(for: StorageKeys.featureToggles),
           let decoded = try? JSONDecoder().decode(FeatureToggles.self, from: data) {
            featureToggles = decoded
        }
    }

    private func saveFeatureToggles() {
        if let encoded = try? JSONEncoder().encode(featureToggles) {
            setData(encoded, for: StorageKeys.featureToggles)
        }
    }

    private func loadEditorSettings() {
        if let data = getData(for: StorageKeys.editorSettings),
           let decoded = try? JSONDecoder().decode(EditorSettings.self, from: data) {
            editorSettings = decoded
        }
    }

    private func saveEditorSettings() {
        if let encoded = try? JSONEncoder().encode(editorSettings) {
            setData(encoded, for: StorageKeys.editorSettings)
        }
    }

    private func loadPerformanceSettings() {
        if let data = getData(for: StorageKeys.performanceSettings),
           let decoded = try? JSONDecoder().decode(PerformanceSettings.self, from: data) {
            performanceSettings = decoded
        }
    }

    private func savePerformanceSettings() {
        if let encoded = try? JSONEncoder().encode(performanceSettings) {
            setData(encoded, for: StorageKeys.performanceSettings)
        }
    }

    private func loadICloudSyncEnabled() {
        iCloudSyncEnabled = getBool(for: StorageKeys.iCloudSyncEnabled)
    }

    private func saveICloudSyncEnabled() {
        setBool(iCloudSyncEnabled, for: StorageKeys.iCloudSyncEnabled)
    }

    private func loadRecentFiles() {
        if let data = getData(for: StorageKeys.recentFiles),
           let decoded = try? JSONDecoder().decode([URL].self, from: data) {
            recentFiles = decoded
        }
    }

    private func saveRecentFiles() {
        if let encoded = try? JSONEncoder().encode(recentFiles) {
            setData(encoded, for: StorageKeys.recentFiles)
        }
    }

    private func loadLastDocument() {
        if let data = getData(for: StorageKeys.lastDocument),
           let decoded = try? JSONDecoder().decode(URL.self, from: data) {
            lastDocument = decoded
        }
    }

    private func saveLastDocument() {
        if let lastDocument = lastDocument,
           let encoded = try? JSONEncoder().encode(lastDocument) {
            setData(encoded, for: StorageKeys.lastDocument)
        }
    }

    private func loadScrollPositions() {
        if let data = getData(for: StorageKeys.scrollPositions),
           let decoded = try? JSONDecoder().decode([String: CGFloat].self, from: data) {
            // Convert string keys back to URLs
            scrollPositions = decoded.compactMapValues { value in value }
                .reduce(into: [URL: CGFloat]()) { result, pair in
                    if let url = URL(string: pair.key) {
                        result[url] = pair.value
                    }
                }
        }
    }

    private func saveScrollPositions() {
        // Convert URL keys to strings for JSON encoding
        let stringKeyed = scrollPositions.reduce(into: [String: CGFloat]()) { result, pair in
            result[pair.key.absoluteString] = pair.value
        }

        if let encoded = try? JSONEncoder().encode(stringKeyed) {
            setData(encoded, for: StorageKeys.scrollPositions)
        }
    }

    private func loadSidebarVisibility() {
        sidebarVisibility = userDefaults.object(forKey: StorageKeys.sidebarVisibility) as? Bool ?? true
    }

    private func saveSidebarVisibility() {
        setBool(sidebarVisibility, for: StorageKeys.sidebarVisibility)
    }

    private func loadSearchVisibility() {
        searchVisibility = getBool(for: StorageKeys.searchVisibility)
    }

    private func saveSearchVisibility() {
        setBool(searchVisibility, for: StorageKeys.searchVisibility)
    }

    // MARK: - Storage Helpers

    private func getData(for key: String) -> Data? {
        if iCloudSyncEnabled, let iCloudData = iCloudStore?.data(forKey: key) {
            return iCloudData
        }
        return userDefaults.data(forKey: key)
    }

    private func setData(_ data: Data, for key: String) {
        userDefaults.set(data, forKey: key)
        if iCloudSyncEnabled {
            iCloudStore?.set(data, forKey: key)
        }
    }

    private func getBool(for key: String) -> Bool {
        if iCloudSyncEnabled {
            return iCloudStore?.bool(forKey: key) ?? userDefaults.bool(forKey: key)
        }
        return userDefaults.bool(forKey: key)
    }

    private func setBool(_ value: Bool, for key: String) {
        userDefaults.set(value, forKey: key)
        if iCloudSyncEnabled {
            iCloudStore?.set(value, forKey: key)
        }
    }

    // MARK: - iCloud Sync

    private func setupICloudObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
    }

    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        guard iCloudSyncEnabled else { return }

        Task { @MainActor in
            // Reload settings from iCloud
            loadAllSettings()
        }
    }
}

// MARK: - Preview Support

extension UserPreferences {
    /// Create preview instance with sample data
    public static var preview: UserPreferences {
        let instance = UserPreferences(userDefaults: UserDefaults())
        instance.theme = .dark
        instance.accessibilitySettings = .highAccessibility
        return instance
    }

    /// Empty preview instance
    public static var previewEmpty: UserPreferences {
        return UserPreferences(userDefaults: UserDefaults())
    }
}
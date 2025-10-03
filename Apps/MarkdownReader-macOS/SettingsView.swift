/// SettingsView - macOS Settings Window
///
/// Provides interactive settings management interface with real-time editing.
/// Fixed: Bindings now properly trigger @Published didSet by replacing entire structs.

import SwiftUI
import Settings
import ViewerUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            EditableSettingsView(coordinator: coordinator)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(0)

            TemplatesView()
                .tabItem {
                    Label("Templates", systemImage: "doc.on.doc")
                }
                .tag(1)

            ImportExportView()
                .tabItem {
                    Label("Import/Export", systemImage: "arrow.up.arrow.down")
                }
                .tag(2)
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - Editable Settings View

struct EditableSettingsView: View {
    @Bindable private var coordinator: AppStateCoordinator
    @State private var showResetConfirmation = false

    init(coordinator: AppStateCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Theme Settings
                GroupBox("Theme") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Name:", text: Binding(
                            get: { coordinator.userPreferences.theme.name },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.name = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        ))

                        Picker("Appearance:", selection: Binding(
                            get: { coordinator.userPreferences.theme.appearance },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.appearance = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        )) {
                            ForEach(Appearance.allCases, id: \.self) { appearance in
                                Text(appearance.displayName).tag(appearance)
                            }
                        }

                        Picker("Accent Color:", selection: Binding(
                            get: { coordinator.userPreferences.theme.accentColor },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.accentColor = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        )) {
                            ForEach(ThemeColor.allCases, id: \.self) { color in
                                Text(color.displayName).tag(color)
                            }
                        }

                        Picker("Font Size:", selection: Binding(
                            get: { coordinator.userPreferences.theme.fontSize },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.fontSize = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        )) {
                            ForEach(FontSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }

                        Picker("Font Family:", selection: Binding(
                            get: { coordinator.userPreferences.theme.fontFamily },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.fontFamily = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        )) {
                            ForEach(FontFamily.allCases, id: \.self) { family in
                                Text(family.displayName).tag(family)
                            }
                        }

                        Picker("Line Spacing:", selection: Binding(
                            get: { coordinator.userPreferences.theme.lineSpacing },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.lineSpacing = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        )) {
                            ForEach(LineSpacing.allCases, id: \.self) { spacing in
                                Text(spacing.displayName).tag(spacing)
                            }
                        }

                        Picker("Code Highlighting:", selection: Binding(
                            get: { coordinator.userPreferences.theme.codeHighlighting },
                            set: { newValue in
                                var theme = coordinator.userPreferences.theme
                                theme.codeHighlighting = newValue
                                coordinator.userPreferences.theme = theme
                            }
                        )) {
                            ForEach(CodeHighlightingTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                    }
                }

                // Accessibility Settings
                GroupBox("Accessibility") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Reduce Motion", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.reduceMotion },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.reduceMotion = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Increase Contrast", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.increaseContrast },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.increaseContrast = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Larger Text", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.largerText },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.largerText = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Bold Text", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.boldText },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.boldText = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Button Shapes", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.buttonShapes },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.buttonShapes = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Reduce Transparency", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.reduceTransparency },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.reduceTransparency = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("VoiceOver", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.voiceOverEnabled },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.voiceOverEnabled = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Speak Selection", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.speakSelection },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.speakSelection = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))

                        Toggle("Speak Screen", isOn: Binding(
                            get: { coordinator.userPreferences.accessibilitySettings.speakScreen },
                            set: { newValue in
                                var settings = coordinator.userPreferences.accessibilitySettings
                                settings.speakScreen = newValue
                                coordinator.userPreferences.accessibilitySettings = settings
                            }
                        ))
                    }
                }

                // Privacy Settings
                GroupBox("Privacy") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Analytics Enabled", isOn: Binding(
                            get: { coordinator.userPreferences.privacySettings.analyticsEnabled },
                            set: { newValue in
                                var settings = coordinator.userPreferences.privacySettings
                                settings.analyticsEnabled = newValue
                                coordinator.userPreferences.privacySettings = settings
                            }
                        ))

                        Toggle("Crash Reporting", isOn: Binding(
                            get: { coordinator.userPreferences.privacySettings.crashReportingEnabled },
                            set: { newValue in
                                var settings = coordinator.userPreferences.privacySettings
                                settings.crashReportingEnabled = newValue
                                coordinator.userPreferences.privacySettings = settings
                            }
                        ))

                        Toggle("Usage Data Collection", isOn: Binding(
                            get: { coordinator.userPreferences.privacySettings.usageDataCollection },
                            set: { newValue in
                                var settings = coordinator.userPreferences.privacySettings
                                settings.usageDataCollection = newValue
                                coordinator.userPreferences.privacySettings = settings
                            }
                        ))

                        Toggle("Personalized Ads", isOn: Binding(
                            get: { coordinator.userPreferences.privacySettings.personalizedAds },
                            set: { newValue in
                                var settings = coordinator.userPreferences.privacySettings
                                settings.personalizedAds = newValue
                                coordinator.userPreferences.privacySettings = settings
                            }
                        ))

                        Toggle("Location Services", isOn: Binding(
                            get: { coordinator.userPreferences.privacySettings.locationServicesEnabled },
                            set: { newValue in
                                var settings = coordinator.userPreferences.privacySettings
                                settings.locationServicesEnabled = newValue
                                coordinator.userPreferences.privacySettings = settings
                            }
                        ))

                        Stepper("Data Retention: \(coordinator.userPreferences.privacySettings.dataRetentionDays) days",
                                value: Binding(
                                    get: { coordinator.userPreferences.privacySettings.dataRetentionDays },
                                    set: { newValue in
                                        var settings = coordinator.userPreferences.privacySettings
                                        settings.dataRetentionDays = newValue
                                        coordinator.userPreferences.privacySettings = settings
                                    }
                                ), in: 1...365)
                    }
                }

                // Feature Toggles
                GroupBox("Features") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Experimental Features", isOn: Binding(
                            get: { coordinator.userPreferences.featureToggles.experimentalFeatures },
                            set: { newValue in
                                var toggles = coordinator.userPreferences.featureToggles
                                toggles.experimentalFeatures = newValue
                                coordinator.userPreferences.featureToggles = toggles
                            }
                        ))

                        Toggle("Beta Search", isOn: Binding(
                            get: { coordinator.userPreferences.featureToggles.betaSearch },
                            set: { newValue in
                                var toggles = coordinator.userPreferences.featureToggles
                                toggles.betaSearch = newValue
                                coordinator.userPreferences.featureToggles = toggles
                            }
                        ))

                        Toggle("Advanced Formatting", isOn: Binding(
                            get: { coordinator.userPreferences.featureToggles.advancedFormatting },
                            set: { newValue in
                                var toggles = coordinator.userPreferences.featureToggles
                                toggles.advancedFormatting = newValue
                                coordinator.userPreferences.featureToggles = toggles
                            }
                        ))

                        Toggle("Cloud Sync", isOn: Binding(
                            get: { coordinator.userPreferences.featureToggles.cloudSync },
                            set: { newValue in
                                var toggles = coordinator.userPreferences.featureToggles
                                toggles.cloudSync = newValue
                                coordinator.userPreferences.featureToggles = toggles
                            }
                        ))

                        Toggle("Collaborative Editing", isOn: Binding(
                            get: { coordinator.userPreferences.featureToggles.collaborativeEditing },
                            set: { newValue in
                                var toggles = coordinator.userPreferences.featureToggles
                                toggles.collaborativeEditing = newValue
                                coordinator.userPreferences.featureToggles = toggles
                            }
                        ))

                        Toggle("AI Assistance", isOn: Binding(
                            get: { coordinator.userPreferences.featureToggles.aiAssistance },
                            set: { newValue in
                                var toggles = coordinator.userPreferences.featureToggles
                                toggles.aiAssistance = newValue
                                coordinator.userPreferences.featureToggles = toggles
                            }
                        ))
                    }
                }

                // Editor Settings
                GroupBox("Editor") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Word Wrap", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.wordWrap },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.wordWrap = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Toggle("Line Numbers", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.lineNumbers },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.lineNumbers = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Toggle("Highlight Current Line", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.highlightCurrentLine },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.highlightCurrentLine = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Toggle("Auto Indent", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.autoIndent },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.autoIndent = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Stepper("Tab Size: \(coordinator.userPreferences.editorSettings.tabSize)",
                                value: Binding(
                                    get: { coordinator.userPreferences.editorSettings.tabSize },
                                    set: { newValue in
                                        var settings = coordinator.userPreferences.editorSettings
                                        settings.tabSize = newValue
                                        coordinator.userPreferences.editorSettings = settings
                                    }
                                ), in: 2...8)

                        Toggle("Insert Spaces", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.insertSpaces },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.insertSpaces = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Toggle("Trim Trailing Whitespace", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.trimTrailingWhitespace },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.trimTrailingWhitespace = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Toggle("Auto Save", isOn: Binding(
                            get: { coordinator.userPreferences.editorSettings.autoSave },
                            set: { newValue in
                                var settings = coordinator.userPreferences.editorSettings
                                settings.autoSave = newValue
                                coordinator.userPreferences.editorSettings = settings
                            }
                        ))

                        Stepper("Auto Save Delay: \(String(format: "%.1f", coordinator.userPreferences.editorSettings.autoSaveDelay))s",
                                value: Binding(
                                    get: { coordinator.userPreferences.editorSettings.autoSaveDelay },
                                    set: { newValue in
                                        var settings = coordinator.userPreferences.editorSettings
                                        settings.autoSaveDelay = newValue
                                        coordinator.userPreferences.editorSettings = settings
                                    }
                                ), in: 0.5...10.0, step: 0.5)
                    }
                }

                // Performance Settings
                GroupBox("Performance") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Hardware Acceleration", isOn: Binding(
                            get: { coordinator.userPreferences.performanceSettings.enableHardwareAcceleration },
                            set: { newValue in
                                var settings = coordinator.userPreferences.performanceSettings
                                settings.enableHardwareAcceleration = newValue
                                coordinator.userPreferences.performanceSettings = settings
                            }
                        ))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Max Cache Size: \(formatBytes(coordinator.userPreferences.performanceSettings.maxCacheSize))")
                            Slider(value: Binding(
                                get: { Double(coordinator.userPreferences.performanceSettings.maxCacheSize) },
                                set: { newValue in
                                    var settings = coordinator.userPreferences.performanceSettings
                                    settings.maxCacheSize = Int64(newValue)
                                    coordinator.userPreferences.performanceSettings = settings
                                }
                            ), in: 10_000_000...500_000_000, step: 10_000_000) {
                                Text("Cache Size")
                            }
                        }

                        Toggle("Background Processing", isOn: Binding(
                            get: { coordinator.userPreferences.performanceSettings.backgroundProcessing },
                            set: { newValue in
                                var settings = coordinator.userPreferences.performanceSettings
                                settings.backgroundProcessing = newValue
                                coordinator.userPreferences.performanceSettings = settings
                            }
                        ))

                        Toggle("Preload Images", isOn: Binding(
                            get: { coordinator.userPreferences.performanceSettings.preloadImages },
                            set: { newValue in
                                var settings = coordinator.userPreferences.performanceSettings
                                settings.preloadImages = newValue
                                coordinator.userPreferences.performanceSettings = settings
                            }
                        ))

                        Toggle("Animations Enabled", isOn: Binding(
                            get: { coordinator.userPreferences.performanceSettings.animationsEnabled },
                            set: { newValue in
                                var settings = coordinator.userPreferences.performanceSettings
                                settings.animationsEnabled = newValue
                                coordinator.userPreferences.performanceSettings = settings
                            }
                        ))

                        Stepper("Max Recent Files: \(coordinator.userPreferences.performanceSettings.maxRecentFiles)",
                                value: Binding(
                                    get: { coordinator.userPreferences.performanceSettings.maxRecentFiles },
                                    set: { newValue in
                                        var settings = coordinator.userPreferences.performanceSettings
                                        settings.maxRecentFiles = newValue
                                        coordinator.userPreferences.performanceSettings = settings
                                    }
                                ), in: 5...100, step: 5)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Memory Usage Limit: \(formatBytes(coordinator.userPreferences.performanceSettings.memoryUsageLimit))")
                            Slider(value: Binding(
                                get: { Double(coordinator.userPreferences.performanceSettings.memoryUsageLimit) },
                                set: { newValue in
                                    var settings = coordinator.userPreferences.performanceSettings
                                    settings.memoryUsageLimit = Int64(newValue)
                                    coordinator.userPreferences.performanceSettings = settings
                                }
                            ), in: 100_000_000...2_000_000_000, step: 50_000_000) {
                                Text("Memory Limit")
                            }
                        }
                    }
                }

                // Actions
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top)
            }
            .padding()
        }
        .confirmationDialog(
            "Reset Settings",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                coordinator.userPreferences.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Templates

struct TemplatesView: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @State private var templates: [SettingsTemplate] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Predefined Settings Templates")
                .font(.headline)
                .padding(.top)

            List(templates) { template in
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Apply Template") {
                        applyTemplate(template)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .task {
            templates = await SettingsManager.shared.getSettingsTemplates()
        }
    }

    private func applyTemplate(_ template: SettingsTemplate) {
        coordinator.userPreferences.theme = template.preferences.theme
        coordinator.userPreferences.accessibilitySettings = template.preferences.accessibilitySettings
        coordinator.userPreferences.privacySettings = template.preferences.privacySettings
        coordinator.userPreferences.featureToggles = template.preferences.featureToggles
        coordinator.userPreferences.editorSettings = template.preferences.editorSettings
        coordinator.userPreferences.performanceSettings = template.preferences.performanceSettings
    }
}

// MARK: - Import/Export

struct ImportExportView: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportedData: Data?
    @State private var errorMessage: String?
    @State private var iCloudStatus: ICloudSyncStatus = .disabled

    var body: some View {
        VStack(spacing: 30) {
            // Export Section
            GroupBox("Export Settings") {
                VStack(spacing: 12) {
                    Text("Export your current settings to a file for backup or sharing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Export Settings") {
                        Task {
                            await exportSettings()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }

            // Import Section
            GroupBox("Import Settings") {
                VStack(spacing: 12) {
                    Text("Import settings from a previously exported file.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Import Settings") {
                        showingImporter = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }

            // iCloud Sync Section
            GroupBox("iCloud Sync") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(iCloudStatus.displayName)
                            .foregroundColor(.secondary)
                    }

                    switch iCloudStatus {
                    case .unavailable:
                        Text("iCloud is not available on this device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    default:
                        Toggle("Enable iCloud Sync", isOn: Binding(
                            get: {
                                if case .enabled = iCloudStatus {
                                    return true
                                }
                                return false
                            },
                            set: { enabled in
                                Task {
                                    if enabled {
                                        await SettingsManager.shared.enableICloudSync()
                                    } else {
                                        await SettingsManager.shared.disableICloudSync()
                                    }
                                    iCloudStatus = await SettingsManager.shared.getICloudSyncStatus()
                                }
                            }
                        ))
                    }
                }
                .padding()
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .fileExporter(
            isPresented: $showingExporter,
            document: exportedData.map { SettingsDocument(data: $0) },
            contentTypes: [.json],
            defaultFilename: "MarkdownReaderSettings.json"
        ) { result in
            switch result {
            case .success:
                errorMessage = nil
            case .failure(let error):
                errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importSettings(from: url)
                }
            case .failure(let error):
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .task {
            iCloudStatus = await SettingsManager.shared.getICloudSyncStatus()
        }
    }

    private func exportSettings() async {
        do {
            let data = try await SettingsManager.shared.exportSettings(coordinator.userPreferences)
            exportedData = data
            showingExporter = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to export settings: \(error.localizedDescription)"
        }
    }

    private func importSettings(from url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            let preferences = try await SettingsManager.shared.importSettings(from: data)

            // Apply imported settings
            coordinator.userPreferences.theme = preferences.theme
            coordinator.userPreferences.accessibilitySettings = preferences.accessibilitySettings
            coordinator.userPreferences.privacySettings = preferences.privacySettings
            coordinator.userPreferences.featureToggles = preferences.featureToggles
            coordinator.userPreferences.editorSettings = preferences.editorSettings
            coordinator.userPreferences.performanceSettings = preferences.performanceSettings

            errorMessage = nil
        } catch {
            errorMessage = "Failed to import settings: \(error.localizedDescription)"
        }
    }
}

// MARK: - Settings Document (for export)

struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
}

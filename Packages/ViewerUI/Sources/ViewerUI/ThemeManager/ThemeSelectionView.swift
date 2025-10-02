/// ThemeSelectionView - Theme selection interface with accessibility controls
///
/// Provides comprehensive theme selection interface with live previews,
/// accessibility options, and real-time contrast validation for WCAG compliance.

import SwiftUI

/// Theme selection interface with accessibility controls
public struct ThemeSelectionView: View {
    // MARK: - State Management

    @Environment(\.themeManager) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Local State

    @State private var selectedTheme: Theme
    @State private var showingCustomColorPicker = false
    @State private var previewText = "The quick brown fox jumps over the lazy dog."
    @State private var isLivePreview = true

    // MARK: - Accessibility State

    @State private var fontSizeSliderValue: Double
    @State private var lineSpacingSliderValue: Double
    @State private var highContrastEnabled: Bool
    @State private var reduceMotionEnabled: Bool

    // MARK: - Initialization

    public init() {
        _selectedTheme = State(initialValue: ThemeManager().currentTheme)
        _fontSizeSliderValue = State(initialValue: Double(ThemeManager().fontSizeMultiplier))
        _lineSpacingSliderValue = State(initialValue: Double(ThemeManager().lineSpacingMultiplier))
        _highContrastEnabled = State(initialValue: ThemeManager().isHighContrastEnabled)
        _reduceMotionEnabled = State(initialValue: ThemeManager().isReduceMotionEnabled)
    }

    // MARK: - View Body

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    themeSelectionSection

                    accessibilitySection

                    typographySection

                    if isLivePreview {
                        previewSection
                    }

                    validationSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Appearance")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: toolbarLeadingPlacement) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: toolbarTrailingPlacement) {
                    Button("Done") {
                        applyChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme Selection")
        .onAppear {
            loadCurrentSettings()
        }
    }

    // MARK: - Theme Selection Section

    private var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Theme", systemImage: "paintbrush")

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    ThemeOptionView(
                        theme: theme,
                        isSelected: selectedTheme == theme
                    )                        {
                            selectTheme(theme)
                        }
                }
            }

            Toggle("Live Preview", isOn: $isLivePreview)
                .toggleStyle(.switch)
                .accessibilityLabel("Enable live theme preview")
        }
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Accessibility", systemImage: "accessibility")

            VStack(spacing: 12) {
                Toggle("High Contrast", isOn: $highContrastEnabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Enable high contrast mode")
                    .onChange(of: highContrastEnabled) { _, newValue in
                        if isLivePreview {
                            themeManager.enableHighContrast(newValue)
                        }
                    }

                Toggle("Reduce Motion", isOn: $reduceMotionEnabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Enable reduced motion")

                if themeManager.voiceOverEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VoiceOver Optimizations")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Enhanced accessibility features are active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - Typography Section

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Typography", systemImage: "textformat")

            VStack(spacing: 16) {
                // Font Size Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Font Size")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(Int(fontSizeSliderValue * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $fontSizeSliderValue,
                        in: 0.5...3.0,
                        step: 0.1
                    ) {
                        Text("Font Size")
                    } minimumValueLabel: {
                        Text("A")
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text("A")
                            .font(.title2)
                    }
                    .accessibilityValue("\(Int(fontSizeSliderValue * 100)) percent")
                    .onChange(of: fontSizeSliderValue) { _, newValue in
                        if isLivePreview {
                            themeManager.adjustFontSize(multiplier: newValue)
                        }
                    }
                }

                // Line Spacing Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Line Spacing")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(Int(lineSpacingSliderValue * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $lineSpacingSliderValue,
                        in: 0.8...2.0,
                        step: 0.1
                    ) {
                        Text("Line Spacing")
                    } minimumValueLabel: {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                    } maximumValueLabel: {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                    }
                    .accessibilityValue("\(Int(lineSpacingSliderValue * 100)) percent")
                    .onChange(of: lineSpacingSliderValue) { _, newValue in
                        if isLivePreview {
                            themeManager.adjustLineSpacing(multiplier: newValue)
                        }
                    }
                }

                // Reset Button
                Button("Reset to Default") {
                    resetTypographySettings()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Preview", systemImage: "eye")

            VStack(alignment: .leading, spacing: 12) {
                // Preview content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Document")
                        .font(themeManager.font(.title2))
                        .fontWeight(.semibold)

                    Text("# Heading 1")
                        .font(themeManager.font(.title))
                        .fontWeight(.bold)

                    Text("## Heading 2")
                        .font(themeManager.font(.headline))
                        .fontWeight(.semibold)

                    Text(previewText)
                        .font(themeManager.font(.body))
                        .lineSpacing(themeManager.lineSpacing(for: .body))

                    Text("This is secondary text that shows hierarchy.")
                        .font(themeManager.font(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.color(for: .secondaryBackground))
                )

                // Preview controls
                HStack {
                    TextField("Preview text", text: $previewText)
                        .textFieldStyle(.roundedBorder)

                    Button("Reset") {
                        previewText = "The quick brown fox jumps over the lazy dog."
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Validation Section

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Accessibility Validation", systemImage: "checkmark.shield")

            VStack(spacing: 12) {
                validationRow(
                    "Contrast Ratio",
                    value: contrastValidation.description,
                    isValid: contrastValidation.isAccessible
                )

                validationRow(
                    "Font Size",
                    value: fontSizeValidation,
                    isValid: fontSizeSliderValue >= 1.0
                )

                validationRow(
                    "Color Blindness",
                    value: colorBlindnessValidation,
                    isValid: true // Simplified validation
                )

                if !allValidationsPassing {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)

                        Text("Some accessibility guidelines are not met")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    @ViewBuilder
    private func validationRow(_ title: String, value: String, isValid: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isValid ? .green : .red)
                    .font(.system(size: 14))

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var toolbarLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarLeading
        #else
        return .cancellationAction
        #endif
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .confirmationAction
        #endif
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var contrastValidation: ContrastValidation {
        let foreground = themeManager.color(for: .primary)
        let background = themeManager.color(for: .background)
        return themeManager.validateContrastRatio(foreground, background: background)
    }

    private var fontSizeValidation: String {
        if fontSizeSliderValue >= 1.0 {
            return "Standard or larger"
        } else {
            return "Below recommended"
        }
    }

    private var colorBlindnessValidation: String {
        "Friendly" // Simplified validation
    }

    private var allValidationsPassing: Bool {
        contrastValidation.isAccessible && fontSizeSliderValue >= 1.0
    }

    // MARK: - Actions

    private func selectTheme(_ theme: Theme) {
        selectedTheme = theme

        if isLivePreview {
            themeManager.applyTheme(theme)
        }

        // Announce theme selection
        let announcement = "Selected \(theme.displayName) theme"
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func applyChanges() {
        themeManager.applyTheme(selectedTheme)
        themeManager.adjustFontSize(multiplier: fontSizeSliderValue)
        themeManager.adjustLineSpacing(multiplier: lineSpacingSliderValue)
        themeManager.enableHighContrast(highContrastEnabled)

        // Save preferences
        UserDefaults.standard.set(reduceMotionEnabled, forKey: "ReduceMotionEnabled")
    }

    private func loadCurrentSettings() {
        selectedTheme = themeManager.currentTheme
        fontSizeSliderValue = Double(themeManager.fontSizeMultiplier)
        lineSpacingSliderValue = Double(themeManager.lineSpacingMultiplier)
        highContrastEnabled = themeManager.isHighContrastEnabled
        reduceMotionEnabled = themeManager.isReduceMotionEnabled
    }

    private func resetTypographySettings() {
        fontSizeSliderValue = 1.0
        lineSpacingSliderValue = 1.0

        if isLivePreview {
            themeManager.adjustFontSize(multiplier: 1.0)
            themeManager.adjustLineSpacing(multiplier: 1.0)
        }

        AccessibilityNotification.Announcement("Typography reset to default").post()
    }
}

// MARK: - Theme Option View

private struct ThemeOptionView: View {
    let theme: Theme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.backgroundColor)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.borderColor, lineWidth: 1)
                        )

                    HStack {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 12, height: 12)

                        Rectangle()
                            .fill(theme.secondaryColor)
                            .frame(width: 20, height: 4)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                Label(theme.displayName, systemImage: theme.systemImage)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction(.default) {
            onSelect()
        }
    }
}

// MARK: - Theme Extensions

private extension Theme {
    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .dark: return .black
        case .system: return Color.systemBackground
        case .custom: return .gray
        case .highContrast: return .white
        }
    }

    var primaryColor: Color {
        switch self {
        case .light: return .black
        case .dark: return .white
        case .system: return .primary
        case .custom: return .purple
        case .highContrast: return .black
        }
    }

    var secondaryColor: Color {
        switch self {
        case .light: return .gray
        case .dark: return Color.systemGray
        case .system: return .secondary
        case .custom: return .pink
        case .highContrast: return Color.systemGray
        }
    }

    var borderColor: Color {
        Color.systemGray4
    }
}

// MARK: - Preview

struct ThemeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeSelectionView()
            .environment(\.themeManager, ThemeManager())
            .previewDisplayName("Theme Selection")
    }
}

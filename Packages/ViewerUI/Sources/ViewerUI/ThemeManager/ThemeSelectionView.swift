/// ThemeSelectionView - Theme selection interface

import SwiftUI

/// Theme selection interface with accessibility controls
public struct ThemeSelectionView: View {
    @Environment(\.themeManager) private var themeManager

    @State private var selectedTheme: Theme = .system
    @State private var fontSizeSliderValue: Double = 1.0
    @State private var lineSpacingValue: Double = 1.0
    @State private var highContrastEnabled: Bool = false

    public init() {}

    public var body: some View {
        Form {
            Section("Theme") {
                ForEach(Theme.allCases, id: \.self) { theme in
                    HStack {
                        Image(systemName: theme.systemImage)
                            .frame(width: 24)
                            .foregroundStyle(selectedTheme == theme ? Color.accentColor : .secondary)
                        Text(theme.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTheme = theme
                        themeManager.applyTheme(theme)
                    }
                }
            }

            Section("Typography") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontSizeSliderValue * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $fontSizeSliderValue, in: 0.5...3.0, step: 0.1)
                        .onChange(of: fontSizeSliderValue) { _, newValue in
                            themeManager.adjustFontSize(multiplier: newValue)
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Line Spacing")
                        Spacer()
                        Text("\(Int(lineSpacingValue * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $lineSpacingValue, in: 0.8...2.0, step: 0.1)
                        .onChange(of: lineSpacingValue) { _, newValue in
                            themeManager.adjustLineSpacing(multiplier: newValue)
                        }
                }

                Button("Reset to Default") {
                    fontSizeSliderValue = 1.0
                    lineSpacingValue = 1.0
                    themeManager.adjustFontSize(multiplier: 1.0)
                    themeManager.adjustLineSpacing(multiplier: 1.0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Accessibility") {
                Toggle("High Contrast", isOn: $highContrastEnabled)
                    .onChange(of: highContrastEnabled) { _, newValue in
                        themeManager.enableHighContrast(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedTheme = themeManager.currentTheme
            fontSizeSliderValue = Double(themeManager.fontSizeMultiplier)
            lineSpacingValue = Double(themeManager.lineSpacingMultiplier)
            highContrastEnabled = themeManager.isHighContrastEnabled
        }
    }
}

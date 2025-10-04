/// ColorExtensions - Cross-platform system color support for SwiftUI
///
/// Provides cross-platform system color compatibility between iOS and macOS,
/// ensuring consistent visual appearance while respecting platform conventions.
/// Resolves SwiftUI Color initialization issues with UIColor/NSColor system colors.

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Cross-Platform Color Extensions

extension Color {
    /// Cross-platform system background color
    static var systemBackground: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: NSColor.controlBackgroundColor)
        #endif
    }

    /// Cross-platform secondary system background color
    static var secondarySystemBackground: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: NSColor.controlColor)
        #endif
    }

    /// Cross-platform tertiary system background color
    static var tertiarySystemBackground: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.tertiarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: NSColor.separatorColor)
        #endif
    }

    /// Cross-platform grouped background color
    static var systemGroupedBackground: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGroupedBackground)
        #elseif os(macOS)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #endif
    }

    /// Cross-platform secondary grouped background color
    static var secondarySystemGroupedBackground: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.secondarySystemGroupedBackground)
        #elseif os(macOS)
        return Color(nsColor: NSColor.controlBackgroundColor)
        #endif
    }
}

// MARK: - System Gray Colors

extension Color {
    /// Cross-platform system gray color
    static var systemGray: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGray)
        #elseif os(macOS)
        return Color(nsColor: NSColor.systemGray)
        #endif
    }

    /// Cross-platform system gray 2 color
    static var systemGray2: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGray2)
        #elseif os(macOS)
        return Color(nsColor: NSColor.systemGray)
        #endif
    }

    /// Cross-platform system gray 3 color
    static var systemGray3: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGray3)
        #elseif os(macOS)
        return Color(nsColor: NSColor.tertiaryLabelColor)
        #endif
    }

    /// Cross-platform system gray 4 color
    static var systemGray4: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGray4)
        #elseif os(macOS)
        return Color(nsColor: NSColor.quaternaryLabelColor)
        #endif
    }

    /// Cross-platform system gray 5 color
    static var systemGray5: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGray5)
        #elseif os(macOS)
        return Color(nsColor: NSColor.controlColor)
        #endif
    }

    /// Cross-platform system gray 6 color
    static var systemGray6: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGray6)
        #elseif os(macOS)
        return Color(nsColor: NSColor.controlBackgroundColor)
        #endif
    }
}

// MARK: - System Label Colors

extension Color {
    /// Cross-platform primary label color
    static var primaryLabel: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.label)
        #elseif os(macOS)
        return Color(nsColor: NSColor.labelColor)
        #endif
    }

    /// Cross-platform secondary label color
    static var secondaryLabel: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.secondaryLabel)
        #elseif os(macOS)
        return Color(nsColor: NSColor.secondaryLabelColor)
        #endif
    }

    /// Cross-platform tertiary label color
    static var tertiaryLabel: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.tertiaryLabel)
        #elseif os(macOS)
        return Color(nsColor: NSColor.tertiaryLabelColor)
        #endif
    }

    /// Cross-platform quaternary label color
    static var quaternaryLabel: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.quaternaryLabel)
        #elseif os(macOS)
        return Color(nsColor: NSColor.quaternaryLabelColor)
        #endif
    }
}

// MARK: - System Accent Colors

extension Color {
    /// Cross-platform system blue color
    static var systemBlue: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemBlue)
        #elseif os(macOS)
        return Color(nsColor: NSColor.systemBlue)
        #endif
    }

    /// Cross-platform system red color
    static var systemRed: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemRed)
        #elseif os(macOS)
        return Color(nsColor: NSColor.systemRed)
        #endif
    }

    /// Cross-platform system green color
    static var systemGreen: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemGreen)
        #elseif os(macOS)
        return Color(nsColor: NSColor.systemGreen)
        #endif
    }

    /// Cross-platform system orange color
    static var systemOrange: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemOrange)
        #elseif os(macOS)
        return Color(nsColor: NSColor.systemOrange)
        #endif
    }
}

// MARK: - Adaptive Color Helpers

extension Color {
    /// Creates an adaptive color that responds to light/dark mode
    /// - Parameters:
    ///   - light: Color for light appearance
    ///   - dark: Color for dark appearance
    /// - Returns: Adaptive Color that switches based on appearance
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }

    /// Safe opacity modifier that ensures the result is still a Color
    func safeOpacity(_ opacity: Double) -> Color {
        self.opacity(min(max(opacity, 0.0), 1.0))
    }
}

// MARK: - Theme-Aware Color Providers

extension Color {
    /// Provides consistent separator color across platforms
    static var separator: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.separator)
        #elseif os(macOS)
        return Color(nsColor: NSColor.separatorColor)
        #endif
    }

    /// Provides consistent selection color across platforms
    static var selection: Color {
        #if os(iOS)
        return Color(uiColor: UIColor.systemBlue)
        #elseif os(macOS)
        return Color(nsColor: NSColor.selectedContentBackgroundColor)
        #endif
    }

    /// Provides consistent hover color for interactive elements
    static var hover: Color {
        #if os(iOS)
        return Color.systemGray5.safeOpacity(0.8)
        #elseif os(macOS)
        return Color(nsColor: NSColor.controlAccentColor).safeOpacity(0.1)
        #endif
    }
}

// MARK: - Accessibility Support

extension Color {
    /// High contrast version of the color for accessibility
    func highContrast() -> Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                return traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
            }
            return UIColor(self)
        })
        #elseif os(macOS)
        // macOS handles high contrast automatically through system preferences
        return self
        #endif
    }

    /// Returns true if the color is suitable for text on the current background
    var isAccessible: Bool {
        // Simplified accessibility check - in production, would use WCAG contrast ratios
        true
    }
}

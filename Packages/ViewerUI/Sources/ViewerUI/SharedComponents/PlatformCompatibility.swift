// PlatformCompatibility - Cross-platform UI compatibility

import SwiftUI

#if os(macOS)
    import AppKit

    extension Color {
        /// Cross-platform Color initializer matching iOS pattern
        init(uiColor: NSColor) {
            self.init(nsColor: uiColor)
        }
    }

    extension NSColor {
        static var systemBackground: NSColor {
            .windowBackgroundColor
        }

        static var secondarySystemBackground: NSColor {
            .controlBackgroundColor
        }

        static var systemGroupedBackground: NSColor {
            .windowBackgroundColor
        }

        static var systemGray5: NSColor {
            .systemGray.withAlphaComponent(0.2)
        }

        static var systemGray6: NSColor {
            .systemGray.withAlphaComponent(0.1)
        }
    }
#endif

/// ViewerUI - Enterprise SwiftUI Markdown Viewer Package
///
/// This package provides the complete user interface for the Swift Markdown Reader,
/// implementing enterprise-grade SwiftUI components with cross-platform support,
/// accessibility compliance, and performance optimization.
///
/// ## Architecture
/// - SwiftUI-first design with 95% code sharing between iOS and macOS
/// - @Observable state management with actor-based coordination
/// - Performance-optimized viewport rendering for large documents
/// - WCAG 2.1 AA accessibility compliance
/// - Platform-adaptive UI patterns
///
/// ## Key Components
/// - DocumentViewer: Main markdown content display with performance optimization
/// - NavigationSidebar: TOC/outline navigation with collapsible sections
/// - SearchInterface: Real-time search with highlighting and navigation
/// - ThemeManager: Theme and accessibility settings management
/// - SharedComponents: Reusable UI elements and platform adaptations

import MarkdownCore
import Settings
import SwiftUI

// MARK: - Public API

/// Main ViewerUI module providing public interfaces for the markdown viewer
@MainActor
public struct ViewerUI {
    /// Current version of the ViewerUI package
    public static let version = "1.0.0"

    /// Feature availability based on platform capabilities
    public static var features: ViewerFeatures {
        ViewerFeatures()
    }
}

/// Available features in the ViewerUI package
public struct ViewerFeatures {
    public let crossPlatformSupport = true
    public let accessibilityCompliance = true
    public let performanceOptimized = true
    public let searchCapabilities = true
    public let themeCustomization = true

    /// Platform-specific feature availability
    public var platformFeatures: PlatformFeatures {
        #if os(macOS)
        return PlatformFeatures(
            keyboardShortcuts: true,
            menuBarIntegration: true,
            multiWindow: true,
            touchBar: false
        )
        #elseif os(iOS)
        return PlatformFeatures(
            keyboardShortcuts: false,
            menuBarIntegration: false,
            multiWindow: false,
            touchBar: false
        )
        #endif
    }
}

/// Platform-specific feature capabilities
public struct PlatformFeatures {
    public let keyboardShortcuts: Bool
    public let menuBarIntegration: Bool
    public let multiWindow: Bool
    public let touchBar: Bool
}

// MARK: - Environment Configuration

/// Environment key for platform detection
private struct PlatformKey: EnvironmentKey {
    static let defaultValue: Platform = {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #endif
    }()
}

/// Platform enumeration for adaptive UI
public enum Platform: Sendable {
    case iOS
    case macOS

    public var isTouch: Bool {
        self == .iOS
    }

    public var isIOS: Bool {
        self == .iOS
    }

    public var supportsCursor: Bool {
        self == .macOS
    }
}

extension EnvironmentValues {
    /// Current platform environment value
    public var platform: Platform {
        get { self[PlatformKey.self] }
        set { self[PlatformKey.self] = newValue }
    }
}

// MARK: - Public View Modifiers

extension View {
    /// Apply platform-conditional modifications
    public func platformConditional<Content: View>(
        _ condition: Platform,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        Group {
            if condition == Environment(\.platform).wrappedValue {
                transform(self)
            } else {
                self
            }
        }
    }

    /// Apply conditional view modifications
    public func conditional<Content: View>(
        _ condition: Bool,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        Group {
            if condition {
                transform(self)
            } else {
                self
            }
        }
    }
}

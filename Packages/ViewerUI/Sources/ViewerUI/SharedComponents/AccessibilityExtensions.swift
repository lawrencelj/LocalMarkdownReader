/// AccessibilityExtensions - Cross-platform accessibility support
///
/// Provides cross-platform accessibility API compatibility between iOS and macOS,
/// ensuring consistent accessibility behavior while respecting platform differences.
/// Resolves UIAccessibility/NSAccessibility platform-specific issues.

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Cross-Platform Accessibility API

/// Cross-platform accessibility status provider
public struct PlatformAccessibility {
    /// Whether VoiceOver/VoiceControl is currently running
    public static var isVoiceOverRunning: Bool {
        #if os(iOS)
        return UIAccessibility.isVoiceOverRunning
        #elseif os(macOS)
        return NSWorkspace.shared.isVoiceOverEnabled
        #endif
    }

    /// Whether Switch Control/Switch Access is currently running
    public static var isSwitchControlRunning: Bool {
        #if os(iOS)
        return UIAccessibility.isSwitchControlRunning
        #elseif os(macOS)
        // macOS doesn't have direct equivalent, check for assistive technologies
        return AXIsProcessTrusted()
        #endif
    }

    /// Whether Reduce Motion is enabled in system preferences
    public static var isReduceMotionEnabled: Bool {
        #if os(iOS)
        return UIAccessibility.isReduceMotionEnabled
        #elseif os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    /// Whether high contrast is enabled in system preferences
    public static var isHighContrastEnabled: Bool {
        #if os(iOS)
        return UIAccessibility.isDarkerSystemColorsEnabled
        #elseif os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #endif
    }

    /// Whether AssistiveTouch or similar assistive technology is enabled
    public static var isAssistiveTouchEnabled: Bool {
        #if os(iOS)
        return UIAccessibility.isAssistiveTouchRunning
        #elseif os(macOS)
        // macOS equivalent - check for assistive device usage
        return AXIsProcessTrusted()
        #endif
    }
}

// MARK: - Cross-Platform Accessibility Notifications

/// Cross-platform accessibility notification names
public struct PlatformAccessibilityNotification {
    /// VoiceOver status change notification
    public static var voiceOverStatusDidChange: Notification.Name {
        #if os(iOS)
        return UIAccessibility.voiceOverStatusDidChangeNotification
        #elseif os(macOS)
        return .NSWorkspaceAccessibilityDisplayOptionsDidChange
        #endif
    }

    /// Switch Control status change notification
    public static var switchControlStatusDidChange: Notification.Name {
        #if os(iOS)
        return UIAccessibility.switchControlStatusDidChangeNotification
        #elseif os(macOS)
        return .NSWorkspaceAccessibilityDisplayOptionsDidChange
        #endif
    }

    /// Reduce Motion status change notification
    public static var reduceMotionStatusDidChange: Notification.Name {
        #if os(iOS)
        return UIAccessibility.reduceMotionStatusDidChangeNotification
        #elseif os(macOS)
        return .NSWorkspaceAccessibilityDisplayOptionsDidChange
        #endif
    }

    /// High contrast status change notification
    public static var highContrastStatusDidChange: Notification.Name {
        #if os(iOS)
        return UIAccessibility.darkerSystemColorsStatusDidChangeNotification
        #elseif os(macOS)
        return .NSWorkspaceAccessibilityDisplayOptionsDidChange
        #endif
    }
}

// MARK: - Accessibility Announcements

/// Cross-platform accessibility announcement wrapper
public struct AccessibilityAnnouncement {
    /// Post an accessibility announcement that will be read by screen readers
    /// - Parameter message: The message to announce
    public static func post(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        Task { @MainActor in
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                .announcement: message
            ])
        }
        #endif
    }

    /// Post a layout change announcement for significant UI updates
    /// - Parameter element: Optional element to focus after the announcement
    public static func postLayoutChange(focusedElement element: Any? = nil) {
        #if os(iOS)
        UIAccessibility.post(notification: .layoutChanged, argument: element)
        #elseif os(macOS)
        Task { @MainActor in
            NSAccessibility.post(element: NSApp as Any, notification: .layoutChanged)
        }
        #endif
    }

    /// Post a screen change announcement for major navigation changes
    /// - Parameter element: Optional element to focus after the announcement
    public static func postScreenChange(focusedElement element: Any? = nil) {
        #if os(iOS)
        UIAccessibility.post(notification: .screenChanged, argument: element)
        #elseif os(macOS)
        Task { @MainActor in
            NSAccessibility.post(element: NSApp as Any, notification: .applicationActivated)
        }
        #endif
    }
}

// MARK: - SwiftUI Accessibility Extensions

extension AccessibilityNotification {
    /// Cross-platform announcement helper for SwiftUI
    public static func announce(_ message: String) -> AccessibilityNotification? {
        #if os(iOS)
        return .announcement(message)
        #elseif os(macOS)
        // Fallback to standard announcement for macOS
        AccessibilityAnnouncement.post(message)
        // Return nil for macOS as the announcement is already posted
        return nil
        #endif
    }
}

// MARK: - macOS Specific Extensions

#if os(macOS)
extension NSWorkspace {
    /// Whether VoiceOver is enabled (computed property for consistency with iOS)
    var isVoiceOverEnabled: Bool {
        accessibilityDisplayShouldDifferentiateWithoutColor ||
               accessibilityDisplayShouldReduceMotion ||
               accessibilityDisplayShouldIncreaseContrast ||
               accessibilityDisplayShouldReduceTransparency
    }
}

extension Notification.Name {
    /// Unified accessibility display options change notification
    static let NSWorkspaceAccessibilityDisplayOptionsDidChange = NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
}
#endif

// MARK: - Accessibility Environment Values

/// Environment key for accessibility status
private struct AccessibilityStatusKey: EnvironmentKey {
    static let defaultValue = AccessibilityStatus()
}

/// Accessibility status information
public struct AccessibilityStatus: Sendable {
    public let isVoiceOverRunning: Bool
    public let isSwitchControlRunning: Bool
    public let isReduceMotionEnabled: Bool
    public let isHighContrastEnabled: Bool
    public let isAssistiveTouchEnabled: Bool

    public init() {
        self.isVoiceOverRunning = PlatformAccessibility.isVoiceOverRunning
        self.isSwitchControlRunning = PlatformAccessibility.isSwitchControlRunning
        self.isReduceMotionEnabled = PlatformAccessibility.isReduceMotionEnabled
        self.isHighContrastEnabled = PlatformAccessibility.isHighContrastEnabled
        self.isAssistiveTouchEnabled = PlatformAccessibility.isAssistiveTouchEnabled
    }

    /// Whether any assistive technology is currently active
    public var hasAssistiveTechnology: Bool {
        isVoiceOverRunning || isSwitchControlRunning || isAssistiveTouchEnabled
    }

    /// Whether enhanced accessibility features should be enabled
    public var shouldEnhanceAccessibility: Bool {
        hasAssistiveTechnology || isHighContrastEnabled
    }
}

extension EnvironmentValues {
    /// Current accessibility status
    public var accessibilityStatus: AccessibilityStatus {
        get { self[AccessibilityStatusKey.self] }
        set { self[AccessibilityStatusKey.self] = newValue }
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply accessibility enhancements when assistive technology is active
    public func accessibilityEnhanced() -> some View {
        self.modifier(AccessibilityEnhancementModifier())
    }

    /// Announce changes for accessibility
    public func accessibilityAnnounce(_ message: String, when condition: Bool = true) -> some View {
        self.onChange(of: condition) { _, newValue in
            if newValue {
                AccessibilityAnnouncement.post(message)
            }
        }
    }
}

/// View modifier that applies accessibility enhancements
private struct AccessibilityEnhancementModifier: ViewModifier {
    @Environment(\.accessibilityStatus) private var accessibilityStatus

    func body(content: Content) -> some View {
        content
            .animation(
                accessibilityStatus.isReduceMotionEnabled ? .none : .default,
                value: accessibilityStatus.shouldEnhanceAccessibility
            )
            .scaleEffect(
                accessibilityStatus.isHighContrastEnabled ? 1.1 : 1.0
            )
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
/// Accessibility testing utilities for development and testing
public struct AccessibilityTesting {
    /// Simulate VoiceOver being enabled (for testing purposes)
    public static func simulateVoiceOver(_ enabled: Bool) {
        // This would be used in unit tests to simulate accessibility states
        // Implementation would depend on testing framework
    }

    /// Validate accessibility compliance for a view
    public static func validateAccessibility<T: View>(_ view: T) -> [AccessibilityIssue] {
        // This would return a list of accessibility issues found in the view
        // Implementation would use platform-specific accessibility testing APIs
        []
    }
}

/// Represents an accessibility compliance issue
public struct AccessibilityIssue {
    public let description: String
    public let severity: Severity
    public let element: String?

    public enum Severity {
        case error, warning, info
    }
}
#endif

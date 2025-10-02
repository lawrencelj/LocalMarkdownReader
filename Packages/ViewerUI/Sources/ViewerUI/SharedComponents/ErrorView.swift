/// ErrorView - Comprehensive error display with recovery actions
///
/// Provides user-friendly error presentation with contextual recovery
/// actions, accessibility support, and detailed error information
/// for debugging purposes.

import SwiftUI

/// Comprehensive error display with recovery actions
public struct ErrorView: View {
    // MARK: - Configuration

    public let error: Error
    public let retryAction: (() -> Void)?
    public let dismissAction: (() -> Void)?
    public let customActions: [ErrorAction]

    // MARK: - Environment

    @Environment(\.platform) private var platform
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - State

    @State private var showingDetails = false
    @State private var hasAnnouncedError = false

    // MARK: - Initialization

    public init(
        error: Error,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil,
        customActions: [ErrorAction] = []
    ) {
        self.error = error
        self.retryAction = retryAction
        self.dismissAction = dismissAction
        self.customActions = customActions
    }

    // MARK: - View Body

    public var body: some View {
        VStack(spacing: spacingForCurrentSize) {
            errorIconView

            errorContentView

            if !availableActions.isEmpty {
                actionButtonsView
            }

            if platform.supportsCursor {
                detailsSection
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundView)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error occurred")
        .accessibilityValue(errorDescription)
        .onAppear {
            announceError()
        }
    }

    // MARK: - Error Icon

    private var errorIconView: some View {
        ZStack {
            Circle()
                .fill(errorColor.opacity(0.1))
                .frame(width: iconBackgroundSize, height: iconBackgroundSize)

            Image(systemName: errorSystemImage)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(errorColor)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Error Content

    private var errorContentView: some View {
        VStack(spacing: 12) {
            Text(errorTitle)
                .font(themeManager.font(.headline))
                .fontWeight(.semibold)
                .foregroundStyle(themeManager.color(for: .primary))
                .multilineTextAlignment(.center)

            Text(errorDescription)
                .font(themeManager.font(.body))
                .foregroundStyle(themeManager.color(for: .secondary))
                .multilineTextAlignment(.center)
                .lineSpacing(themeManager.lineSpacing(for: .body))

            if let suggestion = errorSuggestion {
                Text(suggestion)
                    .font(themeManager.font(.callout))
                    .foregroundStyle(themeManager.color(for: .accent))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // Primary actions (retry, dismiss)
            if !primaryActions.isEmpty {
                primaryActionsView
            }

            // Custom actions
            if !customActions.isEmpty {
                customActionsView
            }
        }
    }

    private var primaryActionsView: some View {
        HStack(spacing: 12) {
            ForEach(primaryActions, id: \.title) { action in
                Button(action.title) {
                    action.handler()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(action.accessibilityLabel ?? action.title)
            }
        }
    }

    private var customActionsView: some View {
        VStack(spacing: 8) {
            ForEach(customActions, id: \.title) { action in
                Button(action.title) {
                    action.handler()
                }
                .buttonStyle(.borderless)
                .font(themeManager.font(.callout))
                .accessibilityLabel(action.accessibilityLabel ?? action.title)
            }
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        VStack(spacing: 12) {
            Button(showingDetails ? "Hide Details" : "Show Details") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingDetails.toggle()
                }
            }
            .font(themeManager.font(.caption))
            .foregroundStyle(themeManager.color(for: .accent))

            if showingDetails {
                errorDetailsView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var errorDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error Details", systemImage: "info.circle")
                .font(themeManager.font(.caption))
                .fontWeight(.medium)
                .foregroundStyle(themeManager.color(for: .secondary))

            VStack(alignment: .leading, spacing: 4) {
                detailRow("Type", value: String(describing: type(of: error)))

                if let localizedError = error as? LocalizedError {
                    if let reason = localizedError.failureReason {
                        detailRow("Reason", value: reason)
                    }

                    if let suggestion = localizedError.recoverySuggestion {
                        detailRow("Suggestion", value: suggestion)
                    }
                }

                detailRow("Description", value: error.localizedDescription)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.color(for: .secondaryBackground))
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error details")
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(themeManager.font(.caption2))
                .fontWeight(.medium)
                .foregroundStyle(themeManager.color(for: .tertiary))

            Text(value)
                .font(themeManager.font(.caption))
                .foregroundStyle(themeManager.color(for: .secondary))
                .textSelection(.enabled)
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(themeManager.color(for: .secondaryBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(errorColor.opacity(0.2), lineWidth: 1)
            )
    }

    // MARK: - Computed Properties

    private var spacingForCurrentSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 16
        case .medium, .large: return 20
        case .xLarge, .xxLarge: return 24
        default: return 28
        }
    }

    private var horizontalPadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 20
        case .medium, .large: return 24
        case .xLarge, .xxLarge: return 28
        default: return 32
        }
    }

    private var verticalPadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 24
        case .medium, .large: return 28
        case .xLarge, .xxLarge: return 32
        default: return 36
        }
    }

    private var iconSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 28
        case .medium, .large: return 32
        case .xLarge, .xxLarge: return 36
        default: return 40
        }
    }

    private var iconBackgroundSize: CGFloat {
        iconSize * 2
    }

    private var errorColor: Color {
        if let markdownError = error as? MarkdownError {
            switch markdownError.severity {
            case .critical: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        return .red
    }

    private var errorSystemImage: String {
        if let markdownError = error as? MarkdownError {
            return markdownError.systemImage
        }

        if error is NetworkError {
            return "wifi.exclamationmark"
        }

        if error is FileError {
            return "doc.badge.exclamationmark"
        }

        return "exclamationmark.triangle"
    }

    private var errorTitle: String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        if let markdownError = error as? MarkdownError {
            return markdownError.title
        }

        return "An Error Occurred"
    }

    private var errorDescription: String {
        if let localizedError = error as? LocalizedError,
           let reason = localizedError.failureReason {
            return reason
        }

        return error.localizedDescription
    }

    private var errorSuggestion: String? {
        if let localizedError = error as? LocalizedError {
            return localizedError.recoverySuggestion
        }
        return nil
    }

    private var availableActions: [ErrorAction] {
        primaryActions + customActions
    }

    private var primaryActions: [ErrorAction] {
        var actions: [ErrorAction] = []

        if let retryAction = retryAction {
            actions.append(ErrorAction(
                title: "Try Again",
                handler: retryAction,
                isPrimary: true,
                accessibilityLabel: "Retry the failed operation"
            ))
        }

        if let dismissAction = dismissAction {
            actions.append(ErrorAction(
                title: "Dismiss",
                handler: dismissAction,
                isPrimary: false,
                accessibilityLabel: "Dismiss this error"
            ))
        }

        return actions
    }

    // MARK: - Accessibility

    private func announceError() {
        guard !hasAnnouncedError else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let announcement = "Error: \(errorDescription)"
            AccessibilityNotification.Announcement(announcement).post()
            hasAnnouncedError = true
        }
    }
}

// MARK: - Error Action

public struct ErrorAction {
    public let title: String
    public let handler: () -> Void
    public let isPrimary: Bool
    public let accessibilityLabel: String?

    public init(
        title: String,
        handler: @escaping () -> Void,
        isPrimary: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.handler = handler
        self.isPrimary = isPrimary
        self.accessibilityLabel = accessibilityLabel
    }
}

// MARK: - Error Types

public protocol MarkdownError: LocalizedError {
    var title: String { get }
    var severity: ErrorSeverity { get }
    var systemImage: String { get }
}

public enum ErrorSeverity {
    case critical
    case warning
    case info
}

public enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(Int)

    public var errorDescription: String? {
        switch self {
        case .noConnection: return "No Internet Connection"
        case .timeout: return "Request Timed Out"
        case .serverError(let code): return "Server Error (\(code))"
        }
    }

    public var failureReason: String? {
        switch self {
        case .noConnection: return "Check your internet connection and try again"
        case .timeout: return "The request took too long to complete"
        case .serverError: return "The server encountered an error"
        }
    }
}

public enum FileError: LocalizedError {
    case notFound
    case accessDenied
    case corrupted
    case unsupportedFormat

    public var errorDescription: String? {
        switch self {
        case .notFound: return "File Not Found"
        case .accessDenied: return "Access Denied"
        case .corrupted: return "File Corrupted"
        case .unsupportedFormat: return "Unsupported Format"
        }
    }

    public var failureReason: String? {
        switch self {
        case .notFound: return "The requested file could not be found"
        case .accessDenied: return "You don't have permission to access this file"
        case .corrupted: return "The file appears to be damaged or corrupted"
        case .unsupportedFormat: return "This file format is not supported"
        }
    }
}

// MARK: - Convenience Initializers

extension ErrorView {
    /// Network error display
    public static func networkError(
        _ error: NetworkError,
        retryAction: @escaping () -> Void
    ) -> ErrorView {
        ErrorView(
            error: error,
            retryAction: retryAction,
            customActions: [
                ErrorAction(title: "Check Settings") {
                    // Open network settings
                }
            ]
        )
    }

    /// File error display
    public static func fileError(
        _ error: FileError,
        retryAction: (() -> Void)? = nil
    ) -> ErrorView {
        ErrorView(
            error: error,
            retryAction: retryAction,
            customActions: [
                ErrorAction(title: "Choose Different File") {
                    // Open file picker
                }
            ]
        )
    }

    /// Generic error with minimal actions
    public static func simple(
        _ error: Error,
        dismissAction: @escaping () -> Void
    ) -> ErrorView {
        ErrorView(
            error: error,
            dismissAction: dismissAction
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                ErrorView.networkError(
                    NetworkError.noConnection
                )                    {}

                ErrorView.fileError(
                    FileError.notFound
                )                    {}

                ErrorView.simple(
                    FileError.corrupted
                )                    {}
            }
            .padding()
        }
    }
}
#endif

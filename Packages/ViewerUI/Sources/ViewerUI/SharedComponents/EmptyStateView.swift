/// EmptyStateView - Contextual empty state display with guidance
///
/// Provides meaningful empty state experiences with clear guidance,
/// action suggestions, and accessibility support for various scenarios
/// throughout the application.

import SwiftUI

// MARK: - Button Style Compatibility

/// Contextual empty state display with action guidance
public struct EmptyStateView: View {
    // MARK: - Configuration

    public let title: String
    public let message: String
    public let systemImage: String
    public let primaryAction: EmptyStateAction?
    public let secondaryActions: [EmptyStateAction]

    // MARK: - Environment

    @Environment(\.platform) private var platform
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Initialization

    public init(
        title: String,
        message: String,
        systemImage: String,
        primaryAction: EmptyStateAction? = nil,
        secondaryActions: [EmptyStateAction] = []
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
    }

    // MARK: - View Body

    public var body: some View {
        VStack(spacing: spacingForCurrentSize) {
            illustrationView

            contentView

            if hasActions {
                actionsView
            }
        }
        .frame(maxWidth: maxContentWidth, maxHeight: .infinity)
        .padding(.horizontal, horizontalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty state: \(title)")
        .accessibilityValue(message)
    }

    // MARK: - Illustration

    private var illustrationView: some View {
        ZStack {
            Circle()
                .fill(illustrationBackgroundColor)
                .frame(width: illustrationBackgroundSize, height: illustrationBackgroundSize)

            Image(systemName: systemImage)
                .font(.system(size: illustrationIconSize, weight: .light))
                .foregroundStyle(illustrationIconColor)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: textSpacing) {
            Text(title)
                .font(themeManager.font(.title2))
                .fontWeight(.semibold)
                .foregroundStyle(themeManager.color(for: .primary))
                .multilineTextAlignment(.center)

            Text(message)
                .font(themeManager.font(.body))
                .foregroundStyle(themeManager.color(for: .secondary))
                .multilineTextAlignment(.center)
                .lineSpacing(themeManager.lineSpacing(for: .body))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsView: some View {
        VStack(spacing: 12) {
            if let primaryAction = primaryAction {
                primaryActionView(primaryAction)
            }

            if !secondaryActions.isEmpty {
                secondaryActionsView
            }
        }
    }

    private func primaryActionView(_ action: EmptyStateAction) -> some View {
        Button(action.title) {
            action.handler()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(action.accessibilityLabel ?? action.title)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var secondaryActionsView: some View {
        if platform.isTouch && secondaryActions.count <= 2 {
            // iOS: Horizontal layout for 1-2 actions
            HStack(spacing: 12) {
                ForEach(secondaryActions.indices, id: \.self) { index in
                    secondaryActionButton(secondaryActions[index])
                }
            }
        } else {
            // macOS or many actions: Vertical layout
            VStack(spacing: 8) {
                ForEach(secondaryActions.indices, id: \.self) { index in
                    secondaryActionButton(secondaryActions[index])
                }
            }
        }
    }

    private func secondaryActionButton(_ action: EmptyStateAction) -> some View {
        Button(action.title) {
            action.handler()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(action.accessibilityLabel ?? action.title)
    }

    // MARK: - Computed Properties

    private var hasActions: Bool {
        primaryAction != nil || !secondaryActions.isEmpty
    }

    private var spacingForCurrentSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 24
        case .medium, .large: return 32
        case .xLarge, .xxLarge: return 40
        default: return 48
        }
    }

    private var horizontalPadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 32
        case .medium, .large: return 40
        case .xLarge, .xxLarge: return 48
        default: return 56
        }
    }

    private var maxContentWidth: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 300
        case .medium, .large: return 350
        case .xLarge, .xxLarge: return 400
        default: return 450
        }
    }

    private var textSpacing: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 8
        case .medium, .large: return 12
        case .xLarge, .xxLarge: return 16
        default: return 20
        }
    }

    private var illustrationBackgroundSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 80
        case .medium, .large: return 100
        case .xLarge, .xxLarge: return 120
        default: return 140
        }
    }

    private var illustrationIconSize: CGFloat {
        illustrationBackgroundSize * 0.4
    }

    private var illustrationBackgroundColor: Color {
        themeManager.color(for: .accent).opacity(0.1)
    }

    private var illustrationIconColor: Color {
        themeManager.color(for: .accent).opacity(0.7)
    }
}

// MARK: - Empty State Action

public struct EmptyStateAction {
    public let title: String
    public let handler: () -> Void
    public let accessibilityLabel: String?

    public init(
        title: String,
        handler: @escaping () -> Void,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.handler = handler
        self.accessibilityLabel = accessibilityLabel
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    /// No document selected state
    public static func noDocument(
        onOpenDocument: @escaping () -> Void,
        onBrowseRecent: (() -> Void)? = nil
    ) -> EmptyStateView {
        var secondaryActions: [EmptyStateAction] = []

        if let onBrowseRecent = onBrowseRecent {
            secondaryActions.append(
                EmptyStateAction(
                    title: "Recent Files",
                    handler: onBrowseRecent,
                    accessibilityLabel: "Browse recently opened files"
                )
            )
        }

        return EmptyStateView(
            title: "No Document Selected",
            message: "Choose a markdown file to begin reading, or open a recent document to continue where you left off.",
            systemImage: "doc.text",
            primaryAction: EmptyStateAction(
                title: "Open Document",
                handler: onOpenDocument,
                accessibilityLabel: "Open a markdown document"
            ),
            secondaryActions: secondaryActions
        )
    }

    /// Search no results state
    public static func noSearchResults(
        query: String,
        onClearSearch: @escaping () -> Void,
        onModifyQuery: (() -> Void)? = nil
    ) -> EmptyStateView {
        var secondaryActions: [EmptyStateAction] = [
            EmptyStateAction(
                title: "Clear Search",
                handler: onClearSearch,
                accessibilityLabel: "Clear the current search"
            )
        ]

        if let onModifyQuery = onModifyQuery {
            secondaryActions.append(
                EmptyStateAction(
                    title: "Modify Search",
                    handler: onModifyQuery,
                    accessibilityLabel: "Modify search parameters"
                )
            )
        }

        return EmptyStateView(
            title: "No Results Found",
            message: "No matches found for \"\(query)\". Try adjusting your search terms or check the spelling.",
            systemImage: "magnifyingglass",
            secondaryActions: secondaryActions
        )
    }

    /// Document loading failed state
    public static func documentLoadFailed(
        onRetry: @escaping () -> Void,
        onChooseAnother: @escaping () -> Void
    ) -> EmptyStateView {
        EmptyStateView(
            title: "Document Unavailable",
            message: "The selected document could not be loaded. It may have been moved, deleted, or you may not have permission to access it.",
            systemImage: "doc.badge.exclamationmark",
            primaryAction: EmptyStateAction(
                title: "Try Again",
                handler: onRetry,
                accessibilityLabel: "Retry loading the document"
            ),
            secondaryActions: [
                EmptyStateAction(
                    title: "Choose Another File",
                    handler: onChooseAnother,
                    accessibilityLabel: "Choose a different document"
                )
            ]
        )
    }

    /// No outline available state
    public static func noOutline(
        onRefresh: (() -> Void)? = nil
    ) -> EmptyStateView {
        var actions: [EmptyStateAction] = []

        if let onRefresh = onRefresh {
            actions.append(
                EmptyStateAction(
                    title: "Refresh",
                    handler: onRefresh,
                    accessibilityLabel: "Refresh document outline"
                )
            )
        }

        return EmptyStateView(
            title: "No Outline Available",
            message: "This document doesn't contain any headings that can be used to generate an outline.",
            systemImage: "list.bullet",
            secondaryActions: actions
        )
    }

    /// Network unavailable state
    public static func networkUnavailable(
        onRetry: @escaping () -> Void,
        onWorkOffline: (() -> Void)? = nil
    ) -> EmptyStateView {
        var secondaryActions: [EmptyStateAction] = []

        if let onWorkOffline = onWorkOffline {
            secondaryActions.append(
                EmptyStateAction(
                    title: "Work Offline",
                    handler: onWorkOffline,
                    accessibilityLabel: "Continue working offline"
                )
            )
        }

        return EmptyStateView(
            title: "No Internet Connection",
            message: "Some features require an internet connection. Check your connection and try again.",
            systemImage: "wifi.exclamationmark",
            primaryAction: EmptyStateAction(
                title: "Try Again",
                handler: onRetry,
                accessibilityLabel: "Retry network connection"
            ),
            secondaryActions: secondaryActions
        )
    }

    /// First time user state
    public static func welcome(
        onGetStarted: @escaping () -> Void,
        onLearnMore: (() -> Void)? = nil
    ) -> EmptyStateView {
        var secondaryActions: [EmptyStateAction] = []

        if let onLearnMore = onLearnMore {
            secondaryActions.append(
                EmptyStateAction(
                    title: "Learn More",
                    handler: onLearnMore,
                    accessibilityLabel: "Learn more about the app"
                )
            )
        }

        return EmptyStateView(
            title: "Welcome to Markdown Reader",
            message: "Enjoy a beautiful, accessible reading experience for your markdown documents with advanced features like search, themes, and navigation.",
            systemImage: "sparkles",
            primaryAction: EmptyStateAction(
                title: "Get Started",
                handler: onGetStarted,
                accessibilityLabel: "Get started with the app"
            ),
            secondaryActions: secondaryActions
        )
    }
}

// MARK: - Preview

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            EmptyStateView.noDocument(
                onOpenDocument: {},
                onBrowseRecent: {}
            )
            .tabItem { Label("No Document", systemImage: "doc") }

            EmptyStateView.noSearchResults(
                query: "test query",
                onClearSearch: {},
                onModifyQuery: {}
            )
            .tabItem { Label("No Results", systemImage: "magnifyingglass") }

            EmptyStateView.welcome(
                onGetStarted: {},
                onLearnMore: {}
            )
            .tabItem { Label("Welcome", systemImage: "sparkles") }
        }
    }
}
#endif

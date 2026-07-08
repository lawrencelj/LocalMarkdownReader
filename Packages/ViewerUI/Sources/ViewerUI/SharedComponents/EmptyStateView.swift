// EmptyStateView - Contextual empty state display with guidance

import SwiftUI

/// Contextual empty state display with action guidance
public struct EmptyStateView: View {
    public let title: String
    public let message: String
    public let systemImage: String
    public let primaryAction: EmptyStateAction?
    public let secondaryActions: [EmptyStateAction]

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

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if let primaryAction = primaryAction {
                    Button(primaryAction.title) {
                        primaryAction.handler()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                ForEach(secondaryActions.indices, id: \.self) { index in
                    Button(secondaryActions[index].title) {
                        secondaryActions[index].handler()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: 350, maxHeight: .infinity)
        .padding(40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Empty state: \(title)")
    }
}

// MARK: - Empty State Action

public struct EmptyStateAction {
    public let title: String
    public let handler: () -> Void
    public let accessibilityLabel: String?

    public init(title: String, handler: @escaping () -> Void, accessibilityLabel: String? = nil) {
        self.title = title
        self.handler = handler
        self.accessibilityLabel = accessibilityLabel
    }
}

// MARK: - Predefined Empty States

public extension EmptyStateView {
    static func noDocument(
        onOpenDocument: @escaping () -> Void,
        onBrowseRecent: (() -> Void)? = nil
    ) -> EmptyStateView {
        var secondaryActions: [EmptyStateAction] = []
        if let onBrowseRecent = onBrowseRecent {
            secondaryActions.append(EmptyStateAction(title: "Recent Files", handler: onBrowseRecent))
        }
        return EmptyStateView(
            title: "No Document Selected",
            message: "Choose a markdown file to begin reading.",
            systemImage: "doc.text",
            primaryAction: EmptyStateAction(title: "Open Document", handler: onOpenDocument),
            secondaryActions: secondaryActions
        )
    }

    static func noSearchResults(
        query: String,
        onClearSearch: @escaping () -> Void,
        onModifyQuery: (() -> Void)? = nil
    ) -> EmptyStateView {
        EmptyStateView(
            title: "No Results Found",
            message: "No matches found for \"\(query)\".",
            systemImage: "magnifyingglass",
            secondaryActions: [EmptyStateAction(title: "Clear Search", handler: onClearSearch)]
        )
    }
}

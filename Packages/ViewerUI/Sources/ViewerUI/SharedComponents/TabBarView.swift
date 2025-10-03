/// TabBarView - Multi-tab document navigation UI
///
/// Displays a horizontal tab bar with tab switching, closing, and creation
/// functionality. Supports keyboard navigation and accessibility.

import MarkdownCore
import SwiftUI

/// Tab bar component for multi-document navigation
public struct TabBarView: View {
    @Bindable var tabState: TabState
    let onNewTab: () -> Void

    @State private var hoveredTabId: UUID?

    public init(tabState: TabState, onNewTab: @escaping () -> Void) {
        self.tabState = tabState
        self.onNewTab = onNewTab
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Tab bar scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabState.tabs) { tab in
                        DocumentTabView(
                            tab: tab,
                            isActive: tab.id == tabState.activeTabId,
                            isHovered: tab.id == hoveredTabId,
                            onSelect: {
                                tabState.switchToTab(tab.id)
                            },
                            onClose: {
                                tabState.closeTab(tab.id)
                            }
                        )
                        .onHover { hovering in
                            hoveredTabId = hovering ? tab.id : nil
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // New tab button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Open new document (⌘T)")
        }
        .background(Color.systemBackground.opacity(0.95))
        .frame(height: 36)
        .overlay(
            Rectangle()
                .fill(Color.separator)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

/// Individual document tab view
struct DocumentTabView: View {
    let tab: TabItem
    let isActive: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isCloseHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Tab title
                Text(tab.shortTitle)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isCloseHovered ? .primary : .secondary.opacity(0.7))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isCloseHovered = hovering
                }
                .help("Close tab")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tabBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .accessibilityLabel("Tab: \(tab.title)")
        .accessibilityHint(isActive ? "Currently active tab" : "Tap to switch to this tab")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var tabBackground: some View {
        Group {
            if isActive {
                Color.accentColor.opacity(0.15)
            } else if isHovered {
                Color.secondary.opacity(0.1)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Preview Support

#Preview("Tab Bar - Multiple Tabs") {
    VStack(spacing: 0) {
        TabBarView(
            tabState: TabState.preview,
            onNewTab: { print("New tab") }
        )

        Spacer()
    }
}

#Preview("Tab Bar - Single Tab") {
    VStack(spacing: 0) {
        TabBarView(
            tabState: TabState.previewSingle,
            onNewTab: { print("New tab") }
        )

        Spacer()
    }
}

#Preview("Tab Bar - Empty") {
    VStack(spacing: 0) {
        TabBarView(
            tabState: TabState.previewEmpty,
            onNewTab: { print("New tab") }
        )

        Spacer()
    }
}

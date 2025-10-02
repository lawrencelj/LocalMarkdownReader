/// OutlineItemView - Individual outline item with expansion and navigation
///
/// Displays individual heading items in the navigation sidebar with
/// proper hierarchy indication, expansion controls, and accessibility support.

import Search
import SwiftUI

/// Individual outline item view with hierarchy and interaction support
struct OutlineItemView: View {
    // MARK: - Properties

    let item: OutlineItem
    let isExpanded: Bool
    let isSelected: Bool
    let onToggleExpansion: () -> Void
    let onSelect: () -> Void

    // MARK: - Environment

    @Environment(\.platform) private var platform
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var isHovered = false

    // MARK: - View Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainItemView

            if isExpanded && !item.children.isEmpty {
                childrenView
            }
        }
    }

    // MARK: - Main Item View

    private var mainItemView: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Indentation for hierarchy
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: indentationWidth)

                // Expansion indicator
                if !item.children.isEmpty {
                    Button(action: onToggleExpansion) {
                        Image(systemName: expansionIcon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(expansionAccessibilityLabel)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 16)
                }

                // Heading level indicator
                levelIndicator

                // Heading text
                Text(item.title)
                    .font(headingFont)
                    .fontWeight(headingWeight)
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                // Word count badge (optional)
                if item.wordCount > 0 && dynamicTypeSize <= .large {
                    Text("\(item.wordCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.systemGray5)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, itemVerticalPadding)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(accessibilityTraits)
        .accessibilityAction(.default) {
            onSelect()
        }
        .accessibilityAction(named: "Toggle Section") {
            if !item.children.isEmpty {
                onToggleExpansion()
            }
        }
    }

    // MARK: - Children View

    @ViewBuilder
    private var childrenView: some View {
        LazyVStack(spacing: 0) {
            ForEach(item.children, id: \.id) { child in
                OutlineItemView(
                    item: child,
                    isExpanded: false, // Children expansion handled at higher level
                    isSelected: false, // Selection handled at higher level
                    onToggleExpansion: { },
                    onSelect: { onSelect() }
                )
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
            removal: .opacity
        ))
    }

    // MARK: - Level Indicator

    @ViewBuilder
    private var levelIndicator: some View {
        Circle()
            .fill(levelColor)
            .frame(width: levelIndicatorSize, height: levelIndicatorSize)
            .overlay(
                Text("\(item.level)")
                    .font(.system(size: levelTextSize, weight: .medium, design: .rounded))
                    .foregroundStyle(levelTextColor)
            )
            .accessibilityHidden(true)
    }

    // MARK: - Computed Properties

    private var indentationWidth: CGFloat {
        CGFloat(max(0, item.level - 1)) * 16
    }

    private var itemVerticalPadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 6
        case .medium, .large:
            return 8
        case .xLarge, .xxLarge:
            return 10
        default: // Accessibility sizes
            return 12
        }
    }

    private var expansionIcon: String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    private var expansionAccessibilityLabel: String {
        isExpanded ? "Collapse section" : "Expand section"
    }

    private var headingFont: Font {
        switch item.level {
        case 1:
            return .system(.body, weight: .semibold)
        case 2:
            return .system(.callout, weight: .medium)
        case 3, 4:
            return .system(.callout)
        default:
            return .system(.caption, weight: .medium)
        }
    }

    private var headingWeight: Font.Weight {
        switch item.level {
        case 1: return .semibold
        case 2: return .medium
        default: return .regular
        }
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            switch item.level {
            case 1: return .primary
            case 2: return .primary
            default: return .secondary
            }
        }
    }

    private var backgroundFill: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor)
        } else if isHovered && platform.supportsCursor {
            return AnyShapeStyle(Color.systemGray5)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    private var levelColor: Color {
        switch item.level {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        case 5: return .pink
        default: return .gray
        }
    }

    private var levelIndicatorSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 16
        case .medium, .large:
            return 18
        case .xLarge, .xxLarge:
            return 20
        default: // Accessibility sizes
            return 22
        }
    }

    private var levelTextSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 9
        case .medium, .large:
            return 10
        case .xLarge, .xxLarge:
            return 11
        default: // Accessibility sizes
            return 12
        }
    }

    private var levelTextColor: Color {
        isSelected ? .white : .white
    }

    private var accessibilityLabel: String {
        "Heading level \(item.level): \(item.title)"
    }

    private var accessibilityValue: String {
        var value = ""

        if !item.children.isEmpty {
            value += isExpanded ? "Expanded" : "Collapsed"
        }

        if item.wordCount > 0 {
            if !value.isEmpty { value += ", " }
            value += "\(item.wordCount) words"
        }

        return value.isEmpty ? "" : value
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = [.isButton]

        if isSelected {
            _ = traits.insert(.isSelected)
        }

        if !item.children.isEmpty {
            _ = traits.insert(.updatesFrequently)
        }

        return traits
    }
}

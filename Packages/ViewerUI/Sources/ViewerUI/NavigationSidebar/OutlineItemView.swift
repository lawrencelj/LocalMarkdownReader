// OutlineItemView - Individual outline item with expansion and navigation

import Search
import SwiftUI

/// Individual outline item view with hierarchy and interaction support
struct OutlineItemView: View {
    let item: OutlineItem
    let isExpanded: Bool
    let isSelected: Bool
    let onToggleExpansion: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainItemButton
            if isExpanded && !item.children.isEmpty {
                childrenList
            }
        }
    }

    private var mainItemButton: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Spacer()
                    .frame(width: CGFloat(max(0, item.level - 1)) * 16)

                expansionButton

                Text(item.title)
                    .font(item.level <= 2 ? .body : .callout)
                    .fontWeight(item.level == 1 ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Heading level \(item.level): \(item.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder private var expansionButton: some View {
        if !item.children.isEmpty {
            Button(action: onToggleExpansion) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        } else {
            Spacer().frame(width: 16, height: 16)
        }
    }

    private var childrenList: some View {
        VStack(spacing: 0) {
            ForEach(item.children, id: \.id) { child in
                OutlineItemView(
                    item: child,
                    isExpanded: false,
                    isSelected: false,
                    onToggleExpansion: {},
                    onSelect: onSelect
                )
            }
        }
    }

    @ViewBuilder private var backgroundFill: some View {
        if isSelected {
            Color.accentColor
        } else {
            Color.clear
        }
    }
}

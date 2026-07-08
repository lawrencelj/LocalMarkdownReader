// SearchResultView - Individual search result with context preview

import Search
import SwiftUI

/// Individual search result view with context and highlighting
struct SearchResultView: View {
    let result: SearchResult
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                resultHeader
                contextText
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search result \(index + 1): \(result.text)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var resultHeader: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(isSelected ? Color.orange : Color.accentColor))

            Text(result.matchType.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if result.lineNumber > 0 {
                Text("Line \(result.lineNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contextText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.text)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)

            if !result.context.isEmpty {
                Text(result.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let heading = result.headingContext {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(heading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

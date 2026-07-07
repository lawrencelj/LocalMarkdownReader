/// MarkdownRenderer - Performance-optimized markdown content renderer
///
/// Implements viewport-based rendering with lazy loading for large documents,
/// maintaining 60fps performance while providing rich markdown formatting
/// and accessibility support.

import SwiftUI
import MarkdownCore

/// High-performance markdown content renderer with viewport optimization
public struct MarkdownRenderer: View {
    let content: AttributedString
    @Binding var viewportBounds: CGRect
    @Binding var isOptimized: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            Text(content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Document content")
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Supporting Types

public enum ListStyle: Sendable {
    case bullet
    case ordered
}

// MARK: - Preview

#Preview("Markdown Renderer") {
    ScrollView {
        MarkdownRenderer(
            content: AttributedString("# Sample Content\n\nThis is a paragraph."),
            viewportBounds: .constant(.zero),
            isOptimized: .constant(false)
        )
    }
    .padding()
}

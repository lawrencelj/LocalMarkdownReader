// MarkdownRenderingTypes - Supporting types for the MarkdownRenderer

import MarkdownCore
import SwiftUI

// MARK: - Markdown Element

/// Represents a single renderable markdown element
public struct MarkdownElement: Identifiable, Sendable {
    public let id: String
    public let type: ElementType
    public let plainText: String

    public init(id: String = UUID().uuidString, type: ElementType, plainText: String) {
        self.id = id
        self.type = type
        self.plainText = plainText
    }

    public enum ElementType: Sendable {
        case heading(level: Int)
        case paragraph
        case codeBlock(language: String?)
        case list(style: ListStyle)
        case blockquote
        case table
        case horizontalRule
        case image
    }
}

// MARK: - Rendered Section

public struct RenderedSection: Identifiable, Sendable {
    public let id: String
    public let elements: [MarkdownElement]
    public let estimatedHeight: CGFloat
    public let accessibilityLabel: String

    public init(
        id: String = UUID().uuidString,
        elements: [MarkdownElement],
        estimatedHeight: CGFloat,
        accessibilityLabel: String
    ) {
        self.id = id
        self.elements = elements
        self.estimatedHeight = estimatedHeight
        self.accessibilityLabel = accessibilityLabel
    }
}

// MARK: - Markdown Content Processor

public actor MarkdownContentProcessor {
    public static func process(_ content: AttributedString) async -> [RenderedSection] {
        let plainText = String(content.characters)
        guard !plainText.isEmpty else { return [] }

        let paragraphs = plainText.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        var sections: [RenderedSection] = []

        let batchSize = 10
        for batchStart in stride(from: 0, to: paragraphs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, paragraphs.count)
            let batch = paragraphs[batchStart ..< batchEnd]

            let elements = batch.map { text -> MarkdownElement in
                MarkdownElement(type: .paragraph, plainText: text)
            }

            let section = RenderedSection(
                elements: elements,
                estimatedHeight: CGFloat(elements.count) * 40.0,
                accessibilityLabel: elements.map(\.plainText).joined(separator: " ").prefix(200).description
            )
            sections.append(section)
        }

        return sections
    }
}

// MARK: - Performance Metrics

public actor PerformanceMetrics {
    public static let shared = PerformanceMetrics()
    private init() {}

    public func recordFrameRate() {}
    public func recordMemoryUsage() {}
}

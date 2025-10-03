/// MarkdownTypes - Type definitions for markdown rendering
///
/// Provides type definitions needed for markdown content rendering,
/// including rendered sections, elements, and rendering state management.

import Foundation
import SwiftUI

// MARK: - Rendered Section

/// Represents a rendered section of markdown content for viewport optimization
public struct RenderedSection: Identifiable {
    public let id: String
    public let range: NSRange
    public let content: AttributedString
    public let estimatedHeight: CGFloat
    public let renderingPriority: RenderingPriority
    public let lineRange: Range<Int>

    public init(
        id: String,
        range: NSRange,
        content: AttributedString,
        estimatedHeight: CGFloat = 0,
        renderingPriority: RenderingPriority = .normal,
        lineRange: Range<Int> = 0..<0
    ) {
        self.id = id
        self.range = range
        self.content = content
        self.estimatedHeight = estimatedHeight
        self.renderingPriority = renderingPriority
        self.lineRange = lineRange
    }
}

/// Rendering priority for viewport optimization
public enum RenderingPriority: Int, Comparable {
    case high = 3
    case normal = 2
    case low = 1
    case deferred = 0

    public static func < (lhs: RenderingPriority, rhs: RenderingPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Markdown Element

/// Represents a markdown element for structured rendering
public struct MarkdownElement: Identifiable {
    public let id: String
    public let type: ElementType
    public let content: String
    public let attributes: [String: Any]
    public let children: [MarkdownElement]?
    public let range: NSRange

    public init(
        id: String = UUID().uuidString,
        type: ElementType,
        content: String,
        attributes: [String: Any] = [:],
        children: [MarkdownElement]? = nil,
        range: NSRange = NSRange(location: 0, length: 0)
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.attributes = attributes
        self.children = children
        self.range = range
    }

    /// Element type classification
    public enum ElementType {
        case text
        case heading(level: Int)
        case paragraph
        case list(style: ListStyle)
        case listItem
        case codeBlock(language: String?)
        case inlineCode
        case blockquote
        case table
        case tableRow
        case tableCell
        case image(url: String?)
        case link(url: String?)
        case emphasis
        case strong
        case lineBreak
        case horizontalRule
        case custom(String)
    }
}

/// List styling options
public enum ListStyle {
    case unordered
    case ordered(start: Int = 1)

    public var isOrdered: Bool {
        switch self {
        case .ordered:
            return true
        case .unordered:
            return false
        }
    }

    public var startNumber: Int {
        switch self {
        case .ordered(let start):
            return start
        case .unordered:
            return 1
        }
    }
}

// MARK: - Element Extensions

extension MarkdownElement {
    /// Whether this element has child elements
    public var hasChildren: Bool {
        children?.isEmpty == false
    }

    /// Flattened list of all descendant elements
    public var allDescendants: [MarkdownElement] {
        var descendants: [MarkdownElement] = []

        if let children = children {
            for child in children {
                descendants.append(child)
                descendants.append(contentsOf: child.allDescendants)
            }
        }

        return descendants
    }

    /// Find first child element of specified type
    public func firstChild(ofType type: ElementType) -> MarkdownElement? {
        children?.first { $0.type == type }
    }

    /// Find all child elements of specified type
    public func children(ofType type: ElementType) -> [MarkdownElement] {
        children?.filter { $0.type == type } ?? []
    }
}

// MARK: - Element Type Equality

extension MarkdownElement.ElementType: Equatable {
    public static func == (lhs: MarkdownElement.ElementType, rhs: MarkdownElement.ElementType) -> Bool {
        switch (lhs, rhs) {
        case (.text, .text),
             (.paragraph, .paragraph),
             (.listItem, .listItem),
             (.inlineCode, .inlineCode),
             (.blockquote, .blockquote),
             (.table, .table),
             (.tableRow, .tableRow),
             (.tableCell, .tableCell),
             (.emphasis, .emphasis),
             (.strong, .strong),
             (.lineBreak, .lineBreak),
             (.horizontalRule, .horizontalRule):
            return true
        case (.heading(let level1), .heading(let level2)):
            return level1 == level2
        case (.list(let style1), .list(let style2)):
            return style1 == style2
        case (.codeBlock(let lang1), .codeBlock(let lang2)):
            return lang1 == lang2
        case (.image(let url1), .image(let url2)):
            return url1 == url2
        case (.link(let url1), .link(let url2)):
            return url1 == url2
        case (.custom(let name1), .custom(let name2)):
            return name1 == name2
        default:
            return false
        }
    }
}

extension ListStyle: Equatable {
    public static func == (lhs: ListStyle, rhs: ListStyle) -> Bool {
        switch (lhs, rhs) {
        case (.unordered, .unordered):
            return true
        case (.ordered(let start1), .ordered(let start2)):
            return start1 == start2
        default:
            return false
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension RenderedSection {
    /// Create preview rendered sections for development
    public static var previewSections: [RenderedSection] {
        [
            RenderedSection(
                id: "section-1",
                range: NSRange(location: 0, length: 50),
                content: AttributedString("# Sample Document\n\nThis is a sample markdown document."),
                estimatedHeight: 120,
                renderingPriority: .high,
                lineRange: 0..<6
            ),
            RenderedSection(
                id: "section-2",
                range: NSRange(location: 50, length: 100),
                content: AttributedString("## Features\n\n- Feature 1\n- Feature 2\n- Feature 3"),
                estimatedHeight: 180,
                renderingPriority: .normal,
                lineRange: 6..<12
            )
        ]
    }
}

extension MarkdownElement {
    /// Create preview markdown elements for development
    public static var previewElements: [MarkdownElement] {
        [
            MarkdownElement(
                type: .heading(level: 1),
                content: "Sample Document",
                range: NSRange(location: 0, length: 15)
            ),
            MarkdownElement(
                type: .paragraph,
                content: "This is a sample paragraph with some content.",
                range: NSRange(location: 16, length: 45)
            ),
            MarkdownElement(
                type: .list(style: .unordered),
                content: "",
                children: [
                    MarkdownElement(type: .listItem, content: "Item 1"),
                    MarkdownElement(type: .listItem, content: "Item 2"),
                    MarkdownElement(type: .listItem, content: "Item 3")
                ]
            )
        ]
    }
}
#endif

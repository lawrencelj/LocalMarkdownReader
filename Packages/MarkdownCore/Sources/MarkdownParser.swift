/// MarkdownParser - Core markdown parsing engine
///
/// High-performance markdown parser using swift-markdown with
/// CommonMark compliance and GitHub Flavored Markdown extensions.
/// Optimized for large documents with streaming and background processing.

import Foundation
@preconcurrency import Markdown
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// High-performance markdown parser with security validation
public actor MarkdownParser {
    /// Maximum document size in bytes (2MB default)
    public static let maxDocumentSize: Int64 = 2 * 1024 * 1024

    /// Parser configuration
    public struct Configuration: Sendable {
        public let enableGitHubFlavoredMarkdown: Bool
        public let enableTableExtensions: Bool
        public let enableStrikethroughExtensions: Bool
        public let enableTaskListExtensions: Bool
        public let enableMathExtensions: Bool
        public let maxNestingLevel: Int
        public let enableSecurityValidation: Bool
        public let allowUnsafeHTML: Bool

        public init(
            enableGitHubFlavoredMarkdown: Bool = true,
            enableTableExtensions: Bool = true,
            enableStrikethroughExtensions: Bool = true,
            enableTaskListExtensions: Bool = true,
            enableMathExtensions: Bool = false,
            maxNestingLevel: Int = 16,
            enableSecurityValidation: Bool = true,
            allowUnsafeHTML: Bool = false
        ) {
            self.enableGitHubFlavoredMarkdown = enableGitHubFlavoredMarkdown
            self.enableTableExtensions = enableTableExtensions
            self.enableStrikethroughExtensions = enableStrikethroughExtensions
            self.enableTaskListExtensions = enableTaskListExtensions
            self.enableMathExtensions = enableMathExtensions
            self.maxNestingLevel = maxNestingLevel
            self.enableSecurityValidation = enableSecurityValidation
            self.allowUnsafeHTML = allowUnsafeHTML
        }

        public static let `default` = Configuration()
        public static let secure = Configuration(allowUnsafeHTML: false)
        public static let permissive = Configuration(enableSecurityValidation: false, allowUnsafeHTML: true)
    }

    private let configuration: Configuration
    private let validator: ValidationEngine
    private let performanceMonitor: PerformanceMonitor

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.validator = ValidationEngine(configuration: configuration)
        self.performanceMonitor = PerformanceMonitor.shared
    }

    // MARK: - Main Parsing Interface

    /// Parse markdown content to DocumentModel
    public func parseDocument(content: String, reference: DocumentReference) async throws -> DocumentModel {
        try await performanceMonitor.trackOperation("parse_document") {
            // Validate input
            try await validator.validateContent(content)

            // Parse markdown to attributed string
            let attributedContent = try await parseToAttributedString(content)

            // Extract metadata
            let metadata = try await extractMetadata(from: content, reference: reference)

            // Extract outline
            let outline = try await extractOutline(from: content)

            return DocumentModel(
                reference: reference,
                content: content,
                attributedContent: attributedContent,
                metadata: metadata,
                outline: outline
            )
        }
    }

    /// Parse markdown content to AttributedString
    public func parseToAttributedString(_ content: String) async throws -> AttributedString {
        guard !content.isEmpty else {
            return AttributedString()
        }

        // Security validation
        if configuration.enableSecurityValidation {
            try await validator.validateContent(content)
        }

        // Parse using swift-markdown
        let document = Document(parsing: content, options: buildParsingOptions())

        // Convert to AttributedString with custom renderer
        let renderer = AttributedStringRenderer(configuration: configuration)
        return renderer.render(document)
    }

    /// Extract document outline (headings)
    public func extractOutline(from content: String) async throws -> [HeadingItem] {
        try await performanceMonitor.trackOperation("extract_outline") {
            let document = Document(parsing: content, options: buildParsingOptions())
            let extractor = ContentExtractor()
            return try await extractor.extractHeadings(from: document, content: content)
        }
    }

    /// Extract document metadata
    public func extractMetadata(from content: String, reference: DocumentReference) async throws -> DocumentMetadata {
        try await performanceMonitor.trackOperation("extract_metadata") {
            let document = Document(parsing: content, options: buildParsingOptions())
            let extractor = ContentExtractor()
            return try await extractor.extractMetadata(from: document, content: content, reference: reference)
        }
    }

    // MARK: - Private Implementation

    nonisolated private func buildParsingOptions() -> ParseOptions {
        var options = ParseOptions()

        if configuration.enableGitHubFlavoredMarkdown {
            options.insert(.parseBlockDirectives)
            options.insert(.parseSymbolLinks)
        }

        return options
    }
}

/// AttributedString renderer with styling support
private struct AttributedStringRenderer {
    private let configuration: MarkdownParser.Configuration

    init(configuration: MarkdownParser.Configuration) {
        self.configuration = configuration
    }

    func render(_ document: Document) -> AttributedString {
        var result = AttributedString()

        for child in document.children {
            result.append(renderMarkup(child))
        }

        return result
    }

    private func renderMarkup(_ markup: Markup) -> AttributedString {
        switch markup {
        case let heading as Heading:
            return renderHeading(heading)
        case let paragraph as Paragraph:
            return renderParagraph(paragraph)
        case let codeBlock as CodeBlock:
            return renderCodeBlock(codeBlock)
        case let list as Markdown.UnorderedList:
            return renderList(list)
        case let list as Markdown.OrderedList:
            return renderList(list)
        case let blockQuote as BlockQuote:
            return renderBlockQuote(blockQuote)
        case let table as Table:
            return renderTable(table)
        default:
            return renderGeneric(markup)
        }
    }

    private func renderHeading(_ heading: Heading) -> AttributedString {
        var result = AttributedString()

        for child in heading.children {
            result.append(renderInline(child))
        }

        // Apply heading styling
        let fontSize: CGFloat = switch heading.level {
        case 1: 24
        case 2: 20
        case 3: 18
        case 4: 16
        case 5: 14
        case 6: 12
        default: 16
        }

        result.font = .systemFont(ofSize: fontSize, weight: .bold)
        result.append(AttributedString("\n\n"))

        return result
    }

    private func renderParagraph(_ paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()

        for child in paragraph.children {
            result.append(renderInline(child))
        }

        result.append(AttributedString("\n\n"))
        return result
    }

    private func renderCodeBlock(_ codeBlock: CodeBlock) -> AttributedString {
        var result = AttributedString(codeBlock.code)

        // Apply code styling
        result.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        result.backgroundColor = NSColor.controlBackgroundColor
        result.foregroundColor = NSColor.controlTextColor

        // Add language hint if available
        if let language = codeBlock.language, !language.isEmpty {
            var header = AttributedString("[\(language)]\n")
            header.font = .systemFont(ofSize: 12, weight: .medium)
            header.foregroundColor = NSColor.secondaryLabelColor
            result = header + result
        }

        result.append(AttributedString("\n\n"))
        return result
    }

    private func renderList(_ list: Markup) -> AttributedString {
        var result = AttributedString()

        for (index, item) in list.children.enumerated() {
            if let listItem = item as? ListItem {
                // Add bullet or number
                let prefix = list is Markdown.OrderedList ? "\(index + 1). " : "• "
                result.append(AttributedString(prefix))

                for child in listItem.children {
                    result.append(renderMarkup(child))
                }
            }
        }

        result.append(AttributedString("\n"))
        return result
    }

    private func renderBlockQuote(_ blockQuote: BlockQuote) -> AttributedString {
        var result = AttributedString()

        for child in blockQuote.children {
            result.append(renderMarkup(child))
        }

        // Apply blockquote styling
        result.foregroundColor = NSColor.secondaryLabelColor

        // Add quote prefix
        let lines = result.characters.split(separator: "\n")
        var quotedResult = AttributedString()

        for line in lines {
            quotedResult.append(AttributedString("> "))
            quotedResult.append(AttributedString(String(line)))
            quotedResult.append(AttributedString("\n"))
        }

        quotedResult.append(AttributedString("\n"))
        return quotedResult
    }

    private func renderTable(_ table: Table) -> AttributedString {
        var result = AttributedString()

        // Simplified table rendering
        for row in table.children {
            if let tableRow = row as? Table.Row {
                for cell in tableRow.children {
                    if let tableCell = cell as? Table.Cell {
                        for child in tableCell.children {
                            result.append(renderInline(child))
                        }
                        result.append(AttributedString(" | "))
                    }
                }
                result.append(AttributedString("\n"))
            }
        }

        result.append(AttributedString("\n"))
        return result
    }

    private func renderInline(_ markup: Markup) -> AttributedString {
        switch markup {
        case let text as Text:
            return AttributedString(text.string)
        case let emphasis as Emphasis:
            var result = AttributedString()
            for child in emphasis.children {
                result.append(renderInline(child))
            }
            result.font = .systemFont(ofSize: 16, weight: .regular).italic()
            return result
        case let strong as Strong:
            var result = AttributedString()
            for child in strong.children {
                result.append(renderInline(child))
            }
            result.font = .systemFont(ofSize: 16, weight: .bold)
            return result
        case let code as InlineCode:
            var result = AttributedString(code.code)
            result.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            result.backgroundColor = NSColor.controlBackgroundColor
            return result
        case let link as Link:
            var result = AttributedString()
            for child in link.children {
                result.append(renderInline(child))
            }
            result.foregroundColor = NSColor.linkColor
            result.underlineStyle = .single
            if let destination = link.destination {
                result.link = URL(string: destination)
            }
            return result
        default:
            return renderGeneric(markup)
        }
    }

    private func renderGeneric(_ markup: Markup) -> AttributedString {
        var result = AttributedString()

        for child in markup.children {
            if child is BlockMarkup {
                result.append(renderMarkup(child))
            } else if child is InlineMarkup {
                result.append(renderInline(child))
            }
        }

        return result
    }
}

// MARK: - Extensions

#if canImport(UIKit)
extension UIFont {
    func italic() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.traitItalic) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#endif

#if canImport(AppKit)
extension NSFont {
    func italic() -> NSFont {
        #if os(macOS)
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
        #else
        return self
        #endif
    }
}

#if os(macOS)
import AppKit
typealias NSColor = AppKit.NSColor
#else
import UIKit
typealias NSColor = UIKit.UIColor
#endif
#endif

/// ContentExtractor - Metadata and outline extraction
///
/// Extracts metadata, outline, and structural information from
/// markdown documents for navigation and analysis purposes.

import Foundation
import Markdown

/// Content extraction engine for document analysis
public struct ContentExtractor {
    /// Extract document outline from parsed markdown
    public func extractHeadings(from document: Document, content: String) async throws -> [HeadingItem] {
        var headings: [HeadingItem] = []
        let lines = content.components(separatedBy: .newlines)
        var currentPosition: CGFloat = 0
        let lineHeight: CGFloat = 20 // Approximate line height

        for markup in document.children {
            let extractedHeadings = try await extractHeadingsRecursive(markup, lines: lines, currentPosition: &currentPosition, lineHeight: lineHeight)
            headings.append(contentsOf: extractedHeadings)
        }

        return buildHeadingHierarchy(headings)
    }

    /// Extract comprehensive document metadata
    public func extractMetadata(from document: Document, content: String, reference: DocumentReference) async throws -> DocumentMetadata {
        let lines = content.components(separatedBy: .newlines)

        // Extract title
        let title = extractTitle(from: document)

        // Count statistics using proper markdown-aware counting
        let wordCount = countWords(in: document)
        let characterCount = content.count
        let lineCount = lines.count
        let estimatedReadingTime = DocumentMetadata.calculateReadingTime(wordCount: wordCount)

        // Analyze content features
        let features = try await analyzeContentFeatures(document)

        // Extract language hints from code blocks
        let languageHints = extractLanguageHints(from: document)

        return DocumentMetadata(
            title: title,
            wordCount: wordCount,
            characterCount: characterCount,
            lineCount: lineCount,
            estimatedReadingTime: estimatedReadingTime,
            lastModified: reference.lastModified,
            fileSize: reference.fileSize,
            encodingName: "UTF-8",
            hasImages: features.hasImages,
            hasTables: features.hasTables,
            hasCodeBlocks: features.hasCodeBlocks,
            languageHints: languageHints
        )
    }

    // MARK: - Private Implementation

    private func extractHeadingsRecursive(
        _ markup: Markup,
        lines: [String],
        currentPosition: inout CGFloat,
        lineHeight: CGFloat
    ) async throws -> [HeadingItem] {
        var headings: [HeadingItem] = []

        if let heading = markup as? Heading {
            let title = extractTextContent(from: heading)
            let range = calculateRange(for: heading, in: lines)

            let headingItem = HeadingItem(
                level: heading.level,
                title: title,
                range: range,
                position: currentPosition
            )

            headings.append(headingItem)
            currentPosition += lineHeight * CGFloat(title.components(separatedBy: .newlines).count)
        } else {
            // Calculate position for non-heading content
            let textContent = extractTextContent(from: markup)
            let contentLines = textContent.components(separatedBy: .newlines).count
            currentPosition += lineHeight * CGFloat(contentLines)
        }

        // Recursively process children
        for child in markup.children {
            let childHeadings = try await extractHeadingsRecursive(child, lines: lines, currentPosition: &currentPosition, lineHeight: lineHeight)
            headings.append(contentsOf: childHeadings)
        }

        return headings
    }

    private func extractTitle(from document: Document) -> String? {
        // Look for the first H1 heading
        for markup in document.children {
            if let heading = markup as? Heading, heading.level == 1 {
                return extractTextContent(from: heading)
            }
        }

        // If no H1, look for the first heading of any level
        for markup in document.children {
            if let heading = markup as? Heading {
                return extractTextContent(from: heading)
            }
        }

        return nil
    }

    private func extractTextContent(from markup: Markup) -> String {
        var text = ""

        if let textMarkup = markup as? Text {
            return textMarkup.string
        }

        for child in markup.children {
            if let childText = child as? Text {
                text += childText.string
            } else {
                text += extractTextContent(from: child)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func calculateRange(for heading: Heading, in lines: [String]) -> NSRange {
        // Find the heading in the content
        let headingText = extractTextContent(from: heading)
        let headingPrefix = String(repeating: "#", count: heading.level) + " "
        let searchText = headingPrefix + headingText

        var currentLocation = 0
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(searchText) {
                return NSRange(location: currentLocation, length: line.count)
            }
            currentLocation += line.count + 1 // +1 for newline
        }

        // Fallback: return range for the text content
        return NSRange(location: 0, length: headingText.count)
    }

    private func buildHeadingHierarchy(_ flatHeadings: [HeadingItem]) -> [HeadingItem] {
        guard !flatHeadings.isEmpty else { return [] }

        var hierarchy: [HeadingItem] = []
        var stack: [(level: Int, item: HeadingItem)] = []

        for heading in flatHeadings {
            // Remove items from stack that are at the same level or deeper
            while !stack.isEmpty && stack.last!.level >= heading.level {
                stack.removeLast()
            }

            if stack.isEmpty {
                // Top-level heading
                hierarchy.append(heading)
            } else {
                // Child heading - this would require a mutable structure
                // For now, we'll keep the flat structure but with proper hierarchy info
                hierarchy.append(heading)
            }

            stack.append((level: heading.level, item: heading))
        }

        return hierarchy
    }

    private func analyzeContentFeatures(_ document: Document) async throws -> ContentFeatures {
        var hasImages = false
        var hasTables = false
        var hasCodeBlocks = false

        try await analyzeMarkupRecursive(document, features: &hasImages, &hasTables, &hasCodeBlocks)

        return ContentFeatures(
            hasImages: hasImages,
            hasTables: hasTables,
            hasCodeBlocks: hasCodeBlocks
        )
    }

    private func analyzeMarkupRecursive(
        _ markup: Markup,
        features hasImages: inout Bool,
        _ hasTables: inout Bool,
        _ hasCodeBlocks: inout Bool
    ) async throws {
        switch markup {
        case is Image:
            hasImages = true
        case is Table:
            hasTables = true
        case is CodeBlock:
            hasCodeBlocks = true
        default:
            break
        }

        // Recursively analyze children
        for child in markup.children {
            try await analyzeMarkupRecursive(child, features: &hasImages, &hasTables, &hasCodeBlocks)
        }
    }

    private func extractLanguageHints(from document: Document) -> Set<String> {
        var languages: Set<String> = []

        extractLanguagesRecursive(document, languages: &languages)

        return languages
    }

    private func extractLanguagesRecursive(_ markup: Markup, languages: inout Set<String>) {
        if let codeBlock = markup as? CodeBlock,
           let language = codeBlock.language,
           !language.isEmpty {
            languages.insert(language.lowercased())
        }

        for child in markup.children {
            extractLanguagesRecursive(child, languages: &languages)
        }
    }

    /// Count words in document, excluding code blocks and inline code
    private func countWords(in document: Document) -> Int {
        var wordCount = 0
        countWordsRecursive(document, wordCount: &wordCount)
        return wordCount
    }

    private func countWordsRecursive(_ markup: Markup, wordCount: inout Int) {
        // Skip code blocks and inline code
        if markup is CodeBlock || markup is InlineCode {
            return
        }

        // If this is a text node, count its words
        if let text = markup as? Text {
            let words = text.string
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            wordCount += words.count
        }

        // Recursively process children
        for child in markup.children {
            countWordsRecursive(child, wordCount: &wordCount)
        }
    }
}

// MARK: - Supporting Types

private struct ContentFeatures {
    let hasImages: Bool
    let hasTables: Bool
    let hasCodeBlocks: Bool
}

// MARK: - Performance Monitor

/// Performance monitoring for parsing operations
public actor PerformanceMonitor {
    public static let shared = PerformanceMonitor()

    private var operationTimes: [String: [TimeInterval]] = [:]
    private var isMonitoring = false

    private init() {}

    public func initialize() {
        isMonitoring = true
    }

    public func trackOperation<T: Sendable>(_ operationName: String, operation: @Sendable () async throws -> T) async rethrows -> T {
        guard isMonitoring else {
            return try await operation()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        recordOperationTime(operationName, duration: duration)

        return result
    }

    public func trackOperation<T>(_ operationName: String, operation: () throws -> T) rethrows -> T {
        guard isMonitoring else {
            return try operation()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        Task {
            recordOperationTime(operationName, duration: duration)
        }

        return result
    }

    private func recordOperationTime(_ operationName: String, duration: TimeInterval) {
        if operationTimes[operationName] == nil {
            operationTimes[operationName] = []
        }
        operationTimes[operationName]?.append(duration)

        // Keep only the last 100 measurements
        if operationTimes[operationName]!.count > 100 {
            operationTimes[operationName]?.removeFirst()
        }
    }

    public func getAverageTime(for operationName: String) -> TimeInterval? {
        guard let times = operationTimes[operationName], !times.isEmpty else {
            return nil
        }

        return times.reduce(0, +) / Double(times.count)
    }

    public func getOperationStats() -> [String: OperationStats] {
        var stats: [String: OperationStats] = [:]

        for (operation, times) in operationTimes {
            guard !times.isEmpty else { continue }

            let average = times.reduce(0, +) / Double(times.count)
            let min = times.min() ?? 0
            let max = times.max() ?? 0
            let count = times.count

            stats[operation] = OperationStats(
                average: average,
                minimum: min,
                maximum: max,
                sampleCount: count
            )
        }

        return stats
    }

    public func startCoordinatorMonitoring() {
        // Placeholder for future coordinator-specific monitoring
    }
}

public struct OperationStats: Sendable {
    public let average: TimeInterval
    public let minimum: TimeInterval
    public let maximum: TimeInterval
    public let sampleCount: Int

    public init(average: TimeInterval, minimum: TimeInterval, maximum: TimeInterval, sampleCount: Int) {
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.sampleCount = sampleCount
    }
}

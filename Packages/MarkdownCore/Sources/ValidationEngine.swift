/// ValidationEngine - Security validation and input sanitization
///
/// Provides comprehensive security validation for markdown content,
/// preventing XSS attacks, malicious content, and ensuring safe parsing.

import Foundation

/// Security validation engine for markdown content
public actor ValidationEngine {
    /// Validation configuration
    public struct Configuration: Sendable {
        public let maxDocumentSize: Int64
        public let maxNestingLevel: Int
        public let allowUnsafeHTML: Bool
        public let enableScriptTagBlocking: Bool
        public let enableLinkValidation: Bool
        public let allowedProtocols: Set<String>
        public let blockedElements: Set<String>

        public init(
            maxDocumentSize: Int64 = 2 * 1024 * 1024, // 2MB
            maxNestingLevel: Int = 16,
            allowUnsafeHTML: Bool = false,
            enableScriptTagBlocking: Bool = true,
            enableLinkValidation: Bool = true,
            allowedProtocols: Set<String> = ["http", "https", "mailto", "file"],
            blockedElements: Set<String> = ["script", "iframe", "object", "embed", "form"]
        ) {
            self.maxDocumentSize = maxDocumentSize
            self.maxNestingLevel = maxNestingLevel
            self.allowUnsafeHTML = allowUnsafeHTML
            self.enableScriptTagBlocking = enableScriptTagBlocking
            self.enableLinkValidation = enableLinkValidation
            self.allowedProtocols = allowedProtocols
            self.blockedElements = blockedElements
        }
    }

    private let configuration: Configuration

    public init(configuration: MarkdownParser.Configuration) {
        self.configuration = Configuration(
            allowUnsafeHTML: configuration.allowUnsafeHTML,
            enableScriptTagBlocking: configuration.enableSecurityValidation,
            enableLinkValidation: configuration.enableSecurityValidation
        )
    }

    // MARK: - Validation Interface

    /// Validate content asynchronously
    public func validateContent(_ content: String) async throws {
        try await validateSize(content)
        try await validateStructure(content)
        try await validateSecurity(content)
    }

    /// Validate content synchronously (for performance-critical paths)
    public func validateContentSync(_ content: String) throws {
        try validateSizeSync(content)
        try validateSecuritySync(content)
    }

    /// Sanitize content by removing dangerous elements
    public func sanitizeContent(_ content: String) async throws -> String {
        var sanitized = content

        // Remove blocked HTML elements
        if !configuration.allowUnsafeHTML {
            sanitized = try await removeBlockedElements(sanitized)
        }

        // Validate and clean links
        if configuration.enableLinkValidation {
            sanitized = try await validateAndCleanLinks(sanitized)
        }

        // Remove script content
        if configuration.enableScriptTagBlocking {
            sanitized = removeScriptContent(sanitized)
        }

        return sanitized
    }

    // MARK: - Size Validation

    private func validateSize(_ content: String) async throws {
        try validateSizeSync(content)
    }

    private func validateSizeSync(_ content: String) throws {
        let size = Int64(content.utf8.count)
        guard size <= configuration.maxDocumentSize else {
            throw DocumentError.fileTooLarge(maxSize: configuration.maxDocumentSize)
        }
    }

    // MARK: - Structure Validation

    private func validateStructure(_ content: String) async throws {
        try await validateNestingLevel(content)
        try await validateMarkdownSyntax(content)
    }

    private func validateNestingLevel(_ content: String) async throws {
        let lines = content.components(separatedBy: .newlines)
        var currentNesting = 0
        var maxNesting = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check list nesting
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("+") {
                let leadingSpaces = line.prefix { $0 == " " }.count
                currentNesting = leadingSpaces / 2
                maxNesting = max(maxNesting, currentNesting)
            }

            // Check blockquote nesting
            if trimmed.hasPrefix(">") {
                let quoteLevel = trimmed.prefix { $0 == ">" }.count
                maxNesting = max(maxNesting, quoteLevel)
            }
        }

        guard maxNesting <= configuration.maxNestingLevel else {
            throw ValidationError.excessiveNesting(level: maxNesting, max: configuration.maxNestingLevel)
        }
    }

    private func validateMarkdownSyntax(_ content: String) async throws {
        // Basic syntax validation
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            // Check for malformed tables
            if line.contains("|") && !isValidTableRow(line) {
                throw ValidationError.malformedTable(line: index + 1)
            }

            // Check for malformed links - only validate if it looks like a link attempt
            // Pattern: text followed by ] and then (
            if line.contains("](") && !hasValidLinkSyntax(line) {
                throw ValidationError.malformedLink(line: index + 1)
            }
        }
    }

    // MARK: - Security Validation

    private func validateSecurity(_ content: String) async throws {
        try validateSecuritySync(content)
    }

    private func validateSecuritySync(_ content: String) throws {
        // Check for dangerous patterns
        let dangerousPatterns = [
            #"<script[^>]*>.*?</script>"#,
            #"javascript:"#,
            #"data:text/html"#,
            #"vbscript:"#,
            #"<iframe"#,
            #"<object"#,
            #"<embed"#
        ]

        for pattern in dangerousPatterns {
            if content.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                throw ValidationError.dangerousContent(pattern: pattern)
            }
        }

        // Validate HTML content if present
        if content.contains("<") && !configuration.allowUnsafeHTML {
            try validateHTMLContent(content)
        }
    }

    private func validateHTMLContent(_ content: String) throws {
        let htmlPattern = #"<[^>]+>"#
        let regex = try NSRegularExpression(pattern: htmlPattern, options: .caseInsensitive)
        let range = NSRange(content.startIndex..., in: content)

        let matches = regex.matches(in: content, options: [], range: range)

        for match in matches {
            let matchRange = Range(match.range, in: content)!
            let htmlTag = String(content[matchRange])

            // Extract tag name
            let tagPattern = #"</?(\w+)[^>]*>"#
            let tagRegex = try NSRegularExpression(pattern: tagPattern, options: .caseInsensitive)
            let tagMatches = tagRegex.matches(in: htmlTag, options: [], range: NSRange(htmlTag.startIndex..., in: htmlTag))

            if let tagMatch = tagMatches.first,
               let tagRange = Range(tagMatch.range(at: 1), in: htmlTag) {
                let tagName = String(htmlTag[tagRange]).lowercased()

                if configuration.blockedElements.contains(tagName) {
                    throw ValidationError.blockedHTMLElement(element: tagName)
                }
            }
        }
    }

    // MARK: - Content Sanitization

    private func removeBlockedElements(_ content: String) async throws -> String {
        var sanitized = content

        for element in configuration.blockedElements {
            let pattern = #"<\s*"# + element + #"[^>]*>.*?<\s*/\s*"# + element + #"\s*>"#
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return sanitized
    }

    private func validateAndCleanLinks(_ content: String) async throws -> String {
        let linkPattern = #"\[([^\]]*)\]\(([^)]+)\)"#
        let regex = try NSRegularExpression(pattern: linkPattern, options: [])
        let range = NSRange(content.startIndex..., in: content)

        var sanitized = content
        let matches = regex.matches(in: content, options: [], range: range).reversed()

        for match in matches {
            guard let urlRange = Range(match.range(at: 2), in: content) else { continue }
            let urlString = String(content[urlRange])

            if let url = URL(string: urlString) {
                // Validate protocol
                if let scheme = url.scheme?.lowercased(),
                   !configuration.allowedProtocols.contains(scheme) {
                    // Remove the link, keep the text
                    if let textRange = Range(match.range(at: 1), in: content) {
                        let linkText = String(content[textRange])
                        let fullRange = Range(match.range, in: content)!
                        sanitized.replaceSubrange(fullRange, with: linkText)
                    }
                }
            } else {
                // Invalid URL, remove the link
                if let textRange = Range(match.range(at: 1), in: content) {
                    let linkText = String(content[textRange])
                    let fullRange = Range(match.range, in: content)!
                    sanitized.replaceSubrange(fullRange, with: linkText)
                }
            }
        }

        return sanitized
    }

    private func removeScriptContent(_ content: String) -> String {
        let scriptPatterns = [
            #"<script[^>]*>.*?</script>"#,
            #"javascript:[^)"'\s]*"#,
            #"on\w+\s*=\s*[^>\s]+"#
        ]

        var sanitized = content

        for pattern in scriptPatterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return sanitized
    }

    // MARK: - Helper Methods

    private func isValidTableRow(_ line: String) -> Bool {
        // Basic table row validation
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    private func hasValidLinkSyntax(_ line: String) -> Bool {
        // Basic link syntax validation
        let linkPattern = #"\[([^\]]*)\]\(([^)]+)\)"#
        return line.range(of: linkPattern, options: .regularExpression) != nil
    }

    // MARK: - Error-Tolerant Validation

    /// Validate content and collect errors instead of throwing
    public func validateContentWithErrorCollection(_ content: String) async -> ValidationResult {
        var errors: [SyntaxError] = []

        // Size validation
        do {
            try await validateSize(content)
        } catch {
            errors.append(SyntaxError(
                line: 0,
                column: 0,
                type: .fileTooLarge,
                message: error.localizedDescription,
                severity: .error
            ))
            return ValidationResult(isValid: false, errors: errors, sanitizedContent: content)
        }

        // Structure validation - collect errors
        let structureErrors = await validateStructureWithErrors(content)
        errors.append(contentsOf: structureErrors)

        // Security validation - collect errors
        if configuration.enableScriptTagBlocking || configuration.enableLinkValidation {
            let securityErrors = await validateSecurityWithErrors(content)
            errors.append(contentsOf: securityErrors)
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            sanitizedContent: content
        )
    }

    private func validateStructureWithErrors(_ content: String) async -> [SyntaxError] {
        var errors: [SyntaxError] = []

        // Validate nesting
        let lines = content.components(separatedBy: .newlines)
        var currentNesting = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check list nesting
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("+") {
                let leadingSpaces = line.prefix { $0 == " " }.count
                currentNesting = leadingSpaces / 2

                if currentNesting > configuration.maxNestingLevel {
                    errors.append(SyntaxError(
                        line: index + 1,
                        column: 0,
                        type: .excessiveNesting,
                        message: "Excessive nesting level \(currentNesting) (maximum: \(configuration.maxNestingLevel))",
                        severity: .warning
                    ))
                }
            }

            // Check malformed tables
            if line.contains("|") && !isValidTableRow(line) {
                errors.append(SyntaxError(
                    line: index + 1,
                    column: 0,
                    type: .malformedTable,
                    message: "Malformed table syntax",
                    severity: .warning
                ))
            }

            // Check malformed links
            if line.contains("](") && !hasValidLinkSyntax(line) {
                errors.append(SyntaxError(
                    line: index + 1,
                    column: 0,
                    type: .malformedLink,
                    message: "Malformed link syntax",
                    severity: .warning
                ))
            }
        }

        return errors
    }

    private func validateSecurityWithErrors(_ content: String) async -> [SyntaxError] {
        var errors: [SyntaxError] = []

        // Check for dangerous patterns
        let dangerousPatterns = [
            "javascript:",
            "data:text/html",
            "vbscript:",
            "file:",
            "about:"
        ]

        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            for pattern in dangerousPatterns {
                if line.lowercased().contains(pattern) {
                    errors.append(SyntaxError(
                        line: index + 1,
                        column: 0,
                        type: .dangerousContent,
                        message: "Dangerous content detected: \(pattern)",
                        severity: .error
                    ))
                }
            }
        }

        return errors
    }
}

/// Validation result with collected errors
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [SyntaxError]
    public let sanitizedContent: String

    public init(isValid: Bool, errors: [SyntaxError], sanitizedContent: String) {
        self.isValid = isValid
        self.errors = errors
        self.sanitizedContent = sanitizedContent
    }
}

/// Syntax error information
public struct SyntaxError: Sendable, Identifiable, Codable, Hashable {
    public let id: UUID
    public let line: Int
    public let column: Int
    public let type: SyntaxErrorType
    public let message: String
    public let severity: ErrorSeverity

    public init(line: Int, column: Int, type: SyntaxErrorType, message: String, severity: ErrorSeverity) {
        self.id = UUID()
        self.line = line
        self.column = column
        self.type = type
        self.message = message
        self.severity = severity
    }
}

/// Types of syntax errors
public enum SyntaxErrorType: String, Sendable, Codable, Hashable {
    case excessiveNesting
    case malformedTable
    case malformedLink
    case dangerousContent
    case fileTooLarge
    case blockedHTML
    case invalidURL
}

/// Error severity levels
public enum ErrorSeverity: String, Sendable, Codable, Hashable {
    case error      // Blocks rendering
    case warning    // Shows warning but renders
    case info       // Informational only
}

/// Validation errors
public enum ValidationError: Error, LocalizedError, Sendable {
    case excessiveNesting(level: Int, max: Int)
    case malformedTable(line: Int)
    case malformedLink(line: Int)
    case dangerousContent(pattern: String)
    case blockedHTMLElement(element: String)
    case invalidURL(url: String)
    case disallowedProtocol(protocolName: String)

    public var errorDescription: String? {
        switch self {
        case .excessiveNesting(let level, let max):
            return "Excessive nesting level \(level) (maximum: \(max))"
        case .malformedTable(let line):
            return "Malformed table syntax at line \(line)"
        case .malformedLink(let line):
            return "Malformed link syntax at line \(line)"
        case .dangerousContent(let pattern):
            return "Dangerous content detected: \(pattern)"
        case .blockedHTMLElement(let element):
            return "Blocked HTML element: <\(element)>"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .disallowedProtocol(let protocolName):
            return "Disallowed protocol: \(protocolName)"
        }
    }
}

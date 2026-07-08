import Foundation

enum LaTeXDocumentProcessor {
    static func outline(from content: String) -> [HeadingItem] {
        // swiftlint:disable:next line_length
        let pattern = #"\\(part|chapter|section|subsection|subsubsection|paragraph|subparagraph)\*?(?![A-Za-z@])(?:\s*\[[^\]]*\])?\s*\{"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }

        let source = content as NSString
        let matches = expression.matches(
            in: content,
            range: NSRange(location: 0, length: source.length)
        ).compactMap { match -> Section? in
            guard !isCommented(location: match.range.location, in: source),
                  match.numberOfRanges > 1,
                  match.range(at: 1).location != NSNotFound else {
                return nil
            }

            let openingBrace = match.range.location + match.range.length - 1
            guard let argument = balancedArgument(in: source, openingBrace: openingBrace) else {
                return nil
            }

            let command = source.substring(with: match.range(at: 1))
            let fullLength = NSMaxRange(argument.range) + 1 - match.range.location
            return Section(
                command: command,
                title: plainText(from: argument.value),
                range: NSRange(location: match.range.location, length: fullLength)
            )
        }.filter { !$0.title.isEmpty }

        guard let minimumRank = matches.map(\.rank).min() else { return [] }

        return matches.map { section in
            let line = source.substring(to: section.range.location)
                .reduce(into: 1) { count, character in
                    if character == "\n" {
                        count += 1
                    }
                }

            return HeadingItem(
                level: min(6, section.rank - minimumRank + 1),
                title: section.title,
                range: section.range,
                position: CGFloat(max(0, line - 1) * 20)
            )
        }
    }

    static func metadata(from content: String, reference: DocumentReference) -> DocumentMetadata {
        let body = documentBody(from: removingComments(from: content))
        let visibleText = plainText(from: body)
        let words = visibleText.components(separatedBy: .whitespacesAndNewlines)
            .filter { word in
                !word.isEmpty && word.rangeOfCharacter(from: .alphanumerics) != nil
            }
        let outline = outline(from: content)
        let title = firstArgument(for: "title", in: content)
            .map { plainText(from: $0) }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? outline.first?.title

        return DocumentMetadata(
            title: title,
            wordCount: words.count,
            characterCount: content.count,
            lineCount: content.components(separatedBy: .newlines).count,
            estimatedReadingTime: DocumentMetadata.calculateReadingTime(wordCount: words.count),
            lastModified: reference.lastModified,
            fileSize: reference.fileSize,
            encoding: .utf8,
            hasImages: contains(#"\\includegraphics\*?(?:\[[^\]]*\])?\s*\{"#, in: content),
            hasTables: contains(#"\\begin\s*\{(?:table|tabular\*?)\}"#, in: content),
            hasCodeBlocks: contains(#"\\begin\s*\{(?:verbatim\*?|lstlisting|minted)\}"#, in: content),
            languageHints: languageHints(from: content)
        )
    }

    private static func firstArgument(for command: String, in content: String) -> String? {
        let escapedCommand = NSRegularExpression.escapedPattern(for: command)
        let pattern = "\\\\\(escapedCommand)\\*?(?![A-Za-z@])(?:\\s*\\[[^\\]]*\\])?\\s*\\{"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }

        let source = content as NSString
        for match in expression.matches(
            in: content,
            range: NSRange(location: 0, length: source.length)
        ) {
            guard !isCommented(location: match.range.location, in: source) else { continue }
            let openingBrace = match.range.location + match.range.length - 1
            if let argument = balancedArgument(in: source, openingBrace: openingBrace) {
                return argument.value
            }
        }
        return nil
    }

    private static func balancedArgument(
        in source: NSString,
        openingBrace: Int
    ) -> (value: String, range: NSRange)? {
        guard openingBrace >= 0,
              openingBrace < source.length,
              source.character(at: openingBrace) == 123 else {
            return nil
        }

        var depth = 0
        var inComment = false

        for index in openingBrace ..< source.length {
            let character = source.character(at: index)
            if character == 10 || character == 13 {
                inComment = false
                continue
            }
            if inComment {
                continue
            }
            if character == 37 && !isEscaped(location: index, in: source) {
                inComment = true
                continue
            }
            if character == 123 && !isEscaped(location: index, in: source) {
                depth += 1
            } else if character == 125 && !isEscaped(location: index, in: source) {
                depth -= 1
                if depth == 0 {
                    let range = NSRange(
                        location: openingBrace + 1,
                        length: index - openingBrace - 1
                    )
                    return (source.substring(with: range), range)
                }
            }
        }

        return nil
    }

    private static func isCommented(location: Int, in source: NSString) -> Bool {
        let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
        guard location > lineRange.location else { return false }

        for index in lineRange.location ..< location
            where source.character(at: index) == 37 && !isEscaped(location: index, in: source) {
            return true
        }
        return false
    }

    private static func isEscaped(location: Int, in source: NSString) -> Bool {
        guard location > 0 else { return false }
        var backslashCount = 0
        var index = location - 1

        while source.character(at: index) == 92 {
            backslashCount += 1
            if index == 0 {
                break
            }
            index -= 1
        }
        return backslashCount.isMultiple(of: 2) == false
    }

    private static func removingComments(from content: String) -> String {
        content.components(separatedBy: .newlines)
            .map(removeComment(from:))
            .joined(separator: "\n")
    }

    private static func removeComment(from line: String) -> String {
        var backslashCount = 0
        for index in line.indices {
            let character = line[index]
            if character == "%" && backslashCount.isMultiple(of: 2) {
                return String(line[..<index])
            }
            if character == "\\" {
                backslashCount += 1
            } else {
                backslashCount = 0
            }
        }
        return line
    }

    private static func documentBody(from content: String) -> String {
        let beginMarker = #"\begin{document}"#
        let endMarker = #"\end{document}"#
        let start = content.range(of: beginMarker).map { $0.upperBound } ?? content.startIndex
        let end = content.range(of: endMarker, range: start ..< content.endIndex)?.lowerBound
            ?? content.endIndex
        return String(content[start ..< end])
    }

    private static func plainText(from source: String) -> String {
        var value = source
        let replacements = [
            (#"\\LaTeX(?![A-Za-z@])"#, "LaTeX"),
            (#"\\TeX(?![A-Za-z@])"#, "TeX"),
            (#"\\&"#, "&"),
            (#"\\%"#, "%"),
            ("\\\\#", "#"),
            (#"\\_"#, "_"),
            (#"~"#, " "),
            (#"\\(?:label|index)\s*\{[^{}]*\}"#, " "),
            (#"\\[A-Za-z@]+\*?"#, " "),
            (#"[{}$]"#, " ")
        ]

        for (pattern, replacement) in replacements {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(location: 0, length: (value as NSString).length)
            value = expression.stringByReplacingMatches(
                in: value,
                range: range,
                withTemplate: replacement
            )
        }

        return value.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func contains(_ pattern: String, in content: String) -> Bool {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return false
        }
        return expression.firstMatch(
            in: content,
            range: NSRange(location: 0, length: (content as NSString).length)
        ) != nil
    }

    private static func languageHints(from content: String) -> Set<String> {
        let patterns = [
            #"\\begin\s*\{minted\}\s*\{([^}]+)\}"#,
            #"\\begin\s*\{lstlisting\}\s*\[[^\]]*language\s*=\s*([A-Za-z0-9_+.-]+)[^\]]*\]"#
        ]
        var languages: Set<String> = []
        let source = content as NSString

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            for match in expression.matches(
                in: content,
                range: NSRange(location: 0, length: source.length)
            ) where match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                languages.insert(source.substring(with: match.range(at: 1)).lowercased())
            }
        }

        return languages
    }

    private struct Section {
        let command: String
        let title: String
        let range: NSRange

        var rank: Int {
            switch command {
            case "part": return 0
            case "chapter": return 1
            case "section": return 2
            case "subsection": return 3
            case "subsubsection": return 4
            case "paragraph": return 5
            default: return 6
            }
        }
    }
}

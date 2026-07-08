import Foundation
import SwiftUI

struct LaTeXBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case title
        case author
        case date
        case section(level: Int)
        case paragraph
        case unorderedList
        case orderedList
        case equation
        case code(language: String?)
        case quote
        case abstract
        case table
        case image
    }

    let id: String
    let kind: Kind
    let content: String
    let items: [String]
    let startLine: Int

    init(
        kind: Kind,
        content: String,
        items: [String] = [],
        startLine: Int,
        ordinal: Int
    ) {
        id = "latex-\(startLine)-\(ordinal)"
        self.kind = kind
        self.content = content
        self.items = items
        self.startLine = startLine
    }

    var anchorID: String {
        if case .section = kind {
            return "heading-\(content)"
        }
        return id
    }
}

enum LaTeXParser {
    static func parse(_ source: String) -> [LaTeXBlock] {
        let cleanedSource = removingComments(from: source)
        let title = commandArgument("title", in: cleanedSource)
        let author = commandArgument("author", in: cleanedSource)
        let date = commandArgument("date", in: cleanedSource)
        let lines = cleanedSource.components(separatedBy: .newlines)
        let bodyStart = lines.firstIndex { $0.contains(#"\begin{document}"#) }.map { $0 + 1 } ?? 0
        let bodyEnd = lines[bodyStart...].firstIndex { $0.contains(#"\end{document}"#) } ?? lines.endIndex

        var blocks: [LaTeXBlock] = []
        var paragraphLines: [String] = []
        var paragraphStart = bodyStart + 1
        var index = bodyStart

        func appendBlock(
            _ kind: LaTeXBlock.Kind,
            content: String,
            items: [String] = [],
            line: Int
        ) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty || !items.isEmpty else { return }
            blocks.append(LaTeXBlock(
                kind: kind,
                content: trimmed,
                items: items,
                startLine: line,
                ordinal: blocks.count
            ))
        }

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            appendBlock(
                .paragraph,
                content: paragraphLines.joined(separator: " "),
                line: paragraphStart
            )
            paragraphLines.removeAll(keepingCapacity: true)
        }

        while index < bodyEnd {
            let lineNumber = index + 1
            let rawLine = lines[index]
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if line.contains(#"\maketitle"#) {
                flushParagraph()
                if let title {
                    appendBlock(.title, content: title, line: lineNumber)
                }
                if let author {
                    appendBlock(.author, content: author, line: lineNumber)
                }
                if let date, !date.contains(#"\today"#) {
                    appendBlock(.date, content: date, line: lineNumber)
                }
                index += 1
                continue
            }

            if let section = sectionCommand(in: line) {
                flushParagraph()
                appendBlock(
                    .section(level: section.level),
                    content: section.title,
                    line: lineNumber
                )
                index += 1
                continue
            }

            if let environment = environmentName(in: line) {
                flushParagraph()
                let collected = collectEnvironment(
                    environment,
                    lines: lines,
                    startingAt: index,
                    endingBefore: bodyEnd
                )
                let environmentContent = collected.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                switch environment {
                case "itemize":
                    appendBlock(
                        .unorderedList,
                        content: environmentContent,
                        items: listItems(from: environmentContent),
                        line: lineNumber
                    )
                case "enumerate", "description":
                    appendBlock(
                        .orderedList,
                        content: environmentContent,
                        items: listItems(from: environmentContent),
                        line: lineNumber
                    )
                case "equation", "equation*", "align", "align*", "displaymath", "gather", "gather*":
                    appendBlock(.equation, content: environmentContent, line: lineNumber)
                case "verbatim", "verbatim*":
                    appendBlock(.code(language: nil), content: environmentContent, line: lineNumber)
                case "lstlisting":
                    appendBlock(
                        .code(language: listingLanguage(from: line)),
                        content: environmentContent,
                        line: lineNumber
                    )
                case "minted":
                    appendBlock(
                        .code(language: mintedLanguage(from: line)),
                        content: environmentContent,
                        line: lineNumber
                    )
                case "quote", "quotation", "verse":
                    appendBlock(.quote, content: environmentContent, line: lineNumber)
                case "abstract":
                    appendBlock(.abstract, content: environmentContent, line: lineNumber)
                case "tabular", "tabular*", "table":
                    appendBlock(.table, content: environmentContent, line: lineNumber)
                case "figure", "figure*":
                    let image = imageDescription(from: environmentContent)
                    appendBlock(.image, content: image, line: lineNumber)
                default:
                    appendBlock(.paragraph, content: environmentContent, line: lineNumber)
                }

                index = collected.endIndex + 1
                continue
            }

            if line.hasPrefix(#"\["#) {
                flushParagraph()
                let collected = collectDelimitedBlock(
                    closingMarker: #"\]"#,
                    lines: lines,
                    startingAt: index,
                    endingBefore: bodyEnd
                )
                appendBlock(.equation, content: collected.content, line: lineNumber)
                index = collected.endIndex + 1
                continue
            }

            if line.hasPrefix("$$") {
                flushParagraph()
                let collected = collectDelimitedBlock(
                    closingMarker: "$$",
                    lines: lines,
                    startingAt: index,
                    endingBefore: bodyEnd
                )
                appendBlock(.equation, content: collected.content, line: lineNumber)
                index = collected.endIndex + 1
                continue
            }

            if line.hasPrefix(#"\includegraphics"#) {
                flushParagraph()
                appendBlock(.image, content: imageDescription(from: line), line: lineNumber)
                index += 1
                continue
            }

            if shouldIgnore(line) {
                index += 1
                continue
            }

            if paragraphLines.isEmpty {
                paragraphStart = lineNumber
            }
            paragraphLines.append(line)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    private static func sectionCommand(in line: String) -> (level: Int, title: String)? {
        let commands = [
            ("part", 1),
            ("chapter", 1),
            ("section", 1),
            ("subsection", 2),
            ("subsubsection", 3),
            ("paragraph", 4),
            ("subparagraph", 5)
        ]

        for (command, level) in commands {
            let prefix = "\\\(command)"
            guard line.hasPrefix(prefix) else { continue }
            let argumentStart = line.index(line.startIndex, offsetBy: prefix.count)
            if let title = firstBracedArgument(in: line, after: argumentStart) {
                return (level, title)
            }
        }
        return nil
    }

    private static func environmentName(in line: String) -> String? {
        guard let begin = line.range(of: #"\begin{"#) else { return nil }
        let remainder = line[begin.upperBound...]
        guard let close = remainder.firstIndex(of: "}") else { return nil }
        return String(remainder[..<close])
    }

    private static func collectEnvironment(
        _ name: String,
        lines: [String],
        startingAt startIndex: Int,
        endingBefore endIndex: Int
    ) -> (content: String, endIndex: Int) {
        let startMarker = "\\begin{\(name)}"
        let endMarker = "\\end{\(name)}"
        var result: [String] = []
        var index = startIndex

        while index < endIndex {
            var line = lines[index]
            if index == startIndex, let marker = line.range(of: startMarker) {
                line = String(line[marker.upperBound...])
                if line.hasPrefix("{") && name == "minted",
                   let close = line.firstIndex(of: "}") {
                    line = String(line[line.index(after: close)...])
                }
            }
            if let marker = line.range(of: endMarker) {
                result.append(String(line[..<marker.lowerBound]))
                return (result.joined(separator: "\n"), index)
            }
            result.append(line)
            index += 1
        }

        return (result.joined(separator: "\n"), max(startIndex, endIndex - 1))
    }

    private static func collectDelimitedBlock(
        closingMarker: String,
        lines: [String],
        startingAt startIndex: Int,
        endingBefore endIndex: Int
    ) -> (content: String, endIndex: Int) {
        let openingMarker = closingMarker == #"\]"# ? #"\["# : closingMarker
        var result: [String] = []
        var index = startIndex

        while index < endIndex {
            var line = lines[index]
            if index == startIndex, let marker = line.range(of: openingMarker) {
                line = String(line[marker.upperBound...])
            }
            if let marker = line.range(of: closingMarker) {
                result.append(String(line[..<marker.lowerBound]))
                return (result.joined(separator: "\n"), index)
            }
            result.append(line)
            index += 1
        }

        return (result.joined(separator: "\n"), max(startIndex, endIndex - 1))
    }

    private static func listItems(from content: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"\\item(?:\s*\[[^\]]*\])?\s*"#
        ) else {
            return []
        }
        let source = content as NSString
        let matches = expression.matches(
            in: content,
            range: NSRange(location: 0, length: source.length)
        )

        return matches.enumerated().compactMap { offset, match in
            let start = NSMaxRange(match.range)
            let end = offset + 1 < matches.count ? matches[offset + 1].range.location : source.length
            guard end >= start else { return nil }
            let item = source.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return item.isEmpty ? nil : item
        }
    }

    private static func commandArgument(_ command: String, in source: String) -> String? {
        let marker = "\\\(command)"
        guard let commandRange = source.range(of: marker) else { return nil }
        return firstBracedArgument(in: source, after: commandRange.upperBound)
    }

    private static func firstBracedArgument(
        in source: String,
        after start: String.Index
    ) -> String? {
        guard let opening = source[start...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = opening

        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[source.index(after: opening) ..< index])
                }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func listingLanguage(from line: String) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: #"language\s*=\s*([A-Za-z0-9_+.-]+)"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let source = line as NSString
        guard let match = expression.firstMatch(
            in: line,
            range: NSRange(location: 0, length: source.length)
        ), match.numberOfRanges > 1 else {
            return nil
        }
        return source.substring(with: match.range(at: 1))
    }

    private static func mintedLanguage(from line: String) -> String? {
        guard let marker = line.range(of: #"\begin{minted}"#) else { return nil }
        return firstBracedArgument(in: line, after: marker.upperBound)
    }

    private static func imageDescription(from content: String) -> String {
        let path = commandArgument("includegraphics", in: content) ?? "Image"
        let caption = commandArgument("caption", in: content)
        return caption.map { "\($0) — \(path)" } ?? path
    }

    private static func shouldIgnore(_ line: String) -> Bool {
        let ignoredPrefixes = [
            #"\documentclass"#,
            #"\usepackage"#,
            #"\title"#,
            #"\author"#,
            #"\date"#,
            #"\label"#,
            #"\bibliography"#,
            #"\bibliographystyle"#,
            #"\end{"#
        ]
        return ignoredPrefixes.contains { line.hasPrefix($0) }
    }

    private static func removingComments(from content: String) -> String {
        content.components(separatedBy: .newlines)
            .map { line in
                var backslashCount = 0
                for index in line.indices {
                    let character = line[index]
                    if character == "%" && backslashCount.isMultiple(of: 2) {
                        return String(line[..<index])
                    }
                    backslashCount = character == "\\" ? backslashCount + 1 : 0
                }
                return line
            }
            .joined(separator: "\n")
    }
}

enum LaTeXInlineFormatter {
    static func attributedString(from source: String) -> AttributedString {
        let markdown = markdown(from: source)
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(plainText(from: source))
    }

    static func mathText(from source: String) -> String {
        var value = source
            .replacingOccurrences(of: "\\\\", with: "  ")
            .replacingOccurrences(of: "&", with: " ")
        let symbols = [
            "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ",
            "epsilon": "ε", "theta": "θ", "lambda": "λ", "mu": "μ",
            "pi": "π", "rho": "ρ", "sigma": "σ", "phi": "φ", "omega": "ω",
            "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ",
            "Pi": "Π", "Sigma": "Σ", "Phi": "Φ", "Omega": "Ω",
            "times": "×", "cdot": "·", "pm": "±", "div": "÷",
            "leq": "≤", "geq": "≥", "neq": "≠", "approx": "≈",
            "infty": "∞", "sum": "∑", "prod": "∏", "int": "∫",
            "partial": "∂", "nabla": "∇", "rightarrow": "→", "leftarrow": "←",
            "Rightarrow": "⇒", "Leftarrow": "⇐", "in": "∈", "notin": "∉"
        ]

        for command in symbols.keys.sorted(by: { $0.count > $1.count }) {
            guard let symbol = symbols[command] else { continue }
            value = value.replacingOccurrences(of: "\\\(command)", with: symbol)
        }
        value = replacingSimpleCommand("frac", argumentCount: 2, in: value) { arguments in
            guard arguments.count == 2 else { return nil }
            return "(\(arguments[0]))/(\(arguments[1]))"
        }
        value = replacingSimpleCommand("sqrt", in: value) { arguments in
            guard let argument = arguments.first else { return nil }
            return "√(\(argument))"
        }
        value = value
            .replacingOccurrences(of: "\\left", with: "")
            .replacingOccurrences(of: "\\right", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "$", with: "")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markdown(from source: String) -> String {
        var result = source
        result = replacingSimpleCommand("textbf", in: result) { "**\($0[0])**" }
        result = replacingSimpleCommand("textit", in: result) { "*\($0[0])*" }
        result = replacingSimpleCommand("emph", in: result) { "*\($0[0])*" }
        result = replacingSimpleCommand("texttt", in: result) { "`\($0[0])`" }
        result = replacingSimpleCommand("underline", in: result) { $0[0] }
        result = replacingSimpleCommand("href", argumentCount: 2, in: result) {
            "[\($0[1])](\($0[0]))"
        }
        result = replacingSimpleCommand("url", in: result) { "<\($0[0])>" }
        result = replacingSimpleCommand("footnote", in: result) { " (\($0[0]))" }
        result = replacingSimpleCommand("cite", in: result) { "[\($0[0])]" }
        result = replacingSimpleCommand("ref", in: result) { $0[0] }

        let sourceString = result as NSString
        guard let mathExpression = try? NSRegularExpression(pattern: #"\$([^$]+)\$"#) else {
            return result
        }
        let matches = mathExpression.matches(
            in: result,
            range: NSRange(location: 0, length: sourceString.length)
        )
        for match in matches.reversed() where match.numberOfRanges > 1 {
            let math = sourceString.substring(with: match.range(at: 1))
            let replacement = "`\(mathText(from: math))`"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        let substitutions = [
            (#"\\LaTeX(?![A-Za-z@])"#, "LaTeX"),
            (#"\\TeX(?![A-Za-z@])"#, "TeX"),
            (#"\\&"#, "&"),
            (#"\\%"#, "%"),
            ("\\\\#", "#"),
            (#"\\_"#, "_"),
            (#"~"#, " "),
            (#"\\(?:label|index)\s*\{[^{}]*\}"#, ""),
            (#"\\[A-Za-z@]+\*?"#, ""),
            (#"[{}]"#, "")
        ]
        for (pattern, replacement) in substitutions {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            result = expression.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: (result as NSString).length),
                withTemplate: replacement
            )
        }
        return result
    }

    private static func plainText(from source: String) -> String {
        markdown(from: source)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    private static func replacingSimpleCommand(
        _ command: String,
        argumentCount: Int = 1,
        in source: String,
        transform: ([String]) -> String?
    ) -> String {
        var result = source
        var searchStart = result.startIndex
        let marker = "\\\(command)"

        while searchStart < result.endIndex,
              let commandRange = result.range(of: marker, range: searchStart ..< result.endIndex) {
            var cursor = commandRange.upperBound
            var arguments: [String] = []
            var end = cursor

            for _ in 0 ..< argumentCount {
                while cursor < result.endIndex && result[cursor].isWhitespace {
                    cursor = result.index(after: cursor)
                }
                guard cursor < result.endIndex, result[cursor] == "{",
                      let argument = bracedArgument(in: result, openingBrace: cursor) else {
                    arguments.removeAll()
                    break
                }
                arguments.append(argument.value)
                end = argument.endIndex
                cursor = argument.endIndex
            }

            guard arguments.count == argumentCount, let replacement = transform(arguments) else {
                searchStart = commandRange.upperBound
                continue
            }
            let replacementOffset = result.distance(
                from: result.startIndex,
                to: commandRange.lowerBound
            )
            result.replaceSubrange(commandRange.lowerBound ..< end, with: replacement)
            searchStart = result.index(
                result.startIndex,
                offsetBy: min(result.count, replacementOffset + replacement.count)
            )
        }
        return result
    }

    private static func bracedArgument(
        in source: String,
        openingBrace: String.Index
    ) -> (value: String, endIndex: String.Index)? {
        var depth = 0
        var index = openingBrace

        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let value = String(source[source.index(after: openingBrace) ..< index])
                    return (value, source.index(after: index))
                }
            }
            index = source.index(after: index)
        }
        return nil
    }
}

struct LaTeXPreviewView: View {
    @Environment(AppStateCoordinator.self) private var coordinator
    @Environment(\.themeManager) private var themeManager

    let content: String

    var body: some View {
        let blocks = LaTeXParser.parse(content)

        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { block in
                        blockRow(block)
                            .id(block.anchorID)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
            .background(themeManager.color(for: .background))
            .onChange(of: coordinator.documentState.scrollToHeadingID) { _, headingID in
                guard let headingID else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(headingID, anchor: .top)
                }
                coordinator.documentState.scrollToHeadingID = nil
            }
            .onChange(of: coordinator.documentState.focusedLine) { _, line in
                guard let line,
                      let target = blocks.min(by: {
                          abs($0.startLine - line) < abs($1.startLine - line)
                      }) else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target.anchorID, anchor: .center)
                }
            }
        }
    }

    private func blockRow(_ block: LaTeXBlock) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if coordinator.uiState.showLineNumbers {
                Text("\(block.startLine)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.gray.opacity(0.45))
                    .frame(width: 36, alignment: .trailing)
            }

            blockContent(block)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, verticalPadding(for: block.kind))
        .contentShape(Rectangle())
        .onTapGesture {
            coordinator.documentState.focusedLine = block.startLine
        }
    }

    @ViewBuilder
    private func blockContent(_ block: LaTeXBlock) -> some View {
        let sizeMultiplier = themeManager.fontSizeMultiplier

        switch block.kind {
        case .title:
            Text(LaTeXInlineFormatter.attributedString(from: block.content))
                .font(.system(size: 30 * sizeMultiplier, weight: .bold, design: .serif))
                .textSelection(.enabled)
        case .author:
            Text(LaTeXInlineFormatter.attributedString(from: block.content))
                .font(.system(size: 17 * sizeMultiplier, design: .serif))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .date:
            Text(LaTeXInlineFormatter.attributedString(from: block.content))
                .font(.system(size: 14 * sizeMultiplier, design: .serif))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case let .section(level):
            Text(LaTeXInlineFormatter.attributedString(from: block.content))
                .font(sectionFont(level: level, multiplier: sizeMultiplier))
                .foregroundStyle(themeManager.color(for: .primary))
                .textSelection(.enabled)
        case .paragraph:
            Text(LaTeXInlineFormatter.attributedString(from: block.content))
                .font(.system(size: 16 * sizeMultiplier, design: .serif))
                .foregroundStyle(themeManager.color(for: .primary))
                .lineSpacing(4)
                .textSelection(.enabled)
        case .unorderedList, .orderedList:
            listView(block)
        case .equation:
            ScrollView(.horizontal) {
                Text(LaTeXInlineFormatter.mathText(from: block.content))
                    .font(.system(size: 18 * sizeMultiplier, design: .serif))
                    .italic()
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        case let .code(language):
            VStack(alignment: .leading, spacing: 6) {
                if let language, !language.isEmpty {
                    Text(language.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(block.content)
                    .font(.system(size: 13 * sizeMultiplier, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        case .quote:
            Text(LaTeXInlineFormatter.attributedString(from: block.content))
                .font(.system(size: 16 * sizeMultiplier, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.accentColor.opacity(0.5)).frame(width: 3)
                }
                .textSelection(.enabled)
        case .abstract:
            VStack(alignment: .leading, spacing: 8) {
                Text("Abstract").font(.headline)
                Text(LaTeXInlineFormatter.attributedString(from: block.content))
                    .font(.system(size: 15 * sizeMultiplier, design: .serif))
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        case .table:
            Text(tableText(from: block.content))
                .font(.system(size: 13 * sizeMultiplier, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .image:
            Label(block.content, systemImage: "photo")
                .font(.system(size: 14 * sizeMultiplier))
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func listView(_ block: LaTeXBlock) -> some View {
        let ordered: Bool
        if case .orderedList = block.kind {
            ordered = true
        } else {
            ordered = false
        }

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .frame(width: 24, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text(LaTeXInlineFormatter.attributedString(from: item))
                        .font(.system(
                            size: 16 * themeManager.fontSizeMultiplier,
                            design: .serif
                        ))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func sectionFont(level: Int, multiplier: CGFloat) -> Font {
        switch level {
        case 1: return .system(size: 25 * multiplier, weight: .bold, design: .serif)
        case 2: return .system(size: 21 * multiplier, weight: .semibold, design: .serif)
        case 3: return .system(size: 18 * multiplier, weight: .semibold, design: .serif)
        default: return .system(size: 16 * multiplier, weight: .semibold, design: .serif)
        }
    }

    private func verticalPadding(for kind: LaTeXBlock.Kind) -> CGFloat {
        switch kind {
        case .title: return 10
        case .section: return 12
        case .equation, .code, .quote, .abstract, .table, .image: return 8
        default: return 5
        }
    }

    private func tableText(from content: String) -> String {
        content
            .replacingOccurrences(of: "\\hline", with: "")
            .replacingOccurrences(of: "&", with: " | ")
            .replacingOccurrences(of: "\\\\", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

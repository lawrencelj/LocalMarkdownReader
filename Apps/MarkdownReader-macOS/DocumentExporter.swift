// DocumentExporter - Export markdown documents to various formats
//
// Provides export functionality for Word (.docx via HTML), RTF, and HTML formats.

import AppKit
import MarkdownCore
import UniformTypeIdentifiers

/// Supported export formats
enum ExportFormat: String, CaseIterable {
    case word = "docx"
    case rtf = "rtf"
    case html = "html"
    case pdf = "pdf"

    var displayName: String {
        switch self {
        case .word: return "Word Document (.docx)"
        case .rtf: return "Rich Text Format (.rtf)"
        case .html: return "HTML Document (.html)"
        case .pdf: return "PDF Document (.pdf)"
        }
    }

    var utType: UTType {
        switch self {
        case .word: return UTType(filenameExtension: "docx") ?? .data
        case .rtf: return .rtf
        case .html: return .html
        case .pdf: return .pdf
        }
    }

    var fileExtension: String {
        rawValue
    }
}

/// Document exporter for converting markdown to various formats
enum DocumentExporter {
    /// Export document content to the specified format
    @MainActor
    static func export(
        content: String,
        title: String,
        to format: ExportFormat,
        at url: URL
    ) throws {
        switch format {
        case .word:
            try exportToWord(content: content, title: title, at: url)
        case .rtf:
            try exportToRTF(content: content, title: title, at: url)
        case .html:
            try exportToHTML(content: content, title: title, at: url)
        case .pdf:
            try exportToPDF(content: content, title: title, at: url)
        }
    }

    /// Show save panel and export document
    @MainActor
    static func exportWithPanel(
        content: String,
        title: String,
        format: ExportFormat
    ) -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Document"
        panel.nameFieldStringValue = "\(title.isEmpty ? "Untitled" : title).\(format.fileExtension)"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [format.utType]

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        do {
            try export(content: content, title: title, to: format, at: url)
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
            return false
        }
    }

    // MARK: - Word Export (.docx)

    /// Export to Word format using HTML intermediary
    /// Word can open .docx files that are actually HTML with proper MIME type
    private static func exportToWord(content: String, title: String, at url: URL) throws {
        let html = generateHTML(content: content, title: title, forWord: true)

        // Create a simple OOXML document structure for true .docx
        // For simplicity, we'll use the HTML-in-docx approach which Word supports
        let wordML = generateWordML(html: html, title: title)

        try wordML.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Generate Word ML (Office Open XML) compatible document
    private static func generateWordML(html: String, title: String) -> String {
        // Convert HTML to a simplified Word-compatible format
        // This creates a minimal .docx-compatible document
        let cleanedContent = convertMarkdownToWordContent(html)

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <?mso-application progid="Word.Document"?>
        <w:wordDocument xmlns:w="http://schemas.microsoft.com/office/word/2003/wordml"
                        xmlns:v="urn:schemas-microsoft-com:vml"
                        xmlns:w10="urn:schemas-microsoft-com:office:word"
                        xmlns:sl="http://schemas.microsoft.com/schemaLibrary/2003/core"
                        xmlns:aml="http://schemas.microsoft.com/aml/2001/core"
                        xmlns:wx="http://schemas.microsoft.com/office/word/2003/auxHint"
                        xmlns:o="urn:schemas-microsoft-com:office:office"
                        xmlns:dt="uuid:C2F41010-65B3-11d1-A29F-00AA00C14882"
                        w:macrosPresent="no" w:embeddedObjPresent="no" w:ocxPresent="no"
                        xml:space="preserve">
            <w:body>
        \(cleanedContent)
            </w:body>
        </w:wordDocument>
        """
    }

    /// Convert markdown content to Word ML paragraphs
    private static func convertMarkdownToWordContent(_ content: String) -> String {
        let blocks = MarkdownBlockParser.parse(content)
        var wordML = ""

        for block in blocks {
            switch block.kind {
            case let .heading(level):
                let fontSize = headingFontSize(level)
                let text = block.runs.map(\.text).joined()
                wordML += """
                        <w:p>
                            <w:pPr>
                                <w:pStyle w:val="Heading\(level)"/>
                            </w:pPr>
                            <w:r>
                                <w:rPr>
                                    <w:b/>
                                    <w:sz w:val="\(fontSize * 2)"/>
                                </w:rPr>
                                <w:t>\(escapeXML(text))</w:t>
                            </w:r>
                        </w:p>

                """

            case .paragraph:
                let runs = generateWordRuns(block.runs)
                wordML += """
                        <w:p>
                            \(runs)
                        </w:p>

                """

            case let .codeBlock(language):
                let langLabel = language.map { "[\($0)]\\n" } ?? ""
                wordML += """
                        <w:p>
                            <w:pPr>
                                <w:pStyle w:val="Code"/>
                            </w:pPr>
                            <w:r>
                                <w:rPr>
                                    <w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>
                                    <w:sz w:val="20"/>
                                </w:rPr>
                                <w:t xml:space="preserve">\(escapeXML(langLabel + block.code))</w:t>
                            </w:r>
                        </w:p>

                """

            case .blockquote:
                let text = block.runs.map(\.text).joined()
                wordML += """
                        <w:p>
                            <w:pPr>
                                <w:pStyle w:val="Quote"/>
                                <w:ind w:left="720"/>
                            </w:pPr>
                            <w:r>
                                <w:rPr>
                                    <w:i/>
                                </w:rPr>
                                <w:t>\(escapeXML(text))</w:t>
                            </w:r>
                        </w:p>

                """

            case .unorderedList:
                for item in block.listItems {
                    let text = item.map(\.text).joined()
                    wordML += """
                        <w:p>
                            <w:pPr>
                                <w:pStyle w:val="ListBullet"/>
                                <w:numPr>
                                    <w:ilvl w:val="0"/>
                                    <w:numId w:val="1"/>
                                </w:numPr>
                            </w:pPr>
                            <w:r>
                                <w:t>• \(escapeXML(text))</w:t>
                            </w:r>
                        </w:p>

                    """
                }

            case .orderedList:
                for (index, item) in block.listItems.enumerated() {
                    let text = item.map(\.text).joined()
                    wordML += """
                        <w:p>
                            <w:pPr>
                                <w:pStyle w:val="ListNumber"/>
                            </w:pPr>
                            <w:r>
                                <w:t>\(index + 1). \(escapeXML(text))</w:t>
                            </w:r>
                        </w:p>

                    """
                }

            case .table:
                wordML += generateWordTable(block.tableRows)

            case .thematicBreak:
                wordML += """
                        <w:p>
                            <w:pPr>
                                <w:pBdr>
                                    <w:bottom w:val="single" w:sz="6" w:space="1" w:color="auto"/>
                                </w:pBdr>
                            </w:pPr>
                        </w:p>

                """
            }
        }

        return wordML
    }

    /// Generate Word ML runs with formatting
    private static func generateWordRuns(_ runs: [InlineRun]) -> String {
        var result = ""
        for run in runs {
            var rPr = ""
            if run.isBold { rPr += "<w:b/>" }
            if run.isItalic { rPr += "<w:i/>" }
            if run.isStrikethrough { rPr += "<w:strike/>" }
            if run.isCode {
                rPr += "<w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\"/>"
                rPr += "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"E8E8E8\"/>"
            }

            result += """
                            <w:r>
                                <w:rPr>\(rPr)</w:rPr>
                                <w:t xml:space="preserve">\(escapeXML(run.text))</w:t>
                            </w:r>

            """
        }
        return result
    }

    /// Generate Word ML table
    private static func generateWordTable(_ rows: [[[InlineRun]]]) -> String {
        guard !rows.isEmpty else { return "" }

        var table = """
                <w:tbl>
                    <w:tblPr>
                        <w:tblBorders>
                            <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                        </w:tblBorders>
                    </w:tblPr>

        """

        for (rowIndex, row) in rows.enumerated() {
            table += "                <w:tr>\n"
            for cell in row {
                let text = cell.map(\.text).joined()
                let bold = rowIndex == 0 ? "<w:b/>" : ""
                table += """
                                    <w:tc>
                                        <w:p>
                                            <w:r>
                                                <w:rPr>\(bold)</w:rPr>
                                                <w:t>\(escapeXML(text))</w:t>
                                            </w:r>
                                        </w:p>
                                    </w:tc>

                """
            }
            table += "                </w:tr>\n"
        }

        table += "            </w:tbl>\n"
        return table
    }

    private static func headingFontSize(_ level: Int) -> Int {
        switch level {
        case 1: return 28
        case 2: return 24
        case 3: return 20
        case 4: return 16
        case 5: return 14
        default: return 12
        }
    }

    // MARK: - RTF Export

    private static func exportToRTF(content: String, title: String, at url: URL) throws {
        let attributedString = createAttributedString(from: content, title: title)

        guard let rtfData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            throw ExportError.conversionFailed
        }

        try rtfData.write(to: url)
    }

    // MARK: - HTML Export

    private static func exportToHTML(content: String, title: String, at url: URL) throws {
        let html = generateHTML(content: content, title: title, forWord: false)
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - PDF Export

    private static func exportToPDF(content: String, title: String, at url: URL) throws {
        let html = generateHTML(content: content, title: title, forWord: false)

        // Create a temporary HTML file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        try html.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Use WebKit to render and print to PDF
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        // For PDF, we'll create from the attributed string
        let attributedString = createAttributedString(from: content, title: title)

        // Create a text view for printing
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612 - 144, height: 792 - 144))
        textView.textStorage?.setAttributedString(attributedString)
        textView.sizeToFit()

        // Print to PDF
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        printOperation.run()
    }

    // MARK: - Helpers

    /// Generate HTML from markdown content
    private static func generateHTML(content: String, title: String, forWord: Bool) -> String {
        let blocks = MarkdownBlockParser.parse(content)
        var body = ""

        for block in blocks {
            switch block.kind {
            case let .heading(level):
                let text = renderInlineHTML(block.runs)
                body += "<h\(level)>\(text)</h\(level)>\n"

            case .paragraph:
                let text = renderInlineHTML(block.runs)
                body += "<p>\(text)</p>\n"

            case let .codeBlock(language):
                let langAttr = language.map { " class=\"language-\($0)\"" } ?? ""
                body += "<pre><code\(langAttr)>\(escapeHTML(block.code))</code></pre>\n"

            case .blockquote:
                let text = renderInlineHTML(block.runs)
                body += "<blockquote>\(text)</blockquote>\n"

            case .unorderedList:
                body += "<ul>\n"
                for item in block.listItems {
                    let text = renderInlineHTML(item)
                    body += "  <li>\(text)</li>\n"
                }
                body += "</ul>\n"

            case .orderedList:
                body += "<ol>\n"
                for item in block.listItems {
                    let text = renderInlineHTML(item)
                    body += "  <li>\(text)</li>\n"
                }
                body += "</ol>\n"

            case .table:
                body += "<table border=\"1\" cellpadding=\"8\" cellspacing=\"0\">\n"
                for (rowIndex, row) in block.tableRows.enumerated() {
                    body += "  <tr>\n"
                    let tag = rowIndex == 0 ? "th" : "td"
                    for cell in row {
                        let text = renderInlineHTML(cell)
                        body += "    <\(tag)>\(text)</\(tag)>\n"
                    }
                    body += "  </tr>\n"
                }
                body += "</table>\n"

            case .thematicBreak:
                body += "<hr>\n"
            }
        }

        let wordMeta = forWord ? """
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            <meta name="Generator" content="Markdown Reader">
            <!--[if gte mso 9]><xml><o:OfficeDocumentSettings><o:AllowPNG/></o:OfficeDocumentSettings></xml><![endif]-->
        """ : ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(escapeHTML(title))</title>
            \(wordMeta)
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    color: #333;
                }
                h1 { font-size: 2em; margin-top: 1em; }
                h2 { font-size: 1.5em; margin-top: 0.8em; }
                h3 { font-size: 1.25em; margin-top: 0.6em; }
                h4, h5, h6 { font-size: 1em; margin-top: 0.5em; }
                pre {
                    background-color: #f5f5f5;
                    padding: 12px;
                    border-radius: 4px;
                    overflow-x: auto;
                }
                code {
                    font-family: 'SF Mono', Menlo, Monaco, 'Courier New', monospace;
                    font-size: 0.9em;
                }
                :not(pre) > code {
                    background-color: #f5f5f5;
                    padding: 2px 4px;
                    border-radius: 3px;
                }
                blockquote {
                    border-left: 4px solid #007AFF;
                    margin-left: 0;
                    padding-left: 16px;
                    color: #666;
                    font-style: italic;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 1em 0;
                }
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                }
                th {
                    background-color: #f5f5f5;
                    font-weight: 600;
                }
                a { color: #007AFF; }
                hr {
                    border: none;
                    border-top: 1px solid #ddd;
                    margin: 2em 0;
                }
            </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    /// Render inline runs to HTML
    private static func renderInlineHTML(_ runs: [InlineRun]) -> String {
        var result = ""
        for run in runs {
            var text = escapeHTML(run.text)

            if run.isCode {
                text = "<code>\(text)</code>"
            }
            if run.isBold {
                text = "<strong>\(text)</strong>"
            }
            if run.isItalic {
                text = "<em>\(text)</em>"
            }
            if run.isStrikethrough {
                text = "<del>\(text)</del>"
            }
            if let link = run.link {
                text = "<a href=\"\(escapeHTML(link))\">\(text)</a>"
            }

            result += text
        }
        return result
    }

    /// Create NSAttributedString from markdown content
    private static func createAttributedString(from content: String, title: String) -> NSAttributedString {
        let blocks = MarkdownBlockParser.parse(content)
        let result = NSMutableAttributedString()

        let defaultFont = NSFont.systemFont(ofSize: 12)
        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineSpacing = 4

        for block in blocks {
            switch block.kind {
            case let .heading(level):
                let fontSize: CGFloat = [28, 24, 20, 17, 15, 14][min(level - 1, 5)]
                let font = NSFont.boldSystemFont(ofSize: fontSize)
                let text = block.runs.map(\.text).joined()
                let attr = NSAttributedString(string: text + "\n\n", attributes: [
                    .font: font,
                    .paragraphStyle: defaultParagraph
                ])
                result.append(attr)

            case .paragraph:
                let attr = createAttributedRuns(block.runs, defaultFont: defaultFont)
                result.append(attr)
                result.append(NSAttributedString(string: "\n\n"))

            case let .codeBlock(language):
                let codeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                var codeText = block.code
                if let lang = language, !lang.isEmpty {
                    codeText = "[\(lang)]\n" + codeText
                }
                let attr = NSAttributedString(string: codeText + "\n\n", attributes: [
                    .font: codeFont,
                    .backgroundColor: NSColor.lightGray.withAlphaComponent(0.2)
                ])
                result.append(attr)

            case .blockquote:
                let italicFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: .italicFontMask)
                let text = block.runs.map(\.text).joined()
                let para = NSMutableParagraphStyle()
                para.headIndent = 20
                para.firstLineHeadIndent = 20
                let attr = NSAttributedString(string: text + "\n\n", attributes: [
                    .font: italicFont,
                    .foregroundColor: NSColor.gray,
                    .paragraphStyle: para
                ])
                result.append(attr)

            case .unorderedList:
                for item in block.listItems {
                    let text = "• " + item.map(\.text).joined()
                    let attr = NSAttributedString(string: text + "\n", attributes: [.font: defaultFont])
                    result.append(attr)
                }
                result.append(NSAttributedString(string: "\n"))

            case .orderedList:
                for (index, item) in block.listItems.enumerated() {
                    let text = "\(index + 1). " + item.map(\.text).joined()
                    let attr = NSAttributedString(string: text + "\n", attributes: [.font: defaultFont])
                    result.append(attr)
                }
                result.append(NSAttributedString(string: "\n"))

            case .table:
                for row in block.tableRows {
                    let text = row.map { $0.map(\.text).joined() }.joined(separator: " | ")
                    let attr = NSAttributedString(string: text + "\n", attributes: [.font: defaultFont])
                    result.append(attr)
                }
                result.append(NSAttributedString(string: "\n"))

            case .thematicBreak:
                result.append(NSAttributedString(string: "───────────────────\n\n"))
            }
        }

        return result
    }

    /// Create attributed string from inline runs
    private static func createAttributedRuns(_ runs: [InlineRun], defaultFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for run in runs {
            var font = defaultFont
            var attributes: [NSAttributedString.Key: Any] = [:]

            if run.isBold && run.isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: [.boldFontMask, .italicFontMask])
            } else if run.isBold {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            } else if run.isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }

            if run.isCode {
                font = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
                attributes[.backgroundColor] = NSColor.lightGray.withAlphaComponent(0.2)
            }

            if run.isStrikethrough {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            if let link = run.link, let url = URL(string: link) {
                attributes[.link] = url
                attributes[.foregroundColor] = NSColor.linkColor
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            attributes[.font] = font

            result.append(NSAttributedString(string: run.text, attributes: attributes))
        }

        return result
    }

    /// Escape HTML special characters
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Escape XML special characters
    private static func escapeXML(_ string: String) -> String {
        escapeHTML(string)
    }
}

/// Export errors
enum ExportError: LocalizedError {
    case conversionFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert document to the selected format"
        case .writeFailed:
            return "Failed to write the exported file"
        }
    }
}

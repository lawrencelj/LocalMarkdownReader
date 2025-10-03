/// SyntaxErrorView - Display syntax errors with highlighting
///
/// Provides visual feedback for markdown syntax errors with
/// severity-based styling and jump-to-error navigation.

import SwiftUI
import MarkdownCore

/// View for displaying syntax errors in a document
public struct SyntaxErrorBanner: View {
    let errors: [SyntaxError]
    let onErrorTap: (SyntaxError) -> Void
    @State private var isExpanded = true

    public init(errors: [SyntaxError], onErrorTap: @escaping (SyntaxError) -> Void = { _ in }) {
        self.errors = errors
        self.onErrorTap = onErrorTap
    }

    public var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: severityIcon)
                        .foregroundColor(severityColor)
                        .font(.title3)

                    Text(headerText)
                        .font(.headline)
                        .foregroundColor(severityColor)

                    Spacer()

                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse errors" : "Expand errors")
                }
                .padding()
                .background(severityColor.opacity(0.1))

                // Error List
                if isExpanded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(errors) { error in
                                SyntaxErrorRow(error: error, onTap: onErrorTap)
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(severityColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Document contains \(errors.count) syntax \(errors.count == 1 ? "error" : "errors")")
        }
    }

    private var headerText: String {
        let errorCount = errors.filter { $0.severity == .error }.count
        let warningCount = errors.filter { $0.severity == .warning }.count

        var parts: [String] = []
        if errorCount > 0 {
            parts.append("\(errorCount) \(errorCount == 1 ? "error" : "errors")")
        }
        if warningCount > 0 {
            parts.append("\(warningCount) \(warningCount == 1 ? "warning" : "warnings")")
        }

        return parts.isEmpty ? "Document Issues" : parts.joined(separator: ", ")
    }

    private var severityIcon: String {
        let hasErrors = errors.contains { $0.severity == .error }
        return hasErrors ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill"
    }

    private var severityColor: Color {
        let hasErrors = errors.contains { $0.severity == .error }
        return hasErrors ? .red : .orange
    }
}

/// Individual error row in the banner
struct SyntaxErrorRow: View {
    let error: SyntaxError
    let onTap: (SyntaxError) -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: { onTap(error) }) {
            HStack(alignment: .top, spacing: 12) {
                // Severity Icon
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.body)
                    .frame(width: 20)

                // Error Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Line \(error.line)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if error.column > 0 {
                            Text("Column \(error.column)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(errorTypeText)
                            .font(.caption)
                            .foregroundColor(severityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(severityColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(error.message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(8)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Line \(error.line): \(error.message)")
        .accessibilityHint("Tap to jump to error location")
    }

    private var severityIcon: String {
        switch error.severity {
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch error.severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    private var errorTypeText: String {
        switch error.type {
        case .excessiveNesting:
            return "Nesting"
        case .malformedTable:
            return "Table"
        case .malformedLink:
            return "Link"
        case .dangerousContent:
            return "Security"
        case .fileTooLarge:
            return "Size"
        case .blockedHTML:
            return "HTML"
        case .invalidURL:
            return "URL"
        }
    }
}

/// Inline error indicator for text highlighting
public struct InlineErrorIndicator: View {
    let error: SyntaxError
    @State private var showTooltip = false

    public init(error: SyntaxError) {
        self.error = error
    }

    public var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundColor(severityColor)
            .font(.caption)
            .help(error.message)
            .onHover { hovering in
                showTooltip = hovering
            }
            .accessibilityLabel("Error: \(error.message)")
    }

    private var severityColor: Color {
        switch error.severity {
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
}

/// Error statistics summary
public struct ErrorStatistics: View {
    let errors: [SyntaxError]

    public init(errors: [SyntaxError]) {
        self.errors = errors
    }

    public var body: some View {
        HStack(spacing: 16) {
            if errorCount > 0 {
                StatBadge(
                    icon: "xmark.circle.fill",
                    count: errorCount,
                    label: "Errors",
                    color: .red
                )
            }

            if warningCount > 0 {
                StatBadge(
                    icon: "exclamationmark.triangle.fill",
                    count: warningCount,
                    label: "Warnings",
                    color: .orange
                )
            }

            if infoCount > 0 {
                StatBadge(
                    icon: "info.circle.fill",
                    count: infoCount,
                    label: "Info",
                    color: .blue
                )
            }
        }
    }

    private var errorCount: Int {
        errors.filter { $0.severity == .error }.count
    }

    private var warningCount: Int {
        errors.filter { $0.severity == .warning }.count
    }

    private var infoCount: Int {
        errors.filter { $0.severity == .info }.count
    }
}

struct StatBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) \(label.lowercased())")
    }
}

// MARK: - Preview Support

#if DEBUG
struct SyntaxErrorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Error Banner
            SyntaxErrorBanner(errors: sampleErrors) { error in
                print("Tapped error at line \(error.line)")
            }

            // Statistics
            ErrorStatistics(errors: sampleErrors)

            // Individual indicators
            HStack {
                InlineErrorIndicator(error: sampleErrors[0])
                InlineErrorIndicator(error: sampleErrors[1])
                InlineErrorIndicator(error: sampleErrors[2])
            }
        }
        .padding()
        .frame(width: 600)
    }

    static var sampleErrors: [SyntaxError] {
        [
            SyntaxError(
                line: 15,
                column: 10,
                type: .malformedLink,
                message: "Malformed link syntax - missing closing parenthesis",
                severity: .error
            ),
            SyntaxError(
                line: 23,
                column: 0,
                type: .malformedTable,
                message: "Table row is missing pipe delimiters",
                severity: .warning
            ),
            SyntaxError(
                line: 45,
                column: 5,
                type: .excessiveNesting,
                message: "List nesting level 18 exceeds maximum of 16",
                severity: .warning
            ),
            SyntaxError(
                line: 67,
                column: 12,
                type: .dangerousContent,
                message: "Dangerous protocol detected: javascript:",
                severity: .error
            )
        ]
    }
}
#endif

// FindBarView - Reusable in-pane find bar UI.
//
// Bound to a `FindState`, this bar edits the query and matching toggles and exposes
// next/previous/close actions. It is position-agnostic: the hosting pane places it at
// the user's configured edge (top or bottom). The owning pane observes the same
// `FindState` and recomputes matches/highlights; the bar only reflects `matchCount`,
// `currentIndex`, and `regexInvalid`.
//
// Replace is opt-in: when `onReplace`/`onReplaceAll` are provided (the editable source
// pane), a second row with the replacement field and Replace / Replace All buttons is
// shown. The read-only content pane omits them, so its bar stays find-only.

import SwiftUI

struct FindBarView: View {
    @Bindable var state: FindState
    /// Placeholder shown in the empty query field (e.g. "Find in source").
    var placeholder = "Find"
    /// Invoked for Return / the next button.
    var onNext: () -> Void
    /// Invoked for the previous button.
    var onPrevious: () -> Void
    /// Invoked for Esc / the close button.
    var onClose: () -> Void
    /// When set, shows the replace controls; invoked to replace the current match.
    var onReplace: (() -> Void)?
    /// When set, shows the replace controls; invoked to replace every match.
    var onReplaceAll: (() -> Void)?

    @FocusState private var queryFocused: Bool

    /// Whether the replace row should be shown (only when the host wired replace up).
    private var showsReplace: Bool {
        onReplace != nil || onReplaceAll != nil
    }

    /// Replace actions are only meaningful when there is at least one live match.
    private var canReplace: Bool {
        !state.query.isEmpty && !state.regexInvalid && state.matchCount > 0
    }

    var body: some View {
        VStack(spacing: 6) {
            findRow
            if showsReplace {
                replaceRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onAppear { queryFocused = true }
        #if os(macOS)
            .onExitCommand(perform: onClose)
        #endif
    }

    // MARK: - Find Row

    private var findRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            queryField

            counterLabel
                .frame(minWidth: 64, alignment: .trailing)

            HStack(spacing: 2) {
                stepButton(system: "chevron.up", help: "Previous match (Shift-Return)", action: onPrevious)
                stepButton(system: "chevron.down", help: "Next match (Return)", action: onNext)
            }

            Divider().frame(height: 16)

            HStack(spacing: 2) {
                toggle(label: "Aa", isOn: $state.caseSensitive, help: "Case sensitive")
                toggle(label: "W", isOn: $state.wholeWord, help: "Whole word", disabled: state.useRegex)
                toggle(label: ".*", isOn: $state.useRegex, help: "Regular expression")
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .accessibilityLabel("Close find bar")
        }
    }

    // MARK: - Replace Row

    private var replaceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.2.squarepath")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            replaceField

            Spacer(minLength: 0)

            Button("Replace") { onReplace?() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canReplace || onReplace == nil)
                .help("Replace the current match")
                .accessibilityLabel("Replace current match")

            Button("All") { onReplaceAll?() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canReplace || onReplaceAll == nil)
                .help("Replace all matches")
                .accessibilityLabel("Replace all matches")
        }
    }

    // MARK: - Query Field

    private var queryField: some View {
        TextField(placeholder, text: $state.query)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
        #if os(iOS)
            .textInputAutocapitalization(.never)
        #endif
            .focused($queryFocused)
            .onSubmit(onNext)
            .overlay(alignment: .trailing) {
                if !state.query.isEmpty {
                    Button {
                        state.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search text")
                }
            }
            .frame(minWidth: 120)
    }

    // MARK: - Replace Field

    private var replaceField: some View {
        TextField("Replace with", text: $state.replaceText)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
        #if os(iOS)
            .textInputAutocapitalization(.never)
        #endif
            .onSubmit { onReplace?() }
            .overlay(alignment: .trailing) {
                if !state.replaceText.isEmpty {
                    Button {
                        state.replaceText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear replacement text")
                }
            }
            .frame(minWidth: 120)
    }

    // MARK: - Counter

    @ViewBuilder private var counterLabel: some View {
        if state.regexInvalid {
            Text("Invalid regex")
                .font(.caption)
                .foregroundStyle(.red)
        } else if state.query.isEmpty {
            EmptyView()
        } else if state.matchCount == 0 {
            Text("No results")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("\(state.displayIndex)/\(state.matchCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Buttons

    private func stepButton(system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(state.matchCount == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
        .disabled(state.matchCount == 0)
        .help(help)
    }

    private func toggle(label: String, isOn: Binding<Bool>, help: String, disabled: Bool = false) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 24, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.25) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOn.wrappedValue ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn.wrappedValue ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isOn.wrappedValue ? [.isSelected] : [])
    }
}

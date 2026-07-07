/// FindBarView - Reusable in-pane find bar UI.
///
/// Bound to a `FindState`, this bar edits the query and matching toggles and exposes
/// next/previous/close actions. It is position-agnostic: the hosting pane places it at
/// the user's configured edge (top or bottom). The owning pane observes the same
/// `FindState` and recomputes matches/highlights; the bar only reflects `matchCount`,
/// `currentIndex`, and `regexInvalid`.

import SwiftUI

struct FindBarView: View {
    @Bindable var state: FindState
    /// Placeholder shown in the empty query field (e.g. "Find in source").
    var placeholder: String = "Find"
    /// Invoked for Return / the next button.
    var onNext: () -> Void
    /// Invoked for the previous button.
    var onPrevious: () -> Void
    /// Invoked for Esc / the close button.
    var onClose: () -> Void

    @FocusState private var queryFocused: Bool

    var body: some View {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onAppear { queryFocused = true }
        #if os(macOS)
        .onExitCommand(perform: onClose)
        #endif
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

    // MARK: - Counter

    @ViewBuilder
    private var counterLabel: some View {
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

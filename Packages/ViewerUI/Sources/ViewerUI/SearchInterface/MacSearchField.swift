#if os(macOS)
import AppKit
import SwiftUI

/// NSSearchField wrapper that supports programmatic focus and command handling.
@MainActor
struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    var placeholder: String
    var onSubmit: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onEscape: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField(string: text)
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.target = context.coordinator
        field.action = #selector(Coordinator.submitSearch(_:))
        field.sendsWholeSearchString = true
        field.sendsSearchStringImmediately = true
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        nsView.placeholderString = placeholder

        if isFocused, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let parent: MacSearchField

        init(_ parent: MacSearchField) {
            self.parent = parent
        }

        @objc
        func submitSearch(_ sender: NSSearchField) {
            parent.text = sender.stringValue
            parent.onSubmit?()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.isFocused = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit?()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMoveDown?()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onMoveUp?()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape?()
                return true
            default:
                return false
            }
        }
    }
}
#endif

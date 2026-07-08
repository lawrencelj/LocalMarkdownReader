#if os(macOS)
    import HTMLPreviewSupport
    import SwiftUI

    struct HTMLPreviewView: NSViewRepresentable {
        let html: String
        let baseURL: URL?

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeNSView(context: Context) -> MRHTMLPreviewView {
            let previewView = MRHTMLPreviewView(frame: .zero)
            load(into: previewView, coordinator: context.coordinator)
            return previewView
        }

        func updateNSView(_ previewView: MRHTMLPreviewView, context: Context) {
            guard context.coordinator.lastHTML != html ||
                context.coordinator.lastBaseURL != baseURL else {
                return
            }
            load(into: previewView, coordinator: context.coordinator)
        }

        private func load(into previewView: MRHTMLPreviewView, coordinator: Coordinator) {
            coordinator.lastHTML = html
            coordinator.lastBaseURL = baseURL
            previewView.loadHTMLString(html, baseURL: baseURL)
        }

        final class Coordinator {
            var lastHTML: String?
            var lastBaseURL: URL?
        }
    }
#endif

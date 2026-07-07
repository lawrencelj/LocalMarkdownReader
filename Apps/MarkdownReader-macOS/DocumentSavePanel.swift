import AppKit
import FileAccess
import UniformTypeIdentifiers

enum DocumentSavePanel {
    @MainActor
    static func selectDestination(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Document"
        panel.nameFieldStringValue = suggestedName.isEmpty ? "Untitled.md" : suggestedName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = FileAccessConfiguration.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}

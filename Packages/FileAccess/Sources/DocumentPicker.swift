/// DocumentPicker - Cross-platform document selection
///
/// Provides cross-platform document picking capabilities using
/// UIDocumentPickerViewController on iOS and NSOpenPanel on macOS.

import Foundation
#if os(macOS)
import AppKit
#else
import ObjectiveC
import UIKit
#endif

/// Cross-platform document picker
public actor DocumentPicker {
    /// Document picker configuration
    public struct Configuration: Sendable {
        public let allowedFileTypes: [String]
        public let allowsMultipleSelection: Bool
        public let canChooseDirectories: Bool

        public init(
            allowedFileTypes: [String] = ["md", "markdown", "txt", "text"],
            allowsMultipleSelection: Bool = false,
            canChooseDirectories: Bool = false
        ) {
            self.allowedFileTypes = allowedFileTypes
            self.allowsMultipleSelection = allowsMultipleSelection
            self.canChooseDirectories = canChooseDirectories
        }

        public static let `default` = Configuration()
    }

    private let configuration: Configuration

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Select a document using platform-appropriate picker
    public func selectDocument() async throws -> URL {
        #if os(macOS)
        return try await selectDocumentMacOS()
        #else
        return try await selectDocumentIOS()
        #endif
    }

    /// Select multiple documents
    public func selectDocuments() async throws -> [URL] {
        guard configuration.allowsMultipleSelection else {
            let url = try await selectDocument()
            return [url]
        }

        #if os(macOS)
        return try await selectDocumentsMacOS()
        #else
        return try await selectDocumentsIOS()
        #endif
    }

    /// Save a new document using platform-appropriate save panel
    public func saveDocument(fileName: String = "Untitled.md", initialContent: String = "") async throws -> URL {
        #if os(macOS)
        return try await saveDocumentMacOS(fileName: fileName, initialContent: initialContent)
        #else
        return try await saveDocumentIOS(fileName: fileName, initialContent: initialContent)
        #endif
    }

    // MARK: - macOS Implementation

    #if os(macOS)
    private func selectDocumentMacOS() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = self.configuration.canChooseDirectories
                openPanel.allowsMultipleSelection = false
                openPanel.canCreateDirectories = false
                openPanel.allowedContentTypes = self.configuration.allowedFileTypes.compactMap {
                    UTType(filenameExtension: $0)
                }

                openPanel.begin { response in
                    if response == .OK, let url = openPanel.url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: DocumentPickerError.cancelled)
                    }
                }
            }
        }
    }

    private func selectDocumentsMacOS() async throws -> [URL] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = self.configuration.canChooseDirectories
                openPanel.allowsMultipleSelection = true
                openPanel.canCreateDirectories = false
                openPanel.allowedContentTypes = self.configuration.allowedFileTypes.compactMap {
                    UTType(filenameExtension: $0)
                }

                openPanel.begin { response in
                    if response == .OK {
                        continuation.resume(returning: openPanel.urls)
                    } else {
                        continuation.resume(throwing: DocumentPickerError.cancelled)
                    }
                }
            }
        }
    }

    private func saveDocumentMacOS(fileName: String, initialContent: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let savePanel = NSSavePanel()
                savePanel.canCreateDirectories = true
                savePanel.showsTagField = true
                savePanel.nameFieldStringValue = fileName
                savePanel.allowedContentTypes = self.configuration.allowedFileTypes.compactMap {
                    UTType(filenameExtension: $0)
                }
                
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        do {
                            // Create the file with initial content
                            try initialContent.write(to: url, atomically: true, encoding: .utf8)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: DocumentPickerError.saveFailed(underlying: error))
                        }
                    } else {
                        continuation.resume(throwing: DocumentPickerError.cancelled)
                    }
                }
            }
        }
    }
    #endif

    // MARK: - iOS Implementation

    #if os(iOS)
    private func selectDocumentIOS() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Enhanced iOS safety checks with proper error handling
                guard let windowScene = self.findActiveWindowScene(),
                      let window = self.findKeyWindow(in: windowScene),
                      let rootViewController = self.findRootViewController(in: window) else {
                    continuation.resume(throwing: DocumentPickerError.noRootViewController)
                    return
                }

                let documentTypes = self.configuration.allowedFileTypes.map { "public.\($0)" }
                let picker = UIDocumentPickerViewController(
                    forOpeningContentTypes: documentTypes.compactMap { UTType($0) }
                )

                picker.allowsMultipleSelection = false
                let delegate = DocumentPickerDelegate(
                    singleSelection: { url in
                        continuation.resume(returning: url)
                    },
                    multipleSelection: { _ in
                        // Not used for single selection
                    },
                    cancellation: {
                        continuation.resume(throwing: DocumentPickerError.cancelled)
                    }
                )
                picker.delegate = delegate

                // Retain delegate to prevent premature deallocation
                objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                rootViewController.present(picker, animated: true)
            }
        }
    }

    private func selectDocumentsIOS() async throws -> [URL] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Enhanced iOS safety checks with proper error handling
                guard let windowScene = self.findActiveWindowScene(),
                      let window = self.findKeyWindow(in: windowScene),
                      let rootViewController = self.findRootViewController(in: window) else {
                    continuation.resume(throwing: DocumentPickerError.noRootViewController)
                    return
                }

                let documentTypes = self.configuration.allowedFileTypes.map { "public.\($0)" }
                let picker = UIDocumentPickerViewController(
                    forOpeningContentTypes: documentTypes.compactMap { UTType($0) }
                )

                picker.allowsMultipleSelection = true
                let delegate = DocumentPickerDelegate(
                    singleSelection: { url in
                        continuation.resume(returning: [url])
                    },
                    multipleSelection: { urls in
                        continuation.resume(returning: urls)
                    },
                    cancellation: {
                        continuation.resume(throwing: DocumentPickerError.cancelled)
                    }
                )
                picker.delegate = delegate

                // Retain delegate to prevent premature deallocation
                objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                rootViewController.present(picker, animated: true)
            }
        }
    }

    // MARK: - iOS Safety Helpers

    private func findActiveWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
    }

    private func findKeyWindow(in windowScene: UIWindowScene) -> UIWindow? {
        // Try key window first
        if let keyWindow = windowScene.keyWindow {
            return keyWindow
        }

        // Fallback to first window
        return windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
    }

    private func findRootViewController(in window: UIWindow) -> UIViewController? {
        guard let rootViewController = window.rootViewController else {
            return nil
        }

        // Navigate to the topmost presented view controller
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }

        return topViewController
    }

    
    private func saveDocumentIOS(fileName: String, initialContent: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Enhanced iOS safety checks
                guard let windowScene = self.findActiveWindowScene(),
                      let window = self.findKeyWindow(in: windowScene),
                      let rootViewController = self.findRootViewController(in: window) else {
                    continuation.resume(throwing: DocumentPickerError.noRootViewController)
                    return
                }
                
                // Create temporary file with initial content
                let temporaryDirectory = FileManager.default.temporaryDirectory
                let temporaryFile = temporaryDirectory.appendingPathComponent(fileName)
                
                do {
                    try initialContent.write(to: temporaryFile, atomically: true, encoding: .utf8)
                    
                    let documentTypes = self.configuration.allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
                    let picker = UIDocumentPickerViewController(forExporting: [temporaryFile], asCopy: false)
                    
                    let delegate = DocumentPickerDelegate(
                        singleSelection: { url in
                            // Clean up temporary file
                            try? FileManager.default.removeItem(at: temporaryFile)
                            continuation.resume(returning: url)
                        },
                        multipleSelection: { urls in
                            // Clean up temporary file
                            try? FileManager.default.removeItem(at: temporaryFile)
                            if let url = urls.first {
                                continuation.resume(returning: url)
                            } else {
                                continuation.resume(throwing: DocumentPickerError.saveFailed(underlying: NSError(domain: "DocumentPicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No URL returned"])))
                            }
                        },
                        cancellation: {
                            // Clean up temporary file
                            try? FileManager.default.removeItem(at: temporaryFile)
                            continuation.resume(throwing: DocumentPickerError.cancelled)
                        }
                    )
                    picker.delegate = delegate
                    
                    // Retain delegate
                    objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    
                    rootViewController.present(picker, animated: true)
                } catch {
                    continuation.resume(throwing: DocumentPickerError.saveFailed(underlying: error))
                }
            }
        }
    }
    #endif
}

// MARK: - iOS Document Picker Delegate

#if os(iOS)
private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let singleSelection: (URL) -> Void
    private let multipleSelection: ([URL]) -> Void
    private let cancellation: () -> Void

    init(
        singleSelection: @escaping (URL) -> Void,
        multipleSelection: @escaping ([URL]) -> Void,
        cancellation: @escaping () -> Void
    ) {
        self.singleSelection = singleSelection
        self.multipleSelection = multipleSelection
        self.cancellation = cancellation
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if urls.count == 1 {
            singleSelection(urls[0])
        } else {
            multipleSelection(urls)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        cancellation()
    }
}
#endif

// MARK: - Document Picker Errors

public enum DocumentPickerError: Error, LocalizedError, Sendable {
    case cancelled
    case noRootViewController
    case invalidSelection
    case permissionDenied
    case saveFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Document selection was cancelled"
        case .noRootViewController:
            return "No root view controller available"
        case .invalidSelection:
            return "Invalid document selection"
        case .permissionDenied:
            return "Permission to access documents was denied"
        case .saveFailed(let error):
            return "Failed to save document: \(error.localizedDescription)"
        }
    }
}

// MARK: - UTType Extension

#if os(macOS)
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(filenameExtension: "md") ?? UTType.plainText
    static let text = UTType(filenameExtension: "txt") ?? UTType.plainText
}
#endif

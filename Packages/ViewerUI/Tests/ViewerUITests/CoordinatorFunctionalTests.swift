/// CoordinatorFunctionalTests - Verifies AppStateCoordinator functions

import XCTest
@testable import ViewerUI
@testable import MarkdownCore
@testable import Search

@MainActor
final class CoordinatorFunctionalTests: XCTestCase {

    var coordinator: AppStateCoordinator!

    override func setUp() async throws {
        coordinator = AppStateCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertNil(coordinator.documentState.currentDocument)
        XCTAssertFalse(coordinator.documentState.isLoading)
        XCTAssertNil(coordinator.documentState.parseError)
        XCTAssertEqual(coordinator.searchState.query, "")
        XCTAssertTrue(coordinator.searchState.results.isEmpty)
        XCTAssertFalse(coordinator.searchState.isSearching)
        XCTAssertFalse(coordinator.uiState.isDocumentLoaded)
        XCTAssertTrue(coordinator.uiState.sidebarVisible)
        XCTAssertFalse(coordinator.uiState.searchVisible)
    }

    // MARK: - Document Loading

    func testLoadDocumentFromFile() async throws {
        // Create a temp markdown file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).md")
        let content = "# Test Document\n\nHello world."
        try content.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let reference = DocumentReference(url: testFile, fileSize: Int64(content.count))
        await coordinator.loadDocument(reference)

        XCTAssertNotNil(coordinator.documentState.currentDocument)
        XCTAssertEqual(coordinator.documentState.currentDocument?.title, "Test Document")
        XCTAssertTrue(coordinator.uiState.isDocumentLoaded)
        XCTAssertFalse(coordinator.documentState.isLoading)
    }

    func testLoadDocumentSetsMetadata() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("meta_\(UUID().uuidString).md")
        let content = "# Title\n\nWord one two three four five six seven eight nine ten."
        try content.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let reference = DocumentReference(url: testFile, fileSize: Int64(content.count))
        await coordinator.loadDocument(reference)

        XCTAssertNotNil(coordinator.documentState.documentMetadata)
        XCTAssertGreaterThan(coordinator.documentState.documentMetadata?.wordCount ?? 0, 5)
    }

    func testLoadNonexistentFile() async {
        let reference = DocumentReference(
            url: URL(fileURLWithPath: "/nonexistent/path/file.md"),
            fileSize: 0
        )
        await coordinator.loadDocument(reference)

        XCTAssertNil(coordinator.documentState.currentDocument)
        XCTAssertNotNil(coordinator.documentState.parseError)
        XCTAssertFalse(coordinator.uiState.isDocumentLoaded)
    }

    func testLoadSupportedSourceFiles() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("source_formats_\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fixtures: [(String, String, DocumentFormat)] = [
            ("document.json", #"{"name":"Markdown Reader","enabled":true}"#, .json),
            ("document.xml", #"<?xml version="1.0"?><document><title>Example</title></document>"#, .xml),
            (
                "document.html",
                #"<!doctype html><html><body><h1>Example</h1><script>window.test = true;</script></body></html>"#,
                .html
            ),
            (
                "document.tex",
                #"\documentclass{article}\begin{document}\section{Example}Text\end{document}"#,
                .latex
            )
        ]

        for (filename, content, format) in fixtures {
            let url = tempDirectory.appendingPathComponent(filename)
            try content.write(to: url, atomically: true, encoding: .utf8)

            await coordinator.loadDocument(DocumentReference(url: url))

            XCTAssertEqual(coordinator.documentState.currentDocument?.content, content)
            XCTAssertEqual(coordinator.documentState.currentDocument?.reference.url, url)
            XCTAssertEqual(coordinator.documentState.currentDocument?.format, format)
            XCTAssertTrue(coordinator.uiState.isDocumentLoaded)
            XCTAssertNil(coordinator.documentState.parseError)
        }

        XCTAssertEqual(coordinator.documentState.openDocuments.count, fixtures.count)
    }

    func testLaTeXOutlineDisplaysSectionHierarchy() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outline_\(UUID().uuidString).tex")
        let content = #"""
        \documentclass{article}
        \title{Structured Paper}
        \begin{document}
        \section{Introduction}
        \subsection{Background}
        \subsubsection{Prior Work}
        \section{Conclusion}
        \end{document}
        """#
        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        await coordinator.loadDocument(DocumentReference(url: url))

        XCTAssertEqual(coordinator.documentState.currentDocument?.format, .latex)
        XCTAssertEqual(coordinator.documentState.currentDocument?.title, "Structured Paper")
        XCTAssertEqual(
            coordinator.searchState.outline.map(\.title),
            ["Introduction", "Background", "Prior Work", "Conclusion"]
        )
        XCTAssertEqual(coordinator.searchState.outline.map(\.level), [1, 2, 3, 1])
    }

    func testJSONOutlineDisplaysHighLevelStructure() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outline_\(UUID().uuidString).json")
        let content = """
        {
          "users": [{ "id": 1, "profile": { "name": "Ada" } }],
          "settings": { "enabled": true }
        }
        """
        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        await coordinator.loadDocument(DocumentReference(url: url))

        let items = coordinator.searchState.outline
        XCTAssertEqual(items.first?.title, "Root: object")
        XCTAssertTrue(items.contains { $0.title == "users: array [1]" && $0.level == 2 })
        XCTAssertTrue(items.contains { $0.title == "profile: object" && $0.level == 4 })
        XCTAssertTrue(items.contains { $0.title == "name: string" && $0.level == 5 })
        XCTAssertTrue(items.contains { $0.title == "enabled: boolean" && $0.level == 3 })
    }

    func testXMLOutlineDisplaysElementAndAttributeStructure() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("outline_\(UUID().uuidString).xml")
        let content = """
        <?xml version="1.0"?>
        <catalog>
          <book id="1"><title>First</title><author>Ada</author></book>
          <book id="2"><title>Second</title><author>Grace</author></book>
        </catalog>
        """
        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        await coordinator.loadDocument(DocumentReference(url: url))

        let items = coordinator.searchState.outline
        XCTAssertTrue(items.contains { $0.title == "catalog" && $0.level == 1 })
        XCTAssertEqual(items.filter { $0.title == "book" }.count, 1)
        XCTAssertTrue(items.contains { $0.title == "@id" && $0.level == 3 })
        XCTAssertTrue(items.contains { $0.title == "title" && $0.level == 3 })
        XCTAssertTrue(items.contains { $0.title == "author" && $0.level == 3 })
    }

    func testSavingJSONRefreshesStructuredOutline() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("refresh_outline_\(UUID().uuidString).json")
        try #"{"oldValue":1}"#.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        await coordinator.loadDocument(DocumentReference(url: url))
        await coordinator.saveEditedContent(#"{"newValue":{"nested":true}}"#)

        XCTAssertFalse(coordinator.searchState.outline.contains { $0.title == "oldValue: number" })
        XCTAssertTrue(coordinator.searchState.outline.contains { $0.title == "newValue: object" })
        XCTAssertTrue(coordinator.searchState.outline.contains { $0.title == "nested: boolean" })
    }

    // MARK: - Close Document

    func testCloseDocument() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("close_\(UUID().uuidString).md")
        try "# Test".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let reference = DocumentReference(url: testFile, fileSize: 6)
        await coordinator.loadDocument(reference)
        XCTAssertNotNil(coordinator.documentState.currentDocument)

        coordinator.closeDocument()

        XCTAssertNil(coordinator.documentState.currentDocument)
        XCTAssertFalse(coordinator.uiState.isDocumentLoaded)
        XCTAssertEqual(coordinator.searchState.query, "")
        XCTAssertTrue(coordinator.searchState.results.isEmpty)
    }

    func testCloseOnlyDocumentByTabIndex() async throws {
        let testFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("close_only_\(UUID().uuidString).md")
        try "# Only Document".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        await coordinator.loadDocument(DocumentReference(url: testFile))
        XCTAssertEqual(coordinator.documentState.openDocuments.count, 1)

        coordinator.closeDocument(at: 0)

        XCTAssertTrue(coordinator.documentState.openDocuments.isEmpty)
        XCTAssertNil(coordinator.documentState.currentDocument)
        XCTAssertFalse(coordinator.uiState.isDocumentLoaded)
        XCTAssertNil(coordinator.documentState.compareDocument)
        XCTAssertFalse(coordinator.documentState.isCompareMode)
    }

    func testOpeningEquivalentFileURLDoesNotDuplicateDocument() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deduplicate_\(UUID().uuidString)")
        let originalFile = tempDirectory.appendingPathComponent("document.md")
        let symbolicLink = tempDirectory.appendingPathComponent("document-link.md")

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        try "# One Document".write(to: originalFile, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: symbolicLink,
            withDestinationURL: originalFile
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        await coordinator.loadDocument(DocumentReference(url: originalFile))
        await coordinator.loadDocument(DocumentReference(url: symbolicLink))

        XCTAssertEqual(coordinator.documentState.openDocuments.count, 1)
        XCTAssertEqual(coordinator.documentState.activeDocumentIndex, 0)
    }

    // MARK: - New and Save As

    func testCreateNewDocumentStartsUntitled() async {
        await coordinator.createNewDocument()

        XCTAssertEqual(coordinator.documentState.openDocuments.count, 1)
        XCTAssertEqual(coordinator.documentState.currentDocument?.content, "")
        XCTAssertEqual(coordinator.uiState.editorContent, "")
        XCTAssertTrue(coordinator.uiState.isDocumentLoaded)
        XCTAssertTrue(coordinator.currentDocumentRequiresSaveAs)

        if let url = coordinator.documentState.currentDocument?.reference.url {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testSaveUntitledDocumentToSelectedDestination() async throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("new_document_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: destination) }

        await coordinator.createNewDocument()
        await coordinator.saveEditedContent("# New Document\n\nSaved content.", to: destination)

        XCTAssertEqual(
            try String(contentsOf: destination, encoding: .utf8),
            "# New Document\n\nSaved content."
        )
        XCTAssertEqual(coordinator.documentState.currentDocument?.reference.url, destination)
        XCTAssertEqual(coordinator.documentState.currentDocument?.title, "New Document")
        XCTAssertFalse(coordinator.currentDocumentRequiresSaveAs)
        XCTAssertFalse(coordinator.uiState.hasUnsavedChanges)
    }

    func testSaveAsCreatesNewFileWithoutChangingOriginal() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("save_as_\(UUID().uuidString)")
        let original = tempDirectory.appendingPathComponent("original.md")
        let destination = tempDirectory.appendingPathComponent("copy.md")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        try "# Original".write(to: original, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        await coordinator.loadDocument(DocumentReference(url: original))
        await coordinator.saveEditedContent("# Edited Copy", to: destination)

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "# Original")
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "# Edited Copy")
        XCTAssertEqual(coordinator.documentState.currentDocument?.reference.url, destination)
        XCTAssertEqual(coordinator.documentState.openDocuments.count, 1)
    }

    // MARK: - Search

    func testPerformSearch() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("search_\(UUID().uuidString).md")
        let content = "# Search Test\n\nThis document contains the word apple and banana."
        try content.write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let reference = DocumentReference(url: testFile, fileSize: Int64(content.count))
        await coordinator.loadDocument(reference)

        await coordinator.performSearch("apple")

        XCTAssertEqual(coordinator.searchState.query, "apple")
        XCTAssertGreaterThan(coordinator.searchState.results.count, 0)
    }

    func testSearchEmptyQuery() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("empty_\(UUID().uuidString).md")
        try "# Test\n\nContent.".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let reference = DocumentReference(url: testFile, fileSize: 20)
        await coordinator.loadDocument(reference)

        await coordinator.performSearch("")

        XCTAssertTrue(coordinator.searchState.results.isEmpty)
    }

    // MARK: - UI State

    func testToggleSearchVisibility() {
        XCTAssertFalse(coordinator.uiState.searchVisible)
        coordinator.uiState.searchVisible = true
        XCTAssertTrue(coordinator.uiState.searchVisible)
        coordinator.uiState.searchVisible = false
        XCTAssertFalse(coordinator.uiState.searchVisible)
    }

    func testToggleSidebarVisibility() {
        XCTAssertTrue(coordinator.uiState.sidebarVisible)
        coordinator.uiState.sidebarVisible = false
        XCTAssertFalse(coordinator.uiState.sidebarVisible)
    }

    func testZoomLevel() {
        XCTAssertEqual(coordinator.documentState.zoomLevel, 1.0)
        coordinator.documentState.zoomLevel = 1.5
        XCTAssertEqual(coordinator.documentState.zoomLevel, 1.5)
    }

    // MARK: - State Persistence

    func testSaveAndRestoreState() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("persist_\(UUID().uuidString).md")
        try "# Persist Test".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }

        let reference = DocumentReference(url: testFile, fileSize: 14)
        await coordinator.loadDocument(reference)
        await coordinator.saveState()

        // State was saved - verify no crash
        XCTAssertTrue(true)
    }

    // MARK: - Recent Files

    func testRecentFiles() async {
        // Clear any existing recent files first
        await coordinator.userPreferences.clearRecentFiles()
        XCTAssertTrue(coordinator.userPreferences.recentFiles.isEmpty)

        let ref = DocumentReference(url: URL(fileURLWithPath: "/tmp/recent_\(UUID().uuidString).md"), fileSize: 100)
        await coordinator.userPreferences.addRecentFile(ref)

        XCTAssertEqual(coordinator.userPreferences.recentFiles.count, 1)
    }

    func testRecentFilesLimit() async {
        for i in 0..<25 {
            let ref = DocumentReference(url: URL(fileURLWithPath: "/tmp/file\(i).md"), fileSize: 100)
            await coordinator.userPreferences.addRecentFile(ref)
        }

        XCTAssertLessThanOrEqual(coordinator.userPreferences.recentFiles.count, 20)
    }

    // MARK: - Initialize

    func testInitialize() async {
        await coordinator.initialize()
        // Should not crash
        XCTAssertTrue(true)
    }
}

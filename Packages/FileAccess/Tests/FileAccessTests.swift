// FileAccessTests - Unit tests for the FileAccess package
//
// Covers deterministic, side-effect-free behavior of SecurityManager,
// RecentDocuments, FileMetadata, FileAccessConfiguration and the error
// types. Tests deliberately avoid the sandbox-only security-scoped access
// paths (which are non-deterministic in an unsandboxed test process) and
// exercise only outcomes that are stable across environments.

@testable import FileAccess
import XCTest

final class FileAccessTests: XCTestCase {
    // MARK: - Helpers

    /// Writes `content` to a unique temp file and returns its URL.
    /// Input: UTF-8 string (arbitrary length). Output: file URL that exists on disk.
    private func makeTempFile(content: String = "hello") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try content.data(using: .utf8)!.write(to: url)
        return url
    }

    // MARK: - SecurityManager

    /// Function: SecurityManager.canAccessFile(_:)
    /// Input: URL to a path that does not exist. Output: Bool == false.
    func testCanAccessFileReturnsFalseForMissingFile() async {
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).md")
        let result = await SecurityManager.shared.canAccessFile(missing)
        XCTAssertFalse(result)
    }

    /// Function: SecurityManager.getAccessInfo(for:)
    /// Input: URL never tracked. Output: Optional<AccessInfo> == nil.
    func testGetAccessInfoNilForUntrackedURL() async {
        let url = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).md")
        let info = await SecurityManager.shared.getAccessInfo(for: url)
        XCTAssertNil(info)
    }

    /// Function: SecurityManager.validateBookmark(_:)
    /// Input: Data that is not a valid bookmark (3 bytes). Output: Bool == false.
    func testValidateBookmarkFalseForGarbage() async {
        let garbage = Data([0x00, 0x01, 0x02])
        let valid = await SecurityManager.shared.validateBookmark(garbage)
        XCTAssertFalse(valid)
    }

    /// Function: SecurityManager.validateBookmarks(_:)
    /// Input: Array of 2 invalid bookmark Data values. Output: [Bool] == [false, false].
    func testValidateBookmarksMapsEachEntry() async {
        let bookmarks = [Data([0x00]), Data([0xFF, 0xFE])]
        let results = await SecurityManager.shared.validateBookmarks(bookmarks)
        XCTAssertEqual(results, [false, false])
    }

    /// Function: SecurityManager.resolveBookmark(_:)
    /// Input: invalid bookmark Data. Output: throws (bookmarkResolutionFailed or bookmarkStale).
    func testResolveBookmarkThrowsForInvalidData() async {
        do {
            _ = try await SecurityManager.shared.resolveBookmark(Data([0x01, 0x02, 0x03]))
            XCTFail("Expected resolveBookmark to throw for invalid data")
        } catch {
            XCTAssertTrue(error is SecurityError)
        }
    }

    // MARK: - AccessInfo / AccessStatistics

    /// Function: AccessInfo.init(isActive:lastAccessed:)
    /// Input: isActive true + a Date. Output: stored values readable back.
    func testAccessInfoInitStoresValues() {
        let now = Date()
        let info = AccessInfo(isActive: true, lastAccessed: now)
        XCTAssertTrue(info.isActive)
        XCTAssertEqual(info.lastAccessed, now)
    }

    /// Function: AccessStatistics.init(totalTracked:activeAccess:inactiveAccess:)
    /// Input: three Ints. Output: stored values readable back.
    func testAccessStatisticsInitStoresValues() {
        let stats = AccessStatistics(totalTracked: 5, activeAccess: 2, inactiveAccess: 3)
        XCTAssertEqual(stats.totalTracked, 5)
        XCTAssertEqual(stats.activeAccess, 2)
        XCTAssertEqual(stats.inactiveAccess, 3)
    }

    // MARK: - Errors

    /// Function: SecurityError.errorDescription
    /// Input: each enum case. Output: non-nil, non-empty String for every case.
    func testSecurityErrorDescriptionsPresent() {
        let underlying = NSError(domain: "test", code: 1)
        let cases: [SecurityError] = [
            .accessFailed,
            .bookmarkCreationFailed(underlying: underlying),
            .bookmarkResolutionFailed(underlying: underlying),
            .bookmarkStale,
            .permissionDenied,
            .securityScopeExpired
        ]
        for error in cases {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    /// Function: FileAccessError.errorDescription
    /// Input: each enum case. Output: non-nil, non-empty String for every case.
    func testFileAccessErrorDescriptionsPresent() {
        let underlying = NSError(domain: "test", code: 1)
        let cases: [FileAccessError] = [
            .fileNotFound,
            .accessDenied,
            .fileTooLarge(maxSize: 1024),
            .unsupportedFileType,
            .readFailed(underlying: underlying),
            .bookmarkCreationFailed,
            .bookmarkResolutionFailed,
            .securityScopeFailure
        ]
        for error in cases {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - FileAccessConfiguration

    /// Function: FileAccessConfiguration static constants.
    /// Input: none. Output: documented fixed values.
    func testFileAccessConfigurationConstants() {
        XCTAssertEqual(FileAccessConfiguration.maxFileSize, 2 * 1024 * 1024)
        XCTAssertEqual(FileAccessConfiguration.maxRecentDocuments, 20)
        XCTAssertTrue(FileAccessConfiguration.supportedExtensions.contains("md"))
        XCTAssertTrue(FileAccessConfiguration.supportedExtensions.contains("markdown"))
    }

    // MARK: - FileMetadata

    /// Function: FileMetadata.from(url:)
    /// Input: URL to a real temp file containing 11 bytes. Output: metadata with
    /// matching name, size == 11, isDirectory false, isReadable true.
    func testFileMetadataFromRealFile() async throws {
        let url = try makeTempFile(content: "hello world") // 11 bytes
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try await FileMetadata.from(url: url)
        XCTAssertEqual(metadata.name, url.lastPathComponent)
        XCTAssertEqual(metadata.size, 11)
        XCTAssertFalse(metadata.isDirectory)
        XCTAssertTrue(metadata.isReadable)
    }

    /// Function: FileMetadata.from(url:)
    /// Input: URL to a directory. Output: metadata with isDirectory == true.
    func testFileMetadataFromDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let metadata = try await FileMetadata.from(url: dir)
        XCTAssertTrue(metadata.isDirectory)
    }

    // MARK: - RecentDocuments

    /// Builds a RecentDocuments backed by an isolated, empty UserDefaults suite.
    private func makeRecentDocuments() -> (RecentDocuments, UserDefaults, String) {
        let suite = "FileAccessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (RecentDocuments(userDefaults: defaults), defaults, suite)
    }

    /// Function: RecentDocuments.getRecentDocuments() on a fresh store.
    /// Input: isolated empty UserDefaults. Output: [] (empty array).
    func testRecentDocumentsStartsEmpty() {
        let (recents, defaults, suite) = makeRecentDocuments()
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(recents.getRecentDocuments().isEmpty)
    }

    /// Function: RecentDocuments.contains(_:) / getBookmark(for:) on empty store.
    /// Input: an arbitrary URL not present. Output: contains == false, bookmark == nil.
    func testRecentDocumentsContainsAndBookmarkQueriesOnEmpty() {
        let (recents, defaults, suite) = makeRecentDocuments()
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).md")
        XCTAssertFalse(recents.contains(url))
        XCTAssertNil(recents.getBookmark(for: url))
    }

    /// Function: RecentDocuments.removeRecentDocument(_:) / clearRecentDocuments().
    /// Input: calls on an empty store. Output: no crash, store remains empty.
    func testRecentDocumentsRemoveAndClearAreSafeOnEmpty() {
        let (recents, defaults, suite) = makeRecentDocuments()
        defer { defaults.removePersistentDomain(forName: suite) }
        recents.removeRecentDocument(URL(fileURLWithPath: "/tmp/none.md"))
        recents.removeRecentDocument(id: UUID())
        recents.clearRecentDocuments()
        XCTAssertTrue(recents.getRecentDocuments().isEmpty)
    }

    /// Function: RecentDocuments.RecentDocument value semantics.
    /// Input: two documents built from the same URL. Output: distinct ids (not equal),
    /// displayName defaults to the URL's last path component.
    func testRecentDocumentIdentityAndDisplayName() {
        let url = URL(fileURLWithPath: "/tmp/report.md")
        let first = RecentDocuments.RecentDocument(url: url)
        let second = RecentDocuments.RecentDocument(url: url)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.displayName, "report.md")
    }

    /// Function: RecentDocuments.RecentDocument Codable round-trip.
    /// Input: a document encoded then decoded via JSON. Output: id preserved.
    func testRecentDocumentCodableRoundTrip() throws {
        let doc = RecentDocuments.RecentDocument(url: URL(fileURLWithPath: "/tmp/a.md"))
        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(RecentDocuments.RecentDocument.self, from: data)
        XCTAssertEqual(decoded.id, doc.id)
        XCTAssertEqual(decoded.displayName, doc.displayName)
    }

    // MARK: - FileAccess entry point

    /// Function: FileAccess.version / FileAccess.initialize()
    /// Input: none. Output: version == "1.0.0"; initialize() completes without throwing.
    func testFileAccessInitialize() async {
        XCTAssertEqual(FileAccess.version, "1.0.0")
        await FileAccess.initialize()
    }
}

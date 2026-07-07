/// RecentDocuments - Recent files management
///
/// Manages a list of recently opened documents with privacy protection
/// and persistence across app sessions.

import Foundation

/// Recent documents manager with privacy protection
public class RecentDocuments: ObservableObject {
    /// Recent document item
    public struct RecentDocument: Codable, Identifiable, Hashable {
        public let id: UUID
        public let url: URL
        public let bookmark: Data?
        public let lastAccessed: Date
        public let displayName: String
        public let fileSize: Int64

        public init(
            url: URL,
            bookmark: Data? = nil,
            lastAccessed: Date = Date(),
            displayName: String? = nil,
            fileSize: Int64 = 0
        ) {
            self.id = UUID()
            self.url = url
            self.bookmark = bookmark
            self.lastAccessed = lastAccessed
            self.displayName = displayName ?? url.lastPathComponent
            self.fileSize = fileSize
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public static func == (lhs: RecentDocument, rhs: RecentDocument) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published private var recentDocuments: [RecentDocument] = []
    private let userDefaults: UserDefaults
    private let storageKey = "MarkdownReader.RecentDocuments"
    private let maxRecentDocuments: Int

    public init(
        userDefaults: UserDefaults = .standard,
        maxRecentDocuments: Int = FileAccessConfiguration.maxRecentDocuments
    ) {
        self.userDefaults = userDefaults
        self.maxRecentDocuments = maxRecentDocuments
        loadRecentDocuments()
    }

    // MARK: - Public Interface

    /// Get list of recent document URLs (for frontend compatibility)
    public func getRecentDocuments() -> [URL] {
        return recentDocuments.map { $0.url }
    }

    /// Get detailed recent documents
    public func getRecentDocumentDetails() -> [RecentDocument] {
        return recentDocuments
    }

    /// Add document to recent list
    public func addRecentDocument(_ url: URL) {
        Task { @MainActor in
            await addRecentDocumentAsync(url)
        }
    }

    /// Add document with security-scoped bookmark
    public func addRecentDocument(_ url: URL, bookmark: Data?) {
        Task { @MainActor in
            await addRecentDocumentWithBookmark(url, bookmark: bookmark)
        }
    }

    /// Remove document from recent list
    public func removeRecentDocument(_ url: URL) {
        recentDocuments.removeAll { $0.url == url }
        saveRecentDocuments()
    }

    /// Remove document by ID
    public func removeRecentDocument(id: UUID) {
        recentDocuments.removeAll { $0.id == id }
        saveRecentDocuments()
    }

    /// Clear all recent documents
    public func clearRecentDocuments() {
        recentDocuments.removeAll()
        saveRecentDocuments()
    }

    /// Update last accessed time for document
    public func updateLastAccessed(_ url: URL) {
        if let index = recentDocuments.firstIndex(where: { $0.url == url }) {
            let document = recentDocuments[index]
            let updated = RecentDocument(
                url: document.url,
                bookmark: document.bookmark,
                lastAccessed: Date(),
                displayName: document.displayName,
                fileSize: document.fileSize
            )
            recentDocuments[index] = updated

            // Move to front
            recentDocuments.remove(at: index)
            recentDocuments.insert(updated, at: 0)

            saveRecentDocuments()
        }
    }

    /// Check if document is in recent list
    public func contains(_ url: URL) -> Bool {
        return recentDocuments.contains { $0.url == url }
    }

    /// Get bookmark data for URL
    public func getBookmark(for url: URL) -> Data? {
        return recentDocuments.first { $0.url == url }?.bookmark
    }

    // MARK: - Private Implementation

    @MainActor
    private func addRecentDocumentAsync(_ url: URL) async {
        await addRecentDocumentWithBookmark(url, bookmark: nil)
    }

    @MainActor
    private func addRecentDocumentWithBookmark(_ url: URL, bookmark: Data?) async {
        // Remove existing entry if present
        recentDocuments.removeAll { $0.url == url }

        // Get file metadata
        let metadata = try? await FileMetadata.from(url: url)

        // Create new recent document
        let recentDocument = RecentDocument(
            url: url,
            bookmark: bookmark,
            lastAccessed: Date(),
            displayName: metadata?.name ?? url.lastPathComponent,
            fileSize: metadata?.size ?? 0
        )

        // Add to front of list
        recentDocuments.insert(recentDocument, at: 0)

        // Maintain maximum count
        if recentDocuments.count > maxRecentDocuments {
            recentDocuments = Array(recentDocuments.prefix(maxRecentDocuments))
        }

        saveRecentDocuments()
    }

    private func loadRecentDocuments() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([RecentDocument].self, from: data)
            // Validate that files still exist and are accessible
            self.recentDocuments = decoded.filter { validateRecentDocument($0) }
        } catch {
            // If decoding fails, start fresh
            self.recentDocuments = []
        }
    }

    private func saveRecentDocuments() {
        do {
            let data = try JSONEncoder().encode(recentDocuments)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // Handle encoding error silently
        }
    }

    private func validateRecentDocument(_ document: RecentDocument) -> Bool {
        // Basic validation - check if file exists
        if document.url.isFileURL {
            return FileManager.default.fileExists(atPath: document.url.path)
        }

        // For non-file URLs, assume valid
        return true
    }
}

// MARK: - Preview Support

extension RecentDocuments {
    /// Create preview instance with sample data
    public static var preview: RecentDocuments {
        let instance = RecentDocuments(userDefaults: UserDefaults())

        // Add sample documents
        let sampleURLs = [
            URL(fileURLWithPath: "/tmp/sample1.md"),
            URL(fileURLWithPath: "/tmp/sample2.md"),
            URL(fileURLWithPath: "/tmp/sample3.md")
        ]

        for url in sampleURLs {
            instance.addRecentDocument(url)
        }

        return instance
    }

    /// Empty preview instance
    public static var previewEmpty: RecentDocuments {
        return RecentDocuments(userDefaults: UserDefaults())
    }
}
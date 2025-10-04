/// RecentDocuments - Recent files management
///
/// Manages a list of recently opened documents with enhanced privacy protection,
/// secure storage, and OWASP Mobile Top 10 compliance.

import CryptoKit
import Foundation
import os.log

/// Recent documents manager with enhanced privacy protection and security
@MainActor
public class RecentDocuments: ObservableObject {
    // MARK: - Security Enhancement

    private let logger = Logger(subsystem: "com.markdownreader.fileaccess", category: "recent-documents")
    private let encryptionKey: SymmetricKey
    private static let keyIdentifier = "RecentDocuments.EncryptionKey"
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

        // Initialize encryption key for secure storage
        self.encryptionKey = Self.getOrCreateEncryptionKey()

        loadRecentDocuments()

        logger.info("RecentDocuments initialized with encryption")
    }

    // MARK: - Public Interface

    /// Get list of recent document URLs (for frontend compatibility)
    public func getRecentDocuments() -> [URL] {
        recentDocuments.map { $0.url }
    }

    /// Get detailed recent documents
    public func getRecentDocumentDetails() -> [RecentDocument] {
        recentDocuments
    }

    /// Add document to recent list with security validation
    public func addRecentDocument(_ url: URL) {
        // Input validation
        guard url.isFileURL,
              !url.path.contains("../"), // Path traversal protection
              !url.path.hasPrefix("/System/"), // System protection
              !url.path.hasPrefix("/private/") else { // Private area protection
            logger.warning("Rejected potentially unsafe URL for recent documents: \(url.path, privacy: .private)")
            return
        }

        addRecentDocumentWithBookmark(url, bookmark: nil)
    }

    /// Add document with security-scoped bookmark
    public func addRecentDocument(_ url: URL, bookmark: Data?) {
        addRecentDocumentWithBookmark(url, bookmark: bookmark)
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
        recentDocuments.contains { $0.url == url }
    }

    /// Get bookmark data for URL
    public func getBookmark(for url: URL) -> Data? {
        recentDocuments.first { $0.url == url }?.bookmark
    }

    // MARK: - Private Implementation

    private func addRecentDocumentWithBookmark(_ url: URL, bookmark: Data?) {
        // Remove existing entry if present
        recentDocuments.removeAll { $0.url == url }

        // Get file metadata
        let metadata = try? FileMetadata.from(url: url)

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
        guard let encryptedData = userDefaults.data(forKey: storageKey) else {
            logger.info("No existing recent documents found")
            return
        }

        do {
            // Decrypt the stored data
            let decryptedData = try Self.decryptData(encryptedData, with: encryptionKey)
            let decoded = try JSONDecoder().decode([RecentDocument].self, from: decryptedData)

            // Validate that files still exist and are accessible
            let validDocuments = decoded.filter { validateRecentDocument($0) }
            self.recentDocuments = validDocuments

            logger.info("Loaded \(validDocuments.count) valid recent documents (\(decoded.count - validDocuments.count) removed)")

            // If we filtered out documents, save the cleaned list
            if validDocuments.count != decoded.count {
                saveRecentDocuments()
            }
        } catch {
            // If decoding fails, start fresh but log the error
            logger.error("Failed to load recent documents: \(error.localizedDescription)")
            self.recentDocuments = []
        }
    }

    private func saveRecentDocuments() {
        do {
            let jsonData = try JSONEncoder().encode(recentDocuments)

            // Encrypt the data before storage
            let encryptedData = try Self.encryptData(jsonData, with: encryptionKey)
            userDefaults.set(encryptedData, forKey: storageKey)

            logger.info("Saved \(self.recentDocuments.count) recent documents (encrypted)")
        } catch {
            logger.error("Failed to save recent documents: \(error.localizedDescription)")
        }
    }

    private func validateRecentDocument(_ document: RecentDocument) -> Bool {
        // Enhanced validation with security checks
        guard document.url.isFileURL else {
            logger.warning("Invalid non-file URL in recent documents")
            return false
        }

        // Path traversal protection
        guard !document.url.path.contains("../"),
              !document.url.path.hasPrefix("/System/"),
              !document.url.path.hasPrefix("/private/") else {
            logger.warning("Potentially dangerous path in recent documents: \(document.url.path, privacy: .private)")
            return false
        }

        // File existence check
        let exists = FileManager.default.fileExists(atPath: document.url.path)
        if !exists {
            logger.info("File no longer exists, removing from recent documents")
        }

        return exists
    }
    // MARK: - Encryption Support

    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        // Try to load existing key from Keychain
        if let keyData = loadKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        }

        // Create new key
        let newKey = SymmetricKey(size: .bits256)
        saveKeyToKeychain(newKey.withUnsafeBytes { Data($0) })
        return newKey
    }

    private static func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess ? result as? Data : nil
    }

    private static func saveKeyToKeychain(_ keyData: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyIdentifier,
            kSecValueData as String: keyData
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func encryptData(_ data: Data, with key: SymmetricKey) throws -> Data {
        let sealedData = try AES.GCM.seal(data, using: key)
        return sealedData.combined!
    }

    private static func decryptData(_ encryptedData: Data, with key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
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
        RecentDocuments(userDefaults: UserDefaults())
    }
}

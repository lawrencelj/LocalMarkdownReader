// SecurityManager - Security-scoped bookmark management
//
// Manages security-scoped bookmarks for sandboxed file access,
// ensuring secure and persistent file access across app sessions.

import Foundation

/// Security manager for sandboxed file access
public actor SecurityManager {
    public static let shared = SecurityManager()

    private var accessTracker: [URL: AccessInfo] = [:]
    private var isInitialized = false

    private init() {}

    // MARK: - Security-Scoped Access

    /// Initialize security manager
    public func initialize() {
        isInitialized = true
    }

    /// Check if file can be accessed
    public func canAccessFile(_ url: URL) -> Bool {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        // Check if we have active access
        if let accessInfo = accessTracker[url] {
            return accessInfo.isActive
        }

        // Try to access file
        let hasAccess = url.startAccessingSecurityScopedResource()
        if hasAccess {
            accessTracker[url] = AccessInfo(isActive: true, lastAccessed: Date())
            url.stopAccessingSecurityScopedResource()
        }

        return hasAccess
    }

    /// Create security-scoped bookmark for URL
    public func createBookmark(for url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityError.accessFailed
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Track bookmark creation
            accessTracker[url] = AccessInfo(isActive: false, lastAccessed: Date())

            return bookmark
        } catch {
            throw SecurityError.bookmarkCreationFailed(underlying: error)
        }
    }

    /// Resolve security-scoped bookmark
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                throw SecurityError.bookmarkStale
            }

            // Update access tracker
            accessTracker[url] = AccessInfo(isActive: false, lastAccessed: Date())

            return url
        } catch {
            throw SecurityError.bookmarkResolutionFailed(underlying: error)
        }
    }

    /// Start accessing security-scoped resource
    public func startAccessing(_ url: URL) -> Bool {
        let success = url.startAccessingSecurityScopedResource()

        if success {
            accessTracker[url] = AccessInfo(isActive: true, lastAccessed: Date())
        }

        return success
    }

    /// Stop accessing security-scoped resource
    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()

        if var accessInfo = accessTracker[url] {
            accessInfo.isActive = false
            accessTracker[url] = accessInfo
        }
    }

    /// Clean up expired access tracking
    public func cleanupExpiredAccess() {
        let now = Date()
        let expirationInterval: TimeInterval = 60 * 60 // 1 hour

        accessTracker = accessTracker.filter { url, accessInfo in
            let isExpired = now.timeIntervalSince(accessInfo.lastAccessed) > expirationInterval

            if isExpired && accessInfo.isActive {
                // Stop accessing expired resources
                url.stopAccessingSecurityScopedResource()
            }

            return !isExpired
        }
    }

    /// Get access information for URL
    public func getAccessInfo(for url: URL) -> AccessInfo? {
        accessTracker[url]
    }

    /// Validate bookmark is still valid
    public func validateBookmark(_ bookmark: Data) -> Bool {
        do {
            var isStale = false
            _ = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return !isStale
        } catch {
            return false
        }
    }

    // MARK: - Access Management

    /// Perform operation with security-scoped access
    public func withSecurityScopedAccess<T>(
        to url: URL,
        operation: () async throws -> T
    ) async throws -> T {
        guard startAccessing(url) else {
            throw SecurityError.accessFailed
        }

        defer {
            stopAccessing(url)
        }

        return try await operation()
    }

    /// Perform operation with bookmark resolution
    public func withBookmarkAccess<T>(
        bookmark: Data,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let url = try resolveBookmark(bookmark)

        return try await withSecurityScopedAccess(to: url) {
            try await operation(url)
        }
    }
}

// MARK: - Supporting Types

/// Access tracking information
public struct AccessInfo: Sendable {
    public var isActive: Bool
    public let lastAccessed: Date

    public init(isActive: Bool, lastAccessed: Date) {
        self.isActive = isActive
        self.lastAccessed = lastAccessed
    }
}

/// Security-related errors
public enum SecurityError: Error, LocalizedError, Sendable {
    case accessFailed
    case bookmarkCreationFailed(underlying: Error)
    case bookmarkResolutionFailed(underlying: Error)
    case bookmarkStale
    case permissionDenied
    case securityScopeExpired

    public var errorDescription: String? {
        switch self {
        case .accessFailed:
            return "Failed to access security-scoped resource"
        case let .bookmarkCreationFailed(underlying):
            return "Failed to create bookmark: \(underlying.localizedDescription)"
        case let .bookmarkResolutionFailed(underlying):
            return "Failed to resolve bookmark: \(underlying.localizedDescription)"
        case .bookmarkStale:
            return "Security-scoped bookmark is stale"
        case .permissionDenied:
            return "Permission to access file was denied"
        case .securityScopeExpired:
            return "Security scope has expired"
        }
    }
}

// MARK: - Security Manager Extensions

public extension SecurityManager {
    /// Batch validate multiple bookmarks
    func validateBookmarks(_ bookmarks: [Data]) -> [Bool] {
        bookmarks.map { validateBookmark($0) }
    }

    /// Create bookmarks for multiple URLs
    func createBookmarks(for urls: [URL]) -> [Result<Data, Error>] {
        urls.map { url in
            do {
                let bookmark = try createBookmark(for: url)
                return .success(bookmark)
            } catch {
                return .failure(error)
            }
        }
    }

    /// Get statistics about current access tracking
    func getAccessStatistics() -> AccessStatistics {
        let activeCount = accessTracker.values.filter { $0.isActive }.count
        let totalCount = accessTracker.count

        return AccessStatistics(
            totalTracked: totalCount,
            activeAccess: activeCount,
            inactiveAccess: totalCount - activeCount
        )
    }
}

/// Access statistics
public struct AccessStatistics: Sendable {
    public let totalTracked: Int
    public let activeAccess: Int
    public let inactiveAccess: Int

    public init(totalTracked: Int, activeAccess: Int, inactiveAccess: Int) {
        self.totalTracked = totalTracked
        self.activeAccess = activeAccess
        self.inactiveAccess = inactiveAccess
    }
}

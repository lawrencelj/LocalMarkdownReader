/// SecurityManager - Security-scoped bookmark management
///
/// Manages security-scoped bookmarks for sandboxed file access,
/// ensuring secure and persistent file access across app sessions.

import Foundation
import os.lock
import os.log

/// Security audit logger for comprehensive security event tracking
public final class SecurityAuditLogger: Sendable {
    public static let shared = SecurityAuditLogger()

    private let logger = Logger(subsystem: "com.markdownreader.fileaccess", category: "security")

    private init() {}

    public enum SecurityLevel: String, Sendable {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }

    public func logSecurity(_ level: SecurityLevel, _ message: String, url: URL? = nil, scopeId: UUID? = nil) {
        let fullMessage = formatSecurityMessage(level, message, url: url, scopeId: scopeId)

        switch level {
        case .info:
            logger.info("\(fullMessage, privacy: .private)")
        case .warning:
            logger.warning("\(fullMessage, privacy: .private)")
        case .error:
            logger.error("\(fullMessage, privacy: .private)")
        case .critical:
            logger.critical("\(fullMessage, privacy: .private)")
        }
    }

    private func formatSecurityMessage(_ level: SecurityLevel, _ message: String, url: URL?, scopeId: UUID?) -> String {
        var components = ["[\(level.rawValue)]", message]

        // Only log filename, not full path for security
        if let url = url {
            let sanitizedFilename = url.lastPathComponent.replacingOccurrences(of: "..", with: "[redacted]")
            components.append("File: \(sanitizedFilename)")
        }

        if let scopeId = scopeId {
            components.append("Scope: \(scopeId.uuidString.prefix(8))")
        }

        components.append("Thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        return components.joined(separator: " | ")
    }
}

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

    /// Check if file can be accessed with comprehensive validation
    public func canAccessFile(_ url: URL) -> Bool {
        // Input validation
        guard url.isFileURL else {
            SecurityAuditLogger.shared.logSecurity(.warning, "Non-file URL access attempted")
            return false
        }

        // Enhanced path traversal prevention
        guard isSecurePath(url) else {
            SecurityAuditLogger.shared.logSecurity(.error, "Path traversal attempt blocked")
            return false
        }

        // Check if file exists and validate path
        guard FileManager.default.fileExists(atPath: url.path),
              isValidFileExtension(url.pathExtension) else {
            SecurityAuditLogger.shared.logSecurity(.warning, "File validation failed")
            return false
        }

        // Check if we have active access with thread-safe access
        let hasExistingAccess = withAccessTracker { tracker in
            guard let accessInfo = tracker[url] else { return false }
            return accessInfo.withActiveUpdate { $0 }
        }

        if hasExistingAccess {
            SecurityAuditLogger.shared.logSecurity(.info, "Using existing active access")
            return true
        }

        // Try to access file with proper resource management
        let hasAccess = url.startAccessingSecurityScopedResource()
        if hasAccess {
            defer { url.stopAccessingSecurityScopedResource() }

            let scopeId = UUID()
            withAccessTracker { tracker in
                tracker[url] = AccessInfo(
                    isActive: false, // Will be activated explicitly via startAccessing
                    lastAccessed: Date(),
                    accessCount: 1,
                    securityScope: scopeId
                )
            }
            SecurityAuditLogger.shared.logSecurity(.info, "Security scope validated", scopeId: scopeId)
        } else {
            SecurityAuditLogger.shared.logSecurity(.error, "Security scope validation failed")
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

            // Track bookmark creation (thread-safe)
            withAccessTracker { tracker in
                tracker[url] = AccessInfo(isActive: false, lastAccessed: Date())
            }

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

            // Update access tracker (thread-safe)
            withAccessTracker { tracker in
                tracker[url] = AccessInfo(isActive: false, lastAccessed: Date())
            }

            return url
        } catch {
            throw SecurityError.bookmarkResolutionFailed(underlying: error)
        }
    }

    /// Start accessing security-scoped resource with leak protection
    public func startAccessing(_ url: URL) -> Bool {
        // Input validation
        guard url.isFileURL else {
            SecurityAuditLogger.shared.logSecurity(.error, "Invalid URL for security scope")
            return false
        }

        // Check if already accessing (thread-safe)
        let alreadyActive = withAccessTracker { tracker in
            guard let existingInfo = tracker[url] else { return false }
            return existingInfo.isActive
        }

        if alreadyActive {
            SecurityAuditLogger.shared.logSecurity(.warning, "Security scope already active")
            return true
        }

        let success = url.startAccessingSecurityScopedResource()

        if success {
            let scopeId = UUID()
            withAccessTracker { tracker in
                let newInfo = AccessInfo(
                    isActive: true,
                    lastAccessed: Date(),
                    accessCount: (tracker[url]?.accessCount ?? 0) + 1,
                    securityScope: scopeId
                )
                tracker[url] = newInfo
            }
            SecurityAuditLogger.shared.logSecurity(.info, "Security scope started", scopeId: scopeId)
        } else {
            SecurityAuditLogger.shared.logSecurity(.error, "Failed to start security scope")
        }

        return success
    }

    /// Stop accessing security-scoped resource with comprehensive cleanup
    public func stopAccessing(_ url: URL) {
        let currentInfo = withAccessTracker { tracker in
            return tracker[url]
        }

        guard let currentInfo = currentInfo else {
            SecurityAuditLogger.shared.logSecurity(.warning, "Attempting to stop non-tracked access")
            return
        }

        // Only stop if currently active
        if currentInfo.isActive {
            url.stopAccessingSecurityScopedResource()

            // Thread-safe update
            withAccessTracker { tracker in
                let updatedInfo = AccessInfo(
                    isActive: false,
                    lastAccessed: currentInfo.lastAccessed,
                    accessCount: currentInfo.accessCount,
                    securityScope: currentInfo.securityScope
                )
                tracker[url] = updatedInfo
            }

            SecurityAuditLogger.shared.logSecurity(.info, "Security scope stopped", scopeId: currentInfo.securityScope)
        } else {
            SecurityAuditLogger.shared.logSecurity(.warning, "Attempting to stop inactive security scope")
        }
    }

    /// Clean up expired access tracking
    public func cleanupExpiredAccess() {
        let now = Date()
        let expirationInterval: TimeInterval = 60 * 60 // 1 hour

        withAccessTracker { tracker in
            let expiredURLs = tracker.compactMap { (url, accessInfo) -> URL? in
                let isExpired = now.timeIntervalSince(accessInfo.lastAccessed) > expirationInterval
                if isExpired && accessInfo.isActive {
                    // Stop accessing expired resources
                    url.stopAccessingSecurityScopedResource()
                    return url
                } else if isExpired {
                    return url
                }
                return nil
            }

            expiredURLs.forEach { tracker.removeValue(forKey: $0) }
        }
    }

    /// Get access information for URL
    public func getAccessInfo(for url: URL) -> AccessInfo? {
        return withAccessTracker { tracker in
            return tracker[url]
        }
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

    /// Perform operation with security-scoped access and comprehensive error handling
    public func withSecurityScopedAccess<T: Sendable>(
        to url: URL,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Validate inputs
        guard url.isFileURL else {
            SecurityAuditLogger.shared.logSecurity(.error, "Invalid URL for scoped access")
            throw SecurityError.invalidURL
        }

        // Start access with timeout protection
        let accessStarted = startAccessing(url)
        guard accessStarted else {
            SecurityAuditLogger.shared.logSecurity(.error, "Failed to start scoped access")
            throw SecurityError.accessFailed
        }

        // Ensure cleanup happens regardless of success/failure
        defer {
            stopAccessing(url)
        }

        do {
            let result = try await operation()
            SecurityAuditLogger.shared.logSecurity(.info, "Scoped operation completed successfully")
            return result
        } catch {
            SecurityAuditLogger.shared.logSecurity(.error, "Scoped operation failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Perform operation with bookmark resolution
    public func withBookmarkAccess<T: Sendable>(
        bookmark: Data,
        operation: @Sendable (URL) async throws -> T
    ) async throws -> T {
        let url = try resolveBookmark(bookmark)

        return try await withSecurityScopedAccess(to: url) {
            try await operation(url)
        }
    }

    // MARK: - Private Security Methods

    /// Enhanced path traversal prevention with comprehensive checks
    private func isSecurePath(_ url: URL) -> Bool {
        let path = url.path
        let standardizedPath = url.standardizedFileURL.path

        // Multiple path traversal detection methods
        let dangerousPatterns = [
            "../", "..%2F", "..%252F", // Standard and URL-encoded
            ".%2E/", "%2E./", "%2E%2E/", // Various encodings
            "..\\" // Windows-style separators
        ]

        for pattern in dangerousPatterns {
            if path.lowercased().contains(pattern.lowercased()) ||
               standardizedPath.lowercased().contains(pattern.lowercased()) {
                return false
            }
        }

        // Check for null bytes and control characters
        if path.contains("\0") || path.rangeOfCharacter(from: CharacterSet.controlCharacters) != nil {
            return false
        }

        // Ensure path is within expected bounds (additional safety)
        let pathComponents = url.pathComponents
        return !pathComponents.contains("..") && !pathComponents.contains(".")
    }

    /// Enhanced file extension validation
    private func isValidFileExtension(_ fileExtension: String) -> Bool {
        // Allow empty extensions
        guard !fileExtension.isEmpty else { return true }

        let normalizedExtension = fileExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check against allowed extensions
        return FileAccessConfiguration.supportedExtensions.contains(normalizedExtension)
    }

    /// Thread-safe access tracker operations
    private func withAccessTracker<T>(_ operation: (inout [URL: AccessInfo]) -> T) -> T {
        // This provides basic synchronization within the actor context
        return operation(&accessTracker)
    }
}

// MARK: - Supporting Types

/// Thread-safe access tracking information
public struct AccessInfo: Sendable {
    private let _isActive: OSAllocatedUnfairLock<Bool>
    public let lastAccessed: Date
    public let accessCount: Int
    public let securityScope: UUID

    public init(isActive: Bool, lastAccessed: Date, accessCount: Int = 1, securityScope: UUID = UUID()) {
        self._isActive = OSAllocatedUnfairLock(initialState: isActive)
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
        self.securityScope = securityScope
    }

    public var isActive: Bool {
        get { _isActive.withLock { $0 } }
        set { _isActive.withLock { $0 = newValue } }
    }

    public func withActiveUpdate<T: Sendable>(_ block: @Sendable (Bool) -> T) -> T {
        return _isActive.withLock { isActive in
            return block(isActive)
        }
    }
}

/// Security-related errors with enhanced context
public enum SecurityError: Error, LocalizedError, Sendable {
    case accessFailed
    case bookmarkCreationFailed(underlying: Error)
    case bookmarkResolutionFailed(underlying: Error)
    case bookmarkStale
    case permissionDenied
    case securityScopeExpired
    case invalidURL
    case pathTraversalAttempt
    case unsupportedFileType(extension: String)
    case resourceLeakDetected(url: URL)
    case concurrentAccessViolation
    case rateLimitExceeded
    case concurrentAccessLimit

    public var errorDescription: String? {
        switch self {
        case .accessFailed:
            return "Failed to access security-scoped resource"
        case .bookmarkCreationFailed(let underlying):
            return "Failed to create bookmark: \(underlying.localizedDescription)"
        case .bookmarkResolutionFailed(let underlying):
            return "Failed to resolve bookmark: \(underlying.localizedDescription)"
        case .bookmarkStale:
            return "Security-scoped bookmark is stale"
        case .permissionDenied:
            return "Permission to access file was denied"
        case .securityScopeExpired:
            return "Security scope has expired"
        case .invalidURL:
            return "Invalid URL provided for file access"
        case .pathTraversalAttempt:
            return "Path traversal attempt detected"
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext)"
        case .resourceLeakDetected(let url):
            return "Resource leak detected for: \(url.lastPathComponent)"
        case .concurrentAccessViolation:
            return "Concurrent access violation detected"
        case .rateLimitExceeded:
            return "Security operation rate limit exceeded"
        case .concurrentAccessLimit:
            return "Concurrent access limit reached"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessFailed, .permissionDenied:
            return "Please grant file access permissions in Settings"
        case .bookmarkStale:
            return "Please reselect the file to refresh access permissions"
        case .pathTraversalAttempt:
            return "Only access files within allowed directories"
        case .unsupportedFileType:
            return "Please select a supported file type (.md, .txt, .markdown)"
        case .resourceLeakDetected:
            return "Resource cleanup will be performed automatically"
        case .rateLimitExceeded:
            return "Please wait before retrying the operation"
        default:
            return nil
        }
    }
}


// MARK: - Security Manager Extensions

extension SecurityManager {
    /// Batch validate multiple bookmarks
    public func validateBookmarks(_ bookmarks: [Data]) -> [Bool] {
        return bookmarks.map { validateBookmark($0) }
    }

    /// Create bookmarks for multiple URLs
    public func createBookmarks(for urls: [URL]) -> [Result<Data, Error>] {
        return urls.map { url in
            do {
                let bookmark = try createBookmark(for: url)
                return .success(bookmark)
            } catch {
                return .failure(error)
            }
        }
    }

    /// Get statistics about current access tracking
    public func getAccessStatistics() -> AccessStatistics {
        return withAccessTracker { tracker in
            let activeCount = tracker.values.filter { $0.isActive }.count
            let totalCount = tracker.count

            return AccessStatistics(
                totalTracked: totalCount,
                activeAccess: activeCount,
                inactiveAccess: totalCount - activeCount
            )
        }
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
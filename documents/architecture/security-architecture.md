# Security Architecture

## Security Philosophy

The Swift Markdown Reader follows a **security-by-design** approach with **zero-trust architecture** principles, implementing defense-in-depth strategies to protect user data and maintain enterprise compliance.

### Core Security Principles
1. **Minimal Privilege**: Request only necessary permissions and access
2. **Privacy by Default**: No data collection or external communication
3. **Secure Defaults**: All security configurations default to most secure option
4. **Fail Secure**: Security failures result in denial of access, not elevated privileges
5. **Defense in Depth**: Multiple security layers for comprehensive protection
6. **Transparency**: Clear communication about security measures and data handling

## Threat Model

### Assets to Protect
- **User Documents**: Markdown files containing potentially sensitive information
- **File Access Permissions**: Security-scoped bookmarks and file system access
- **User Preferences**: Settings and configuration data
- **Application State**: Runtime state and temporary data

### Threat Actors
- **Malicious Files**: Crafted markdown files designed to exploit parsing vulnerabilities
- **Privilege Escalation**: Attempts to access files outside granted permissions
- **Data Exfiltration**: Unauthorized access to user documents or metadata
- **System Compromise**: Exploitation of app vulnerabilities to compromise system

### Attack Vectors
- **File Content Attacks**: Malicious markdown content causing crashes or exploits
- **Path Traversal**: Attempts to access files outside sandbox
- **Memory Attacks**: Buffer overflows or memory corruption vulnerabilities
- **State Manipulation**: Unauthorized modification of app state or preferences
- **Side-Channel Attacks**: Information disclosure through timing or resource usage

## Security Architecture Layers

### Layer 1: Platform Security (iOS/macOS Sandbox)

#### App Sandbox Compliance
```xml
<!-- iOS Entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>

<!-- macOS Entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
<key>com.apple.security.print</key>
<true/>
```

#### Security-Scoped Resource Access
```swift
class SecurityScopeManager: Sendable {
    private let accessQueue = DispatchQueue(label: "security-scope-access", qos: .userInitiated)
    private var activeScopes: Set<URL> = []
    private let scopeLock = NSLock()

    func withSecurityScope<T>(for url: URL, perform operation: () throws -> T) throws -> T {
        try scopeLock.withLock {
            guard url.startAccessingSecurityScopedResource() else {
                throw SecurityError.accessDenied(url: url)
            }
            activeScopes.insert(url)
        }

        defer {
            scopeLock.withLock {
                url.stopAccessingSecurityScopedResource()
                activeScopes.remove(url)
            }
        }

        return try operation()
    }
}
```

### Layer 2: Input Validation and Sanitization

#### Markdown Content Validation
```swift
class SecureMarkdownValidator {
    private let maxFileSize: Int64 = 2_097_152 // 2MB
    private let maxLineLength: Int = 10_000
    private let maxNestingDepth: Int = 100

    func validateContent(_ content: String) throws {
        // Size validation
        guard content.utf8.count <= maxFileSize else {
            throw ValidationError.fileTooLarge
        }

        // Line length validation
        for line in content.components(separatedBy: .newlines) {
            guard line.count <= maxLineLength else {
                throw ValidationError.lineTooLong
            }
        }

        // Nesting depth validation
        try validateNestingDepth(content)

        // Malicious pattern detection
        try detectMaliciousPatterns(content)
    }

    private func validateNestingDepth(_ content: String) throws {
        var currentDepth = 0
        var maxDepth = 0

        for line in content.components(separatedBy: .newlines) {
            let indentLevel = line.prefix { $0.isWhitespace }.count / 2
            currentDepth = indentLevel
            maxDepth = max(maxDepth, currentDepth)

            guard maxDepth <= maxNestingDepth else {
                throw ValidationError.nestingTooDeep
            }
        }
    }

    private func detectMaliciousPatterns(_ content: String) throws {
        // Detect potentially malicious patterns
        let suspiciousPatterns = [
            #"javascript:"#,
            #"data:text/html"#,
            #"<script"#,
            #"<iframe"#,
            #"<object"#,
            #"<embed"#
        ]

        for pattern in suspiciousPatterns {
            if content.localizedCaseInsensitiveContains(pattern) {
                throw ValidationError.suspiciousContent(pattern: pattern)
            }
        }
    }
}
```

#### File Path Validation
```swift
class SecurePathValidator {
    func validatePath(_ url: URL) throws {
        // Prevent path traversal
        let normalizedPath = url.standardized.path
        guard !normalizedPath.contains("..") else {
            throw SecurityError.pathTraversal(path: normalizedPath)
        }

        // Validate file extension
        let allowedExtensions = Set(["md", "markdown", "txt", "text"])
        guard let pathExtension = url.pathExtension.nilIfEmpty,
              allowedExtensions.contains(pathExtension.lowercased()) else {
            throw SecurityError.invalidFileType(extension: url.pathExtension)
        }

        // Validate filename
        let filename = url.lastPathComponent
        guard isValidFilename(filename) else {
            throw SecurityError.invalidFilename(filename: filename)
        }
    }

    private func isValidFilename(_ filename: String) -> Bool {
        // Check for null bytes and control characters
        guard !filename.contains("\0") else { return false }
        guard filename.rangeOfCharacter(from: .controlCharacters) == nil else { return false }

        // Check length
        guard filename.count <= 255 else { return false }

        // Check for reserved names (Windows compatibility)
        let reservedNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4",
                           "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2",
                           "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]
        let nameWithoutExtension = (filename as NSString).deletingPathExtension.uppercased()
        guard !reservedNames.contains(nameWithoutExtension) else { return false }

        return true
    }
}
```

### Layer 3: Memory Safety and Resource Management

#### Safe Memory Operations
```swift
class SecureMemoryManager {
    private let memoryLimit: Int64 = 104_857_600 // 100MB
    private let allocationTracker = AllocationTracker()

    func allocateSecurely<T>(_ type: T.Type, count: Int) throws -> UnsafeMutablePointer<T> {
        let size = MemoryLayout<T>.stride * count

        guard size <= memoryLimit else {
            throw MemoryError.allocationTooLarge(requested: size, limit: memoryLimit)
        }

        guard allocationTracker.canAllocate(size) else {
            throw MemoryError.memoryLimitExceeded
        }

        let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
        allocationTracker.recordAllocation(size, pointer: UnsafeRawPointer(pointer))

        return pointer
    }

    func deallocateSecurely<T>(_ pointer: UnsafeMutablePointer<T>, count: Int) {
        let size = MemoryLayout<T>.stride * count

        // Zero memory before deallocation
        pointer.initialize(repeating: T.self as! T, count: count)
        pointer.deinitialize(count: count)
        pointer.deallocate()

        allocationTracker.recordDeallocation(size, pointer: UnsafeRawPointer(pointer))
    }
}

class AllocationTracker {
    private var currentAllocations: [UnsafeRawPointer: Int64] = [:]
    private var totalAllocated: Int64 = 0
    private let lock = NSLock()

    func canAllocate(_ size: Int64) -> Bool {
        lock.withLock {
            return totalAllocated + size <= 104_857_600 // 100MB limit
        }
    }

    func recordAllocation(_ size: Int64, pointer: UnsafeRawPointer) {
        lock.withLock {
            currentAllocations[pointer] = size
            totalAllocated += size
        }
    }

    func recordDeallocation(_ size: Int64, pointer: UnsafeRawPointer) {
        lock.withLock {
            currentAllocations.removeValue(forKey: pointer)
            totalAllocated -= size
        }
    }
}
```

#### Resource Limits and Monitoring
```swift
class ResourceMonitor {
    private let cpuThreshold: Double = 0.8 // 80%
    private let memoryThreshold: Double = 0.9 // 90%
    private let monitoringQueue = DispatchQueue(label: "resource-monitor", qos: .background)

    func startMonitoring() {
        monitoringQueue.async { [weak self] in
            self?.monitorResources()
        }
    }

    private func monitorResources() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkResourceUsage()
        }
    }

    private func checkResourceUsage() {
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()

        if cpuUsage > cpuThreshold {
            handleHighCPUUsage(cpuUsage)
        }

        if memoryUsage > memoryThreshold {
            handleHighMemoryUsage(memoryUsage)
        }
    }

    private func handleHighCPUUsage(_ usage: Double) {
        // Throttle operations
        NotificationCenter.default.post(
            name: .highCPUUsage,
            object: usage
        )
    }

    private func handleHighMemoryUsage(_ usage: Double) {
        // Clear caches and free memory
        NotificationCenter.default.post(
            name: .highMemoryUsage,
            object: usage
        )
    }
}
```

### Layer 4: Secure Data Storage

#### Secure Preferences Storage
```swift
class SecurePreferencesStorage {
    private let keychain = Keychain(service: "com.markdownreader.preferences")
    private let userDefaults = UserDefaults.standard
    private let encryptionKey: SymmetricKey

    init() {
        self.encryptionKey = try! Self.getOrCreateEncryptionKey()
    }

    func store<T: Codable>(_ value: T, for key: PreferenceKey) throws {
        let data = try JSONEncoder().encode(value)

        switch key.securityLevel {
        case .sensitive:
            let encryptedData = try encrypt(data)
            try keychain.set(encryptedData, key: key.rawValue)

        case .normal:
            userDefaults.set(data, forKey: key.rawValue)

        case .public:
            userDefaults.set(data, forKey: key.rawValue)
        }
    }

    func retrieve<T: Codable>(_ type: T.Type, for key: PreferenceKey) throws -> T? {
        let data: Data?

        switch key.securityLevel {
        case .sensitive:
            guard let encryptedData = try keychain.getData(key.rawValue) else { return nil }
            data = try decrypt(encryptedData)

        case .normal, .public:
            data = userDefaults.data(forKey: key.rawValue)
        }

        guard let data = data else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }

    private func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }

    private static func getOrCreateEncryptionKey() throws -> SymmetricKey {
        let keychain = Keychain(service: "com.markdownreader.encryption")

        if let keyData = try keychain.getData("master-key") {
            return SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            try keychain.set(keyData, key: "master-key")
            return key
        }
    }
}

enum PreferenceKey: String, CaseIterable {
    case theme = "user.theme"
    case fontSize = "user.fontSize"
    case recentFiles = "user.recentFiles" // sensitive
    case enableAnalytics = "app.enableAnalytics"

    var securityLevel: SecurityLevel {
        switch self {
        case .recentFiles:
            return .sensitive
        case .theme, .fontSize:
            return .normal
        case .enableAnalytics:
            return .public
        }
    }
}

enum SecurityLevel {
    case sensitive  // Encrypted in keychain
    case normal     // UserDefaults
    case public     // UserDefaults, can be synced
}
```

### Layer 5: Error Handling and Logging

#### Secure Error Handling
```swift
enum SecurityError: LocalizedError {
    case accessDenied(url: URL)
    case pathTraversal(path: String)
    case invalidFileType(extension: String)
    case invalidFilename(filename: String)
    case bookmarkValidationFailed
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to the requested file was denied"
        case .pathTraversal:
            return "Invalid file path detected"
        case .invalidFileType:
            return "Unsupported file type"
        case .invalidFilename:
            return "Invalid filename"
        case .bookmarkValidationFailed:
            return "File access bookmark validation failed"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "Please ensure you have permission to access this file"
        case .pathTraversal, .invalidFilename:
            return "Please select a different file"
        case .invalidFileType:
            return "Please select a markdown (.md) or text (.txt) file"
        case .bookmarkValidationFailed:
            return "Please reselect the file to restore access"
        case .encryptionFailed, .decryptionFailed:
            return "Please restart the application and try again"
        }
    }
}
```

#### Security-Aware Logging
```swift
class SecureLogger {
    private let logger = Logger(subsystem: "com.markdownreader", category: "security")

    func logSecurityEvent(_ event: SecurityEvent) {
        // Never log sensitive data
        let sanitizedEvent = sanitize(event)

        switch event.severity {
        case .info:
            logger.info("\(sanitizedEvent.message)")
        case .warning:
            logger.warning("\(sanitizedEvent.message)")
        case .error:
            logger.error("\(sanitizedEvent.message)")
        case .critical:
            logger.critical("\(sanitizedEvent.message)")
        }
    }

    private func sanitize(_ event: SecurityEvent) -> SecurityEvent {
        var sanitizedMessage = event.message

        // Remove potential PII and sensitive data
        sanitizedMessage = sanitizedMessage.replacingOccurrences(
            of: #"/Users/[^/]+/"#,
            with: "/Users/[redacted]/",
            options: .regularExpression
        )

        sanitizedMessage = sanitizedMessage.replacingOccurrences(
            of: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            with: "[email-redacted]",
            options: .regularExpression
        )

        return SecurityEvent(
            severity: event.severity,
            message: sanitizedMessage,
            timestamp: event.timestamp
        )
    }
}

struct SecurityEvent {
    let severity: Severity
    let message: String
    let timestamp: Date

    enum Severity {
        case info
        case warning
        case error
        case critical
    }
}
```

## Security Validation and Testing

### Security Test Suite
```swift
class SecurityTestSuite: XCTestCase {

    func testPathTraversalPrevention() {
        let validator = SecurePathValidator()

        let maliciousPaths = [
            URL(fileURLWithPath: "../../../etc/passwd"),
            URL(fileURLWithPath: "..\\..\\windows\\system32\\"),
            URL(fileURLWithPath: "/etc/passwd"),
            URL(fileURLWithPath: "file:///etc/passwd")
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(try validator.validatePath(path))
        }
    }

    func testMaliciousContentDetection() {
        let validator = SecureMarkdownValidator()

        let maliciousContent = [
            "<script>alert('xss')</script>",
            "[click me](javascript:alert('xss'))",
            "![image](data:text/html,<script>alert('xss')</script>)",
            "<iframe src='javascript:alert(1)'></iframe>"
        ]

        for content in maliciousContent {
            XCTAssertThrowsError(try validator.validateContent(content))
        }
    }

    func testMemoryLimitEnforcement() {
        let memoryManager = SecureMemoryManager()

        // Test allocation limit
        XCTAssertThrowsError(
            try memoryManager.allocateSecurely(UInt8.self, count: 200_000_000) // 200MB
        )
    }

    func testEncryptionDecryption() {
        let storage = SecurePreferencesStorage()
        let testData = "sensitive data"

        XCTAssertNoThrow(try storage.store(testData, for: .recentFiles))

        let retrieved: String? = try? storage.retrieve(String.self, for: .recentFiles)
        XCTAssertEqual(retrieved, testData)
    }
}
```

### Security Audit Checklist

#### Code Security Review
- [ ] All user inputs validated and sanitized
- [ ] No hardcoded secrets or credentials
- [ ] Proper error handling without information disclosure
- [ ] Memory safety verified (no buffer overflows)
- [ ] Resource limits enforced and monitored
- [ ] Secure defaults implemented throughout

#### File Access Security
- [ ] Security-scoped bookmarks properly managed
- [ ] Path traversal attacks prevented
- [ ] File type validation implemented
- [ ] Access permissions minimized and validated
- [ ] Temporary files securely handled and cleaned up

#### Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] Keychain integration secure and tested
- [ ] No sensitive data in logs or error messages
- [ ] Memory cleared after sensitive operations
- [ ] Data not persisted unnecessarily

#### Platform Security
- [ ] App sandbox properly configured
- [ ] Entitlements minimized to necessary permissions
- [ ] Code signing and notarization completed
- [ ] Privacy policy and data handling documented
- [ ] Third-party dependencies audited

## Compliance and Standards

### Compliance Framework
- **GDPR**: No personal data collection, user control over file access
- **SOC 2 Type II**: Security controls and operational effectiveness
- **ISO 27001**: Information security management system
- **NIST Cybersecurity Framework**: Identify, Protect, Detect, Respond, Recover

### Security Monitoring and Incident Response

#### Monitoring Strategy
```swift
class SecurityMonitor {
    private let secureLogger = SecureLogger()

    func monitorFileAccess(_ operation: FileOperation, url: URL) {
        secureLogger.logSecurityEvent(SecurityEvent(
            severity: .info,
            message: "File operation: \(operation) on \(url.lastPathComponent)",
            timestamp: Date()
        ))
    }

    func monitorSecurityViolation(_ violation: SecurityViolation) {
        secureLogger.logSecurityEvent(SecurityEvent(
            severity: .critical,
            message: "Security violation: \(violation.type)",
            timestamp: Date()
        ))

        // Implement automated response
        handleSecurityViolation(violation)
    }

    private func handleSecurityViolation(_ violation: SecurityViolation) {
        switch violation.severity {
        case .high:
            // Terminate suspicious operations
            terminateSuspiciousOperations()
        case .medium:
            // Increase monitoring
            increaseMonitoringLevel()
        case .low:
            // Log and continue
            break
        }
    }
}
```

### Security Configuration Management

#### Secure Configuration
```swift
struct SecurityConfiguration {
    static let shared = SecurityConfiguration()

    let enableSecurityLogging = true
    let enablePathValidation = true
    let enableContentValidation = true
    let maxFileSize: Int64 = 2_097_152 // 2MB
    let maxMemoryUsage: Int64 = 104_857_600 // 100MB
    let encryptSensitivePreferences = true
    let secureMemoryClearing = true

    private init() {}
}
```

## Security Maintenance

### Regular Security Tasks
1. **Dependency Auditing**: Regular review of all dependencies for vulnerabilities
2. **Code Security Review**: Periodic manual and automated code security reviews
3. **Penetration Testing**: Annual third-party security assessment
4. **Vulnerability Management**: Process for addressing discovered vulnerabilities
5. **Security Training**: Ongoing security training for development team

### Security Update Process
1. **Vulnerability Discovery**: Internal or external vulnerability identification
2. **Risk Assessment**: Evaluate impact and exploitability
3. **Patch Development**: Develop and test security fixes
4. **Emergency Release**: Deploy critical security updates immediately
5. **Post-Incident Review**: Learn from security incidents and improve processes
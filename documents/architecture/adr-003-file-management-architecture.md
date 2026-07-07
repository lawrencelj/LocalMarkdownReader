# ADR-003: File Management Architecture

## Status
**APPROVED** - 2025-01-23

## Context

The Swift Markdown Reader requires secure, efficient file access across iOS and macOS platforms while adhering to platform security models and providing excellent user experience. The application must handle local files, iCloud documents, and third-party file providers while maintaining enterprise-grade security.

### Requirements
- **Security First**: Full compliance with iOS/macOS app sandbox restrictions
- **Cross-Platform**: Unified file access patterns for iOS and macOS
- **Performance**: Fast file operations with minimal latency
- **User Experience**: Intuitive file selection and management
- **Persistence**: Remember file access permissions across app launches
- **Enterprise Compliance**: Support for managed environments and restrictions
- **Large File Support**: Handle documents up to 2MB efficiently

### Platform Security Models
- **iOS**: App sandbox with document picker and security-scoped bookmarks
- **macOS**: App sandbox with security-scoped bookmarks and user consent
- **Both**: iCloud entitlements and file provider extensions

### Options Considered

#### Option 1: Platform-Unified Security-Scoped Bookmark Architecture (SELECTED)
- **Pros**:
  - Full compliance with both iOS and macOS security models
  - Persistent file access across app launches
  - Security-first design with minimal privilege escalation
  - Supports all file sources (local, iCloud, file providers)
  - Clean abstraction layer for cross-platform development
- **Cons**:
  - Complex bookmark management and validation
  - Requires careful security scope lifecycle management
  - Platform-specific implementation complexity

#### Option 2: Temporary Access with Re-Selection Pattern
- **Pros**:
  - Simple implementation without bookmark persistence
  - Minimal security surface area
  - Easy to understand and debug
- **Cons**:
  - Poor user experience requiring re-selection
  - No support for recent files or file history
  - Breaks user workflow for frequently accessed documents
  - Cannot support background processing or auto-save

#### Option 3: Copy-to-App-Container Pattern
- **Pros**:
  - Simple file access within app sandbox
  - No security scope management complexity
  - Predictable file locations and permissions
- **Cons**:
  - Storage duplication and waste
  - Sync issues with original file modifications
  - User confusion about file locations
  - Does not work with large documents efficiently

## Decision

**Selected: Platform-Unified Security-Scoped Bookmark Architecture**

### Implementation Strategy

#### 1. File Access Abstraction Layer
```swift
protocol FileAccessManager {
    func selectDocument() async throws -> DocumentReference
    func accessDocument(_ reference: DocumentReference) async throws -> DocumentContent
    func createBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ bookmark: Data) throws -> URL
    func validateAccess(to reference: DocumentReference) -> Bool
}
```

#### 2. Security-Scoped Bookmark Management
```swift
class SecurityScopeManager {
    private var activeScopes: Set<URL> = []

    func startAccessing(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw FileAccessError.securityScopeAccessFailed
        }
        activeScopes.insert(url)
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
        activeScopes.remove(url)
    }
}
```

#### 3. Document Reference Model
```swift
struct DocumentReference: Codable {
    let id: UUID
    let bookmark: Data
    let originalURL: URL
    let lastAccessed: Date
    let fileSize: Int64
    let isCloudDocument: Bool
    let displayName: String
}
```

### Architecture Components

#### Core File Access Layer
- **DocumentPicker**: Platform-specific file selection interfaces
- **BookmarkManager**: Security-scoped bookmark persistence and validation
- **SecurityScopeManager**: Resource access lifecycle management
- **FileWatcher**: Monitor file changes and updates
- **RecentFilesManager**: Track and manage recently accessed documents

#### Platform Integration Layer
- **iOS Integration**: UIDocumentPickerViewController and security scopes
- **macOS Integration**: NSOpenPanel and security scopes
- **iCloud Integration**: NSMetadataQuery for iCloud document discovery
- **File Provider Integration**: Support for third-party file providers

#### Data Persistence Layer
- **BookmarkStore**: Secure storage of security-scoped bookmarks
- **FileMetadataCache**: Cache file information for performance
- **AccessPermissionTracker**: Monitor and validate ongoing file access

## Consequences

### Positive Consequences
- **Security Compliance**: Full adherence to iOS/macOS security models
- **User Experience**: Persistent file access without re-selection
- **Cross-Platform Consistency**: Unified file access patterns
- **Enterprise Ready**: Supports managed environments and restrictions
- **Performance**: Efficient access to frequently used documents
- **Flexibility**: Supports all file sources and storage providers

### Negative Consequences
- **Implementation Complexity**: Significant complexity in bookmark management
- **Security Scope Management**: Careful lifecycle management required
- **Platform-Specific Code**: Some platform differences require separate handling
- **Debugging Complexity**: Security scope issues can be difficult to diagnose

### Risk Mitigation
- **Comprehensive Testing**: Security scope testing on both platforms
- **Graceful Degradation**: Fallback to document picker when bookmarks fail
- **Security Validation**: Regular validation of stored bookmarks
- **Error Handling**: Clear error messages and recovery paths
- **Documentation**: Comprehensive documentation of security patterns

### File Access Patterns

#### Document Selection Flow
```swift
// 1. User triggers document selection
// 2. Platform-specific document picker presented
// 3. User selects document
// 4. Create security-scoped bookmark
// 5. Store bookmark in secure storage
// 6. Return DocumentReference for app use

func selectDocument() async throws -> DocumentReference {
    let url = try await presentDocumentPicker()
    let bookmark = try createSecurityScopedBookmark(for: url)
    let reference = DocumentReference(
        id: UUID(),
        bookmark: bookmark,
        originalURL: url,
        lastAccessed: Date(),
        fileSize: try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
        isCloudDocument: url.pathComponents.contains("Mobile Documents"),
        displayName: url.lastPathComponent
    )
    try await bookmarkStore.save(reference)
    return reference
}
```

#### Document Access Flow
```swift
// 1. Resolve security-scoped bookmark to URL
// 2. Start accessing security-scoped resource
// 3. Read document content
// 4. Stop accessing security-scoped resource
// 5. Return document content

func accessDocument(_ reference: DocumentReference) async throws -> DocumentContent {
    let url = try resolveBookmark(reference.bookmark)
    try securityScopeManager.startAccessing(url)
    defer { securityScopeManager.stopAccessing(url) }

    let data = try Data(contentsOf: url)
    return DocumentContent(data: data, url: url, reference: reference)
}
```

### Platform-Specific Implementations

#### iOS Document Picker
```swift
#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.markdownText, .plainText]
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        func documentPicker(_ controller: UIDocumentPickerViewController,
                           didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
        }
    }
}
#endif
```

#### macOS Open Panel
```swift
#if os(macOS)
class DocumentPicker: ObservableObject {
    @Published var selectedURL: URL?

    func presentOpenPanel() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.markdownText, .plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        if openPanel.runModal() == .OK {
            selectedURL = openPanel.url
        }
    }
}
#endif
```

### Security Architecture

#### Bookmark Validation
```swift
class BookmarkValidator {
    func validateBookmark(_ bookmark: Data) throws -> ValidationResult {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmark,
                         bookmarkDataIsStale: &isStale)

        if isStale {
            return .stale(originalURL: url)
        }

        if !url.checkResourceIsReachable() {
            return .unreachable(url: url)
        }

        return .valid(url: url)
    }
}

enum ValidationResult {
    case valid(url: URL)
    case stale(originalURL: URL)
    case unreachable(url: URL)
    case invalid
}
```

#### Secure Storage
```swift
class SecureBookmarkStore {
    private let keychain = Keychain(service: "com.markdownreader.bookmarks")

    func save(_ reference: DocumentReference) throws {
        let data = try JSONEncoder().encode(reference)
        try keychain.set(data, key: reference.id.uuidString)
    }

    func load(id: UUID) throws -> DocumentReference? {
        guard let data = try keychain.getData(id.uuidString) else { return nil }
        return try JSONDecoder().decode(DocumentReference.self, from: data)
    }
}
```

## Technical Implementation

### Error Handling Strategy
```swift
enum FileAccessError: LocalizedError {
    case securityScopeAccessFailed
    case bookmarkResolutionFailed
    case fileNotFound
    case permissionDenied
    case fileTooLarge
    case unsupportedFileType

    var errorDescription: String? {
        switch self {
        case .securityScopeAccessFailed:
            return "Unable to access file due to security restrictions"
        case .bookmarkResolutionFailed:
            return "File location has changed or is no longer accessible"
        // ... additional cases
        }
    }
}
```

### Performance Optimizations
- **Lazy Loading**: Only resolve bookmarks when file access is needed
- **Caching**: Cache file metadata to avoid repeated file system calls
- **Background Processing**: Validate bookmarks in background queue
- **Efficient Reading**: Use memory-mapped files for large documents when appropriate

## Validation Criteria
- [ ] All file access operations go through security-scoped bookmarks
- [ ] Bookmarks persist correctly across app launches
- [ ] Platform-specific file pickers work correctly
- [ ] Error handling provides clear user guidance
- [ ] Performance meets requirements (<100ms for file operations)
- [ ] Security audit confirms sandbox compliance
- [ ] Works with iCloud and file provider documents
- [ ] Enterprise restrictions properly enforced
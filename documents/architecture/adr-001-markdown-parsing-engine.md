# ADR-001: Markdown Parsing Engine Selection

## Status
**APPROVED** - 2025-01-23

## Context

The Swift Markdown Reader requires a robust markdown parsing engine that supports CommonMark specification with GitHub Flavored Markdown (GFM) extensions. The application must handle documents up to 2MB efficiently while maintaining 60fps UI performance.

### Requirements
- **Standard Compliance**: Full CommonMark + GFM support (tables, strikethrough, task lists, autolinks)
- **Performance**: Parse 2MB documents within 100ms on modern hardware
- **Security**: Protection against malicious markdown that could cause crashes or exploits
- **Platform Support**: Native Swift implementation for iOS 15.0+ and macOS 12.0+
- **Maintainability**: Long-term maintenance and feature updates
- **Integration**: Seamless integration with SwiftUI AttributedString rendering

### Options Considered

#### Option 1: Apple's AttributedString(markdown:) (SELECTED)
- **Pros**:
  - Native Apple implementation with optimal platform integration
  - Built-in security sandbox and memory management
  - Direct AttributedString output for SwiftUI Text rendering
  - Zero external dependencies reducing app size
  - Automatic updates with OS releases
  - Optimized for Apple Silicon and iOS performance characteristics
- **Cons**:
  - Limited CommonMark compliance (missing some GFM features)
  - No control over parsing behavior or extensions
  - Cannot customize syntax highlighting or advanced features
  - Tied to Apple's release cycle for feature updates

#### Option 2: cmark-gfm (GitHub's C Library)
- **Pros**:
  - Complete GFM specification compliance
  - Mature, battle-tested codebase used by GitHub
  - High performance C implementation
  - Full control over parsing behavior
- **Cons**:
  - C library requiring Swift bridge and memory management
  - Larger app size due to external dependency
  - Security responsibility for managing C memory and potential vulnerabilities
  - Additional maintenance burden for Swift wrapper
  - Complex integration with SwiftUI rendering pipeline

#### Option 3: Third-party Swift Libraries (MarkdownKit, Down)
- **Pros**:
  - Pure Swift implementation
  - Some GFM feature support
  - Community-driven development
- **Cons**:
  - Incomplete CommonMark/GFM compliance
  - Performance characteristics unknown for large documents
  - Dependency on third-party maintenance and security updates
  - Potential compatibility issues with SwiftUI AttributedString
  - Additional app size and complexity

## Decision

**Selected: Apple's AttributedString(markdown:) with feature detection and graceful fallbacks**

### Implementation Strategy
1. **Primary Parser**: Use `AttributedString(markdown:)` for all standard parsing
2. **Feature Detection**: Runtime detection of supported markdown features
3. **Graceful Fallbacks**: Custom handling for unsupported GFM features
4. **Performance Monitoring**: Benchmark parsing performance with telemetry
5. **Future Migration Path**: Architecture supports parser replacement if needed

### Feature Handling Strategy
```swift
// Supported natively by AttributedString(markdown:)
- Headers (H1-H6)
- Bold, italic, strikethrough
- Links and autolinks
- Lists (ordered/unordered)
- Code blocks and inline code
- Blockquotes
- Line breaks and paragraphs

// Custom handling required
- Tables → Fallback to plain text representation
- Task lists → Convert [ ] and [x] to appropriate symbols
- Advanced syntax highlighting → Use basic code formatting
```

## Consequences

### Positive Consequences
- **Security**: Maximum security through Apple's sandboxed implementation
- **Performance**: Optimal performance characteristics for Apple platforms
- **Maintenance**: Zero external dependency maintenance burden
- **Integration**: Seamless SwiftUI AttributedString integration
- **App Size**: Minimal impact on app bundle size
- **Stability**: Apple-maintained code with OS-level optimization

### Negative Consequences
- **Feature Limitations**: Missing some advanced GFM features initially
- **Control Constraints**: Limited ability to customize parsing behavior
- **Update Dependency**: Feature additions tied to Apple's OS release schedule
- **Differentiation**: Cannot offer unique markdown extensions or features

### Risk Mitigation
- **Architecture Flexibility**: Parser abstraction layer enables future migration
- **Feature Communication**: Clear documentation of supported/unsupported features
- **User Education**: Guide users on compatible markdown syntax
- **Performance Monitoring**: Continuous monitoring to ensure 60fps target
- **Feedback Loop**: User feedback collection for critical missing features

### Migration Strategy
If future requirements demand complete GFM compliance:
1. **Phase 1**: Implement parser abstraction interface
2. **Phase 2**: Add cmark-gfm as optional parser for advanced features
3. **Phase 3**: User preference for parser selection
4. **Phase 4**: Gradual migration based on feature requirements

## Technical Implementation

### Parser Abstraction Layer
```swift
protocol MarkdownParser {
    func parse(_ markdown: String) -> DocumentModel
    func supportedFeatures() -> Set<MarkdownFeature>
    func renderToAttributedString(_ document: DocumentModel) -> AttributedString
}

class NativeAppleParser: MarkdownParser {
    func parse(_ markdown: String) -> DocumentModel {
        let attributedString = try? AttributedString(markdown: markdown)
        return DocumentModel(content: attributedString ?? AttributedString())
    }
}
```

### Performance Requirements
- **Target**: 95% of documents parse within 100ms
- **Monitoring**: Telemetry for parsing times by document size
- **Fallback**: Progressive rendering for extremely large documents
- **Memory**: Peak memory usage <50MB for 2MB documents

## Validation Criteria
- [ ] All CommonMark core features supported
- [ ] Performance target achieved (100ms for 2MB documents)
- [ ] Security audit completed with no vulnerabilities
- [ ] UI responsiveness maintained during parsing (60fps)
- [ ] Graceful handling of unsupported GFM features
- [ ] Parser abstraction layer tested and documented
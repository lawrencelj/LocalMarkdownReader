# Code Style & Conventions

## Swift API Design Guidelines
Following official Apple Swift API Design Guidelines with enterprise-specific extensions.

## File Header Requirements
All Swift files must include standardized header:
```swift
//
// FileName.swift
// SwiftMarkdownReader
//
// Created by [Author] on MM/DD/YYYY.
//
```

## Code Quality Standards
- **Zero-warning policy**: All SwiftLint warnings must be resolved
- **SwiftFormat**: Automatic code formatting with enterprise rules
- **Strict concurrency**: All modules enable StrictConcurrency feature
- **Error handling**: Comprehensive error handling, no force unwrapping
- **Documentation**: DocC comments for all public APIs

## Naming Conventions
- **Types**: PascalCase (e.g., `MarkdownRenderer`, `SearchEngine`)
- **Variables/Methods**: camelCase (e.g., `documentContent`, `parseMarkdown()`)
- **Constants**: camelCase with clear descriptive names
- **Protocols**: Descriptive nouns or adjectives ending in -able/-ible when appropriate

## Architecture Patterns
- **MVVM**: Model-View-ViewModel with SwiftUI
- **Dependency Injection**: Protocol-based dependency inversion
- **Modular Design**: Clear separation between packages
- **Async/Await**: Swift concurrency over completion handlers
- **Combine Integration**: For reactive programming where appropriate

## SwiftLint Configuration Highlights
- Line length: 120 characters (warning), 200 (error)
- Function body: 60 lines (warning), 100 (error)
- File length: 400 lines (warning), 1000 (error)
- Cyclomatic complexity: 10 (warning), 20 (error)
- Function parameters: 5 (warning), 8 (error)
- Force unwrapping: Prohibited in production code

## Testing Standards
- **Unit Tests**: ≥85% coverage for critical paths
- **Test Naming**: `test_methodName_condition_expectedResult`
- **Given-When-Then**: Clear test structure
- **Mocking**: Protocol-based mocking for dependencies
- **Performance Tests**: Benchmark critical operations

## Security Guidelines
- No hardcoded secrets or API keys
- Proper error handling without information disclosure
- Sandboxed file access patterns
- Privacy-by-design principles
- Secure coding practices per OWASP guidelines

## Accessibility Requirements
- All UI elements have appropriate accessibility labels
- Support for Dynamic Type scaling
- VoiceOver navigation support
- High contrast theme compatibility
- Keyboard navigation support
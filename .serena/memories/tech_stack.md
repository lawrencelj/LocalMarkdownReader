# Technology Stack

## Core Technologies

### Language & Platform
- **Swift 5.9+**: Modern Swift with strict concurrency enabled
- **iOS 17+**: Latest iOS features and frameworks
- **macOS 14+**: Native macOS integration and performance

### UI Framework
- **SwiftUI**: Primary UI framework for both platforms
- **UIKit/AppKit**: Platform-specific integrations where needed
- **Combine**: Reactive programming for data flow

### Dependencies
- **swift-markdown (0.3.0+)**: Apple's official CommonMark parser
  - CommonMark compliance with GitHub Flavored Markdown extensions
  - High-performance native parsing
- **swift-collections (1.1.0+)**: Efficient data structures
  - OrderedCollections for search indexing
  - Performance-optimized collections
- **swift-syntax (509.0.0+)**: Enhanced syntax processing

### Build System
- **Swift Package Manager**: Native dependency management
- **Xcode 15.0+**: IDE and build toolchain
- **GitHub Actions**: CI/CD automation on macOS runners

### Code Quality Tools
- **SwiftLint**: Code style enforcement with zero-warning policy
- **SwiftFormat**: Automatic code formatting
- **DocC**: Documentation generation
- **XCTest**: Unit and integration testing framework

### Security & Performance
- **App Sandbox**: Full sandboxing for enhanced security
- **Code Signing**: Automated certificate management
- **Performance Testing**: Built-in benchmarking framework
- **Memory Management**: ARC with strict concurrency patterns

## Architecture Patterns

### Design Patterns
- **MVVM**: Model-View-ViewModel with SwiftUI
- **Dependency Injection**: Protocol-based inversion of control
- **Repository Pattern**: Data access abstraction
- **Factory Pattern**: Object creation and configuration

### Concurrency Model
- **Swift Concurrency**: async/await primary pattern
- **Actor Model**: Thread-safe state management
- **MainActor**: UI updates on main thread
- **TaskGroup**: Parallel processing where appropriate

### Module Architecture
```
MarkdownCore     -> Core parsing and rendering engine
ViewerUI         -> SwiftUI components and theming
FileAccess       -> Cross-platform file management
Search           -> Document search and indexing
Settings         -> Configuration and preferences
```

## Platform-Specific Features

### iOS-Specific
- **UIDocumentPickerViewController**: File selection
- **Files app integration**: Seamless file access
- **Dynamic Type**: Accessibility scaling support
- **Scene-based architecture**: Modern app lifecycle

### macOS-Specific
- **NSOpenPanel**: Native file dialogs
- **Drag and drop**: Desktop file interaction
- **Menu bar integration**: Native macOS menus
- **Keyboard shortcuts**: Desktop productivity features

## Development Environment

### Required Tools
- **Xcode 15.0+**: Primary development environment
- **SwiftLint**: Code quality enforcement
- **SwiftFormat**: Code formatting tool
- **Git**: Version control with conventional commits

### Recommended Tools
- **Instruments**: Performance profiling
- **Accessibility Inspector**: Accessibility validation
- **Console.app**: System log monitoring
- **SF Symbols**: Apple's icon library

## Performance Targets
- **Document Loading**: <2s for 1MB files, <5s for 2MB files
- **UI Rendering**: 60fps scrolling on all supported devices
- **Memory Usage**: <50MB typical, <150MB maximum
- **Search Response**: <100ms for content search
- **App Launch**: <2s cold start, <1s warm start
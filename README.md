# SwiftMarkdownReader
## Enterprise Markdown Viewer for iOS and macOS

[![CI/CD Pipeline](https://github.com/enterprise/SwiftMarkdownReader/workflows/CI/CD%20Pipeline/badge.svg)](https://github.com/enterprise/SwiftMarkdownReader/actions)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%20|%20macOS%2014-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Enterprise-green.svg)](LICENSE)

A high-performance, accessible markdown viewer designed for enterprise environments with cross-platform support for iOS and macOS.

## ✨ Features

- **📱 Cross-Platform**: Native iOS and macOS applications with shared business logic
- **⚡ High Performance**: 60fps scrolling, <2s load times for 1MB documents
- **♿ Accessibility**: WCAG 2.1 AA compliant with VoiceOver support
- **🔍 Smart Search**: Intelligent search with relevance ranking and real-time filtering
- **🎨 Themes**: Light, dark, and high-contrast themes with Dynamic Type support
- **🔐 Enterprise Security**: Full App Sandbox compliance with privacy-by-design

## 🚀 Quick Start

### Prerequisites

- **macOS**: 14.0+ (for development)
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **iOS**: 17.0+ (for iOS app)

### Development Environment Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/enterprise/SwiftMarkdownReader.git
   cd SwiftMarkdownReader
   ```

2. **Run the bootstrap script**:
   ```bash
   ./Scripts/bootstrap.sh
   ```

3. **Build and run**:
   ```bash
   # Build the project
   swift build

   # Run tests
   swift test

   # Run iOS app (requires Xcode)
   open Package.swift
   # Select MarkdownReader-iOS scheme and run
   ```

## 🏗️ Architecture

### Modular Package Structure

```
SwiftMarkdownReader/
├── Apps/
│   ├── MarkdownReader-iOS/     # iOS application target
│   └── MarkdownReader-macOS/   # macOS application target
└── Packages/
    ├── MarkdownCore/           # Markdown parsing engine
    ├── ViewerUI/               # SwiftUI interface components
    ├── FileAccess/             # Cross-platform file management
    ├── Search/                 # Document search and indexing
    └── Settings/               # Configuration management
```

### Core Technologies

- **Swift Package Manager**: Modular architecture and dependency management
- **SwiftUI**: Modern, declarative user interface framework
- **swift-markdown**: CommonMark parsing with GitHub Flavored Markdown extensions
- **swift-collections**: High-performance data structures for search and indexing

## 🔧 Development

### Code Quality Standards

This project maintains enterprise-grade code quality with:

- **SwiftLint**: Zero-warning policy with comprehensive rule set
- **SwiftFormat**: Consistent code formatting across the team
- **Pre-commit Hooks**: Automated validation before commits
- **CI/CD Pipeline**: 8-stage quality gates with comprehensive testing

### Building

```bash
# Debug build
swift build --configuration debug

# Release build
swift build --configuration release

# Run tests with coverage
swift test --enable-code-coverage
```

### Code Quality Checks

```bash
# Run SwiftLint
swiftlint

# Run SwiftFormat check
swiftformat --lint .

# Run all quality checks
./Scripts/lint.sh
```

## 📱 Platform Support

### iOS Application
- **Minimum Version**: iOS 17.0
- **Features**: Touch-optimized interface, Document Picker integration
- **Performance**: 60fps scrolling on all supported devices

### macOS Application
- **Minimum Version**: macOS 14.0
- **Features**: Menu bar integration, drag-and-drop support, keyboard shortcuts
- **Performance**: Native macOS experience with system integration

## 🧪 Testing

### Test Coverage Requirements
- **Unit Tests**: ≥85% coverage
- **Integration Tests**: ≥70% coverage
- **Performance Tests**: All benchmarks must pass
- **Accessibility Tests**: WCAG 2.1 AA compliance

### Running Tests

```bash
# Run all tests
swift test

# Run tests with coverage report
swift test --enable-code-coverage

# Run performance tests
swift test --filter PerformanceTests
```

## 📚 Documentation

- **[Development Guide](Documentation/Development/)**: Setup and contribution guidelines
- **[Architecture Documentation](Documentation/Architecture/)**: Technical architecture and ADRs
- **[User Guide](Documentation/User/)**: End-user documentation
- **[API Documentation](https://enterprise.github.io/SwiftMarkdownReader/)**: Generated API docs

## 🔒 Security & Privacy

### Enterprise Security Features
- **App Sandbox**: Full sandboxing for enhanced security
- **Privacy by Design**: No PII collection, optional telemetry
- **Secure File Access**: Scoped file access with user permission
- **Code Signing**: Automated certificate management

### Privacy Policy
This application respects user privacy:
- No personal data collection
- No network requests without user consent
- All data processing happens locally
- Optional usage analytics with explicit user permission

## 🚀 Deployment

### Development Deployment
- **iOS**: Automatic TestFlight deployment via CI/CD
- **macOS**: Internal distribution with automated notarization

### Production Release
- **iOS**: App Store distribution with automated submission
- **macOS**: Mac App Store or enterprise distribution

## 🤝 Contributing

### Development Workflow
1. Create feature branch from `develop`
2. Make changes following our coding standards
3. Run quality checks: `./Scripts/lint.sh`
4. Create pull request to `develop`
5. CI/CD pipeline validates changes
6. Code review and merge

### Code Review Guidelines
- All code must pass SwiftLint validation
- Test coverage must meet minimum thresholds
- Performance benchmarks must pass
- Accessibility requirements must be met

## 📈 Performance Targets

### UI Performance
- **Frame Rate**: 60fps scrolling on all devices
- **Load Time**: <2s for 1MB documents, <5s for 2MB documents
- **Memory Usage**: <50MB typical, <150MB for large documents

### Search Performance
- **Content Search**: <100ms response time
- **Index Building**: <100ms for typical documents
- **Navigation**: Instant heading navigation

## 🏢 Enterprise Features

### Compliance
- **Accessibility**: WCAG 2.1 AA compliant
- **Security**: Full App Sandbox compliance
- **Privacy**: GDPR and enterprise privacy policy compliant

### Management
- **Configuration**: Enterprise policy support
- **Monitoring**: Optional usage analytics and performance metrics
- **Support**: Enterprise support channels and documentation

## 📄 License

This project is licensed under the Enterprise License. See [LICENSE](LICENSE) for details.

## 📞 Support

- **Documentation**: [Project Wiki](https://github.com/enterprise/SwiftMarkdownReader/wiki)
- **Issues**: [GitHub Issues](https://github.com/enterprise/SwiftMarkdownReader/issues)
- **Enterprise Support**: Contact your platform team

---

**Status**:   🟢 **Production Ready** 
**Quality**:  ✅ **Enterprise Grade**
**Platform**: 📱 **iOS/macOS**

*Built with ❤️ by the Platform Cluster Team*
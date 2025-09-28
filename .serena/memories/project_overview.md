# SwiftMarkdownReader Project Overview

## Purpose
Enterprise-grade Markdown file reader application for iOS and macOS platforms, built with Swift. Provides high-performance, accessible viewing of CommonMark and GitHub Flavored Markdown documents with native platform integration.

## Key Requirements
- **Platforms**: iOS 17+, macOS 14+ (latest two major versions)
- **Performance**: 60fps UI, <2s load time for 1MB documents, <50MB memory usage
- **Accessibility**: WCAG 2.1 AA compliance, VoiceOver support, Dynamic Type
- **Security**: Full App Sandbox, privacy-by-design, no PII collection
- **Quality**: Zero-warning policy, ≥85% unit test coverage, enterprise standards

## Architecture
**Modular Package Structure:**
- `MarkdownCore`: Parsing engine using swift-markdown (CommonMark + GFM)
- `ViewerUI`: SwiftUI components with theming and accessibility
- `FileAccess`: Cross-platform file management with sandboxing
- `Search`: Document search and indexing with performance optimization
- `Settings`: Configuration management with enterprise policy support

## Applications
- `MarkdownReader-iOS`: Touch-optimized interface with Document Picker
- `MarkdownReader-macOS`: Desktop experience with drag-and-drop, keyboard shortcuts

## Dependencies
- **swift-markdown**: Apple's official CommonMark parser with GFM extensions
- **swift-collections**: High-performance data structures for search/indexing
- **swift-syntax**: Enhanced parsing capabilities

## Status
- Requirements analysis: ✅ COMPLETED
- Architecture design: ✅ COMPLETED  
- Development environment: ✅ COMPLETED
- CI/CD pipeline: 🔄 IN PROGRESS
- Security implementation: ⏳ PENDING
- Core functionality: ⏳ PENDING
- Testing framework: ⏳ PENDING
- Documentation: ⏳ PENDING
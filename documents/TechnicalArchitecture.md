# Swift Markdown Reader - Technical Architecture

## Overview

SwiftMarkdownReader is a native macOS markdown viewer and editor built with Swift 5.9+ and SwiftUI. It provides rich markdown rendering, document navigation, search, theming, and source editing capabilities.

## Module Structure

```
SwiftMarkdownReader/
├── Apps/
│   └── MarkdownReader-macOS/       # macOS application (SwiftUI App)
├── Packages/
│   ├── MarkdownCore/               # Parsing engine (swift-markdown + AttributedString)
│   ├── ViewerUI/                   # UI components and state management
│   ├── FileAccess/                 # File operations and security-scoped access
│   ├── Search/                     # Full-text search and indexing
│   └── Settings/                   # User preferences and persistence
```

## Core Modules

### 1. MarkdownCore

Handles markdown parsing using Apple's `swift-markdown` library with CommonMark + GFM extensions.

**Key Components:**
- `MarkdownParser` — Actor-based parser producing `AttributedString` output
- `DocumentModel` — Immutable document representation with metadata and outline
- `ContentExtractor` — Extracts headings, metadata, and content features
- `ValidationEngine` — Security validation (XSS prevention, size limits)
- `DocumentService` — High-level service interface for loading/parsing

**Capabilities:**
- CommonMark + GitHub Flavoured Markdown parsing
- Heading outline extraction
- Word count, reading time, language detection
- Image/table/code block detection
- File size validation (2MB limit)
- Security-scoped bookmark resolution

### 2. ViewerUI

SwiftUI components and the central `AppStateCoordinator` for state management.

**Key Components:**
- `AppStateCoordinator` — Central `@Observable` state manager
- `DocumentViewer` — Renders formatted markdown with block-level parsing
- `NavigationSidebar` — Document outline with click-to-scroll navigation
- `SearchInterface` — Real-time search with result navigation
- `SourceEditorView` — Raw markdown editor with save-and-refresh
- `ThemeManager` — Theme, font size, line spacing, high contrast
- `FileAccessManager` — Coordinates file picker and permissions

**Features:**
- Multi-document tabs (open multiple files simultaneously)
- Side-by-side file comparison
- Alternating line shading
- Optional line numbers
- Scroll-to-heading from outline clicks
- Inline formatting (bold, italic, code, links)
- Code block rendering with language labels

### 3. FileAccess

Cross-platform file management with macOS sandbox support.

**Key Components:**
- `FileService` — Main file operations interface
- `DocumentPicker` — NSOpenPanel wrapper
- `RecentDocuments` — Persisted recent files list
- `SecurityManager` — Security-scoped bookmark management

### 4. Search

In-memory full-text search engine with relevance scoring.

**Key Components:**
- `SearchEngine` — Actor-based indexing and query engine
- `SearchService` — Frontend service interface
- `ContentHighlighter` — NSAttributedString highlighting

**Capabilities:**
- Full-text indexing with term positions
- Relevance scoring (heading matches rank higher)
- Case-sensitive and whole-word options
- Regex search support
- Outline generation from document headings
- Sub-100ms search response time

### 5. Settings

User preferences with UserDefaults persistence and optional iCloud sync.

**Key Components:**
- `PreferencesService` — Frontend preferences interface
- `UserPreferences` — Persistence layer with iCloud support
- `SettingsManager` — Import/export and migration

## State Architecture

The app uses SwiftUI's `@Observable` macro with a single `AppStateCoordinator`:

```
AppStateCoordinator
├── DocumentState      (current doc, loading, content, open docs, compare)
├── SearchState        (query, results, outline)
├── UIState            (sidebar, search visibility, line numbers, editor)
├── CoordinatorUserPreferences  (recent files, scroll positions)
├── DocumentService    (parsing)
├── SearchService      (indexing/querying)
└── ThemeManager       (appearance)
```

## Build & Run

```bash
# Build macOS app
swift build --product MarkdownReader-macOS

# Run tests
swift test

# Launch
open .build/arm64-apple-macosx/debug/MarkdownReader-macOS
```

## Platform Requirements

- **macOS**: 14.0+ (Sonoma)
- **Swift**: 5.9+
- **Dependencies**: swift-markdown 0.3+, swift-collections 1.1+

## Performance Characteristics

- Document parsing: <1s for typical files
- Search indexing: <100ms
- Search queries: <50ms for 100 results
- UI rendering: 60fps scrolling with LazyVStack
- Memory: ~50MB typical usage

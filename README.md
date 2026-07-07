# SwiftMarkdownReader

A native macOS markdown viewer and editor built with Swift and SwiftUI.

## Features

- **Formatted Rendering** — Headings, bold, italic, code blocks, lists, blockquotes, links
- **Document Outline** — Click headings to navigate
- **Full-Text Search** — Fast search with relevance scoring
- **Source Editor** — Edit raw markdown with live preview refresh
- **Source File Support** — Open and edit JSON, XML, HTML, and plain-text files
- **HTML Preview** — Render HTML in a browser-style content pane while editing source
- **Structured Outlines** — Inspect JSON keys and XML element/attribute hierarchy
- **Multiple Documents** — Open several files with tab navigation
- **File Comparison** — Side-by-side view of two documents
- **Themes** — Light, Dark, System, Custom, High Contrast
- **Line Numbers** — Optional line number gutter
- **Customizable** — Font size, line spacing, high contrast mode
- **English to Chinese Translation** — Translate the whole displayed document on demand and toggle back to English

## Requirements

- macOS 15.0 or later
- Intel (`x86_64`) or Apple silicon Mac for development
- Swift 5.9+

## Quick Start

```bash
# Build
swift build --product MarkdownReader-macOS

# Build a distributable Intel macOS application
./Scripts/build-intel-app.sh

# Run the packaged application
open "dist/Markdown Reader.app"

# Test
swift test --filter "FunctionalTests"
```

The Intel packaging script creates:

- `dist/Markdown Reader.app`
- `dist/MarkdownReader-macOS-x86_64.zip`

The application is ad-hoc signed for local use. Distribution to other Macs
requires signing with an Apple Developer ID certificate and notarization.

## Architecture

```
Packages/
├── MarkdownCore    — Parsing engine (swift-markdown + AttributedString)
├── ViewerUI        — SwiftUI components and state management
├── FileAccess      — File operations and security-scoped access
├── Search          — Full-text search and indexing
└── Settings        — User preferences and persistence
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Document | ⌘O |
| Close Document | ⌘W |
| Find | ⌘F |
| Compare | ⇧⌘D |
| Line Numbers | ⇧⌘L |
| Zoom In/Out | ⌘+ / ⌘- |
| Font Size | ⇧⌘= / ⇧⌘- |

## Testing

66 functional tests covering parsing, search, settings, and state management:

```bash
swift test --filter "FunctionalTests"
```

## License

See LICENSE file.

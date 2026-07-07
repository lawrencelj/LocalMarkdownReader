# Build & CI Notes

## Local Build

```bash
# Build macOS app
swift build --product MarkdownReader-macOS

# Build all libraries
swift build --target MarkdownCore
swift build --target ViewerUI
swift build --target FileAccess
swift build --target Search
swift build --target Settings

# Run tests
swift test --filter "FunctionalTests"

# Clean build
swift package clean
```

## Build Output

The macOS executable is produced at:
```
.build/arm64-apple-macosx/debug/MarkdownReader-macOS
```

## Dependencies

Resolved via Swift Package Manager:
- `swift-markdown` 0.3+ (Apple) — CommonMark/GFM parsing
- `swift-collections` 1.1+ (Apple) — OrderedDictionary for search index

## Platform Notes

- The iOS target exists in source but is excluded from the SPM build (requires Xcode for iOS-specific APIs)
- macOS target builds and runs via SPM command line
- No external CI/CD pipeline configured — build and test locally

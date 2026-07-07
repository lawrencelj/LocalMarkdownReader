# Team & Development Notes

## Current Status

This project is maintained as a single-developer Swift application. The original enterprise team structure documents have been superseded by the actual implementation.

## Development Approach

- Single SPM workspace with 5 modular packages
- All code in Swift 5.9 with SwiftUI
- Tests run via `swift test`
- Build via `swift build --product MarkdownReader-macOS`

## Module Ownership

All modules are maintained together:
- **MarkdownCore** — Parsing and document model
- **ViewerUI** — UI components and state
- **FileAccess** — File operations
- **Search** — Search engine
- **Settings** — Preferences

## Contributing

1. Make changes to the relevant package
2. Run `swift test --filter "FunctionalTests"` to verify
3. Build with `swift build --product MarkdownReader-macOS`
4. Test the app manually

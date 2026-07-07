# Quality Standards

## Code Quality

### Build Requirements
- Zero compilation errors
- Swift 5.9+ with strict concurrency enabled
- All targets build independently

### Testing
- **66 functional tests** covering all core modules
- Test categories:
  - MarkdownCore: Parsing, metadata, outline, validation, performance
  - Search: Indexing, querying, highlighting, outline generation
  - Settings: Preferences, export/import, templates
  - ViewerUI: State management, document loading, UI state

### Running Tests
```bash
swift test --filter "FunctionalTests"
```

### Code Organization
- Modular SPM packages with clear boundaries
- Each package has Sources and Tests directories
- Public API surfaces are minimal and documented
- `@MainActor` isolation for UI-related code
- Actor-based concurrency for thread safety

## Performance Standards

| Metric | Target | Verified |
|--------|--------|----------|
| Document load (<1MB) | <2 seconds | ✅ |
| Search response | <100ms | ✅ |
| UI scrolling | 60fps | ✅ |
| Memory (typical) | <50MB | ✅ |
| App launch | <3 seconds | ✅ |

## Accessibility

- VoiceOver labels on all interactive elements
- Keyboard navigation support
- Dynamic Type / font scaling
- High contrast mode
- Reduce motion support

## Security

- No network requests (fully offline)
- Security-scoped file access
- Input validation on all parsed content
- No PII collection or logging

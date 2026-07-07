# Module Integration

## Package Dependencies

```
MarkdownReader-macOS (App)
├── ViewerUI
│   ├── MarkdownCore → swift-markdown, swift-collections
│   ├── Search → MarkdownCore, swift-collections
│   ├── FileAccess
│   └── Settings
├── MarkdownCore
├── FileAccess
├── Search
└── Settings
```

## Integration Points

### ViewerUI ↔ MarkdownCore
- `DocumentService` loads and parses files into `DocumentModel`
- `DocumentModel` provides `AttributedString` content and `[HeadingItem]` outline
- `DocumentMetadata` provides word count, reading time, feature flags

### ViewerUI ↔ Search
- `SearchService` indexes `DocumentModel` instances
- Returns `[SearchResult]` with line numbers and relevance scores
- Generates `[OutlineItem]` for navigation sidebar

### ViewerUI ↔ FileAccess
- `FileAccessManager` wraps `FileService` for the UI layer
- `SecurityManager` handles security-scoped bookmarks
- `RecentDocuments` persists recently opened file URLs

### ViewerUI ↔ Settings
- `PreferencesService` provides theme and accessibility settings
- `UserPreferences` persists to UserDefaults with optional iCloud sync

## Data Flow

```
User opens file
  → NSOpenPanel returns URL
  → DocumentReference created
  → AppStateCoordinator.loadDocument()
    → DocumentService.loadDocument()
      → Read file content
      → MarkdownParser.parseDocument()
      → Return DocumentModel
    → Update DocumentState
    → SearchService.indexDocument()
    → Update SearchState.outline
  → UI re-renders with new content
```

# ADR-004: Search Implementation Strategy

## Status
**APPROVED** - 2025-01-23

## Context

The Swift Markdown Reader requires fast, responsive search functionality across markdown documents with real-time result highlighting and navigation. Search must work efficiently with documents up to 2MB while maintaining 60fps UI performance and providing instant feedback to users.

### Requirements
- **Performance**: Search results within 50ms for typical queries
- **Real-time**: Live search with instant results as user types
- **Highlighting**: Accurate result highlighting and navigation
- **Memory Efficiency**: Reasonable memory usage for search index
- **Content Awareness**: Understand markdown structure (headers, code, etc.)
- **Fuzzy Search**: Support for approximate matching and typo tolerance
- **Large Document Support**: Efficient handling of 2MB documents
- **Cross-Platform**: Identical search behavior on iOS and macOS

### Search Use Cases
1. **Quick Find**: Find specific text within current document
2. **Content Navigation**: Jump to specific sections or headers
3. **Code Search**: Search within code blocks with syntax awareness
4. **Fuzzy Matching**: Find content with approximate spelling
5. **Structural Search**: Search by markdown element types

### Options Considered

#### Option 1: In-Memory Search Index with Optimized Data Structures (SELECTED)
- **Pros**:
  - Sub-50ms search performance for all document sizes
  - Real-time indexing as documents load/change
  - Complete control over search algorithms and ranking
  - Memory-efficient custom data structures
  - No disk I/O latency during search operations
  - Supports advanced features like fuzzy matching and structural search
- **Cons**:
  - Memory usage increases with document size
  - Index rebuild required for document changes
  - Implementation complexity for advanced search features

#### Option 2: Core Spotlight Integration (iOS/macOS)
- **Pros**:
  - Native OS integration with system search
  - Automatic indexing and maintenance
  - Users can find documents from system search
  - No memory overhead in app
- **Cons**:
  - Limited control over search ranking and behavior
  - Cannot provide real-time in-app search experience
  - Doesn't support markdown-aware search
  - Privacy concerns with system-wide document indexing
  - No support for custom search features

#### Option 3: SQLite FTS (Full-Text Search)
- **Pros**:
  - Mature full-text search implementation
  - Good performance for large document collections
  - Persistent index across app launches
  - SQL-based query interface
- **Cons**:
  - Disk I/O latency impacts search performance
  - Limited customization for markdown-specific features
  - Complexity of SQLite integration and schema management
  - Overkill for single-document search use case

#### Option 4: Third-Party Search Libraries
- **Pros**:
  - Pre-built search functionality
  - Potentially advanced features out of the box
- **Cons**:
  - External dependency and maintenance burden
  - May not integrate well with SwiftUI and Apple platforms
  - Performance characteristics unknown for our use case
  - Limited customization for markdown-specific needs

## Decision

**Selected: In-Memory Search Index with Optimized Data Structures**

### Implementation Strategy

#### 1. Multi-Layered Search Architecture
```swift
protocol SearchEngine {
    func indexDocument(_ document: DocumentModel) async
    func search(_ query: String) async -> [SearchResult]
    func highlightMatches(in content: AttributedString, for query: String) -> AttributedString
    func clearIndex()
}

class MarkdownSearchEngine: SearchEngine {
    private let textIndex: TextSearchIndex
    private let structureIndex: StructureSearchIndex
    private let fuzzyMatcher: FuzzyMatcher
}
```

#### 2. Optimized Data Structures
```swift
// Inverted index for text search
class TextSearchIndex {
    private var tokenIndex: [String: Set<WordPosition>] = [:]
    private var ngramIndex: [String: Set<WordPosition>] = [:]

    struct WordPosition {
        let range: NSRange
        let context: SearchContext
        let weight: Float
    }
}

// Structure-aware indexing
class StructureSearchIndex {
    private var headers: [HeaderInfo] = []
    private var codeBlocks: [CodeBlockInfo] = []
    private var links: [LinkInfo] = []
}
```

#### 3. Search Performance Optimization
```swift
// Async indexing with progress tracking
actor SearchIndexBuilder {
    func buildIndex(for document: DocumentModel) async -> SearchIndex {
        let tokenizer = MarkdownTokenizer()
        let tokens = await tokenizer.tokenize(document)

        return await withTaskGroup(of: IndexPart.self) { group in
            group.addTask { await buildTextIndex(tokens) }
            group.addTask { await buildStructureIndex(tokens) }
            group.addTask { await buildNGramIndex(tokens) }

            var parts: [IndexPart] = []
            for await part in group {
                parts.append(part)
            }
            return SearchIndex(parts: parts)
        }
    }
}
```

### Search Index Architecture

#### Text Index Structure
```swift
class TextSearchIndex {
    // Primary token index for exact matches
    private var tokenIndex: [String: TokenInfo] = [:]

    // N-gram index for fuzzy matching
    private var bigramIndex: [String: Set<Position>] = [:]
    private var trigramIndex: [String: Set<Position>] = [:]

    // Position tracking with context
    struct Position {
        let range: NSRange
        let context: ContextType
        let weight: SearchWeight
    }

    enum ContextType {
        case header(level: Int)
        case body
        case code
        case link
        case emphasis
    }
}
```

#### Markdown Structure Index
```swift
class StructureSearchIndex {
    private var headers: [HeaderElement] = []
    private var codeBlocks: [CodeElement] = []
    private var links: [LinkElement] = []
    private var lists: [ListElement] = []

    struct HeaderElement {
        let text: String
        let level: Int
        let range: NSRange
        let id: String
    }
}
```

### Search Algorithm Implementation

#### Multi-Phase Search Process
```swift
class SearchProcessor {
    func executeSearch(_ query: String) async -> [SearchResult] {
        // Phase 1: Query preprocessing
        let processedQuery = preprocessQuery(query)

        // Phase 2: Parallel search across indices
        async let exactMatches = findExactMatches(processedQuery)
        async let fuzzyMatches = findFuzzyMatches(processedQuery)
        async let structureMatches = findStructureMatches(processedQuery)

        // Phase 3: Result ranking and merging
        let allMatches = await [exactMatches, fuzzyMatches, structureMatches].flatMap { $0 }
        return rankResults(allMatches, for: processedQuery)
    }
}
```

#### Fuzzy Matching Algorithm
```swift
class FuzzyMatcher {
    func findFuzzyMatches(_ query: String, threshold: Float = 0.8) -> [FuzzyMatch] {
        var matches: [FuzzyMatch] = []

        // Use Levenshtein distance with early termination
        for (token, positions) in tokenIndex {
            let distance = levenshteinDistance(query, token)
            let similarity = 1.0 - Float(distance) / Float(max(query.count, token.count))

            if similarity >= threshold {
                matches.append(FuzzyMatch(
                    token: token,
                    positions: positions,
                    similarity: similarity
                ))
            }
        }

        return matches.sorted { $0.similarity > $1.similarity }
    }
}
```

### Real-Time Search Implementation

#### Live Search with Debouncing
```swift
class LiveSearchController: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false

    private let searchEngine: SearchEngine
    private var searchTask: Task<Void, Never>?

    func search(_ query: String) {
        searchTask?.cancel()

        searchTask = Task {
            // Debounce short queries
            if query.count < 3 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            } else {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            guard !Task.isCancelled else { return }

            await MainActor.run { isSearching = true }

            let results = await searchEngine.search(query)

            await MainActor.run {
                if !Task.isCancelled {
                    searchResults = results
                    isSearching = false
                }
            }
        }
    }
}
```

#### Result Highlighting
```swift
class SearchHighlighter {
    func highlightMatches(in content: AttributedString,
                         for results: [SearchResult]) -> AttributedString {
        var highlightedContent = content

        // Sort ranges in reverse order to maintain index validity
        let sortedRanges = results
            .map { $0.range }
            .sorted { $0.location > $1.location }

        for range in sortedRanges {
            highlightedContent[range].backgroundColor = .yellow
            highlightedContent[range].foregroundColor = .black
        }

        return highlightedContent
    }
}
```

## Consequences

### Positive Consequences
- **Performance**: Sub-50ms search times for all document sizes
- **Responsiveness**: Real-time search results with live highlighting
- **Feature Richness**: Support for fuzzy search, structural search, and advanced ranking
- **Memory Efficiency**: Optimized data structures minimize memory overhead
- **Control**: Complete control over search behavior and customization
- **Integration**: Seamless integration with SwiftUI and markdown rendering

### Negative Consequences
- **Memory Usage**: Search index increases memory footprint
- **Implementation Complexity**: Significant complexity in search algorithm implementation
- **Index Maintenance**: Need to rebuild index when documents change
- **Development Time**: More development effort compared to using existing solutions

### Risk Mitigation
- **Memory Monitoring**: Implement memory usage tracking and optimization
- **Performance Testing**: Comprehensive benchmarking across document sizes
- **Incremental Updates**: Support incremental index updates for small changes
- **Fallback Strategy**: Simple text search fallback if advanced search fails
- **Profiling**: Regular performance profiling to identify bottlenecks

### Memory Management Strategy

#### Index Size Estimation
```swift
class IndexSizeEstimator {
    func estimateIndexSize(for document: DocumentModel) -> IndexSizeEstimate {
        let textLength = document.content.length
        let tokenCount = estimateTokenCount(textLength)

        // Approximate memory usage calculations
        let textIndexSize = tokenCount * 64 // bytes per token entry
        let ngramIndexSize = tokenCount * 32 // bytes per n-gram entry
        let structureIndexSize = document.headers.count * 128 // bytes per header

        return IndexSizeEstimate(
            total: textIndexSize + ngramIndexSize + structureIndexSize,
            textIndex: textIndexSize,
            ngramIndex: ngramIndexSize,
            structureIndex: structureIndexSize
        )
    }
}
```

#### Memory Optimization Techniques
- **Lazy Loading**: Only build index components when needed
- **Index Compression**: Use efficient data structures to minimize memory usage
- **Token Deduplication**: Share common tokens across index structures
- **Cleanup Strategy**: Clear old indices when documents are closed

### Performance Targets

#### Search Performance Requirements
- **Query Processing**: <10ms for query preprocessing and tokenization
- **Index Search**: <30ms for searching across all indices
- **Result Ranking**: <10ms for ranking and sorting results
- **Total Search Time**: <50ms from query to results
- **Memory Usage**: <20MB for 2MB document index
- **Index Building**: <200ms for 2MB document indexing

## Technical Implementation

### Search Result Model
```swift
struct SearchResult {
    let id: UUID
    let range: NSRange
    let context: SearchContext
    let snippet: String
    let relevanceScore: Float
    let matchType: MatchType

    enum MatchType {
        case exact
        case fuzzy(similarity: Float)
        case structure(type: StructureType)
    }
}

struct SearchContext {
    let elementType: MarkdownElementType
    let elementText: String
    let surroundingText: String
}
```

### Integration with Document Viewer
```swift
class DocumentSearchCoordinator: ObservableObject {
    @Published var currentResult: SearchResult?
    @Published var allResults: [SearchResult] = []

    func navigateToResult(_ result: SearchResult) {
        currentResult = result
        // Scroll to result and highlight
        NotificationCenter.default.post(
            name: .scrollToSearchResult,
            object: result
        )
    }

    func navigateToNext() {
        guard let current = currentResult,
              let currentIndex = allResults.firstIndex(of: current),
              currentIndex < allResults.count - 1 else { return }

        navigateToResult(allResults[currentIndex + 1])
    }
}
```

## Validation Criteria
- [ ] Search results returned within 50ms for all document sizes
- [ ] Real-time search with smooth UI interaction (60fps maintained)
- [ ] Accurate fuzzy matching with configurable similarity thresholds
- [ ] Structural search correctly identifies markdown elements
- [ ] Result highlighting accurately shows matches in rendered content
- [ ] Memory usage stays within 20MB for 2MB documents
- [ ] Index building completes within 200ms for large documents
- [ ] Search works identically across iOS and macOS platforms
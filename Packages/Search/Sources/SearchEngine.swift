/// SearchEngine - Core search functionality
///
/// High-performance in-memory search engine optimized for <100ms response times
/// with full-text indexing and relevance scoring.

import Foundation
import MarkdownCore
import OrderedCollections

/// High-performance search engine with in-memory indexing
public actor SearchEngine {
    /// Search index for documents
    private var searchIndex: SearchIndex
    private var documents: [UUID: DocumentModel] = [:]
    private var isIndexing = false

    public init() {
        self.searchIndex = SearchIndex()
    }

    // MARK: - Document Management

    /// Index a document for searching
    public func indexDocument(_ document: DocumentModel) async {
        isIndexing = true
        defer { isIndexing = false }

        // Store document
        documents[document.id] = document

        // Index document content
        await searchIndex.indexDocument(document)
    }

    /// Update existing document in index
    public func updateDocument(_ document: DocumentModel) async {
        // Remove existing index
        await removeDocument(document.id)

        // Re-index updated document
        await indexDocument(document)
    }

    /// Remove document from index
    public func removeDocument(_ documentId: UUID) async {
        documents.removeValue(forKey: documentId)
        await searchIndex.removeDocument(documentId)
    }

    /// Clear entire search index
    public func clearIndex() async {
        documents.removeAll()
        await searchIndex.clear()
    }

    // MARK: - Search Operations

    /// Perform basic search
    public func search(query: String) async -> [SearchResult] {
        guard !query.isEmpty, !isIndexing else { return [] }

        return await searchIndex.search(
            query: query,
            options: SearchOptions.default,
            documents: documents
        )
    }

    /// Perform advanced search with options
    public func advancedSearch(
        query: String,
        options: SearchOptions,
        document: DocumentModel?
    ) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        // If searching specific document, filter to that document
        let searchDocuments: [UUID: DocumentModel]
        if let document = document {
            searchDocuments = [document.id: document]
        } else {
            searchDocuments = documents
        }

        return await searchIndex.search(
            query: query,
            options: options,
            documents: searchDocuments
        )
    }

    /// Generate outline from document
    public func generateOutline(from document: DocumentModel) async throws -> [OutlineItem] {
        return document.outline.map { heading in
            OutlineItem(
                level: heading.level,
                title: heading.title,
                range: heading.range,
                position: heading.position,
                children: heading.children.map { child in
                    OutlineItem(
                        level: child.level,
                        title: child.title,
                        range: child.range,
                        position: child.position
                    )
                }
            )
        }
    }

    /// Get search statistics
    public func getStatistics() async -> SearchStatistics {
        return await searchIndex.getStatistics()
    }

    // MARK: - Real-time Search

    /// Perform incremental search as user types
    public func incrementalSearch(query: String, maxResults: Int = 10) async -> [SearchResult] {
        guard query.count >= 2 else { return [] } // Minimum 2 characters

        let options = SearchOptions(maxResults: maxResults)
        return await searchIndex.search(
            query: query,
            options: options,
            documents: documents
        )
    }

    /// Get search suggestions based on partial query
    public func getSearchSuggestions(for partialQuery: String) async -> [String] {
        return await searchIndex.getSuggestions(for: partialQuery)
    }
}

/// Search index implementation
private actor SearchIndex {
    /// Term index mapping terms to document positions
    private var termIndex: OrderedDictionary<String, Set<SearchTerm>> = [:]

    /// Document content cache for context extraction
    private var documentContent: [UUID: String] = [:]

    /// Search statistics
    private var statistics = SearchIndexStatistics()

    // MARK: - Indexing

    /// Index a document
    func indexDocument(_ document: DocumentModel) async {
        let content = document.content
        documentContent[document.id] = content

        // Tokenize content
        let tokens = tokenizeContent(content)

        // Index each token
        for token in tokens {
            let searchTerm = SearchTerm(
                documentId: document.id,
                term: token.term,
                position: token.position,
                lineNumber: token.lineNumber,
                columnNumber: token.columnNumber,
                context: token.context,
                matchType: token.matchType
            )

            if termIndex[token.term] == nil {
                termIndex[token.term] = Set()
            }
            termIndex[token.term]?.insert(searchTerm)
        }

        // Update statistics
        statistics.documentsIndexed += 1
        statistics.totalTerms = termIndex.count
        statistics.lastIndexUpdate = Date()
    }

    /// Remove document from index
    func removeDocument(_ documentId: UUID) async {
        documentContent.removeValue(forKey: documentId)

        // Remove all terms for this document
        for (term, searchTerms) in termIndex {
            let filtered = searchTerms.filter { $0.documentId != documentId }
            if filtered.isEmpty {
                termIndex.removeValue(forKey: term)
            } else {
                termIndex[term] = Set(filtered)
            }
        }

        statistics.documentsIndexed = max(0, statistics.documentsIndexed - 1)
        statistics.totalTerms = termIndex.count
    }

    /// Clear all indexed content
    func clear() async {
        termIndex.removeAll()
        documentContent.removeAll()
        statistics = SearchIndexStatistics()
    }

    // MARK: - Search

    /// Search for query in indexed documents
    func search(
        query: String,
        options: SearchOptions,
        documents: [UUID: DocumentModel]
    ) async -> [SearchResult] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            updateSearchStatistics(duration: duration)
        }

        // Process search query
        let processedQuery = processSearchQuery(query, options: options)

        // Find matching terms
        var matchingTerms: Set<SearchTerm> = Set()

        for queryTerm in processedQuery {
            if let termsForQuery = findMatchingTerms(for: queryTerm, options: options) {
                matchingTerms.formUnion(termsForQuery)
            }
        }

        // Convert to search results with scoring
        let results = await convertToSearchResults(
            matchingTerms: matchingTerms,
            query: query,
            options: options,
            documents: documents
        )

        // Sort by relevance and limit results
        let sortedResults = results
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(options.maxResults)

        return Array(sortedResults)
    }

    /// Get search suggestions
    func getSuggestions(for partialQuery: String) async -> [String] {
        let lowercaseQuery = partialQuery.lowercased()

        return termIndex.keys
            .filter { $0.lowercased().hasPrefix(lowercaseQuery) }
            .sorted()
            .prefix(10)
            .map { String($0) }
    }

    /// Get search statistics
    func getStatistics() async -> SearchStatistics {
        return SearchStatistics(
            documentsIndexed: statistics.documentsIndexed,
            totalSearchTerms: statistics.totalTerms,
            averageSearchTime: statistics.averageSearchTime,
            indexSize: calculateIndexSize(),
            lastIndexUpdate: statistics.lastIndexUpdate
        )
    }

    // MARK: - Private Implementation

    private func tokenizeContent(_ content: String) -> [Token] {
        var tokens: [Token] = []
        let lines = content.components(separatedBy: .newlines)

        for (lineIndex, line) in lines.enumerated() {
            let lineTokens = tokenizeLine(line, lineNumber: lineIndex + 1)
            tokens.append(contentsOf: lineTokens)
        }

        return tokens
    }

    private func tokenizeLine(_ line: String, lineNumber: Int) -> [Token] {
        var tokens: [Token] = []

        // Determine match type based on line content
        let matchType: MatchType
        if line.hasPrefix("#") {
            matchType = .heading
        } else if line.hasPrefix("```") {
            matchType = .codeBlock
        } else if line.contains("[") && line.contains("](") {
            matchType = .link
        } else if line.contains("**") || line.contains("*") {
            matchType = .emphasis
        } else {
            matchType = .content
        }

        // Tokenize words
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let words = line.components(separatedBy: separators)
            .filter { !$0.isEmpty }

        for (wordIndex, word) in words.enumerated() {
            let term = word.lowercased()
            let position = line.range(of: word)?.lowerBound.utf16Offset(in: line) ?? 0
            let context = extractContext(from: line, around: word)

            let token = Token(
                term: term,
                position: position,
                lineNumber: lineNumber,
                columnNumber: wordIndex + 1,
                context: context,
                matchType: matchType
            )

            tokens.append(token)
        }

        return tokens
    }

    private func extractContext(from line: String, around word: String) -> String {
        // Extract context around the word (simplified implementation)
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func processSearchQuery(_ query: String, options: SearchOptions) -> [String] {
        if options.useRegex {
            return [query] // Return regex as-is
        }

        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let terms = query.components(separatedBy: separators)
            .filter { !$0.isEmpty }

        return options.caseSensitive ? terms : terms.map { $0.lowercased() }
    }

    private func findMatchingTerms(for queryTerm: String, options: SearchOptions) -> Set<SearchTerm>? {
        if options.useRegex {
            return findRegexMatchingTerms(pattern: queryTerm)
        }

        if options.wholeWords {
            return termIndex[queryTerm]
        } else {
            // Partial matching
            var allMatches: Set<SearchTerm> = Set()
            for (indexTerm, searchTerms) in termIndex {
                if indexTerm.contains(queryTerm) {
                    allMatches.formUnion(searchTerms)
                }
            }
            return allMatches.isEmpty ? nil : allMatches
        }
    }

    private func findRegexMatchingTerms(pattern: String) -> Set<SearchTerm>? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        var allMatches: Set<SearchTerm> = Set()

        for (indexTerm, searchTerms) in termIndex {
            let range = NSRange(indexTerm.startIndex..., in: indexTerm)
            if regex.firstMatch(in: indexTerm, options: [], range: range) != nil {
                allMatches.formUnion(searchTerms)
            }
        }

        return allMatches.isEmpty ? nil : allMatches
    }

    private func convertToSearchResults(
        matchingTerms: Set<SearchTerm>,
        query: String,
        options: SearchOptions,
        documents: [UUID: DocumentModel]
    ) async -> [SearchResult] {
        var results: [SearchResult] = []

        for term in matchingTerms {
            guard let document = documents[term.documentId] else { continue }

            // Calculate relevance score
            let relevanceScore = calculateRelevanceScore(
                term: term,
                query: query,
                document: document
            )

            // Get heading context
            let headingContext = findHeadingContext(
                for: term,
                in: document
            )

            let result = SearchResult(
                documentId: term.documentId,
                text: term.term,
                context: term.context,
                range: NSRange(location: term.position, length: term.term.count),
                lineNumber: term.lineNumber,
                columnNumber: term.columnNumber,
                relevanceScore: relevanceScore,
                matchType: term.matchType,
                headingContext: headingContext
            )

            results.append(result)
        }

        return results
    }

    private func calculateRelevanceScore(
        term: SearchTerm,
        query: String,
        document: DocumentModel
    ) -> Double {
        var score: Double = 0.0

        // Base score for exact match
        if term.term.lowercased() == query.lowercased() {
            score += 1.0
        } else if term.term.lowercased().contains(query.lowercased()) {
            score += 0.7
        } else {
            score += 0.5
        }

        // Bonus for match type
        switch term.matchType {
        case .heading:
            score += 0.5
        case .emphasis:
            score += 0.2
        case .link:
            score += 0.1
        default:
            break
        }

        // Position bonus (earlier in document is more relevant)
        let positionRatio = Double(term.position) / Double(document.content.count)
        score += (1.0 - positionRatio) * 0.2

        return min(score, 1.0)
    }

    private func findHeadingContext(for term: SearchTerm, in document: DocumentModel) -> String? {
        // Find the most recent heading before this term
        let termPosition = term.position

        let relevantHeading = document.outline
            .filter { heading in
                heading.range.location <= termPosition
            }
            .max { first, second in
                first.range.location < second.range.location
            }

        return relevantHeading?.title
    }

    private func updateSearchStatistics(duration: TimeInterval) {
        statistics.searchCount += 1
        statistics.totalSearchTime += duration
        statistics.averageSearchTime = statistics.totalSearchTime / Double(statistics.searchCount)
    }

    private func calculateIndexSize() -> Int {
        return termIndex.values.reduce(0) { total, termSet in
            total + termSet.count
        }
    }
}

// MARK: - Supporting Types

/// Search term in index
private struct SearchTerm: Hashable, Sendable {
    let documentId: UUID
    let term: String
    let position: Int
    let lineNumber: Int
    let columnNumber: Int
    let context: String
    let matchType: MatchType

    func hash(into hasher: inout Hasher) {
        hasher.combine(documentId)
        hasher.combine(term)
        hasher.combine(position)
    }

    static func == (lhs: SearchTerm, rhs: SearchTerm) -> Bool {
        lhs.documentId == rhs.documentId &&
        lhs.term == rhs.term &&
        lhs.position == rhs.position
    }
}

/// Token from content tokenization
private struct Token {
    let term: String
    let position: Int
    let lineNumber: Int
    let columnNumber: Int
    let context: String
    let matchType: MatchType
}

/// Search index statistics
private struct SearchIndexStatistics {
    var documentsIndexed: Int = 0
    var totalTerms: Int = 0
    var searchCount: Int = 0
    var totalSearchTime: TimeInterval = 0
    var averageSearchTime: TimeInterval = 0
    var lastIndexUpdate: Date = Date()
}

/// Search performance monitor
public actor SearchPerformanceMonitor {
    public static let shared = SearchPerformanceMonitor()

    private var operationTimes: [String: [TimeInterval]] = [:]
    private var isMonitoring = false

    private init() {}

    public func initialize() {
        isMonitoring = true
    }

    public func trackOperation<T>(_ operationName: String, operation: () async -> T) async -> T {
        guard isMonitoring else {
            return await operation()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        await recordOperationTime(operationName, duration: duration)
        return result
    }

    public func trackSyncOperation<T>(_ operationName: String, operation: () -> T) -> T {
        guard isMonitoring else {
            return operation()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        Task {
            await recordOperationTime(operationName, duration: duration)
        }

        return result
    }

    private func recordOperationTime(_ operationName: String, duration: TimeInterval) {
        if operationTimes[operationName] == nil {
            operationTimes[operationName] = []
        }
        operationTimes[operationName]?.append(duration)

        // Keep only the last 100 measurements
        if operationTimes[operationName]!.count > 100 {
            operationTimes[operationName]?.removeFirst()
        }
    }

    public func getAverageTime(for operationName: String) -> TimeInterval? {
        guard let times = operationTimes[operationName], !times.isEmpty else {
            return nil
        }

        return times.reduce(0, +) / Double(times.count)
    }
}
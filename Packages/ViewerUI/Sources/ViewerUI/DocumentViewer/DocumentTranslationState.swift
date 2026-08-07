import Foundation

enum TranslationToggleAction: Equatable {
    case startTranslation
    case showEnglish
    case showCachedChinese
}

/// Identifies a translatable unit of a document.
///
/// Most blocks translate as a whole and are keyed by their 1-based source line.
/// Tables are the exception: each cell is translated independently so the grid
/// keeps its shape, so table units carry their row/column as well.
enum TranslationKey {
    /// Key for a whole block (heading, paragraph, blockquote, list).
    static func block(line: Int) -> String {
        String(line)
    }

    /// Key for a single table cell. Row 0 is the header row.
    static func tableCell(line: Int, row: Int, column: Int) -> String {
        "\(line)#\(row)#\(column)"
    }
}

struct DocumentTranslationState: Equatable {
    /// Translated text by `TranslationKey`.
    private(set) var translatedBlocks: [String: String] = [:]
    private(set) var isShowingChinese = false
    private(set) var isTranslating = false
    private(set) var completedBlockCount = 0
    private(set) var totalBlockCount = 0
    private(set) var errorMessage: String?

    var progressText: String? {
        guard isTranslating, totalBlockCount > 0 else { return nil }
        return "Translating \(completedBlockCount)/\(totalBlockCount)…"
    }

    mutating func toggle() -> TranslationToggleAction {
        errorMessage = nil

        if isShowingChinese {
            isShowingChinese = false
            return .showEnglish
        }

        if !translatedBlocks.isEmpty {
            isShowingChinese = true
            return .showCachedChinese
        }

        isTranslating = true
        completedBlockCount = 0
        totalBlockCount = 0
        return .startTranslation
    }

    mutating func beginTranslation(totalBlockCount: Int) {
        isTranslating = true
        completedBlockCount = 0
        self.totalBlockCount = totalBlockCount
        errorMessage = nil
    }

    mutating func recordTranslatedBlock() {
        completedBlockCount = min(completedBlockCount + 1, totalBlockCount)
    }

    mutating func translatedBlockArrived(key: String, text: String) {
        let isNewBlock = translatedBlocks[key] == nil
        translatedBlocks[key] = text
        isShowingChinese = true
        if isNewBlock {
            recordTranslatedBlock()
        }
    }

    mutating func showCachedTranslation(_ blocks: [String: String]) {
        translatedBlocks = blocks
        completedBlockCount = blocks.count
        totalBlockCount = blocks.count
        isShowingChinese = !blocks.isEmpty
        isTranslating = false
        errorMessage = nil
    }

    mutating func complete(with blocks: [String: String]) {
        translatedBlocks = blocks
        isShowingChinese = true
        isTranslating = false
        completedBlockCount = blocks.count
        totalBlockCount = max(totalBlockCount, blocks.count)
        errorMessage = nil
    }

    mutating func cancel() {
        isShowingChinese = false
        isTranslating = false
        completedBlockCount = 0
        totalBlockCount = 0
        errorMessage = nil
    }

    mutating func fail(with message: String) {
        isShowingChinese = false
        isTranslating = false
        errorMessage = message
    }

    mutating func reset() {
        self = DocumentTranslationState()
    }
}

#if os(macOS)
/// Small disk-backed cache for completed document translations.
struct TranslationCache {
    private struct Entry: Codable {
        let blocks: [String: String]
    }

    /// Bumped when the on-disk shape changes. v1 keyed blocks by source line and
    /// had no table cells; v2 keys by `TranslationKey`. Older files are simply
    /// never read (a different suffix), so a stale cache re-translates instead of
    /// decoding into the wrong shape.
    private static let formatVersion = "v2"

    private let directory: URL

    init(fileManager: FileManager = .default) {
        self.init(
            directory: fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MarkdownReader/Translations", isDirectory: true),
            fileManager: fileManager
        )
    }

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(for key: String) -> [String: String]? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else {
            return nil
        }
        return entry.blocks
    }

    func save(_ blocks: [String: String], for key: String) {
        let url = fileURL(for: key)
        guard let data = try? JSONEncoder().encode(Entry(blocks: blocks)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(key).\(Self.formatVersion).json")
    }
}
#endif

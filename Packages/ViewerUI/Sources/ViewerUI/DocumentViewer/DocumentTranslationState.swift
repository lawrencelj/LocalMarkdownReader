import Foundation

enum TranslationToggleAction: Equatable {
    case startTranslation
    case showEnglish
    case showCachedChinese
}

struct DocumentTranslationState: Equatable {
    private(set) var translatedBlocks: [Int: String] = [:]
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

    mutating func translatedBlockArrived(line: Int, text: String) {
        let isNewBlock = translatedBlocks[line] == nil
        translatedBlocks[line] = text
        isShowingChinese = true
        if isNewBlock {
            recordTranslatedBlock()
        }
    }

    mutating func showCachedTranslation(_ blocks: [Int: String]) {
        translatedBlocks = blocks
        completedBlockCount = blocks.count
        totalBlockCount = blocks.count
        isShowingChinese = !blocks.isEmpty
        isTranslating = false
        errorMessage = nil
    }

    mutating func complete(with blocks: [Int: String]) {
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
        let blocks: [Int: String]
    }

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

    func load(for key: String) -> [Int: String]? {
        let url = directory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else {
            return nil
        }
        return entry.blocks
    }

    func save(_ blocks: [Int: String], for key: String) {
        let url = directory.appendingPathComponent("\(key).json")
        guard let data = try? JSONEncoder().encode(Entry(blocks: blocks)) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
#endif

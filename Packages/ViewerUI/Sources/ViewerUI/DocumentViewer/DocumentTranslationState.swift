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
    private(set) var errorMessage: String?

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
        return .startTranslation
    }

    mutating func complete(with blocks: [Int: String]) {
        translatedBlocks = blocks
        isShowingChinese = true
        isTranslating = false
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

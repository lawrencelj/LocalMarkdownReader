/// TabState - Multi-tab document management
///
/// Manages multiple open documents as tabs with independent scroll positions
/// and state. Integrates with AppStateCoordinator for centralized state management.

import MarkdownCore
import SwiftUI

/// Represents a single document tab with associated state
public struct TabItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let document: DocumentModel
    public var scrollPosition: CGFloat
    public var selectedRange: NSRange?

    public init(
        id: UUID = UUID(),
        document: DocumentModel,
        scrollPosition: CGFloat = 0,
        selectedRange: NSRange? = nil
    ) {
        self.id = id
        self.document = document
        self.scrollPosition = scrollPosition
        self.selectedRange = selectedRange
    }

    /// Display title for the tab
    public var title: String {
        document.metadata.title ?? document.reference.url.deletingPathExtension().lastPathComponent
    }

    /// Short title for display in tab bar (truncate if needed)
    public var shortTitle: String {
        let maxLength = 20
        let title = self.title
        if title.count > maxLength {
            return String(title.prefix(maxLength - 1)) + "…"
        }
        return title
    }
}

/// Observable state manager for document tabs
@MainActor
@Observable
public class TabState {
    /// All open tabs
    public var tabs: [TabItem] = []

    /// ID of the currently active tab
    public var activeTabId: UUID?

    /// Maximum number of tabs allowed
    public let maxTabs: Int = 20

    public init() {}

    /// Get the currently active tab
    public var activeTab: TabItem? {
        guard let activeId = activeTabId else { return nil }
        return tabs.first { $0.id == activeId }
    }

    /// Get index of active tab
    public var activeTabIndex: Int? {
        guard let activeId = activeTabId else { return nil }
        return tabs.firstIndex { $0.id == activeId }
    }

    // MARK: - Tab Management

    /// Add a new tab with a document
    public func addTab(document: DocumentModel) {
        // Check if document is already open in a tab
        if let existingTab = tabs.first(where: { $0.document.id == document.id }) {
            // Switch to existing tab
            activeTabId = existingTab.id
            return
        }

        // Check max tabs limit
        guard tabs.count < maxTabs else {
            print("Maximum tab limit (\(maxTabs)) reached")
            return
        }

        // Create new tab
        let newTab = TabItem(document: document)
        tabs.append(newTab)

        // Make it active
        activeTabId = newTab.id
    }

    /// Close a tab by ID
    public func closeTab(_ tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

        // If closing active tab, activate another tab
        if tabId == activeTabId {
            if index > 0 {
                // Activate previous tab
                activeTabId = tabs[index - 1].id
            } else if index < tabs.count - 1 {
                // Activate next tab
                activeTabId = tabs[index + 1].id
            } else {
                // No other tabs
                activeTabId = nil
            }
        }

        // Remove tab
        tabs.remove(at: index)
    }

    /// Close all tabs
    public func closeAllTabs() {
        tabs.removeAll()
        activeTabId = nil
    }

    /// Close all tabs except the active one
    public func closeOtherTabs() {
        guard let activeId = activeTabId,
              let activeTab = tabs.first(where: { $0.id == activeId }) else {
            return
        }

        tabs = [activeTab]
    }

    /// Switch to a specific tab
    public func switchToTab(_ tabId: UUID) {
        guard tabs.contains(where: { $0.id == tabId }) else { return }
        activeTabId = tabId
    }

    /// Switch to next tab (with wrapping)
    public func switchToNextTab() {
        guard !tabs.isEmpty else { return }

        if let currentIndex = activeTabIndex {
            let nextIndex = (currentIndex + 1) % tabs.count
            activeTabId = tabs[nextIndex].id
        } else if !tabs.isEmpty {
            activeTabId = tabs[0].id
        }
    }

    /// Switch to previous tab (with wrapping)
    public func switchToPreviousTab() {
        guard !tabs.isEmpty else { return }

        if let currentIndex = activeTabIndex {
            let previousIndex = currentIndex == 0 ? tabs.count - 1 : currentIndex - 1
            activeTabId = tabs[previousIndex].id
        } else if !tabs.isEmpty {
            activeTabId = tabs.last?.id
        }
    }

    // MARK: - Tab State Updates

    /// Update scroll position for a specific tab
    public func updateScrollPosition(_ position: CGFloat, for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[index].scrollPosition = position
    }

    /// Update selected range for a specific tab
    public func updateSelectedRange(_ range: NSRange?, for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[index].selectedRange = range
    }

    /// Update scroll position for active tab
    public func updateActiveTabScrollPosition(_ position: CGFloat) {
        guard let activeId = activeTabId else { return }
        updateScrollPosition(position, for: activeId)
    }

    /// Update selected range for active tab
    public func updateActiveTabSelectedRange(_ range: NSRange?) {
        guard let activeId = activeTabId else { return }
        updateSelectedRange(range, for: activeId)
    }
}

// MARK: - Preview Support

extension TabState {
    public static var preview: TabState {
        let state = TabState()

        // Create sample documents
        let doc1 = DocumentModel.preview
        let doc2 = DocumentModel.preview

        state.addTab(document: doc1)
        state.addTab(document: doc2)

        return state
    }

    public static var previewSingle: TabState {
        let state = TabState()
        state.addTab(document: DocumentModel.preview)
        return state
    }

    public static var previewEmpty: TabState {
        TabState()
    }
}

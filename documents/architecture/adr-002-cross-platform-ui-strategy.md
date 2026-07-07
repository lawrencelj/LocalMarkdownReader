# ADR-002: Cross-Platform UI Strategy

## Status
**APPROVED** - 2025-01-23

## Context

The Swift Markdown Reader must provide native user experiences on both iOS and macOS while maximizing code sharing and maintaining platform-specific design patterns. The application must feel natural on each platform while avoiding the compromises typically associated with cross-platform solutions.

### Requirements
- **Platform Native Feel**: Follow iOS Human Interface Guidelines and macOS Design Guidelines
- **Code Sharing**: Maximize shared business logic and UI components where appropriate
- **Performance**: 60fps UI performance on both platforms
- **Maintainability**: Single codebase with minimal platform-specific duplication
- **Feature Parity**: Core functionality available on both platforms with platform-appropriate adaptations
- **Future Scalability**: Architecture supports adding watchOS/visionOS in the future

### Platform Differences to Address
- **Navigation Patterns**: iOS navigation stack vs macOS sidebar/toolbar
- **Input Methods**: Touch gestures vs mouse/keyboard interaction
- **Window Management**: iOS single window vs macOS multi-window
- **Menu Systems**: iOS limited menus vs macOS extensive menu bar
- **File Access**: iOS document picker vs macOS open panels
- **Keyboard Shortcuts**: iOS limited vs macOS extensive shortcut support

### Options Considered

#### Option 1: SwiftUI-First with Targeted UIKit/AppKit Integration (SELECTED)
- **Pros**:
  - Maximum code sharing for business logic and core UI
  - Native performance and platform integration
  - Declarative UI reduces complexity and bugs
  - SwiftUI handles platform differences automatically for common patterns
  - Future-ready for new Apple platforms
  - Smaller codebase with better maintainability
- **Cons**:
  - Some advanced platform features require UIKit/AppKit integration
  - SwiftUI learning curve for complex custom components
  - Potential limitations for highly customized UI elements

#### Option 2: Platform-Specific Apps with Shared Framework
- **Pros**:
  - Complete control over platform-specific user experience
  - Access to all platform capabilities without limitations
  - Optimal performance for each platform
- **Cons**:
  - Significant code duplication between platforms
  - Higher maintenance burden with separate UI codebases
  - Slower feature development and potential feature drift
  - Complex coordination between platform teams

#### Option 3: UIKit/AppKit with Manual Cross-Platform Abstractions
- **Pros**:
  - Complete platform control and flexibility
  - Access to all advanced platform features
- **Cons**:
  - Massive development overhead for cross-platform abstractions
  - Complex manual view lifecycle management
  - Higher bug potential due to manual platform coordination
  - Much larger codebase and development time

## Decision

**Selected: SwiftUI-First with Targeted UIKit/AppKit Integration**

### Implementation Strategy

#### 1. SwiftUI Core (90% of UI)
```swift
// Shared SwiftUI components
- DocumentViewer (adaptive layout)
- SearchInterface (platform-adaptive)
- SettingsView (adaptive to platform conventions)
- NavigationSidebar (responsive design)
- ThemeSelector (universal component)
```

#### 2. Platform Adapters (10% of UI)
```swift
// iOS-specific integrations
- UIDocumentPickerViewController wrapper
- iOS-specific gesture recognizers
- iOS navigation enhancements

// macOS-specific integrations
- NSOpenPanel wrapper
- Menu bar integration
- macOS keyboard shortcut handling
- Touch Bar support (if applicable)
```

#### 3. Responsive Design Patterns
```swift
// Adaptive navigation
@Environment(\.horizontalSizeClass) var sizeClass
@Environment(\.platform) var platform

// Platform-specific behaviors
#if os(iOS)
    NavigationStack { ... }
#elseif os(macOS)
    NavigationSplitView { ... }
#endif
```

### Architecture Layers

#### Layer 1: Shared Business Logic (100% shared)
- Markdown parsing and rendering
- Search functionality
- Document management
- User preferences
- Theme management

#### Layer 2: SwiftUI Views (95% shared)
- Core document viewing components
- Search interface
- Settings and preferences
- Theme selection
- Navigation structure

#### Layer 3: Platform Integration (Platform-specific)
- File system access patterns
- Platform-specific UI enhancements
- Keyboard/gesture handling
- Menu and toolbar customization

## Consequences

### Positive Consequences
- **Development Velocity**: Single SwiftUI codebase accelerates feature development
- **Consistency**: Shared components ensure consistent behavior across platforms
- **Maintainability**: Smaller codebase reduces bug surface area and maintenance overhead
- **Future-Proofing**: SwiftUI architecture supports easy expansion to new platforms
- **Performance**: Native SwiftUI performance characteristics on both platforms
- **Platform Integration**: Targeted UIKit/AppKit integration provides native platform features

### Negative Consequences
- **SwiftUI Limitations**: Some advanced UI customizations may require workarounds
- **Platform Optimization**: May not achieve 100% optimal platform-specific experience
- **Complexity in Integration**: UIKit/AppKit bridging adds complexity for advanced features
- **SwiftUI Evolution**: Dependency on SwiftUI evolution for advanced features

### Risk Mitigation
- **Incremental UIKit/AppKit Integration**: Add platform-specific code only when necessary
- **Platform Testing**: Dedicated testing on both platforms for user experience validation
- **Performance Monitoring**: Continuous performance monitoring to ensure 60fps target
- **SwiftUI Expertise**: Team training on advanced SwiftUI patterns and best practices

### Platform-Specific Adaptations

#### iOS Optimizations
```swift
// Touch-optimized interactions
.onTapGesture { ... }
.onLongPressGesture { ... }
.swipeActions { ... }

// iOS-specific navigation
NavigationStack {
    DocumentView()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
}
```

#### macOS Optimizations
```swift
// Keyboard-optimized interactions
.keyboardShortcut("o", modifiers: .command)
.keyboardShortcut("f", modifiers: .command)

// macOS-specific layout
NavigationSplitView {
    SidebarView()
} detail: {
    DocumentView()
        .toolbar {
            ToolbarItemGroup { ... }
        }
}
```

### Integration Points

#### File Access Integration
```swift
// Platform-specific file pickers
#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // iOS document picker implementation
    }
}
#elseif os(macOS)
struct DocumentPicker: View {
    var body: some View {
        Button("Open") {
            // NSOpenPanel implementation
        }
    }
}
#endif
```

#### Menu Integration
```swift
// macOS menu bar integration
#if os(macOS)
@main
struct MarkdownReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            FileCommands()
            EditCommands()
            ViewCommands()
        }
    }
}
#endif
```

## Technical Implementation

### Shared Component Architecture
```swift
// Base component with platform adaptations
struct DocumentViewer: View {
    @Environment(\.platform) var platform

    var body: some View {
        ScrollView {
            MarkdownContentView()
        }
        .if(platform == .macOS) { view in
            view.scrollIndicators(.visible)
        }
        .if(platform == .iOS) { view in
            view.refreshable { refreshDocument() }
        }
    }
}
```

### Platform Detection and Adaptation
```swift
extension EnvironmentValues {
    var platform: Platform {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #endif
    }
}

enum Platform {
    case iOS, macOS
}
```

## Validation Criteria
- [ ] Core functionality identical on both platforms
- [ ] Platform-specific features properly implemented
- [ ] 60fps performance maintained on both platforms
- [ ] Platform design guidelines followed
- [ ] Code sharing >90% for business logic
- [ ] UI code sharing >85% overall
- [ ] User experience feels native on each platform
- [ ] Accessibility compliance on both platforms
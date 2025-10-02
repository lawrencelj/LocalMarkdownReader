/// LoadingIndicator - Reusable loading states with accessibility support
///
/// Provides various loading indicator styles with proper accessibility
/// announcements, animation controls, and cross-platform adaptations.

import SwiftUI

/// Configurable loading indicator with accessibility support
public struct LoadingIndicator: View {
    // MARK: - Configuration

    public let style: LoadingStyle
    public let message: String?
    public let progress: Double?

    // MARK: - Environment

    @Environment(\.platform) private var platform
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - State

    @State private var isAnimating = false
    @State private var hasAnnounced = false

    // MARK: - Initialization

    public init(
        style: LoadingStyle = .spinner,
        message: String? = nil,
        progress: Double? = nil
    ) {
        self.style = style
        self.message = message
        self.progress = progress
    }

    // MARK: - View Body

    public var body: some View {
        VStack(spacing: spacingForCurrentSize) {
            indicatorView

            if let message = message {
                messageView(message)
            }

            if let progress = progress {
                progressView(progress)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            startAnimation()
            announceLoading()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: message) { _, _ in
            announceLoadingUpdate()
        }
        .onChange(of: progress) { _, _ in
            announceProgressUpdate()
        }
    }

    // MARK: - Indicator Views

    @ViewBuilder
    private var indicatorView: some View {
        switch style {
        case .spinner:
            spinnerView

        case .dots:
            dotsView

        case .pulse:
            pulseView

        case .progress:
            progressSpinner

        case .minimal:
            minimalView
        }
    }

    private var spinnerView: some View {
        ProgressView()
            .scaleEffect(scaleForCurrentSize)
            .tint(themeManager.color(for: .accent))
            .accessibilityHidden(true) // Message provides context
    }

    private var dotsView: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(themeManager.color(for: .accent))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private var pulseView: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(themeManager.color(for: .accent), lineWidth: 2)
                    .frame(width: pulseSize, height: pulseSize)
                    .scaleEffect(isAnimating ? 1.5 : 0.5)
                    .opacity(isAnimating ? 0.0 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: isAnimating
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private var progressSpinner: some View {
        ZStack {
            Circle()
                .stroke(
                    themeManager.color(for: .accent).opacity(0.2),
                    lineWidth: progressLineWidth
                )

            Circle()
                .trim(from: 0, to: progress ?? 0.3)
                .stroke(
                    themeManager.color(for: .accent),
                    style: StrokeStyle(
                        lineWidth: progressLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .frame(width: progressSize, height: progressSize)
        .accessibilityHidden(true)
    }

    private var minimalView: some View {
        Rectangle()
            .fill(themeManager.color(for: .accent))
            .frame(width: 2, height: 20)
            .opacity(isAnimating ? 1.0 : 0.3)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .accessibilityHidden(true)
    }

    // MARK: - Supporting Views

    @ViewBuilder
    private func messageView(_ text: String) -> some View {
        Text(text)
            .font(themeManager.font(.subheadline))
            .foregroundStyle(themeManager.color(for: .secondary))
            .multilineTextAlignment(.center)
            .accessibilityLabel(text)
    }

    @ViewBuilder
    private func progressView(_ value: Double) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: value)
                .tint(themeManager.color(for: .accent))
                .scaleEffect(y: 1.5)

            Text("\(Int(value * 100))%")
                .font(themeManager.font(.caption))
                .foregroundStyle(themeManager.color(for: .secondary))
                .monospacedDigit()
        }
    }

    // MARK: - Computed Properties

    private var spacingForCurrentSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 12
        case .medium, .large:
            return 16
        case .xLarge, .xxLarge:
            return 20
        default: // Accessibility sizes
            return 24
        }
    }

    private var scaleForCurrentSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 1.0
        case .medium, .large:
            return 1.2
        case .xLarge, .xxLarge:
            return 1.4
        default: // Accessibility sizes
            return 1.6
        }
    }

    private var dotSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 8
        case .medium, .large:
            return 10
        case .xLarge, .xxLarge:
            return 12
        default: // Accessibility sizes
            return 14
        }
    }

    private var pulseSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 40
        case .medium, .large:
            return 50
        case .xLarge, .xxLarge:
            return 60
        default: // Accessibility sizes
            return 70
        }
    }

    private var progressSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 30
        case .medium, .large:
            return 40
        case .xLarge, .xxLarge:
            return 50
        default: // Accessibility sizes
            return 60
        }
    }

    private var progressLineWidth: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 3
        case .medium, .large:
            return 4
        case .xLarge, .xxLarge:
            return 5
        default: // Accessibility sizes
            return 6
        }
    }

    private var accessibilityLabel: String {
        if let message = message {
            return "Loading: \(message)"
        } else {
            return "Loading"
        }
    }

    private var accessibilityValue: String {
        if let progress = progress {
            return "\(Int(progress * 100)) percent complete"
        } else {
            return "In progress"
        }
    }

    // MARK: - Animation Control

    private func startAnimation() {
        guard !themeManager.isReduceMotionEnabled else { return }

        withAnimation {
            isAnimating = true
        }
    }

    private func stopAnimation() {
        withAnimation {
            isAnimating = false
        }
    }

    // MARK: - Accessibility Announcements

    private func announceLoading() {
        guard !hasAnnounced else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let announcement = message ?? "Loading"
            AccessibilityNotification.Announcement(announcement).post()
            hasAnnounced = true
        }
    }

    private func announceLoadingUpdate() {
        guard let message = message else { return }

        AccessibilityNotification.Announcement(message).post()
    }

    private func announceProgressUpdate() {
        guard let progress = progress else { return }

        // Only announce at significant intervals
        let percentage = Int(progress * 100)
        if percentage % 25 == 0 {
            let announcement = "\(percentage) percent complete"
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

// MARK: - Loading Styles

public enum LoadingStyle: CaseIterable {
    case spinner
    case dots
    case pulse
    case progress
    case minimal

    public var displayName: String {
        switch self {
        case .spinner: return "Spinner"
        case .dots: return "Dots"
        case .pulse: return "Pulse"
        case .progress: return "Progress"
        case .minimal: return "Minimal"
        }
    }
}

// MARK: - Convenience Initializers

extension LoadingIndicator {
    /// Document loading indicator
    public static func documentLoading(message: String? = nil) -> LoadingIndicator {
        LoadingIndicator(
            style: .spinner,
            message: message ?? "Loading document..."
        )
    }

    /// Search loading indicator
    public static func searching(message: String? = nil) -> LoadingIndicator {
        LoadingIndicator(
            style: .dots,
            message: message ?? "Searching..."
        )
    }

    /// Progress-based loading
    public static func progress(_ value: Double, message: String? = nil) -> LoadingIndicator {
        LoadingIndicator(
            style: .progress,
            message: message,
            progress: value
        )
    }

    /// Minimal loading for small spaces
    public static var minimal: LoadingIndicator {
        LoadingIndicator(style: .minimal)
    }
}

// MARK: - View Extensions

extension View {
    /// Add loading overlay to any view
    public func loadingOverlay(
        isLoading: Bool,
        style: LoadingStyle = .spinner,
        message: String? = nil
    ) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    LoadingIndicator(style: style, message: message)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                        )
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                ForEach(LoadingStyle.allCases, id: \.self) { style in
                    VStack(spacing: 16) {
                        Text(style.displayName)
                            .font(.headline)

                        LoadingIndicator(
                            style: style,
                            message: "Loading content...",
                            progress: style == .progress ? 0.7 : nil
                        )
                    }
                    .frame(height: 100)
                }
            }
            .padding()
        }
        .previewDisplayName("Loading Indicators")
    }
}

struct LoadingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Sample Content")
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.1))
        }
        .loadingOverlay(
            isLoading: true,
            style: .spinner,
            message: "Loading document..."
        )
        .previewDisplayName("Loading Overlay")
    }
}
#endif

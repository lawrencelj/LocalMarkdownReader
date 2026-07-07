/// LoadingIndicator - Reusable loading states with accessibility support

import SwiftUI

/// Configurable loading indicator with accessibility support
public struct LoadingIndicator: View {
    public let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Document loading indicator
    public static func documentLoading(message: String? = nil) -> LoadingIndicator {
        LoadingIndicator(message: message ?? "Loading document...")
    }

    /// Search loading indicator
    public static func searching(message: String? = nil) -> LoadingIndicator {
        LoadingIndicator(message: message ?? "Searching...")
    }
}

// MARK: - View Extension

extension View {
    /// Add loading overlay to any view
    public func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    LoadingIndicator(message: message)
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
                }
                .transition(.opacity)
            }
        }
    }
}

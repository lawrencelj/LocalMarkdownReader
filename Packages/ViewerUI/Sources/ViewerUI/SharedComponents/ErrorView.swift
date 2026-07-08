// ErrorView - Comprehensive error display with recovery actions

import SwiftUI

/// Comprehensive error display with recovery actions
public struct ErrorView: View {
    public let error: Error
    public let retryAction: (() -> Void)?
    public let dismissAction: (() -> Void)?

    public init(
        error: Error,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("An Error Occurred")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                if let retryAction = retryAction {
                    Button("Try Again") {
                        retryAction()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(error.localizedDescription)")
    }
}

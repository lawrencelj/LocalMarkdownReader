/// PerformanceMonitor - Lightweight performance tracking and monitoring
///
/// Provides simple performance monitoring for document viewer optimization
/// without heavy instrumentation overhead.

import Foundation

/// Lightweight performance monitoring for document viewer
@MainActor
public class PerformanceMonitor {
    public static let shared = PerformanceMonitor()

    private var isMonitoring = false
    private var documentViewerTask: Task<Void, Never>?

    private init() {}

    /// Initialize performance monitoring
    public func initialize() async {
        // Basic initialization - no heavy setup needed
        isMonitoring = true
    }

    /// Start document viewer specific monitoring
    public func startDocumentViewerMonitoring() async {
        guard !isMonitoring else { return }

        isMonitoring = true
        documentViewerTask = Task {
            await monitorDocumentViewer()
        }
    }

    /// Stop document viewer monitoring
    public func stopDocumentViewerMonitoring() {
        documentViewerTask?.cancel()
        documentViewerTask = nil
        isMonitoring = false
    }

    /// Start coordinator-specific monitoring
    public func startCoordinatorMonitoring() async {
        guard !isMonitoring else { return }

        isMonitoring = true
        print("📊 AppStateCoordinator performance monitoring started")

        // Start basic monitoring for coordinator operations
        documentViewerTask = Task {
            await monitorCoordinatorPerformance()
        }
    }

    /// Track an operation's performance
    public func trackOperation<T>(_ name: String, operation: @escaping () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("📊 Operation '\(name)' took \(String(format: "%.3f", duration))s")

        return result
    }

    /// Get current memory usage in bytes
    public func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }

    /// Monitor document viewer performance
    private func monitorDocumentViewer() async {
        while !Task.isCancelled && isMonitoring {
            // Simple monitoring - just track basic metrics
            let memoryUsage = getCurrentMemoryUsage()

            // Log high memory usage
            if memoryUsage > 200 * 1024 * 1024 { // > 200MB
                print("⚠️ High memory usage detected: \(memoryUsage / 1024 / 1024)MB")
            }

            try? await Task.sleep(for: .seconds(5))
        }
    }

    /// Monitor coordinator performance
    private func monitorCoordinatorPerformance() async {
        while !Task.isCancelled && isMonitoring {
            // Monitor coordinator-specific metrics
            let memoryUsage = getCurrentMemoryUsage()

            // Log coordinator memory usage thresholds
            let memoryMB = memoryUsage / 1024 / 1024
            if memoryMB > 150 {
                print("📊 Coordinator memory usage: \(memoryMB)MB")
            }

            try? await Task.sleep(for: .seconds(10))
        }
    }
}

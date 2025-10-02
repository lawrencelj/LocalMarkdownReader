/// PerformanceMetrics - Basic performance metrics collection
///
/// Provides lightweight metrics collection for frame rate and memory monitoring
/// without the overhead of full instrumentation frameworks.

import Foundation
import SwiftUI

/// Basic performance metrics collection
@MainActor
public class PerformanceMetrics {
    public static let shared = PerformanceMetrics()

    private var frameRateHistory: [Double] = []
    private var memoryHistory: [Int64] = []
    private var lastFrameTime: CFTimeInterval = 0

    private init() {}

    /// Record current frame rate
    public func recordFrameRate() async {
        let currentTime = CACurrentMediaTime()

        if lastFrameTime > 0 {
            let frameDuration = currentTime - lastFrameTime
            let frameRate = 1.0 / frameDuration

            // Store reasonable frame rates (avoid division by very small numbers)
            if frameRate > 0 && frameRate < 200 {
                frameRateHistory.append(frameRate)

                // Keep only recent history
                if frameRateHistory.count > 60 {
                    frameRateHistory.removeFirst()
                }

                // Log low frame rates
                if frameRate < 30 {
                    print("📊 Low frame rate: \(String(format: "%.1f", frameRate))fps")
                }
            }
        }

        lastFrameTime = currentTime
    }

    /// Record current memory usage
    public func recordMemoryUsage() async {
        let memoryUsage = getCurrentMemoryUsage()
        memoryHistory.append(memoryUsage)

        // Keep only recent history
        if memoryHistory.count > 60 {
            memoryHistory.removeFirst()
        }

        // Log high memory usage
        let memoryMB = memoryUsage / 1024 / 1024
        if memoryMB > 150 {
            print("📊 High memory usage: \(memoryMB)MB")
        }
    }

    /// Get current memory usage
    private func getCurrentMemoryUsage() -> Int64 {
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

        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    /// Get average frame rate
    public func getAverageFrameRate() -> Double {
        guard !frameRateHistory.isEmpty else { return 0 }
        return frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
    }

    /// Get average memory usage
    public func getAverageMemoryUsage() -> Int64 {
        guard !memoryHistory.isEmpty else { return 0 }
        return memoryHistory.reduce(0, +) / Int64(memoryHistory.count)
    }
}

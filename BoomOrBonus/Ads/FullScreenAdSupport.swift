//
//  FullScreenAdSupport.swift
//  BoomOrBonus
//
//  Shared by the rewarded and interstitial managers.
//

import Foundation
import UIKit

/// Exponential back-off for background reloads: 4 s, 8 s, ... capped at 60 s.
struct LoadBackoff {
    private(set) var attempts = 0
    mutating func next() -> TimeInterval {
        attempts += 1
        return min(60, 4 * pow(2, Double(min(attempts - 1, 6))))
    }
    mutating func reset() { attempts = 0 }
}

/// Guards a presentation: if the ad never reports that it appeared, the caller is released with a failure.
@MainActor
final class PresentWatchdog {
    private var task: Task<Void, Never>?
    func start(after seconds: Double = 5, onTimeout: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled { onTimeout() }
        }
    }
    func cancel() { task?.cancel(); task = nil }
}

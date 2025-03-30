//
//  HapticManager.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    private init() { }

    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func playError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    func playClick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

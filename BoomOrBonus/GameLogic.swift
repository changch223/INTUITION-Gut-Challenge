//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI

enum Operation: String, CaseIterable {
    case add = "+"
    case subtract = "-"
    case multiply = "×"

    static func random() -> Operation {
        Operation.allCases.randomElement()!
    }

    func apply(_ lhs: Int, _ rhs: Int) -> Int {
        switch self {
        case .add: return lhs + rhs
        case .subtract: return lhs - rhs
        case .multiply: return lhs * rhs
        }
    }
}

struct Option {
    var operation: Operation
    var number: Int
    var isBomb: Bool = false

    static func generatePair() -> [Option] {
        let safeOption = Option(operation: .random(), number: Int.random(in: 1...10))
        let bombOption = Option(operation: .random(), number: Int.random(in: 1...10), isBomb: true)
        return [safeOption, bombOption].shuffled()
    }
}

class GameLogic: ObservableObject {
    @Published var currentValue: Int = 0
    @Published var options: [Option] = Option.generatePair()
    @Published var isGameOver = false
    @Published var luckScore: Int = 0

    func selectOption(_ option: Option) {
        if option.isBomb {
            isGameOver = true
        } else {
            currentValue = option.operation.apply(currentValue, option.number)
            luckScore += 1
            options = Option.generatePair()
        }
    }

    func resetGame() {
        currentValue = 0
        luckScore = 0
        isGameOver = false
        options = Option.generatePair()
    }
}

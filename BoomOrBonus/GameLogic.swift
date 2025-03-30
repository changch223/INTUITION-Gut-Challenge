//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI
import Foundation

enum Operation: String, CaseIterable {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    
    static func random() -> Operation {
        let rand = Double.random(in: 0..<1)
        if rand < 0.6 {
            return .add
        } else if rand < 0.8 {
            return .subtract
        } else {
            return .multiply
        }
    }
    
    func apply(_ lhs: Int, _ rhs: Int) -> Int {
        switch self {
        case .add:
            return lhs + rhs
        case .subtract:
            return lhs - rhs
        case .multiply:
            return lhs * rhs
        }
    }
}

struct Option {
    var operation: Operation
    var number: Int
    var isBomb: Bool = false
    
    // 以指數遞減方式生成 1～50 的隨機數，alpha = 0.24
    static func randomNumber() -> Int {
        let alpha = 0.24
        let numbers = Array(1...50)
        let weights = numbers.map { exp(-alpha * Double($0 - 1)) }
        let totalWeight = weights.reduce(0, +)
        let rand = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if rand < cumulative {
                return numbers[index]
            }
        }
        return 50
    }
    
    // 生成一組選項：一個安全選項、一個炸彈選項（順序隨機）
    static func generatePair() -> [Option] {
        let safeOption = Option(operation: Operation.random(), number: randomNumber())
        let bombOption = Option(operation: Operation.random(), number: randomNumber(), isBomb: true)
        return [safeOption, bombOption].shuffled()
    }
    
    // 計算 1～50 的數字出現機率（百分比）
    static func numberProbabilities() -> [(number: Int, probability: Double)] {
        let alpha = 0.24
        let numbers = Array(1...50)
        let weights = numbers.map { exp(-alpha * Double($0 - 1)) }
        let totalWeight = weights.reduce(0, +)
        let probabilities = weights.map { $0 / totalWeight * 100 }
        return Array(zip(numbers, probabilities))
    }
}

class GameLogic: ObservableObject {
    @Published var currentValue: Int = 0
    @Published var options: [Option] = Option.generatePair()
    @Published var isGameOver = false
    @Published var luckScore: Int = 0          // 安全選項次數（得分）
    @Published var levelsPassed: Int = 0       // 闖關數
    
    func selectOption(_ option: Option) {
        if option.isBomb {
            isGameOver = true
        } else {
            currentValue = option.operation.apply(currentValue, option.number)
            luckScore += 1
            levelsPassed += 1
            options = Option.generatePair()
        }
    }
    
    func resetGame() {
        currentValue = 0
        luckScore = 0
        levelsPassed = 0
        isGameOver = false
        options = Option.generatePair()
    }
}

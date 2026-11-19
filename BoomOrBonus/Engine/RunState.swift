//
//  RunState.swift
//  BoomOrBonus
//
//  Value types for one run. Foundation only.
//

import Foundation

enum BlessingID: String, Codable, CaseIterable, Hashable, CodingKeyRepresentable {
    // Declaration order affects shop shuffles; do not reorder.
    case add, snow, cool, gamb, hot, grit, hand, eye, bank, defuse
}

enum BossID: String, Codable, CaseIterable, Hashable {
    case fog, crush, short, shaky
}

enum ModID: String, Codable, CaseIterable, Hashable {
    // Declaration order affects which rule a stage gets; do not reorder.
    case heat, calm, wild, lean, rich, small, fuse, gold
}

enum ItemID: String, Codable, CaseIterable, Hashable {
    case peek, roll, dbl, shield
}

enum Phase: String, Codable {
    case play, shop, win, over
}

enum Mode: String, Codable {
    case daily, free
}

enum CardOp: String, Codable {
    case add, mul
}

struct Card: Codable, Equatable {
    var danger: Int          // 1...4
    var p: Double            // boom probability
    var op: CardOp
    var n: Double            // add cards are integers
    var boom: Bool
    var fog: Bool = false
}

struct Inventory: Codable, Equatable {
    var peek: Int
    var roll: Int
    var dbl: Int
}

enum RewardKind: String, Codable {
    case base, picksLeft, stretch, interest
}

struct RewardPart: Codable, Equatable {
    var kind: RewardKind
    var amount: Int
}

struct RunState: Codable, Equatable {
    var version: Int = 6
    var seed: UInt32
    var lv: Int
    var targetMul: Double
    var mode: Mode
    var day: Int = 0
    var attempt: Int = 0
    var stage: Int = 1
    var value: Int = 0
    var picks: Int = 0
    var stagePicksAtStart: Int = 0       // sp
    var idx: Int = 0
    var rerolls: Int = 0                 // rr
    var shopRerolls: Int = 0             // srr
    var streak: Int = 0
    var coins: Int = 0
    var shield: Int = 0
    var inventory: Inventory
    var blessings: [BlessingID: Int] = [:]
    var doubleArmed: Bool = false
    var peekArmed: Bool = false
    var defusedThisStage: Bool = false
    var adUsed: Bool = false
    var marks: [Int] = []
    var total: Int = 0
    var pair: [Card] = []
    var shopOffer: [BlessingID?] = []
    var lastRewardParts: [RewardPart] = []
    var phase: Phase = .play
    var endless: Bool = false
    var coinsEarned: Int = 0
    var brokenRecords: [String] = []     // RecordID raw values broken in this run (once each)
    /// RecordID raw values that already had a record when this run began (taken at the first check).
    /// Only these can pop a new-record pill, so a first run never does. nil = no check has happened yet.
    var recordBase: [String]? = nil
    var newlyUnlockedLevel: Int? = nil
    var statsCounted: Bool = false
    var dailyCounted: Bool = false
    var abandoned: Bool = false

    /// Stack count of a blessing (0 if not owned).
    func level(_ b: BlessingID) -> Int { blessings[b] ?? 0 }
    func has(_ b: BlessingID) -> Bool { level(b) > 0 }
}

enum PickEvent: Equatable {
    case safe(delta: Int)
    case boom(lost: Int, s0: Int, s1: Int)
    case shield
    case defuse
}

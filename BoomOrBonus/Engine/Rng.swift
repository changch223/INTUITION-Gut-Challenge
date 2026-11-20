//
//  Rng.swift
//  BoomOrBonus
//
//  Seeded RNG. Must stay bit-exact with docs/redesign/reference/core.js
//  (mulberry32 + FNV-style seedOf). Never use system randomness in the engine.
//

import Foundation

struct Mulberry32 {
    private var a: UInt32

    init(_ seed: UInt32) { a = seed }

    /// Returns a value in [0, 1).
    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }
}

func seedOf(_ xs: Int...) -> UInt32 {
    var h: UInt32 = 2166136261
    for x in xs {
        h ^= UInt32(truncatingIfNeeded: x)
        h = h &* 16777619
        h ^= h >> 13
    }
    return h
}

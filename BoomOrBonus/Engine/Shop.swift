//
//  Shop.swift
//  BoomOrBonus
//
//  Shop offer (seeded Fisher-Yates) and purchases. Port of core.js.
//

import Foundation

enum Shop {

    static func shopOffer(_ run: RunState) -> [BlessingID] {
        var r = Mulberry32(seedOf(Int(run.seed), 77, run.stage, run.shopRerolls))
        let full = run.blessings.count >= Rules.MAX_BLESSINGS
        var pool = BlessingID.allCases.filter { run.has($0) ? $0.stackable : !full }
        var i = pool.count - 1
        while i > 0 {
            let j = Int(floor(r.next() * Double(i + 1)))
            pool.swapAt(i, j)
            i -= 1
        }
        return Array(pool.prefix(3))
    }

    @discardableResult
    static func buyBlessing(_ run: inout RunState, _ id: BlessingID) -> Bool {
        let cost = GameEngine.price(run, id.basePrice)
        if run.coins < cost { return false }
        if !run.has(id) && run.blessings.count >= Rules.MAX_BLESSINGS { return false }
        if run.has(id) && !id.stackable { return false }
        run.coins -= cost
        run.blessings[id] = run.level(id) + 1
        if let slot = run.shopOffer.firstIndex(where: { $0 == id }) { run.shopOffer[slot] = nil }
        return true
    }

    @discardableResult
    static func buyItem(_ run: inout RunState, _ id: ItemID) -> Bool {
        let cost = GameEngine.price(run, id.basePrice)
        if run.coins < cost { return false }
        run.coins -= cost
        switch id {
        case .shield: run.shield += 1
        case .peek: run.inventory.peek += 1
        case .roll: run.inventory.roll += 1
        case .dbl: run.inventory.dbl += 1
        }
        return true
    }
}

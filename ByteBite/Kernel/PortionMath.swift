import Foundation

/// PortionMath scales per-100 g macros. Rounding happens only at display time.
enum PortionMath: Sendable {
    static let kjPerKcal = 4.184

    /// Energy per 100 g: kcal field wins, else kJ / 4.184.
    static func kcal100(energyKcal: Double?, energyKJ: Double?) -> Double? {
        if let energyKcal { return energyKcal }
        if let energyKJ { return energyKJ / kjPerKcal }
        return nil
    }

    static func portion(per100: MacroPacket, grams: Double) -> MacroPacket {
        per100.scaled(grams: grams)
    }
}

/// IntakeMath aggregates day totals. Totals are computed, never stored.
enum IntakeMath: Sendable {
    static func packets(entries: [IntakeEntry], day: Int, eaten: Bool?) -> [MacroPacket] {
        entries.compactMap { entry in
            guard entry.cycle == day else { return nil }
            if let eaten, entry.eaten != eaten { return nil }
            return entry.packet
        }
    }

    static func totals(entries: [IntakeEntry], day: Int, eaten: Bool?) -> MacroPacket {
        MacroPacket.accumulate(packets(entries: entries, day: day, eaten: eaten))
    }

    static func grouped(entries: [IntakeEntry], day: Int, eaten: Bool) -> [CycleSlot: [IntakeEntry]] {
        var map: [CycleSlot: [IntakeEntry]] = [:]
        for slot in CycleSlot.allCases {
            map[slot] = []
        }
        for entry in entries where entry.cycle == day && entry.eaten == eaten {
            map[entry.slot, default: []].append(entry)
        }
        return map
    }
}

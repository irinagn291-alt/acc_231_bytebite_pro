import Foundation

/// DemoSeed writes one simulator-only day, gated by byb.demo.v1.
enum DemoSeed {
    static let flagKey = "byb.demo.v1"

    #if targetEnvironment(simulator)
    static func shouldPlant(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: flagKey)
    }

    static func markPlanted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: flagKey)
    }
    #else
    static func shouldPlant(defaults: UserDefaults = .standard) -> Bool {
        false
    }

    static func markPlanted(defaults: UserDefaults = .standard) {}
    #endif

    static func entries(day: CycleKey) -> [IntakeEntry] {
        let shelf = LocalShelf.records
        guard shelf.count >= 4 else { return [] }
        return [
            IntakeEntry(id: UUID(), product: shelf[0], grams: 150, slot: .boot, cycle: day.rawValue, eaten: true),
            IntakeEntry(id: UUID(), product: shelf[1], grams: 80, slot: .runtime, cycle: day.rawValue, eaten: true),
            IntakeEntry(id: UUID(), product: shelf[4], grams: 250, slot: .interrupt, cycle: day.rawValue, eaten: true),
            IntakeEntry(
                id: UUID(),
                product: shelf[5],
                grams: 30,
                slot: .shutdown,
                cycle: day.shifting(1).rawValue,
                eaten: false
            ),
        ]
    }
}

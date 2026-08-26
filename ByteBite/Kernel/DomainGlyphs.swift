import Foundation

/// CycleKey is the day identity: Int YYYYMMDD, rendered as a hex string.
struct CycleKey: Hashable, Sendable, Codable, RawRepresentable, Comparable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    var hexGlyph: String {
        String(format: "0x%08X", rawValue)
    }

    static func from(_ date: Date, calendar: Calendar = .current) -> CycleKey {
        let start = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        let year = parts.year ?? 1970
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        return CycleKey(rawValue: year * 10_000 + month * 100 + day)
    }

    static func today(calendar: Calendar = .current, now: Date = Date()) -> CycleKey {
        from(now, calendar: calendar)
    }

    func date(calendar: Calendar = .current) -> Date? {
        var parts = DateComponents()
        parts.year = rawValue / 10_000
        parts.month = (rawValue / 100) % 100
        parts.day = rawValue % 100
        return calendar.date(from: parts)
    }

    func shifting(_ days: Int, calendar: Calendar = .current) -> CycleKey {
        guard let base = date(calendar: calendar),
              let next = calendar.date(byAdding: .day, value: days, to: base)
        else { return self }
        return CycleKey.from(next, calendar: calendar)
    }

    static func < (lhs: CycleKey, rhs: CycleKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// CycleSlot is a meal window named in the computing lexicon.
enum CycleSlot: String, Sendable, Codable, CaseIterable, Identifiable {
    case boot
    case runtime
    case shutdown
    case interrupt

    var id: String { rawValue }

    var canPlanAhead: Bool { self != .interrupt }

    var assetName: String {
        switch self {
        case .boot: "byb_SlotBoot"
        case .runtime: "byb_SlotRuntime"
        case .shutdown: "byb_SlotShutdown"
        case .interrupt: "byb_SlotInterrupt"
        }
    }

    /// Snack fallback: interrupt remaps to runtime (midday) when planned ahead.
    static func resolved(_ slot: CycleSlot, eaten: Bool) -> CycleSlot {
        if !eaten && slot == .interrupt { return .runtime }
        return slot
    }
}

/// MacroPacket is an optional nutriment tuple. Missing stays missing.
struct MacroPacket: Sendable, Equatable, Codable {
    var kcal: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?

    static let unknown = MacroPacket(kcal: nil, protein: nil, carbs: nil, fat: nil)

    func scaled(grams: Double) -> MacroPacket {
        MacroPacket(
            kcal: kcal.map { $0 * grams / 100 },
            protein: protein.map { $0 * grams / 100 },
            carbs: carbs.map { $0 * grams / 100 },
            fat: fat.map { $0 * grams / 100 }
        )
    }

    static func accumulate(_ packets: [MacroPacket]) -> MacroPacket {
        var kcal: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        for packet in packets {
            if let value = packet.kcal { kcal = (kcal ?? 0) + value }
            if let value = packet.protein { protein = (protein ?? 0) + value }
            if let value = packet.carbs { carbs = (carbs ?? 0) + value }
            if let value = packet.fat { fat = (fat ?? 0) + value }
        }
        return MacroPacket(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }
}

/// GlyphRecord is a cached catalog product.
struct GlyphRecord: Sendable, Equatable, Codable, Identifiable {
    var barcode: String
    var name: String
    var brand: String?
    var per100: MacroPacket
    var imagePath: String?
    var shelfAsset: String?
    var refreshedAt: Date

    var id: String { barcode }
}

/// IntakeEntry is one logged or planned portion.
struct IntakeEntry: Sendable, Equatable, Codable, Identifiable {
    var id: UUID
    var product: GlyphRecord
    var grams: Double
    var slot: CycleSlot
    var cycle: Int
    var eaten: Bool

    var packet: MacroPacket {
        product.per100.scaled(grams: grams)
    }
}

/// TargetRegister holds daily energy and macro goals. Never shipped as zeros.
struct TargetRegister: Sendable, Equatable, Codable {
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    static let factory = TargetRegister(kcal: 2_000, protein: 140, carbs: 220, fat: 65)
}

/// WishRecord is a barcode-unique shopping intent.
struct WishRecord: Sendable, Equatable, Codable, Identifiable {
    var barcode: String
    var product: GlyphRecord
    var addedOn: Int

    var id: String { barcode }
}

/// ScoreLedger is the persisted gamification projection.
struct ScoreLedger: Sendable, Equatable, Codable {
    var totalXP: Int
    var streak: Int
    var longest: Int
    var freezeTokens: Int
    var lastActiveDay: Int?
    var badges: [String]
    var lastComboMultiplier: Double

    static let empty = ScoreLedger(
        totalXP: 0,
        streak: 0,
        longest: 0,
        freezeTokens: 0,
        lastActiveDay: nil,
        badges: [],
        lastComboMultiplier: 1
    )
}

/// KitchenProjection is the in-memory source of truth rebuilt from the event tape.
struct KitchenProjection: Sendable, Equatable, Codable {
    var schemaVersion: Int
    var didCompleteBoot: Bool
    var targets: TargetRegister
    var entries: [IntakeEntry]
    var wishes: [WishRecord]
    var catalog: [String: GlyphRecord]
    var score: ScoreLedger
    var eventCount: Int
    var lastHighlightID: UUID?
    var storeWipedNotice: Bool

    static let empty = KitchenProjection(
        schemaVersion: 1,
        didCompleteBoot: false,
        targets: .factory,
        entries: [],
        wishes: [],
        catalog: [:],
        score: .empty,
        eventCount: 0,
        lastHighlightID: nil,
        storeWipedNotice: false
    )
}

/// OverlayKind is the full-screen overlay router. Search, scan and commit are not cards.
enum OverlayKind: Equatable, Sendable {
    case none
    case query
    case scan
    case commit(GlyphRecord)
    case boot
}

/// DeckCard is one swipeable stack face.
enum DeckCard: String, CaseIterable, Identifiable, Sendable {
    case intake
    case log
    case plan
    case wish
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .intake: "today"
        case .log: "log"
        case .plan: "plan"
        case .wish: "wish"
        case .profile: "profile"
        }
    }
}

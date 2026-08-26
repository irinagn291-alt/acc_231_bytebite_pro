import Foundation
import ByteKit

/// DeckModel is the immutable render state of the card stack.
struct DeckModel: Equatable, Sendable {
    var order: [DeckCard]
    var dragX: Double
    var dismissing: Bool

    static let initial = DeckModel(order: DeckCard.allCases, dragX: 0, dismissing: false)

    var top: DeckCard { order.first ?? .intake }
}

/// BootSequenceModel is the immutable render state of onboarding.
struct BootSequenceModel: Equatable, Sendable {
    var page: Int
    var targets: TargetRegister
    var finishing: Bool

    static let initial = BootSequenceModel(page: 0, targets: .factory, finishing: false)
}

enum QueryPhase: Equatable, Sendable {
    case idle
    case pending
    case loading
    case results
    case empty
    case fault
}

/// CatalogQueryModel is the immutable render state of search.
struct CatalogQueryModel: Equatable, Sendable {
    var query: String
    var phase: QueryPhase
    var rows: [GlyphRecord]
    var faultCopy: String?

    static let initial = CatalogQueryModel(query: "", phase: .idle, rows: [], faultCopy: nil)
}

enum ScanPermission: Equatable, Sendable {
    case unknown
    case asking
    case allowed
    case denied
    case restricted
    case noDevice
}

/// ScanFrameModel is the immutable render state of live capture.
struct ScanFrameModel: Equatable, Sendable {
    var permission: ScanPermission
    var hasDevice: Bool
    var typed: String
    var flashUntil: Date?
    var lastPayload: String?
    var lastDecodeAt: Date?
    var samples: [GlyphRecord]
    var resolving: Bool
    var faultCopy: String?
    var shouldRunSession: Bool

    static let initial = ScanFrameModel(
        permission: .unknown,
        hasDevice: false,
        typed: "",
        flashUntil: nil,
        lastPayload: nil,
        lastDecodeAt: nil,
        samples: LocalShelf.records,
        resolving: false,
        faultCopy: nil,
        shouldRunSession: false
    )
}

enum CommitFault: Equatable, Sendable {
    case gramsOutOfRange
    case inFlight
}

/// CommitCardModel is the immutable render state of the fused commit card.
struct CommitCardModel: Equatable, Sendable {
    var product: GlyphRecord?
    var gramsGlyph: String
    var grams: Double?
    var slot: CycleSlot
    var when: CommitWhen
    var alreadyWished: Bool
    var award: ScoreAward
    var inFlight: Bool
    var fault: CommitFault?

    static let initial = CommitCardModel(
        product: nil,
        gramsGlyph: "100",
        grams: 100,
        slot: .runtime,
        when: .eatenToday,
        alreadyWished: false,
        award: .zero,
        inFlight: false,
        fault: nil
    )

    var gramsValid: Bool {
        guard let grams else { return false }
        return grams > 0 && grams <= 5_000
    }

    var eaten: Bool {
        if case .eatenToday = when { return true }
        return false
    }

    var cycle: Int {
        switch when {
        case .eatenToday: return CycleKey.today().rawValue
        case .planned(let day): return day
        }
    }
}

/// SlotLane is one slot column on today / log.
struct SlotLane: Equatable, Sendable, Identifiable {
    var slot: CycleSlot
    var entries: [IntakeEntry]
    var subtotal: MacroPacket

    var id: String { slot.rawValue }
}

/// IntakeBufferModel is the immutable render state of today.
struct IntakeBufferModel: Equatable, Sendable {
    var cycle: CycleKey
    var hexDay: String
    var totals: MacroPacket
    var targets: TargetRegister
    var lanes: [SlotLane]
    var score: ScoreLedger
    var level: Int
    var xpProgress: Double
    var empty: Bool
    var exceeded: Bool

    static func project(_ projection: KitchenProjection, now: Date = Date()) -> IntakeBufferModel {
        let cycle = CycleKey.today(now: now)
        let totals = IntakeMath.totals(entries: projection.entries, day: cycle.rawValue, eaten: true)
        let grouped = IntakeMath.grouped(entries: projection.entries, day: cycle.rawValue, eaten: true)
        let lanes = CycleSlot.allCases.map { slot in
            let rows = grouped[slot] ?? []
            return SlotLane(slot: slot, entries: rows, subtotal: MacroPacket.accumulate(rows.map(\.packet)))
        }
        let band = LevelCurve.band(for: projection.score.totalXP)
        let energy = totals.kcal ?? 0
        return IntakeBufferModel(
            cycle: cycle,
            hexDay: cycle.hexGlyph,
            totals: totals,
            targets: projection.targets,
            lanes: lanes,
            score: projection.score,
            level: band.level,
            xpProgress: LevelCurve.progress(for: projection.score.totalXP),
            empty: lanes.allSatisfy(\.entries.isEmpty),
            exceeded: energy > projection.targets.kcal
        )
    }
}

/// EntryStackModel is the immutable render state of the log.
struct EntryStackModel: Equatable, Sendable {
    var cycle: CycleKey
    var hexDay: String
    var lanes: [SlotLane]
    var totals: MacroPacket
    var empty: Bool
    var pendingPurge: UUID?
    var highlight: UUID?

    static func project(_ projection: KitchenProjection, cycle: CycleKey) -> EntryStackModel {
        let grouped = IntakeMath.grouped(entries: projection.entries, day: cycle.rawValue, eaten: true)
        let lanes = CycleSlot.allCases.map { slot in
            let rows = grouped[slot] ?? []
            return SlotLane(slot: slot, entries: rows, subtotal: MacroPacket.accumulate(rows.map(\.packet)))
        }
        return EntryStackModel(
            cycle: cycle,
            hexDay: cycle.hexGlyph,
            lanes: lanes,
            totals: IntakeMath.totals(entries: projection.entries, day: cycle.rawValue, eaten: true),
            empty: lanes.allSatisfy(\.entries.isEmpty),
            pendingPurge: nil,
            highlight: projection.lastHighlightID
        )
    }
}

struct HorizonRow: Equatable, Sendable, Identifiable {
    var entry: IntakeEntry
    var hexDay: String
    var id: UUID { entry.id }
}

/// HorizonModel is the immutable render state of the 14-day plan.
struct HorizonModel: Equatable, Sendable {
    var rows: [HorizonRow]
    var empty: Bool
    var pendingPurge: UUID?
    var horizonDays: Int

    static let horizonDays = 14

    static func project(_ projection: KitchenProjection, now: Date = Date()) -> HorizonModel {
        let today = CycleKey.today(now: now)
        let last = today.shifting(horizonDays)
        let planned = projection.entries.filter { entry in
            !entry.eaten && entry.cycle >= today.rawValue && entry.cycle <= last.rawValue
        }
        .sorted { $0.cycle < $1.cycle }
        let rows = planned.map { HorizonRow(entry: $0, hexDay: CycleKey(rawValue: $0.cycle).hexGlyph) }
        return HorizonModel(rows: rows, empty: rows.isEmpty, pendingPurge: nil, horizonDays: horizonDays)
    }
}

/// WishRegisterModel is the immutable render state of the wish list.
struct WishRegisterModel: Equatable, Sendable {
    var rows: [WishRecord]
    var empty: Bool
    var pendingPurge: String?

    static func project(_ projection: KitchenProjection) -> WishRegisterModel {
        WishRegisterModel(rows: projection.wishes, empty: projection.wishes.isEmpty, pendingPurge: nil)
    }
}

struct BadgeCell: Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var unlocked: Bool
}

/// ScoreLedgerModel is the immutable render state of profile + goals.
struct ScoreLedgerModel: Equatable, Sendable {
    var score: ScoreLedger
    var level: Int
    var xpInto: Int
    var xpNeeded: Int
    var progress: Double
    var badges: [BadgeCell]
    var draft: TargetRegister
    var pendingReset: Bool
    var saving: Bool
    var hexDay: String

    static func project(_ projection: KitchenProjection) -> ScoreLedgerModel {
        let band = LevelCurve.band(for: projection.score.totalXP)
        let unlocked = Set(projection.score.badges)
        let badges = BadgeID.allCases.map { id in
            BadgeCell(id: id.rawValue, title: BadgeRoster.title(for: id.rawValue), unlocked: unlocked.contains(id.rawValue))
        }
        return ScoreLedgerModel(
            score: projection.score,
            level: band.level,
            xpInto: band.into,
            xpNeeded: band.needed,
            progress: LevelCurve.progress(for: projection.score.totalXP),
            badges: badges,
            draft: projection.targets,
            pendingReset: false,
            saving: false,
            hexDay: CycleKey.today().hexGlyph
        )
    }
}

/// OverlayModel is the immutable render state of overlays.
struct OverlayModel: Equatable, Sendable {
    var kind: OverlayKind
    var successUntil: Date?

    static let initial = OverlayModel(kind: .none, successUntil: nil)
}

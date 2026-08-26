import Foundation

/// TapeLine is one append-only JSONL record. schemaVersion is required from v1.
struct TapeLine: Sendable, Codable, Equatable {
    var schemaVersion: Int
    var occurredAt: Date
    var body: TapeBody
}

/// TapeBody is the closed set of kitchen mutations.
enum TapeBody: Sendable, Codable, Equatable {
    case targetsCommitted(TargetRegister)
    case entryAppended(IntakeEntry)
    case entryPurged(UUID)
    case wishBound(WishRecord)
    case wishPurged(String)
    case bootCompleted
    case bootReopened
    case productCached(GlyphRecord)
    case scoreMutated(ScoreLedger)
    case highlight(UUID)
    case storeWiped
}

/// TapeSnapshot is a projection checkpoint written every 200 events.
struct TapeSnapshot: Sendable, Codable {
    var schemaVersion: Int
    var eventCount: Int
    var projection: KitchenProjection
}

/// KitchenFold is the pure replay function. Processors never fold events themselves.
enum KitchenFold {
    static func apply(_ body: TapeBody, onto state: KitchenProjection) -> KitchenProjection {
        var next = state
        next.storeWipedNotice = false
        switch body {
        case .targetsCommitted(let targets):
            next.targets = sanitized(targets)
        case .entryAppended(let entry):
            next.entries.removeAll { $0.id == entry.id }
            next.entries.append(entry)
            next.catalog[entry.product.barcode] = entry.product
            next.lastHighlightID = entry.id
        case .entryPurged(let id):
            next.entries.removeAll { $0.id == id }
            if next.lastHighlightID == id { next.lastHighlightID = nil }
        case .wishBound(let wish):
            if let index = next.wishes.firstIndex(where: { $0.barcode == wish.barcode }) {
                next.wishes[index] = wish
            } else {
                next.wishes.append(wish)
            }
            next.catalog[wish.product.barcode] = wish.product
        case .wishPurged(let barcode):
            next.wishes.removeAll { $0.barcode == barcode }
        case .bootCompleted:
            next.didCompleteBoot = true
        case .bootReopened:
            next.didCompleteBoot = false
        case .productCached(let record):
            next.catalog[record.barcode] = record
        case .scoreMutated(let score):
            next.score = score
        case .highlight(let id):
            next.lastHighlightID = id
        case .storeWiped:
            next = .empty
            next.storeWipedNotice = true
        }
        return next
    }

    static func sanitized(_ targets: TargetRegister) -> TargetRegister {
        TargetRegister(
            kcal: max(targets.kcal, 1),
            protein: max(targets.protein, 0),
            carbs: max(targets.carbs, 0),
            fat: max(targets.fat, 0)
        )
    }
}

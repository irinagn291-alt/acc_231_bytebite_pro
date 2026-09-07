import Foundation

/// DeckIntent is user input for the swipeable card stack.
enum DeckIntent: Sendable, Equatable {
    case swipeAway
    case jump(DeckCard)
    case dragChanged(Double)
    case dragEnded(Double)
}

/// BootSequenceIntent is user input for first-run setup.
enum BootSequenceIntent: Sendable, Equatable {
    case next
    case back
    case skip
    case setKcal(Double)
    case setProtein(Double)
    case setCarbs(Double)
    case setFat(Double)
    case finish
}

/// IntakeBufferIntent is user input for the today card.
enum IntakeBufferIntent: Sendable, Equatable {
    case appear
    case clockTicked
    case openQuery
    case openScan
    case openCommit(GlyphRecord)
}

/// CatalogQueryIntent is user input for the search overlay.
enum CatalogQueryIntent: Sendable, Equatable {
    case editQuery(String)
    case retry
    case pick(GlyphRecord)
    case openScan
    case dismiss
}

/// ScanFrameIntent is user input and capture callbacks for the scan overlay.
enum ScanFrameIntent: Sendable, Equatable {
    case appear
    case disappear
    case appBackgrounded
    case decoded(String)
    case typed(String)
    case submitManual
    case pickSample(String)
    case openSettings
    case dismiss
    case clearFault
}

/// CommitWhen chooses eaten-today versus a future cycle.
enum CommitWhen: Sendable, Equatable {
    case eatenToday
    case planned(Int)
}

/// CommitCardIntent is user input for the fused detail+assign card.
enum CommitCardIntent: Sendable, Equatable {
    case bind(GlyphRecord)
    case setGrams(String)
    case setSlot(CycleSlot)
    case setWhen(CommitWhen)
    case commit
    case wish
    case dismiss
    case clearFault
}

/// EntryStackIntent is user input for the log card.
enum EntryStackIntent: Sendable, Equatable {
    case appear
    case shiftDay(Int)
    case askPurge(UUID)
    case confirmPurge
    case cancelPurge
}

/// HorizonIntent is user input for the 14-day plan card.
enum HorizonIntent: Sendable, Equatable {
    case appear
    case eat(UUID)
    case askPurge(UUID)
    case confirmPurge
    case cancelPurge
}

/// WishRegisterIntent is user input for the wish card.
enum WishRegisterIntent: Sendable, Equatable {
    case appear
    case promote(GlyphRecord)
    case askPurge(String)
    case confirmPurge
    case cancelPurge
}

/// ScoreLedgerIntent is user input for the profile + goals card.
enum ScoreLedgerIntent: Sendable, Equatable {
    case appear
    case setKcal(Double)
    case setProtein(Double)
    case setCarbs(Double)
    case setFat(Double)
    case saveTargets
    case rerunBoot
    case askReset
    case confirmReset
    case cancelReset
    case openContact
}

/// OverlayIntent routes full-screen overlays.
enum OverlayIntent: Sendable, Equatable {
    case present(OverlayKind)
    case dismiss
    case flashSuccess
}

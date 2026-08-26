/// BadgeRoster lists unlockable badges and evaluates them against a score snapshot.
public enum BadgeID: String, Sendable, CaseIterable {
    case firstCommit = "first_commit"
    case weekFlame = "week_flame"
    case kiloByte = "kilo_byte"
    case comboLock = "combo_lock"
    case fullCycle = "full_cycle"
    case freezeCache = "freeze_cache"
    case dawnBoot = "dawn_boot"
    case interruptNibble = "interrupt_nibble"
    case monthFlame = "month_flame"
}

/// BadgeProbe is the input snapshot used to decide newly unlocked badges.
public struct BadgeProbe: Sendable, Equatable {
    public var totalXP: Int
    public var streak: Int
    public var freezeTokens: Int
    public var comboHit: Bool
    public var eatenCount: Int
    public var slotsToday: Set<String>
    public var already: Set<String>

    public init(
        totalXP: Int,
        streak: Int,
        freezeTokens: Int,
        comboHit: Bool,
        eatenCount: Int,
        slotsToday: Set<String>,
        already: Set<String>
    ) {
        self.totalXP = totalXP
        self.streak = streak
        self.freezeTokens = freezeTokens
        self.comboHit = comboHit
        self.eatenCount = eatenCount
        self.slotsToday = slotsToday
        self.already = already
    }
}

public enum BadgeRoster: Sendable {
    /// Returns badge ids that should unlock given the probe.
    public static func unlocks(from probe: BadgeProbe) -> [String] {
        var fresh: [String] = []
        func consider(_ id: BadgeID, _ ok: Bool) {
            if ok && !probe.already.contains(id.rawValue) {
                fresh.append(id.rawValue)
            }
        }
        consider(.firstCommit, probe.eatenCount >= 1)
        consider(.weekFlame, probe.streak >= 7)
        consider(.monthFlame, probe.streak >= 30)
        consider(.kiloByte, probe.totalXP >= 1_000)
        consider(.comboLock, probe.comboHit)
        consider(.fullCycle, probe.slotsToday.count >= 4)
        consider(.freezeCache, probe.freezeTokens >= 1)
        consider(.dawnBoot, probe.slotsToday.contains("boot"))
        consider(.interruptNibble, probe.slotsToday.contains("interrupt"))
        return fresh
    }

    public static func title(for id: String) -> String {
        switch BadgeID(rawValue: id) {
        case .firstCommit: return "first commit"
        case .weekFlame: return "week flame"
        case .kiloByte: return "kilo byte"
        case .comboLock: return "combo lock"
        case .fullCycle: return "full cycle"
        case .freezeCache: return "freeze cache"
        case .dawnBoot: return "dawn boot"
        case .interruptNibble: return "interrupt nibble"
        case .monthFlame: return "month flame"
        case .none: return id
        }
    }
}

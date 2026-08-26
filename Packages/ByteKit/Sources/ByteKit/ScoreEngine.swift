/// ScoreEngine is the pure scoring kernel for ByteBite gamification.
/// It maps a logged portion onto XP and a combo multiplier. No UI, no storage.
public enum ScoreEngine: Sendable {
    /// Tolerance band around a macro target that counts as a hit.
    public static let hitBand: Double = 0.15

    /// Computes how many of protein / carbs / fat sit inside the hit band.
    public static func macroHits(
        protein: Double?,
        carbs: Double?,
        fat: Double?,
        proteinTarget: Double,
        carbsTarget: Double,
        fatTarget: Double
    ) -> Int {
        var hits = 0
        if isHit(protein, target: proteinTarget) { hits += 1 }
        if isHit(carbs, target: carbsTarget) { hits += 1 }
        if isHit(fat, target: fatTarget) { hits += 1 }
        return hits
    }

    /// Combo multiplier: 1.0 default, 1.5 for two hits, 2.0 for a full lock.
    public static func comboMultiplier(hits: Int) -> Double {
        switch hits {
        case 3: return 2.0
        case 2: return 1.5
        default: return 1.0
        }
    }

    /// Base XP from grams, reduced when energy data is missing.
    public static func baseXP(grams: Double, hasEnergy: Bool) -> Int {
        let clamped = min(max(grams, 0), 2_000)
        let bonus = min(28, Int(clamped / 10))
        return hasEnergy ? (12 + bonus) : 8
    }

    /// Full award for one eaten commit.
    public static func award(grams: Double, hasEnergy: Bool, hits: Int) -> ScoreAward {
        let base = baseXP(grams: grams, hasEnergy: hasEnergy)
        let combo = comboMultiplier(hits: hits)
        let awarded = Int((Double(base) * combo).rounded(.down))
        return ScoreAward(
            baseXP: base,
            comboMultiplier: combo,
            awardedXP: awarded,
            comboHit: hits >= 2
        )
    }

    public static func isHit(_ actual: Double?, target: Double) -> Bool {
        guard let actual, target > 0 else { return false }
        let ratio = actual / target
        return ratio >= (1 - hitBand) && ratio <= (1 + hitBand)
    }
}

/// ScoreAward is an immutable XP packet produced by ScoreEngine.
public struct ScoreAward: Sendable, Equatable {
    public let baseXP: Int
    public let comboMultiplier: Double
    public let awardedXP: Int
    public let comboHit: Bool

    public init(baseXP: Int, comboMultiplier: Double, awardedXP: Int, comboHit: Bool) {
        self.baseXP = baseXP
        self.comboMultiplier = comboMultiplier
        self.awardedXP = awardedXP
        self.comboHit = comboHit
    }

    public static let zero = ScoreAward(baseXP: 0, comboMultiplier: 1, awardedXP: 0, comboHit: false)
}

/// LevelCurve maps cumulative XP onto a level and the fill of the current band.
/// Cost to finish level L is 100 * L. Cumulative to reach L is 50 * L * (L - 1).
public enum LevelCurve: Sendable {
    /// 1-based level for a given XP total.
    public static func level(for xp: Int) -> Int {
        let safe = max(xp, 0)
        let inner = 1.0 + (8.0 * Double(safe) / 100.0)
        let level = Int((1.0 + inner.squareRoot()) / 2.0)
        return max(level, 1)
    }

    /// XP already spent to reach the current level.
    public static func cumulative(toReach level: Int) -> Int {
        let l = max(level, 1)
        return 50 * (l - 1) * l
    }

    /// XP into the current level and XP needed to clear it.
    public static func band(for xp: Int) -> (into: Int, needed: Int, level: Int) {
        let level = level(for: xp)
        let cum = cumulative(toReach: level)
        let needed = 100 * level
        return (max(xp - cum, 0), needed, level)
    }

    /// 0...1 progress across the current level band.
    public static func progress(for xp: Int) -> Double {
        let band = band(for: xp)
        guard band.needed > 0 else { return 1 }
        return min(1, Double(band.into) / Double(band.needed))
    }
}

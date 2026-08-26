import Foundation

/// StreakEngine advances a daily streak with optional freeze tokens.
/// A missed calendar day consumes one token; a wider gap breaks the flame.
public enum StreakEngine: Sendable {
    /// Days between two YYYYMMDD integers using the supplied calendar.
    public static func dayGap(from: Int, to: Int, calendar: Calendar) -> Int? {
        guard let a = date(fromYYYYMMDD: from, calendar: calendar),
              let b = date(fromYYYYMMDD: to, calendar: calendar)
        else { return nil }
        return calendar.dateComponents([.day], from: a, to: b).day
    }

    /// Tokens granted when a streak crosses a multiple of 7.
    public static func tokensEarned(oldStreak: Int, newStreak: Int) -> Int {
        let oldBuckets = max(oldStreak, 0) / 7
        let newBuckets = max(newStreak, 0) / 7
        return max(newBuckets - oldBuckets, 0)
    }

    /// Applies one eaten-day tick.
    public static func advance(
        lastActiveDay: Int?,
        currentDay: Int,
        streak: Int,
        tokens: Int,
        calendar: Calendar
    ) -> StreakOutcome {
        if lastActiveDay == currentDay {
            return StreakOutcome(
                streak: max(streak, 1),
                longestHint: max(streak, 1),
                freezeRemaining: tokens,
                usedFreeze: false,
                broken: false,
                tokensGranted: 0,
                lastActiveDay: currentDay
            )
        }

        guard let last = lastActiveDay else {
            return minted(streak: 1, tokens: tokens, day: currentDay)
        }

        let gap = dayGap(from: last, to: currentDay, calendar: calendar) ?? 99
        if gap <= 0 {
            return StreakOutcome(
                streak: streak,
                longestHint: streak,
                freezeRemaining: tokens,
                usedFreeze: false,
                broken: false,
                tokensGranted: 0,
                lastActiveDay: last
            )
        }
        if gap == 1 {
            let next = streak + 1
            let granted = tokensEarned(oldStreak: streak, newStreak: next)
            return StreakOutcome(
                streak: next,
                longestHint: next,
                freezeRemaining: tokens + granted,
                usedFreeze: false,
                broken: false,
                tokensGranted: granted,
                lastActiveDay: currentDay
            )
        }
        if gap == 2 && tokens > 0 {
            let next = streak + 1
            let granted = tokensEarned(oldStreak: streak, newStreak: next)
            return StreakOutcome(
                streak: next,
                longestHint: next,
                freezeRemaining: tokens - 1 + granted,
                usedFreeze: true,
                broken: false,
                tokensGranted: granted,
                lastActiveDay: currentDay
            )
        }
        return minted(streak: 1, tokens: tokens, day: currentDay, broken: true)
    }

    private static func minted(streak: Int, tokens: Int, day: Int, broken: Bool = false) -> StreakOutcome {
        let granted = tokensEarned(oldStreak: 0, newStreak: streak)
        return StreakOutcome(
            streak: streak,
            longestHint: streak,
            freezeRemaining: tokens + granted,
            usedFreeze: false,
            broken: broken,
            tokensGranted: granted,
            lastActiveDay: day
        )
    }

    private static func date(fromYYYYMMDD value: Int, calendar: Calendar) -> Date? {
        var parts = DateComponents()
        parts.year = value / 10_000
        parts.month = (value / 100) % 100
        parts.day = value % 100
        return calendar.date(from: parts)
    }
}

/// StreakOutcome is the immutable result of one streak tick.
public struct StreakOutcome: Sendable, Equatable {
    public let streak: Int
    public let longestHint: Int
    public let freezeRemaining: Int
    public let usedFreeze: Bool
    public let broken: Bool
    public let tokensGranted: Int
    public let lastActiveDay: Int

    public init(
        streak: Int,
        longestHint: Int,
        freezeRemaining: Int,
        usedFreeze: Bool,
        broken: Bool,
        tokensGranted: Int,
        lastActiveDay: Int
    ) {
        self.streak = streak
        self.longestHint = longestHint
        self.freezeRemaining = freezeRemaining
        self.usedFreeze = usedFreeze
        self.broken = broken
        self.tokensGranted = tokensGranted
        self.lastActiveDay = lastActiveDay
    }
}

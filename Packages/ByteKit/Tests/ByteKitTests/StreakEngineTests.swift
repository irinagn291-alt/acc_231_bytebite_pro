import XCTest
@testable import ByteKit

final class StreakEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testConsecutiveDaysGrowStreak() {
        let first = StreakEngine.advance(
            lastActiveDay: nil,
            currentDay: 20260824,
            streak: 0,
            tokens: 0,
            calendar: calendar
        )
        let next = StreakEngine.advance(
            lastActiveDay: first.lastActiveDay,
            currentDay: 20260825,
            streak: first.streak,
            tokens: first.freezeRemaining,
            calendar: calendar
        )
        XCTAssertEqual(next.streak, 2)
        XCTAssertFalse(next.usedFreeze)
        XCTAssertFalse(next.broken)
    }

    func testFreezeTokenBridgesOneMissedDay() {
        let outcome = StreakEngine.advance(
            lastActiveDay: 20260823,
            currentDay: 20260825,
            streak: 4,
            tokens: 1,
            calendar: calendar
        )
        XCTAssertEqual(outcome.streak, 5)
        XCTAssertTrue(outcome.usedFreeze)
        XCTAssertEqual(outcome.freezeRemaining, 0)
        XCTAssertFalse(outcome.broken)
    }

    func testBrokenStreakWithoutToken() {
        let outcome = StreakEngine.advance(
            lastActiveDay: 20260820,
            currentDay: 20260825,
            streak: 9,
            tokens: 0,
            calendar: calendar
        )
        XCTAssertEqual(outcome.streak, 1)
        XCTAssertTrue(outcome.broken)
    }

    func testTokenGrantOnWeekBoundary() {
        XCTAssertEqual(StreakEngine.tokensEarned(oldStreak: 6, newStreak: 7), 1)
        XCTAssertEqual(StreakEngine.tokensEarned(oldStreak: 7, newStreak: 8), 0)
    }

    func testBadgeUnlocks() {
        let probe = BadgeProbe(
            totalXP: 1_200,
            streak: 8,
            freezeTokens: 1,
            comboHit: true,
            eatenCount: 3,
            slotsToday: ["boot", "runtime", "shutdown", "interrupt"],
            already: []
        )
        let ids = Set(BadgeRoster.unlocks(from: probe))
        XCTAssertTrue(ids.contains(BadgeID.firstCommit.rawValue))
        XCTAssertTrue(ids.contains(BadgeID.kiloByte.rawValue))
        XCTAssertTrue(ids.contains(BadgeID.fullCycle.rawValue))
        XCTAssertTrue(ids.contains(BadgeID.comboLock.rawValue))
    }
}

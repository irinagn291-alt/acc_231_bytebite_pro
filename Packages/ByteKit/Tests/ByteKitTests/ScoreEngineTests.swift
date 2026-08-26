import XCTest
@testable import ByteKit

final class ScoreEngineTests: XCTestCase {
    func testBaseXPGrowsWithGramsAndDropsWithoutEnergy() {
        let rich = ScoreEngine.baseXP(grams: 200, hasEnergy: true)
        let thin = ScoreEngine.baseXP(grams: 200, hasEnergy: false)
        XCTAssertGreaterThan(rich, thin)
        XCTAssertEqual(thin, 8)
        XCTAssertEqual(rich, 12 + 20)
    }

    func testComboMultiplierAndAward() {
        XCTAssertEqual(ScoreEngine.comboMultiplier(hits: 0), 1.0)
        XCTAssertEqual(ScoreEngine.comboMultiplier(hits: 2), 1.5)
        XCTAssertEqual(ScoreEngine.comboMultiplier(hits: 3), 2.0)
        let award = ScoreEngine.award(grams: 100, hasEnergy: true, hits: 3)
        XCTAssertTrue(award.comboHit)
        XCTAssertEqual(award.awardedXP, award.baseXP * 2)
    }

    func testMacroHitBandDoesNotTreatNilAsZero() {
        let hits = ScoreEngine.macroHits(
            protein: nil,
            carbs: 220,
            fat: 65,
            proteinTarget: 140,
            carbsTarget: 220,
            fatTarget: 65
        )
        XCTAssertEqual(hits, 2)
        XCTAssertFalse(ScoreEngine.isHit(nil, target: 140))
        XCTAssertFalse(ScoreEngine.isHit(0, target: 140))
    }

    func testLevelCurveBand() {
        XCTAssertEqual(LevelCurve.level(for: 0), 1)
        XCTAssertEqual(LevelCurve.level(for: 99), 1)
        XCTAssertEqual(LevelCurve.level(for: 100), 2)
        let band = LevelCurve.band(for: 100)
        XCTAssertEqual(band.level, 2)
        XCTAssertEqual(band.into, 0)
        XCTAssertEqual(band.needed, 200)
    }
}

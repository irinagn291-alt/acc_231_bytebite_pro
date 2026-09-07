import XCTest
@testable import ByteBite

final class PortionAndBarcodeTests: XCTestCase {
    func testPortionMathKcalAndKilojouleFallback() {
        let fromKcal = PortionMath.kcal100(energyKcal: 208, energyKJ: 870)
        XCTAssertEqual(fromKcal, 208)
        let fromKJ = PortionMath.kcal100(energyKcal: nil, energyKJ: 418.4)
        XCTAssertEqual(fromKJ ?? 0, 100, accuracy: 0.001)
        XCTAssertNil(PortionMath.kcal100(energyKcal: nil, energyKJ: nil))
        let per100 = MacroPacket(kcal: 200, protein: 10, carbs: 20, fat: 5)
        let portion = PortionMath.portion(per100: per100, grams: 50)
        XCTAssertEqual(portion.kcal ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(portion.protein ?? 0, 5, accuracy: 0.0001)
    }

    func testBarcodeNormalisation() {
        XCTAssertEqual(BarcodeGlyph.normalize("12345678"), "12345678")
        XCTAssertEqual(BarcodeGlyph.normalize("4006381333931"), "4006381333931")
        XCTAssertEqual(BarcodeGlyph.normalize("012345678901"), "0012345678901")
        XCTAssertEqual(
            BarcodeGlyph.normalize("https://world.openfoodfacts.org/product/3017620422003/nutella"),
            "3017620422003"
        )
        XCTAssertEqual(
            BarcodeGlyph.normalize("https://example.com/lookup?gtin=3046920029759"),
            "3046920029759"
        )
        XCTAssertEqual(BarcodeGlyph.normalize("3046920029759"), "3046920029759")
        XCTAssertEqual(LocalShelf.record("3046920029759")?.barcode, "3046920029759")
        XCTAssertNil(BarcodeGlyph.normalize("no-digits-here"))
        XCTAssertFalse(BarcodeGlyph.candidates("042100005264").isEmpty)
    }

    func testMissingMacroStaysUnknown() {
        let packet = MacroPacket(kcal: 100, protein: nil, carbs: 10, fat: nil)
        XCTAssertNil(packet.protein)
        XCTAssertNil(packet.fat)
        let scaled = packet.scaled(grams: 50)
        XCTAssertNil(scaled.protein)
        XCTAssertNil(scaled.fat)
        XCTAssertEqual(scaled.kcal ?? 0, 50, accuracy: 0.0001)
        XCTAssertNotEqual(scaled.protein, 0)
    }

    func testDayTotalsAcrossSlots() {
        let day = 20260825
        let product = LocalShelf.records[0]
        let entries = [
            IntakeEntry(id: UUID(), product: product, grams: 100, slot: .boot, cycle: day, eaten: true),
            IntakeEntry(id: UUID(), product: product, grams: 100, slot: .runtime, cycle: day, eaten: true),
            IntakeEntry(id: UUID(), product: product, grams: 100, slot: .shutdown, cycle: day, eaten: true),
            IntakeEntry(id: UUID(), product: product, grams: 100, slot: .interrupt, cycle: day, eaten: true),
            IntakeEntry(id: UUID(), product: product, grams: 999, slot: .boot, cycle: day, eaten: false),
        ]
        let totals = IntakeMath.totals(entries: entries, day: day, eaten: true)
        XCTAssertEqual(totals.kcal ?? 0, 208 * 4, accuracy: 0.001)
        let grouped = IntakeMath.grouped(entries: entries, day: day, eaten: true)
        XCTAssertEqual(grouped[.boot]?.count, 1)
        XCTAssertEqual(grouped[.interrupt]?.count, 1)
    }

    func testDayBoundaryAcrossDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 3
        parts.day = 8
        parts.hour = 15
        let before = calendar.date(from: parts) ?? Date()
        let keyA = CycleKey.from(before, calendar: calendar)
        XCTAssertEqual(keyA.rawValue, 20260308)
        let start = calendar.startOfDay(for: before)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let keyB = CycleKey.from(next, calendar: calendar)
        XCTAssertEqual(keyB.rawValue, 20260309)
        XCTAssertEqual(keyA.shifting(1, calendar: calendar).rawValue, 20260309)
        XCTAssertNotEqual(keyA.hexGlyph, keyB.hexGlyph)
        XCTAssertTrue(keyA.hexGlyph.hasPrefix("0x"))
    }
}

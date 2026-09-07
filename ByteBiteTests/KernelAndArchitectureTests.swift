import XCTest
@testable import ByteBite
import ByteKit

final class CatalogDecodeTests: XCTestCase {
    func testOpenFoodFactsPayloadWithStringAndMissingNutriments() throws {
        let json = """
        {
          "products": [
            {
              "code": "3017620422003",
              "product_name": "sardine tin",
              "brands": "shelf.tar",
              "nutriments": {
                "energy-kcal_100g": "208",
                "proteins_100g": 24.6,
                "carbohydrates_100g": "0.0"
              }
            },
            {
              "code": "000",
              "product_name": "",
              "nutriments": {}
            }
          ]
        }
        """.data(using: .utf8) ?? Data()
        let rows = try CatalogPayloadMap.decodeSearch(json)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].per100.kcal, 208)
        XCTAssertEqual(rows[0].per100.protein, 24.6)
        XCTAssertEqual(rows[0].per100.carbs, 0)
        XCTAssertNil(rows[0].per100.fat)

        let productJSON = """
        {
          "status": 0,
          "code": "00000000",
          "product": {}
        }
        """.data(using: .utf8) ?? Data()
        XCTAssertThrowsError(try CatalogPayloadMap.decodeProduct(productJSON)) { error in
            XCTAssertEqual(error as? ProbeFault, .notFound)
        }
    }
}

@MainActor
final class KernelBehaviourTests: XCTestCase {
    private func isolatedKernel() -> (KitchenKernel, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaults = UserDefaults(suiteName: "byb.test.\(UUID().uuidString)") ?? UserDefaults.standard
        defaults.set(true, forKey: DemoSeed.flagKey)
        return (KitchenKernel(root: dir, defaults: defaults), dir)
    }

    func testWishListBarcodeUniqueness() async {
        let (kernel, _) = isolatedKernel()
        await kernel.boot()
        let product = LocalShelf.records[0]
        let first = await kernel.bindWish(product)
        let second = await kernel.bindWish(product)
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(kernel.projection.wishes.count, 1)
    }

    func testPersistenceRoundTrip() async {
        let (kernel, dir) = isolatedKernel()
        await kernel.boot()
        await kernel.completeBoot(targets: .factory)
        let product = LocalShelf.records[1]
        _ = await kernel.commitIntake(
            product: product,
            grams: 80,
            slot: .runtime,
            cycle: CycleKey.today().rawValue,
            eaten: true
        )
        await kernel.flushBuffer()
        let defaults = UserDefaults(suiteName: "byb.test.reload.\(UUID().uuidString)") ?? UserDefaults.standard
        defaults.set(true, forKey: DemoSeed.flagKey)
        let reloaded = KitchenKernel(root: dir, defaults: defaults)
        await reloaded.boot()
        XCTAssertTrue(reloaded.projection.didCompleteBoot)
        XCTAssertEqual(reloaded.projection.entries.count, 1)
        XCTAssertEqual(reloaded.projection.entries.first?.product.barcode, product.barcode)
        XCTAssertGreaterThan(reloaded.projection.score.totalXP, 0)
    }

    func testInterruptRemapsWhenPlanned() async {
        let (kernel, _) = isolatedKernel()
        await kernel.boot()
        let future = CycleKey.today().shifting(2).rawValue
        _ = await kernel.commitIntake(
            product: LocalShelf.records[2],
            grams: 40,
            slot: .interrupt,
            cycle: future,
            eaten: false
        )
        XCTAssertEqual(kernel.projection.entries.first?.slot, .runtime)
        XCTAssertFalse(kernel.projection.entries.first?.eaten ?? true)
    }

    func testTwistScoringCombo() {
        let hits = ScoreEngine.macroHits(
            protein: 140,
            carbs: 220,
            fat: 65,
            proteinTarget: 140,
            carbsTarget: 220,
            fatTarget: 65
        )
        XCTAssertEqual(hits, 3)
        let award = ScoreEngine.award(grams: 100, hasEnergy: true, hits: hits)
        XCTAssertTrue(award.comboHit)
        XCTAssertEqual(award.comboMultiplier, 2)
    }
}

final class ArchitectureTests: XCTestCase {
    func testCommitReducerRejectsIllegalGrams() {
        var model = CommitCardModel.initial
        model.product = LocalShelf.records[0]
        let invalid = CommitCardProcessor.reduce(.setGrams("0"), model)
        XCTAssertEqual(invalid.fault, .gramsOutOfRange)
        XCTAssertFalse(invalid.gramsValid)
        let blocked = CommitCardProcessor.reduce(.commit, invalid)
        XCTAssertEqual(blocked.fault, .gramsOutOfRange)
        let planned = CommitCardProcessor.reduce(.setWhen(.planned(20260830)), model)
        let remapped = CommitCardProcessor.reduce(.setSlot(.interrupt), planned)
        XCTAssertEqual(remapped.slot, .runtime)
    }

    func testDeckReducerCyclesCards() {
        let start = DeckModel.initial
        let next = DeckProcessor.reduce(.swipeAway, start)
        XCTAssertEqual(next.top, .log)
        XCTAssertEqual(next.order.last, .intake)
        let jumped = DeckProcessor.reduce(.jump(.profile), next)
        XCTAssertEqual(jumped.top, .profile)
    }
}

@MainActor
final class CatalogQueryOverlayTests: XCTestCase {
    func testScanInsteadPresentsScanOverlay() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaults = UserDefaults(suiteName: "byb.test.scan.\(UUID().uuidString)") ?? .standard
        let kernel = KitchenKernel(root: dir, defaults: defaults)
        let overlay = OverlayProcessor()
        let query = CatalogQueryProcessor(kernel: kernel, overlay: overlay)
        query.dispatch(.openScan)
        XCTAssertEqual(overlay.model.kind, .scan)
    }
}

import Combine
import Foundation
import ByteKit

/// KitchenKernel is the single seam between processors and persistence, catalog and scoring.
@MainActor
final class KitchenKernel: ObservableObject {
    @Published private(set) var projection: KitchenProjection = .empty
    @Published private(set) var launchNotice: String?

    private let tape: EventTape
    private let probe: CatalogProbe
    private let defaults: UserDefaults

    init(root: URL? = nil, defaults: UserDefaults = .standard) {
        let directory = root ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ByteBite", isDirectory: true)
        self.tape = EventTape(root: directory)
        self.probe = CatalogProbe()
        self.defaults = defaults
    }

    func boot() async {
        let result = await tape.replay()
        projection = result.0
        launchNotice = result.1
        #if targetEnvironment(simulator)
        await plantDemoIfNeeded()
        #endif
    }

    func flushBuffer() async {
        await tape.flushBuffer()
    }

    func commitTargets(_ targets: TargetRegister) async {
        projection = await tape.append(.targetsCommitted(KitchenFold.sanitized(targets)))
    }

    func completeBoot(targets: TargetRegister) async {
        projection = await tape.append(.targetsCommitted(KitchenFold.sanitized(targets)))
        projection = await tape.append(.bootCompleted)
    }

    func reopenBoot() async {
        projection = await tape.append(.bootReopened)
    }

    func resetAllData() async {
        projection = await tape.resetAllData()
        await tape.flushBuffer()
    }

    func bindWish(_ product: GlyphRecord) async -> Bool {
        let existed = projection.wishes.contains { $0.barcode == product.barcode }
        let wish = WishRecord(barcode: product.barcode, product: product, addedOn: CycleKey.today().rawValue)
        projection = await tape.append(.wishBound(wish))
        return !existed
    }

    func purgeWish(_ barcode: String) async {
        projection = await tape.append(.wishPurged(barcode))
        await tape.flushBuffer()
    }

    func purgeEntry(_ id: UUID) async {
        projection = await tape.append(.entryPurged(id))
        await tape.flushBuffer()
    }

    func alreadyWished(_ barcode: String) -> Bool {
        projection.wishes.contains { $0.barcode == barcode }
    }

    func eatPlanned(_ id: UUID) async -> ScoreAward {
        guard let entry = projection.entries.first(where: { $0.id == id }) else { return .zero }
        var eaten = entry
        eaten.eaten = true
        eaten.cycle = CycleKey.today().rawValue
        eaten.slot = CycleSlot.resolved(entry.slot, eaten: true)
        projection = await tape.append(.entryPurged(id))
        return await commitIntake(
            product: eaten.product,
            grams: eaten.grams,
            slot: eaten.slot,
            cycle: eaten.cycle,
            eaten: true,
            reuseID: eaten.id
        )
    }

    @discardableResult
    func commitIntake(
        product: GlyphRecord,
        grams: Double,
        slot: CycleSlot,
        cycle: Int,
        eaten: Bool,
        reuseID: UUID? = nil
    ) async -> ScoreAward {
        let resolved = CycleSlot.resolved(slot, eaten: eaten)
        let entry = IntakeEntry(
            id: reuseID ?? UUID(),
            product: product,
            grams: grams,
            slot: resolved,
            cycle: cycle,
            eaten: eaten
        )
        projection = await tape.append(.productCached(product))
        projection = await tape.append(.entryAppended(entry))
        guard eaten else { return .zero }

        let totals = IntakeMath.totals(entries: projection.entries, day: cycle, eaten: true)
        let hits = ScoreEngine.macroHits(
            protein: totals.protein,
            carbs: totals.carbs,
            fat: totals.fat,
            proteinTarget: projection.targets.protein,
            carbsTarget: projection.targets.carbs,
            fatTarget: projection.targets.fat
        )
        let award = ScoreEngine.award(
            grams: grams,
            hasEnergy: product.per100.kcal != nil,
            hits: hits
        )
        var score = projection.score
        score.totalXP += award.awardedXP
        score.lastComboMultiplier = award.comboMultiplier
        let outcome = StreakEngine.advance(
            lastActiveDay: score.lastActiveDay,
            currentDay: cycle,
            streak: score.streak,
            tokens: score.freezeTokens,
            calendar: .current
        )
        score.streak = outcome.streak
        score.longest = max(score.longest, outcome.longestHint)
        score.freezeTokens = outcome.freezeRemaining
        score.lastActiveDay = outcome.lastActiveDay

        let eatenToday = projection.entries.filter { $0.eaten && $0.cycle == cycle }
        let probe = BadgeProbe(
            totalXP: score.totalXP,
            streak: score.streak,
            freezeTokens: score.freezeTokens,
            comboHit: award.comboHit,
            eatenCount: projection.entries.filter(\.eaten).count,
            slotsToday: Set(eatenToday.map(\.slot.rawValue)),
            already: Set(score.badges)
        )
        score.badges.append(contentsOf: BadgeRoster.unlocks(from: probe))
        projection = await tape.append(.scoreMutated(score))
        return award
    }

    func queryCatalog(terms: String) async throws -> [GlyphRecord] {
        var remote: [GlyphRecord] = []
        var remoteFailed = false
        do {
            remote = try await probe.search(terms: terms)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            remoteFailed = true
        }
        let local = LocalShelf.match(terms)
        let cached = projection.catalog.values.filter { record in
            let needle = terms.lowercased()
            return record.name.lowercased().contains(needle)
                || (record.brand?.lowercased().contains(needle) ?? false)
                || record.barcode.contains(terms)
        }
        let merged = mergeCatalog(remote + local + Array(cached))
        if merged.isEmpty && remoteFailed {
            throw ProbeFault.transport
        }
        return merged
    }

    func resolveCode(_ raw: String) async throws -> GlyphRecord {
        let codes = BarcodeGlyph.candidates(raw)
        if codes.isEmpty { throw ProbeFault.notFound }
        var sawTransport = false
        for code in codes {
            if let cached = projection.catalog[code] { return cached }
            if let shelf = LocalShelf.record(code) {
                projection = await tape.append(.productCached(shelf))
                return shelf
            }
            do {
                let record = try await probe.product(code: code)
                projection = await tape.append(.productCached(record))
                return record
            } catch is CancellationError {
                throw CancellationError()
            } catch ProbeFault.notFound {
                continue
            } catch ProbeFault.transport {
                sawTransport = true
            } catch {
                sawTransport = true
            }
        }
        if sawTransport { throw ProbeFault.transport }
        throw ProbeFault.notFound
    }

    func previewAward(product: GlyphRecord, grams: Double, cycle: Int) -> ScoreAward {
        let totals = IntakeMath.totals(entries: projection.entries, day: cycle, eaten: true)
        let added = product.per100.scaled(grams: grams)
        let merged = MacroPacket.accumulate([totals, added])
        let hits = ScoreEngine.macroHits(
            protein: merged.protein,
            carbs: merged.carbs,
            fat: merged.fat,
            proteinTarget: projection.targets.protein,
            carbsTarget: projection.targets.carbs,
            fatTarget: projection.targets.fat
        )
        return ScoreEngine.award(grams: grams, hasEnergy: product.per100.kcal != nil, hits: hits)
    }

    private func mergeCatalog(_ rows: [GlyphRecord]) -> [GlyphRecord] {
        var seen: Set<String> = []
        var out: [GlyphRecord] = []
        for row in rows {
            if row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if seen.contains(row.barcode) { continue }
            seen.insert(row.barcode)
            out.append(row)
        }
        return out
    }

    #if targetEnvironment(simulator)
    private func plantDemoIfNeeded() async {
        guard DemoSeed.shouldPlant(defaults: defaults) else { return }
        let day = CycleKey.today()
        if !projection.didCompleteBoot {
            projection = await tape.append(.targetsCommitted(.factory))
            projection = await tape.append(.bootCompleted)
        }
        for entry in DemoSeed.entries(day: day) {
            _ = await commitIntake(
                product: entry.product,
                grams: entry.grams,
                slot: entry.slot,
                cycle: entry.cycle,
                eaten: entry.eaten,
                reuseID: entry.id
            )
        }
        DemoSeed.markPlanted(defaults: defaults)
    }
    #endif
}

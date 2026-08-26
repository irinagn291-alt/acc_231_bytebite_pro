import Combine
import Foundation
import ByteKit

/// CommitCardProcessor maps CommitCardIntent onto CommitCardModel.
/// Reduce is a pure total function; kernel writes happen after a legal confirm.
@MainActor
final class CommitCardProcessor: ObservableObject {
    @Published private(set) var model: CommitCardModel = .initial
    private let kernel: KitchenKernel
    private let overlay: OverlayProcessor

    init(kernel: KitchenKernel, overlay: OverlayProcessor) {
        self.kernel = kernel
        self.overlay = overlay
    }

    func bind(_ product: GlyphRecord) {
        var next = CommitCardModel.initial
        next.product = product
        next.alreadyWished = kernel.alreadyWished(product.barcode)
        next.award = kernel.previewAward(product: product, grams: next.grams ?? 100, cycle: next.cycle)
        model = next
    }

    func dispatch(_ intent: CommitCardIntent) {
        switch intent {
        case .bind(let product):
            bind(product)
        case .commit:
            confirm()
        case .wish:
            Task { await saveWish() }
        case .dismiss:
            overlay.dispatch(.dismiss)
        default:
            model = Self.reduce(intent, model)
            if let product = model.product, model.gramsValid, let grams = model.grams {
                model.award = kernel.previewAward(product: product, grams: grams, cycle: model.cycle)
            }
        }
    }

    /// Pure reducer used by tests. Rejects confirm when grams are illegal.
    nonisolated static func reduce(_ intent: CommitCardIntent, _ model: CommitCardModel) -> CommitCardModel {
        var next = model
        switch intent {
        case .bind(let product):
            next.product = product
            next.fault = nil
        case .setGrams(let raw):
            next.gramsGlyph = raw
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                next.grams = nil
                next.fault = .gramsOutOfRange
            } else if let parsed = GlyphFormat.parseDecimal(raw), parsed > 0, parsed <= 5_000 {
                next.grams = parsed
                next.fault = nil
            } else {
                next.grams = nil
                next.fault = .gramsOutOfRange
            }
        case .setSlot(let slot):
            if !next.eaten && slot == .interrupt {
                next.slot = .runtime
            } else {
                next.slot = slot
            }
        case .setWhen(let when):
            next.when = when
            if !next.eaten && next.slot == .interrupt {
                next.slot = .runtime
            }
        case .commit:
            if !next.gramsValid || next.inFlight {
                next.fault = next.inFlight ? .inFlight : .gramsOutOfRange
            }
        case .clearFault:
            next.fault = nil
        case .wish, .dismiss:
            break
        }
        return next
    }

    private func confirm() {
        let reduced = Self.reduce(.commit, model)
        if reduced.fault != nil {
            model = reduced
            return
        }
        guard let product = model.product, let grams = model.grams else {
            model.fault = .gramsOutOfRange
            return
        }
        model.inFlight = true
        Task {
            _ = await kernel.commitIntake(
                product: product,
                grams: grams,
                slot: model.slot,
                cycle: model.cycle,
                eaten: model.eaten
            )
            HapticPulse.commit()
            model.inFlight = false
            overlay.dispatch(.flashSuccess)
            overlay.dispatch(.dismiss)
        }
    }

    private func saveWish() async {
        guard let product = model.product else { return }
        if kernel.alreadyWished(product.barcode) {
            model.alreadyWished = true
            return
        }
        model.inFlight = true
        _ = await kernel.bindWish(product)
        model.alreadyWished = true
        model.inFlight = false
        HapticPulse.commit()
    }
}

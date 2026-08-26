import Combine
import Foundation

/// ScoreLedgerProcessor maps ScoreLedgerIntent onto ScoreLedgerModel.
@MainActor
final class ScoreLedgerProcessor: ObservableObject {
    @Published private(set) var model: ScoreLedgerModel
    private let kernel: KitchenKernel
    private var bag = Set<AnyCancellable>()

    init(kernel: KitchenKernel) {
        self.kernel = kernel
        self.model = ScoreLedgerModel.project(kernel.projection)
        kernel.$projection
            .sink { [weak self] projection in
                guard let self else { return }
                var next = ScoreLedgerModel.project(projection)
                next.draft = self.model.draft
                next.pendingReset = self.model.pendingReset
                next.saving = self.model.saving
                self.model = next
            }
            .store(in: &bag)
    }

    func dispatch(_ intent: ScoreLedgerIntent) {
        switch intent {
        case .appear:
            let draft = model.draft
            model = ScoreLedgerModel.project(kernel.projection)
            model.draft = draft
        case .setKcal(let value):
            model.draft.kcal = max(value, 1)
        case .setProtein(let value):
            model.draft.protein = max(value, 0)
        case .setCarbs(let value):
            model.draft.carbs = max(value, 0)
        case .setFat(let value):
            model.draft.fat = max(value, 0)
        case .saveTargets:
            model.saving = true
            Task {
                await kernel.commitTargets(model.draft)
                model.saving = false
                HapticPulse.commit()
            }
        case .rerunBoot:
            Task { await kernel.reopenBoot() }
        case .askReset:
            model.pendingReset = true
        case .cancelReset:
            model.pendingReset = false
        case .confirmReset:
            model.pendingReset = false
            Task { await kernel.resetAllData() }
        case .openContact:
            break
        }
    }
}

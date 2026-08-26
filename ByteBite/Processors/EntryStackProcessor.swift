import Combine
import Foundation

/// EntryStackProcessor maps EntryStackIntent onto EntryStackModel.
@MainActor
final class EntryStackProcessor: ObservableObject {
    @Published private(set) var model: EntryStackModel
    private let kernel: KitchenKernel
    private var cycle: CycleKey
    private var bag = Set<AnyCancellable>()

    init(kernel: KitchenKernel) {
        self.kernel = kernel
        self.cycle = CycleKey.today()
        self.model = EntryStackModel.project(kernel.projection, cycle: cycle)
        kernel.$projection
            .sink { [weak self] projection in
                guard let self else { return }
                let pending = self.model.pendingPurge
                self.model = EntryStackModel.project(projection, cycle: self.cycle)
                self.model.pendingPurge = pending
            }
            .store(in: &bag)
    }

    func dispatch(_ intent: EntryStackIntent) {
        switch intent {
        case .appear:
            refresh()
        case .shiftDay(let delta):
            cycle = cycle.shifting(delta)
            refresh()
        case .askPurge(let id):
            model.pendingPurge = id
        case .cancelPurge:
            model.pendingPurge = nil
        case .confirmPurge:
            guard let id = model.pendingPurge else { return }
            model.pendingPurge = nil
            Task { await kernel.purgeEntry(id) }
        }
    }

    private func refresh() {
        let pending = model.pendingPurge
        model = EntryStackModel.project(kernel.projection, cycle: cycle)
        model.pendingPurge = pending
    }
}

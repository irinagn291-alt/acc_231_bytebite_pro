import Combine
import Foundation

/// HorizonProcessor maps HorizonIntent onto HorizonModel.
@MainActor
final class HorizonProcessor: ObservableObject {
    @Published private(set) var model: HorizonModel
    private let kernel: KitchenKernel
    private var bag = Set<AnyCancellable>()

    init(kernel: KitchenKernel) {
        self.kernel = kernel
        self.model = HorizonModel.project(kernel.projection)
        kernel.$projection
            .sink { [weak self] projection in
                guard let self else { return }
                let pending = self.model.pendingPurge
                self.model = HorizonModel.project(projection)
                self.model.pendingPurge = pending
            }
            .store(in: &bag)
    }

    func dispatch(_ intent: HorizonIntent) {
        switch intent {
        case .appear:
            let pending = model.pendingPurge
            model = HorizonModel.project(kernel.projection)
            model.pendingPurge = pending
        case .eat(let id):
            Task {
                _ = await kernel.eatPlanned(id)
                HapticPulse.commit()
            }
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
}

import Combine
import Foundation

/// WishRegisterProcessor maps WishRegisterIntent onto WishRegisterModel.
@MainActor
final class WishRegisterProcessor: ObservableObject {
    @Published private(set) var model: WishRegisterModel
    private let kernel: KitchenKernel
    private let overlay: OverlayProcessor
    private var bag = Set<AnyCancellable>()

    init(kernel: KitchenKernel, overlay: OverlayProcessor) {
        self.kernel = kernel
        self.overlay = overlay
        self.model = WishRegisterModel.project(kernel.projection)
        kernel.$projection
            .sink { [weak self] projection in
                guard let self else { return }
                let pending = self.model.pendingPurge
                self.model = WishRegisterModel.project(projection)
                self.model.pendingPurge = pending
            }
            .store(in: &bag)
    }

    func dispatch(_ intent: WishRegisterIntent) {
        switch intent {
        case .appear:
            let pending = model.pendingPurge
            model = WishRegisterModel.project(kernel.projection)
            model.pendingPurge = pending
        case .promote(let record):
            overlay.dispatch(.present(.commit(record)))
        case .askPurge(let barcode):
            model.pendingPurge = barcode
        case .cancelPurge:
            model.pendingPurge = nil
        case .confirmPurge:
            guard let barcode = model.pendingPurge else { return }
            model.pendingPurge = nil
            Task { await kernel.purgeWish(barcode) }
        }
    }
}

import Combine
import Foundation

/// IntakeBufferProcessor projects kitchen state into today's render model.
@MainActor
final class IntakeBufferProcessor: ObservableObject {
    @Published private(set) var model: IntakeBufferModel
    private let kernel: KitchenKernel
    private let overlay: OverlayProcessor
    private var bag = Set<AnyCancellable>()

    init(kernel: KitchenKernel, overlay: OverlayProcessor) {
        self.kernel = kernel
        self.overlay = overlay
        self.model = IntakeBufferModel.project(kernel.projection)
        kernel.$projection
            .sink { [weak self] projection in
                self?.model = IntakeBufferModel.project(projection)
            }
            .store(in: &bag)
    }

    func dispatch(_ intent: IntakeBufferIntent) {
        switch intent {
        case .appear, .clockTicked:
            model = IntakeBufferModel.project(kernel.projection)
        case .openQuery:
            overlay.dispatch(.present(.query))
        case .openScan:
            overlay.dispatch(.present(.scan))
        case .openCommit(let record):
            overlay.dispatch(.present(.commit(record)))
        }
    }
}

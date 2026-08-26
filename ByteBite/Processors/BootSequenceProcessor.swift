import Combine
import Foundation

/// BootSequenceProcessor maps BootSequenceIntent onto BootSequenceModel.
@MainActor
final class BootSequenceProcessor: ObservableObject {
    @Published private(set) var model: BootSequenceModel = .initial
    private let kernel: KitchenKernel

    init(kernel: KitchenKernel) {
        self.kernel = kernel
    }

    func dispatch(_ intent: BootSequenceIntent) {
        switch intent {
        case .finish:
            model.finishing = true
            Task { await kernel.completeBoot(targets: model.targets) }
        case .skip:
            model.finishing = true
            Task { await kernel.completeBoot(targets: .factory) }
        default:
            model = Self.reduce(intent, model)
        }
    }

    nonisolated static func reduce(_ intent: BootSequenceIntent, _ model: BootSequenceModel) -> BootSequenceModel {
        var next = model
        switch intent {
        case .next:
            next.page = min(next.page + 1, 3)
        case .back:
            next.page = max(next.page - 1, 0)
        case .setKcal(let value):
            next.targets.kcal = max(value, 1)
        case .setProtein(let value):
            next.targets.protein = max(value, 0)
        case .setCarbs(let value):
            next.targets.carbs = max(value, 0)
        case .setFat(let value):
            next.targets.fat = max(value, 0)
        case .skip, .finish:
            break
        }
        return next
    }
}

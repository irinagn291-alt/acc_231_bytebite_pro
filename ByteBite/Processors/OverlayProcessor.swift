import Combine
import Foundation

/// OverlayProcessor maps OverlayIntent onto OverlayModel.
@MainActor
final class OverlayProcessor: ObservableObject {
    @Published private(set) var model: OverlayModel = .initial

    func dispatch(_ intent: OverlayIntent) {
        switch intent {
        case .present(let kind):
            model.kind = kind
        case .dismiss:
            model.kind = .none
        case .flashSuccess:
            model.successUntil = Date().addingTimeInterval(1.1)
        }
    }
}

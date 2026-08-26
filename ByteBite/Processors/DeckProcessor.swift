import Combine
import Foundation

/// DeckProcessor maps DeckIntent onto DeckModel. Views emit intents only.
@MainActor
final class DeckProcessor: ObservableObject {
    @Published private(set) var model: DeckModel = .initial

    func dispatch(_ intent: DeckIntent) {
        model = Self.reduce(intent, model)
    }

    /// Pure total transition. Illegal values clamp to a defined stack.
    nonisolated static func reduce(_ intent: DeckIntent, _ model: DeckModel) -> DeckModel {
        var next = model
        switch intent {
        case .dragChanged(let x):
            next.dragX = x
            next.dismissing = false
        case .dragEnded(let x):
            if abs(x) > 110 {
                var order = next.order
                if !order.isEmpty {
                    let top = order.removeFirst()
                    order.append(top)
                }
                next.order = order
                next.dragX = 0
                next.dismissing = true
            } else {
                next.dragX = 0
                next.dismissing = false
            }
        case .swipeAway:
            var order = next.order
            if !order.isEmpty {
                let top = order.removeFirst()
                order.append(top)
            }
            next.order = order
            next.dragX = 0
        case .jump(let card):
            guard let index = next.order.firstIndex(of: card) else { break }
            let head = Array(next.order[index...])
            let tail = Array(next.order[..<index])
            next.order = head + tail
            next.dragX = 0
        }
        return next
    }
}

import Combine
import Foundation

/// CatalogQueryProcessor maps CatalogQueryIntent onto CatalogQueryModel.
@MainActor
final class CatalogQueryProcessor: ObservableObject {
    @Published private(set) var model: CatalogQueryModel = .initial
    private let kernel: KitchenKernel
    private let overlay: OverlayProcessor
    private var debounceTask: Task<Void, Never>?
    private var queryTask: Task<Void, Never>?

    init(kernel: KitchenKernel, overlay: OverlayProcessor) {
        self.kernel = kernel
        self.overlay = overlay
    }

    func dispatch(_ intent: CatalogQueryIntent) {
        switch intent {
        case .editQuery(let text):
            model.query = text
            scheduleQuery()
        case .retry:
            scheduleQuery(immediate: true)
        case .pick(let record):
            overlay.dispatch(.present(.commit(record)))
        case .openScan:
            debounceTask?.cancel()
            queryTask?.cancel()
            overlay.dispatch(.present(.scan))
        case .dismiss:
            debounceTask?.cancel()
            queryTask?.cancel()
            overlay.dispatch(.dismiss)
        }
    }

    private func scheduleQuery(immediate: Bool = false) {
        debounceTask?.cancel()
        queryTask?.cancel()
        let terms = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if terms.isEmpty {
            model.phase = .idle
            model.rows = []
            model.faultCopy = nil
            return
        }
        model.phase = .pending
        debounceTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            await self?.runQuery(terms)
        }
    }

    private func runQuery(_ terms: String) async {
        queryTask?.cancel()
        queryTask = Task { [weak self] in
            guard let self else { return }
            let spinner = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                if self?.model.phase == .pending {
                    self?.model.phase = .loading
                }
            }
            do {
                let rows = try await self.kernel.queryCatalog(terms: terms)
                spinner.cancel()
                guard !Task.isCancelled else { return }
                self.model.rows = rows
                self.model.faultCopy = nil
                self.model.phase = rows.isEmpty ? .empty : .results
            } catch is CancellationError {
                spinner.cancel()
            } catch {
                spinner.cancel()
                guard !Task.isCancelled else { return }
                self.model.rows = []
                self.model.phase = .fault
                self.model.faultCopy = "catalog probe dropped. the remote shelf did not answer."
            }
        }
        await queryTask?.value
    }
}

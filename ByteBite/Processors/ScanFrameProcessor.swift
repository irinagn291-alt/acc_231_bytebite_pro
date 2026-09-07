import Combine
import Foundation

/// ScanFrameProcessor maps ScanFrameIntent onto ScanFrameModel.
@MainActor
final class ScanFrameProcessor: ObservableObject {
    @Published private(set) var model: ScanFrameModel = .initial
    private let kernel: KitchenKernel
    private let overlay: OverlayProcessor
    private var resolveTask: Task<Void, Never>?

    init(kernel: KitchenKernel, overlay: OverlayProcessor) {
        self.kernel = kernel
        self.overlay = overlay
        model.samples = LocalShelf.records
    }

    func dispatch(_ intent: ScanFrameIntent) {
        switch intent {
        case .appear:
            model.samples = LocalShelf.records
        case .disappear:
            model.shouldRunSession = false
            resolveTask?.cancel()
        case .appBackgrounded:
            resolveTask?.cancel()
        case .decoded(let raw):
            handleDecode(raw)
        case .typed(let text):
            model.typed = text
        case .submitManual:
            resolve(model.typed)
        case .pickSample(let code):
            resolve(code)
        case .openSettings:
            break
        case .dismiss:
            model.shouldRunSession = false
            overlay.dispatch(.dismiss)
        case .clearFault:
            model.faultCopy = nil
        }
    }

    func applyPermission(_ permission: ScanPermission, hasDevice: Bool) {
        model.permission = permission
        model.hasDevice = hasDevice
        model.shouldRunSession = permission == .allowed && hasDevice
    }

    private func handleDecode(_ raw: String) {
        let now = Date()
        if let last = model.lastDecodeAt, now.timeIntervalSince(last) < 1.8 {
            return
        }
        if model.lastPayload == raw { return }
        model.lastPayload = raw
        model.lastDecodeAt = now
        model.flashUntil = now.addingTimeInterval(0.45)
        resolve(raw)
    }

    private func resolve(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        resolveTask?.cancel()
        model.resolving = true
        model.faultCopy = nil
        resolveTask = Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await self.kernel.resolveCode(trimmed)
                guard !Task.isCancelled else { return }
                self.model.resolving = false
                self.overlay.dispatch(.present(.commit(record)))
            } catch is CancellationError {
                return
            } catch ProbeFault.notFound {
                self.model.resolving = false
                self.model.faultCopy = "code not in the catalog. try another packet or type it."
            } catch ProbeFault.transport {
                self.model.resolving = false
                self.model.faultCopy = "offline and this code is not cached. reconnect or pick a shelf sample."
            } catch {
                self.model.resolving = false
                self.model.faultCopy = "probe could not decode that packet."
            }
        }
    }
}

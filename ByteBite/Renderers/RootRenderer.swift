import SwiftUI
import UIKit

/// RootRenderer is the scene root. It hosts the deck or boot sequence and overlays.
@MainActor
struct RootRenderer: View {
    @ObservedObject var kernel: KitchenKernel
    @StateObject private var overlay: OverlayProcessor
    @StateObject private var deck: DeckProcessor
    @StateObject private var boot: BootSequenceProcessor
    @StateObject private var intake: IntakeBufferProcessor
    @StateObject private var query: CatalogQueryProcessor
    @StateObject private var scan: ScanFrameProcessor
    @StateObject private var commit: CommitCardProcessor
    @StateObject private var log: EntryStackProcessor
    @StateObject private var plan: HorizonProcessor
    @StateObject private var wish: WishRegisterProcessor
    @StateObject private var profile: ScoreLedgerProcessor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kernel: KitchenKernel) {
        self.kernel = kernel
        let overlay = OverlayProcessor()
        _overlay = StateObject(wrappedValue: overlay)
        _deck = StateObject(wrappedValue: DeckProcessor())
        _boot = StateObject(wrappedValue: BootSequenceProcessor(kernel: kernel))
        _intake = StateObject(wrappedValue: IntakeBufferProcessor(kernel: kernel, overlay: overlay))
        _query = StateObject(wrappedValue: CatalogQueryProcessor(kernel: kernel, overlay: overlay))
        _scan = StateObject(wrappedValue: ScanFrameProcessor(kernel: kernel, overlay: overlay))
        _commit = StateObject(wrappedValue: CommitCardProcessor(kernel: kernel, overlay: overlay))
        _log = StateObject(wrappedValue: EntryStackProcessor(kernel: kernel))
        _plan = StateObject(wrappedValue: HorizonProcessor(kernel: kernel))
        _wish = StateObject(wrappedValue: WishRegisterProcessor(kernel: kernel, overlay: overlay))
        _profile = StateObject(wrappedValue: ScoreLedgerProcessor(kernel: kernel))
    }

    var body: some View {
        ZStack {
            TextureBackdrop()
            if !kernel.projection.didCompleteBoot {
                BootSequenceRenderer(processor: boot)
            } else {
                CardDeckRenderer(
                    processor: deck,
                    intake: intake,
                    log: log,
                    plan: plan,
                    wish: wish,
                    profile: profile
                )
            }

            switch overlay.model.kind {
            case .none:
                EmptyView()
            case .query:
                CatalogQueryRenderer(processor: query)
            case .scan:
                ScanFrameRenderer(processor: scan)
            case .commit:
                CommitCardRenderer(processor: commit)
            case .boot:
                BootSequenceRenderer(processor: boot)
            }

            TimelineView(.animation) { timeline in
                if let until = overlay.model.successUntil, until > timeline.date {
                    Image("byb_SuccessMark")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .transition(reduceMotion ? .opacity : .scale)
                        .accessibilityLabel("commit succeeded")
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: overlay.model.kind) { _, kind in
            if case .commit(let record) = kind {
                commit.bind(record)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            intake.dispatch(.clockTicked)
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            guard let index = args.firstIndex(of: "-ReviewScreen"), index + 1 < args.count else { return }
            switch args[index + 1] {
            case "log": deck.dispatch(.jump(.log))
            case "goals": deck.dispatch(.jump(.profile))
            default: break
            }
        }
    }
}

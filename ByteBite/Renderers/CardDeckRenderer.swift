import SwiftUI

/// CardDeckRenderer is the swipeable stack. Depth uses scale + offset.
@MainActor
struct CardDeckRenderer: View {
    @ObservedObject var processor: DeckProcessor
    let intake: IntakeBufferProcessor
    let log: EntryStackProcessor
    let plan: HorizonProcessor
    let wish: WishRegisterProcessor
    let profile: ScoreLedgerProcessor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        render(model: processor.model)
    }

    func render(model: DeckModel) -> some View {
        GeometryReader { geo in
            VStack(spacing: GridUnit.n(1)) {
                ZStack {
                    ForEach(Array(model.order.prefix(4).enumerated()), id: \.element.id) { index, card in
                        face(card)
                            .frame(width: geo.size.width - GridUnit.n(3), height: geo.size.height - GridUnit.n(10))
                            .background(PhosphorPalette.surface)
                            .overlay(Rectangle().stroke(PhosphorPalette.ink.opacity(index == 0 ? 1 : 0.4), lineWidth: 1))
                            .scaleEffect(1 - CGFloat(index) * 0.045)
                            .offset(y: CGFloat(index) * 14)
                            .offset(x: index == 0 ? model.dragX : 0)
                            .rotationEffect(.degrees(index == 0 && !reduceMotion ? model.dragX / 22 : 0))
                            .opacity(reduceMotion && index > 0 ? 0.35 : 1)
                            .zIndex(Double(10 - index))
                            .gesture(index == 0 ? drag : nil)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: GridUnit.n(1)) {
                    ForEach(DeckCard.allCases) { card in
                        Button(card.label) { processor.dispatch(.jump(card)) }
                            .font(GlyphType.font(.micro))
                            .foregroundStyle(model.top == card ? PhosphorPalette.accent : PhosphorPalette.muted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityLabel(card.label)
                            .accessibilityAddTraits(model.top == card ? .isSelected : [])
                    }
                }
                Text("swipe a card away to reveal the next")
                    .font(GlyphType.font(.micro))
                    .foregroundStyle(PhosphorPalette.ink)
            }
            .padding(.horizontal, GridUnit.n(1))
            .padding(.bottom, GridUnit.n(1))
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                processor.dispatch(.dragChanged(value.translation.width))
            }
            .onEnded { value in
                if reduceMotion {
                    if abs(value.translation.width) > 80 {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            processor.dispatch(.swipeAway)
                        }
                    } else {
                        processor.dispatch(.dragEnded(0))
                    }
                } else {
                    withAnimation(MotionCurve.easing) {
                        processor.dispatch(.dragEnded(value.translation.width))
                    }
                }
            }
    }

    @ViewBuilder
    private func face(_ card: DeckCard) -> some View {
        switch card {
        case .intake:
            IntakeBufferRenderer(processor: intake)
        case .log:
            EntryStackRenderer(processor: log)
        case .plan:
            HorizonRenderer(processor: plan)
        case .wish:
            WishRegisterRenderer(processor: wish)
        case .profile:
            ScoreLedgerRenderer(processor: profile)
        }
    }
}

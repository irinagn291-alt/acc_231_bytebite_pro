import SwiftUI

/// HorizonRenderer is the 14-day plan card.
@MainActor
struct HorizonRenderer: View {
    @ObservedObject var processor: HorizonProcessor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        render(model: processor.model)
            .onAppear { processor.dispatch(.appear) }
    }

    func render(model: HorizonModel) -> some View {
        VStack(alignment: .leading, spacing: GridUnit.n(2)) {
            Text("horizon")
                .font(GlyphType.font(.title))
                .foregroundStyle(PhosphorPalette.ink)
            Text("next \(GlyphFormat.integer(model.horizonDays)) cycles")
                .font(GlyphType.font(.caption))
                .foregroundStyle(PhosphorPalette.muted)

            if model.empty {
                EmptySignal(
                    asset: "byb_EmptyPlan",
                    headline: "horizon clear",
                    line: "no planned packets in the next fourteen cycles.",
                    actionTitle: "stay"
                ) {}
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: GridUnit.n(1)) {
                        ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                            HStack {
                                GlyphThumb(record: row.entry.product, side: 40)
                                VStack(alignment: .leading) {
                                    Text(row.entry.product.name)
                                        .font(GlyphType.font(.body))
                                        .foregroundStyle(PhosphorPalette.ink)
                                        .lineLimit(1)
                                    Text("\(row.hexDay) · \(row.entry.slot.rawValue)")
                                        .font(GlyphType.font(.caption))
                                        .foregroundStyle(PhosphorPalette.muted)
                                }
                                Spacer()
                                Button("eat") { processor.dispatch(.eat(row.entry.id)) }
                                    .buttonStyle(PhosphorGhostStyle())
                                    .accessibilityLabel("convert \(row.entry.product.name) to eaten")
                                Button {
                                    processor.dispatch(.askPurge(row.entry.id))
                                } label: {
                                    Image(systemName: "xmark")
                                        .frame(width: 44, height: 44)
                                }
                                .foregroundStyle(PhosphorPalette.ink)
                                .accessibilityLabel("delete planned \(row.entry.product.name)")
                            }
                            .padding(4)
                            .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
                            .animation(MotionCurve.honor(reduceMotion: reduceMotion).delay(Double(index) * 0.04), value: model.rows.count)
                        }
                    }
                }
            }

            if model.pendingPurge != nil {
                confirmBar(
                    copy: "purge this planned row?",
                    confirm: { processor.dispatch(.confirmPurge) },
                    cancel: { processor.dispatch(.cancelPurge) }
                )
            }
        }
        .padding(GridUnit.n(2))
        .background(PhosphorPalette.surface)
    }
}

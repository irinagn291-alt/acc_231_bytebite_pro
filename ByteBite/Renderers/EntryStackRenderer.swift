import SwiftUI

/// EntryStackRenderer is the eaten log card with hex day switching.
@MainActor
struct EntryStackRenderer: View {
    @ObservedObject var processor: EntryStackProcessor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        render(model: processor.model)
            .onAppear { processor.dispatch(.appear) }
    }

    func render(model: EntryStackModel) -> some View {
        VStack(alignment: .leading, spacing: GridUnit.n(2)) {
            HStack {
                Button {
                    processor.dispatch(.shiftDay(-1))
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(PhosphorPalette.ink)
                .accessibilityLabel("previous day")
                Spacer()
                VStack {
                    Text("entry stack")
                        .font(GlyphType.font(.title))
                        .foregroundStyle(PhosphorPalette.ink)
                    Text(model.hexDay)
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.accent)
                }
                Spacer()
                Button {
                    processor.dispatch(.shiftDay(1))
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(PhosphorPalette.ink)
                .accessibilityLabel("next day")
            }

            Text("total \(GlyphFormat.kcal(model.totals.kcal ?? 0)) kcal")
                .font(GlyphType.font(.body))
                .foregroundStyle(PhosphorPalette.accent)

            if model.empty {
                EmptySignal(
                    asset: "byb_EmptyLog",
                    headline: "stack idle",
                    line: "nothing eaten on this cycle. swipe to today and commit a packet.",
                    actionTitle: "stay"
                ) {}
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: GridUnit.n(2)) {
                        ForEach(Array(model.lanes.enumerated()), id: \.element.id) { index, lane in
                            laneBlock(lane, highlight: model.highlight)
                                .opacity(1)
                                .animation(MotionCurve.honor(reduceMotion: reduceMotion).delay(Double(index) * 0.04), value: model.hexDay)
                        }
                    }
                }
            }

            if model.pendingPurge != nil {
                confirmBar(
                    copy: "purge this row from the tape?",
                    confirm: { processor.dispatch(.confirmPurge) },
                    cancel: { processor.dispatch(.cancelPurge) }
                )
            }
        }
        .padding(GridUnit.n(2))
        .background(PhosphorPalette.surface)
    }

    private func laneBlock(_ lane: SlotLane, highlight: UUID?) -> some View {
        VStack(alignment: .leading, spacing: GridUnit.n(1)) {
            HStack {
                Image(lane.slot.assetName)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(lane.slot.rawValue)
                    .font(GlyphType.font(.body))
                    .foregroundStyle(PhosphorPalette.ink)
                Spacer()
                Text(GlyphFormat.kcal(lane.subtotal.kcal ?? 0))
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.accent)
            }
            if lane.entries.isEmpty {
                Text("idle")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.muted)
            }
            ForEach(lane.entries) { entry in
                HStack {
                    GlyphThumb(record: entry.product, side: 40)
                    VStack(alignment: .leading) {
                        Text(entry.product.name)
                            .font(GlyphType.font(.body))
                            .foregroundStyle(PhosphorPalette.ink)
                            .lineLimit(1)
                        Text("\(GlyphFormat.grams(entry.grams)) g")
                            .font(GlyphType.font(.caption))
                            .foregroundStyle(PhosphorPalette.muted)
                    }
                    Spacer()
                    Text(GlyphFormat.kcal(entry.packet.kcal ?? 0))
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.accent)
                    Button {
                        processor.dispatch(.askPurge(entry.id))
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(PhosphorPalette.ink)
                    .accessibilityLabel("delete \(entry.product.name)")
                }
                .padding(4)
                .background(highlight == entry.id ? PhosphorPalette.accent.opacity(0.18) : Color.clear)
            }
        }
        .padding(GridUnit.n(1))
        .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
    }
}

@MainActor
func confirmBar(copy: String, confirm: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
    VStack(spacing: GridUnit.n(1)) {
        Text(copy)
            .font(GlyphType.font(.body))
            .foregroundStyle(PhosphorPalette.accent)
            .multilineTextAlignment(.center)
        HStack {
            Button("cancel", action: cancel)
                .buttonStyle(PhosphorGhostStyle())
                .accessibilityLabel("cancel")
            Button("confirm", action: confirm)
                .buttonStyle(PhosphorButtonStyle(destructive: true))
                .accessibilityLabel("confirm delete")
        }
    }
    .padding(GridUnit.n(1))
    .overlay(Rectangle().stroke(PhosphorPalette.accent, lineWidth: 1))
}

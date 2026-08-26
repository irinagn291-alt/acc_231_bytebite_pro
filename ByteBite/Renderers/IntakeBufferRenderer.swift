import SwiftUI

/// IntakeBufferRenderer is the today card. One render(model:) entry point.
@MainActor
struct IntakeBufferRenderer: View {
    @ObservedObject var processor: IntakeBufferProcessor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        render(model: processor.model)
            .onAppear { processor.dispatch(.appear) }
    }

    func render(model: IntakeBufferModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridUnit.n(2)) {
                Image("byb_HeaderDecor")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 72)
                    .clipped()
                    .accessibilityHidden(true)

                HStack {
                    VStack(alignment: .leading, spacing: GridUnit.n(1)) {
                        Text("intake buffer")
                            .font(GlyphType.font(.title))
                            .foregroundStyle(PhosphorPalette.ink)
                        Text(model.hexDay)
                            .font(GlyphType.font(.caption))
                            .foregroundStyle(PhosphorPalette.accent)
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        StreakFlameCanvas(
                            streak: model.score.streak,
                            tokens: model.score.freezeTokens,
                            reduceMotion: reduceMotion
                        )
                        Text("x\(GlyphFormat.integer(model.score.streak))")
                            .font(GlyphType.font(.micro))
                            .foregroundStyle(PhosphorPalette.accent)
                    }
                }

                EnergyGlyphCanvas(
                    value: model.totals.kcal ?? 0,
                    target: model.targets.kcal,
                    reduceMotion: reduceMotion
                )
                Text("target \(GlyphFormat.kcal(model.targets.kcal))\(model.exceeded ? "  overflow" : "")")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(model.exceeded ? PhosphorPalette.accent : PhosphorPalette.muted)

                HStack(alignment: .center, spacing: GridUnit.n(1)) {
                    Text("lv \(GlyphFormat.integer(model.level))")
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.ink)
                    XPBarCanvas(progress: model.xpProgress, level: model.level, reduceMotion: reduceMotion)
                    Text("xp \(GlyphFormat.integer(model.score.totalXP))")
                        .font(GlyphType.font(.micro))
                        .foregroundStyle(PhosphorPalette.muted)
                }
                .accessibilityElement(children: .combine)

                macroRow("protein", asset: "byb_MacroProtein", actual: model.totals.protein, target: model.targets.protein)
                macroRow("carbs", asset: "byb_MacroCarbs", actual: model.totals.carbs, target: model.targets.carbs)
                macroRow("fat", asset: "byb_MacroFat", actual: model.totals.fat, target: model.targets.fat)

                HStack(spacing: GridUnit.n(1)) {
                    Button("search") { processor.dispatch(.openQuery) }
                        .buttonStyle(PhosphorButtonStyle())
                        .accessibilityLabel("search catalog")
                    Button("scan") { processor.dispatch(.openScan) }
                        .buttonStyle(PhosphorGhostStyle())
                        .accessibilityLabel("scan barcode")
                }

                if model.empty {
                    EmptySignal(
                        asset: "byb_EmptyLog",
                        headline: "buffer empty",
                        line: "no packets committed today. probe the catalog or scan a code.",
                        actionTitle: "open search"
                    ) { processor.dispatch(.openQuery) }
                } else {
                    ForEach(Array(model.lanes.enumerated()), id: \.element.id) { index, lane in
                        laneBlock(lane)
                            .opacity(1)
                            .animation(MotionCurve.honor(reduceMotion: reduceMotion).delay(Double(index) * 0.04), value: lane.entries.count)
                    }
                }
            }
            .padding(GridUnit.n(2))
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PhosphorPalette.surface)
    }

    private func macroRow(_ title: String, asset: String, actual: Double?, target: Double) -> some View {
        HStack(spacing: GridUnit.n(1)) {
            Image(asset)
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.ink)
                    Spacer()
                    Text("\(GlyphFormat.macro(actual)) / \(GlyphFormat.macro(target))")
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.muted)
                        .lineLimit(1)
                }
                MacroMeterCanvas(title: title, actual: actual, target: target, reduceMotion: reduceMotion)
            }
        }
    }

    private func laneBlock(_ lane: SlotLane) -> some View {
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
            } else {
                ForEach(lane.entries) { entry in
                    HStack {
                        GlyphThumb(record: entry.product, side: 40)
                        Text(entry.product.name)
                            .font(GlyphType.font(.body))
                            .foregroundStyle(PhosphorPalette.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(GlyphFormat.kcal(entry.packet.kcal ?? 0))
                            .font(GlyphType.font(.caption))
                            .foregroundStyle(PhosphorPalette.accent)
                    }
                    .accessibilityLabel("\(entry.product.name), \(GlyphFormat.kcal(entry.packet.kcal ?? 0)) kcal")
                }
            }
        }
        .padding(GridUnit.n(1))
        .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
    }
}

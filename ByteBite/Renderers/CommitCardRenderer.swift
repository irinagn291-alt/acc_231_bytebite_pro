import SwiftUI

/// CommitCardRenderer fuses detail and assign into one XP commit card.
@MainActor
struct CommitCardRenderer: View {
    @ObservedObject var processor: CommitCardProcessor
    @FocusState private var gramsFocused: Bool

    var body: some View {
        render(model: processor.model)
    }

    func render(model: CommitCardModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridUnit.n(2)) {
                HStack {
                    Text("commit card")
                        .font(GlyphType.font(.title))
                        .foregroundStyle(PhosphorPalette.ink)
                    Spacer()
                    Button {
                        processor.dispatch(.dismiss)
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(PhosphorPalette.ink)
                    .accessibilityLabel("close commit card")
                }

                Image("byb_CardBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 96)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        if let product = model.product {
                            HStack {
                                GlyphThumb(record: product, side: 56)
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                        .font(GlyphType.font(.body))
                                        .foregroundStyle(PhosphorPalette.ink)
                                        .lineLimit(1)
                                    Text(product.brand ?? "unbranded")
                                        .font(GlyphType.font(.caption))
                                        .foregroundStyle(PhosphorPalette.muted)
                                        .lineLimit(1)
                                }
                            }
                            .padding(GridUnit.n(1))
                        }
                    }
                    .accessibilityHidden(true)

                if let product = model.product {
                    macroLine("energy / 100g", product.per100.kcal.map(GlyphFormat.kcal) ?? "unknown")
                    macroLine("protein / 100g", GlyphFormat.macro(product.per100.protein))
                    macroLine("carbs / 100g", GlyphFormat.macro(product.per100.carbs))
                    macroLine("fat / 100g", GlyphFormat.macro(product.per100.fat))
                    if product.per100.kcal == nil {
                        Text("energy unknown — you can still commit. xp is reduced.")
                            .font(GlyphType.font(.caption))
                            .foregroundStyle(PhosphorPalette.accent)
                    }
                }

                Text("grams")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.muted)
                TextField("grams", text: Binding(
                    get: { model.gramsGlyph },
                    set: { processor.dispatch(.setGrams($0)) }
                ))
                .keyboardType(.decimalPad)
                .font(GlyphType.font(.body))
                .foregroundStyle(PhosphorPalette.ink)
                .padding(GridUnit.n(1))
                .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
                .focused($gramsFocused)
                .frame(minHeight: 44)
                .accessibilityLabel("grams")

                if let grams = model.grams, model.gramsValid, let product = model.product {
                    let live = product.per100.scaled(grams: grams)
                    Text("live \(GlyphFormat.kcal(live.kcal ?? 0)) kcal · p \(GlyphFormat.macro(live.protein)) · c \(GlyphFormat.macro(live.carbs)) · f \(GlyphFormat.macro(live.fat))")
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.ink)
                }

                if model.fault == .gramsOutOfRange {
                    Text("grams must be greater than 0 and at most 5000")
                        .font(GlyphType.font(.caption))
                        .foregroundStyle(PhosphorPalette.accent)
                }

                Text("slot")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.muted)
                HStack(spacing: GridUnit.n(1)) {
                    ForEach(CycleSlot.allCases) { slot in
                        let blocked = !model.eaten && slot == .interrupt
                        Button {
                            processor.dispatch(.setSlot(slot))
                        } label: {
                            VStack {
                                Image(slot.assetName)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .accessibilityHidden(true)
                                Text(slot.rawValue)
                                    .font(GlyphType.font(.micro))
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(model.slot == slot ? PhosphorPalette.accent : PhosphorPalette.ink)
                            .overlay(Rectangle().stroke(model.slot == slot ? PhosphorPalette.accent : PhosphorPalette.muted, lineWidth: 1))
                            .opacity(blocked ? 0.35 : 1)
                        }
                        .disabled(blocked)
                        .accessibilityLabel(slot.rawValue)
                    }
                }

                Text("when")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.muted)
                Button("eaten today") { processor.dispatch(.setWhen(.eatenToday)) }
                    .font(GlyphType.font(.body))
                    .foregroundStyle(model.eaten ? PhosphorPalette.background : PhosphorPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(model.eaten ? PhosphorPalette.accent : PhosphorPalette.surface)
                    .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
                    .accessibilityLabel("eaten today")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GridUnit.n(1)) {
                        ForEach(1...14, id: \.self) { offset in
                            let key = CycleKey.today().shifting(offset)
                            Button(key.hexGlyph) {
                                processor.dispatch(.setWhen(.planned(key.rawValue)))
                            }
                            .buttonStyle(PhosphorGhostStyle())
                            .overlay {
                                if case .planned(let day) = model.when, day == key.rawValue {
                                    Rectangle().stroke(PhosphorPalette.accent, lineWidth: 2)
                                }
                            }
                            .accessibilityLabel("plan \(key.hexGlyph)")
                        }
                    }
                }

                Text("xp preview +\(GlyphFormat.integer(model.award.awardedXP))\(model.award.comboHit ? " combo" : "")")
                    .font(GlyphType.font(.body))
                    .foregroundStyle(PhosphorPalette.accent)

                Button("commit") { processor.dispatch(.commit) }
                    .buttonStyle(PhosphorButtonStyle(disabled: model.inFlight || !model.gramsValid))
                    .disabled(model.inFlight || !model.gramsValid)
                    .accessibilityLabel("commit entry")

                Button(model.alreadyWished ? "already on wish stack" : "bind to wish") {
                    processor.dispatch(.wish)
                }
                .buttonStyle(PhosphorGhostStyle())
                .disabled(model.alreadyWished || model.inFlight)
                .accessibilityLabel(model.alreadyWished ? "already on wish stack" : "bind to wish")
            }
            .padding(GridUnit.n(2))
        }
        .scrollDismissesKeyboard(.interactively)
        .background(TextureBackdrop())
        .onTapGesture { gramsFocused = false }
    }

    private func macroLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(GlyphType.font(.caption))
                .foregroundStyle(PhosphorPalette.muted)
            Spacer()
            Text(value)
                .font(GlyphType.font(.body))
                .foregroundStyle(PhosphorPalette.ink)
        }
    }
}

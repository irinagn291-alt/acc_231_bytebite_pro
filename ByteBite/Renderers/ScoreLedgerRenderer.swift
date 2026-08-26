import SwiftUI

/// ScoreLedgerRenderer is the profile, badge grid and goals card.
@MainActor
struct ScoreLedgerRenderer: View {
    @ObservedObject var processor: ScoreLedgerProcessor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContact = false

    var body: some View {
        render(model: processor.model)
            .onAppear { processor.dispatch(.appear) }
    }

    func render(model: ScoreLedgerModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridUnit.n(2)) {
                Image("byb_TwistHero")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Text("score ledger")
                    .font(GlyphType.font(.title))
                    .foregroundStyle(PhosphorPalette.ink)
                Text(model.hexDay)
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.accent)

                Text("level \(GlyphFormat.integer(model.level))")
                    .font(GlyphType.font(.display))
                    .foregroundStyle(PhosphorPalette.ink)
                XPBarCanvas(progress: model.progress, level: model.level, reduceMotion: reduceMotion)
                Text("\(GlyphFormat.integer(model.xpInto)) / \(GlyphFormat.integer(model.xpNeeded)) xp  ·  total \(GlyphFormat.integer(model.score.totalXP))")
                    .font(GlyphType.font(.caption))
                    .foregroundStyle(PhosphorPalette.muted)

                HStack {
                    StreakFlameCanvas(
                        streak: model.score.streak,
                        tokens: model.score.freezeTokens,
                        reduceMotion: reduceMotion
                    )
                    VStack(alignment: .leading) {
                        Text("streak \(GlyphFormat.integer(model.score.streak))  longest \(GlyphFormat.integer(model.score.longest))")
                            .font(GlyphType.font(.body))
                            .foregroundStyle(PhosphorPalette.ink)
                        Text("freeze tokens \(GlyphFormat.integer(model.score.freezeTokens))")
                            .font(GlyphType.font(.caption))
                            .foregroundStyle(PhosphorPalette.muted)
                    }
                }

                Text("badge grid")
                    .font(GlyphType.font(.title))
                    .foregroundStyle(PhosphorPalette.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: GridUnit.n(1))], spacing: GridUnit.n(1)) {
                    ForEach(model.badges) { badge in
                        VStack(spacing: 4) {
                            Image(badge.unlocked ? "byb_SuccessMark" : "byb_ControlFace")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .opacity(badge.unlocked ? 1 : 0.35)
                                .accessibilityHidden(true)
                            Text(badge.title)
                                .font(GlyphType.font(.micro))
                                .foregroundStyle(badge.unlocked ? PhosphorPalette.accent : PhosphorPalette.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(minHeight: 72)
                        .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
                        .accessibilityLabel("\(badge.title) \(badge.unlocked ? "unlocked" : "locked")")
                    }
                }

                Text("targets")
                    .font(GlyphType.font(.title))
                    .foregroundStyle(PhosphorPalette.ink)
                targetStepper("kcal", value: model.draft.kcal, step: 50) {
                    processor.dispatch(.setKcal($0))
                }
                targetStepper("protein", value: model.draft.protein, step: 5) {
                    processor.dispatch(.setProtein($0))
                }
                targetStepper("carbs", value: model.draft.carbs, step: 5) {
                    processor.dispatch(.setCarbs($0))
                }
                targetStepper("fat", value: model.draft.fat, step: 5) {
                    processor.dispatch(.setFat($0))
                }
                Button("write targets") { processor.dispatch(.saveTargets) }
                    .buttonStyle(PhosphorButtonStyle(disabled: model.saving))
                    .disabled(model.saving)
                    .accessibilityLabel("write targets")

                Button("re-run boot sequence") { processor.dispatch(.rerunBoot) }
                    .buttonStyle(PhosphorGhostStyle())
                    .accessibilityLabel("re-run onboarding")

                Button("reset all data") { processor.dispatch(.askReset) }
                    .buttonStyle(PhosphorGhostStyle())
                    .accessibilityLabel("reset all data")

                if model.pendingReset {
                    confirmBar(
                        copy: "wipe the event tape? this cannot be undone.",
                        confirm: { processor.dispatch(.confirmReset) },
                        cancel: { processor.dispatch(.cancelReset) }
                    )
                }

                Button("contact bytebite.pro") { showContact = true }
                    .font(GlyphType.font(.body))
                    .foregroundStyle(PhosphorPalette.ink)
                    .frame(minHeight: 44)
                    .accessibilityLabel("contact bytebite.pro")

                Text("nutrition data from open food facts. not medical advice.")
                    .font(GlyphType.font(.micro))
                    .foregroundStyle(PhosphorPalette.muted)
            }
            .padding(GridUnit.n(2))
        }
        .background(PhosphorPalette.surface)
        .sheet(isPresented: $showContact) {
            ContactWebSheet()
        }
    }
}

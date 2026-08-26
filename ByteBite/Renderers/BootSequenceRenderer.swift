import SwiftUI

/// BootSequenceRenderer is the onboarding view. It emits BootSequenceIntent only.
@MainActor
struct BootSequenceRenderer: View {
    @ObservedObject var processor: BootSequenceProcessor

    var body: some View {
        render(model: processor.model)
    }

    @ViewBuilder
    func render(model: BootSequenceModel) -> some View {
        VStack(spacing: GridUnit.n(2)) {
            TabView(selection: bindPage(model)) {
                page(
                    asset: "byb_Onboarding1",
                    title: "eat. score. streak.",
                    line: "bytebite turns packaged food into xp. log what you eat, hit macros, keep the flame.",
                    tag: 0
                )
                page(
                    asset: "byb_Onboarding2",
                    title: "probe the catalog",
                    line: "search by name or scan a barcode. every resolved packet is cached on this device.",
                    tag: 1
                )
                targetsPage(model).tag(2)
                page(
                    asset: "byb_TwistHero",
                    title: "combo lock",
                    line: "xp per commit, combo when macros lock, freeze tokens if you miss a day. skip writes factory targets.",
                    tag: 3
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: GridUnit.n(1)) {
                if model.page > 0 {
                    Button("back") { processor.dispatch(.back) }
                        .buttonStyle(PhosphorGhostStyle())
                        .accessibilityLabel("back")
                }
                Button(model.page == 3 ? "boot" : "next") {
                    if model.page == 3 {
                        processor.dispatch(.finish)
                    } else {
                        processor.dispatch(.next)
                    }
                }
                .buttonStyle(PhosphorButtonStyle(disabled: model.finishing))
                .disabled(model.finishing)
                .accessibilityLabel(model.page == 3 ? "boot" : "next")
            }
            Button("skip") { processor.dispatch(.skip) }
                .font(GlyphType.font(.caption))
                .foregroundStyle(PhosphorPalette.muted)
                .frame(minHeight: 44)
                .disabled(model.finishing)
                .accessibilityLabel("skip onboarding")
        }
        .padding(GridUnit.n(2))
        .background(TextureBackdrop())
    }

    private func bindPage(_ model: BootSequenceModel) -> Binding<Int> {
        Binding(
            get: { model.page },
            set: { new in
                if new > model.page { processor.dispatch(.next) }
                if new < model.page { processor.dispatch(.back) }
            }
        )
    }

    private func page(asset: String, title: String, line: String, tag: Int) -> some View {
        VStack(spacing: GridUnit.n(2)) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .accessibilityHidden(true)
            Text(title)
                .font(GlyphType.font(.display))
                .foregroundStyle(PhosphorPalette.ink)
                .multilineTextAlignment(.center)
            Text(line)
                .font(GlyphType.font(.body))
                .foregroundStyle(PhosphorPalette.muted)
                .multilineTextAlignment(.center)
        }
        .tag(tag)
        .padding(GridUnit.n(1))
    }

    private func targetsPage(_ model: BootSequenceModel) -> some View {
        VStack(spacing: GridUnit.n(2)) {
            Image("byb_Onboarding3")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .accessibilityHidden(true)
            Text("set daily targets")
                .font(GlyphType.font(.title))
                .foregroundStyle(PhosphorPalette.ink)
            targetStepper("kcal", value: model.targets.kcal, step: 50) {
                processor.dispatch(.setKcal($0))
            }
            targetStepper("protein", value: model.targets.protein, step: 5) {
                processor.dispatch(.setProtein($0))
            }
            targetStepper("carbs", value: model.targets.carbs, step: 5) {
                processor.dispatch(.setCarbs($0))
            }
            targetStepper("fat", value: model.targets.fat, step: 5) {
                processor.dispatch(.setFat($0))
            }
        }
    }
}

@MainActor
func targetStepper(_ title: String, value: Double, step: Double, onChange: @escaping (Double) -> Void) -> some View {
    HStack {
        Text(title)
            .font(GlyphType.font(.body))
            .foregroundStyle(PhosphorPalette.ink)
            .frame(width: 88, alignment: .leading)
        Button("-") { onChange(max(value - step, title == "kcal" ? 1 : 0)) }
            .buttonStyle(PhosphorGhostStyle())
            .accessibilityLabel("decrease \(title)")
        Text(title == "kcal" ? GlyphFormat.kcal(value) : GlyphFormat.macro(value))
            .font(GlyphType.font(.body))
            .foregroundStyle(PhosphorPalette.accent)
            .frame(minWidth: 64)
        Button("+") { onChange(value + step) }
            .buttonStyle(PhosphorGhostStyle())
            .accessibilityLabel("increase \(title)")
    }
}

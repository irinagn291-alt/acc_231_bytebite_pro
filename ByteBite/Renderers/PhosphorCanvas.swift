import SwiftUI

/// PhosphorCanvas draws XP, streak flame and macro meters. No stacked chrome views.
@MainActor
struct XPBarCanvas: View {
    let progress: Double
    let level: Int
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.85 + 0.15 * sin(t * 4)
                let inset = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
                context.stroke(
                    Path(inset),
                    with: .color(PhosphorPalette.muted),
                    lineWidth: 2
                )
                let width = inset.width * max(0, min(progress, 1))
                var fill = inset
                fill.size.width = width
                context.fill(Path(fill), with: .color(PhosphorPalette.accent.opacity(pulse)))
                for y in stride(from: 0, to: size.height, by: 3) {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(PhosphorPalette.background.opacity(0.35)), lineWidth: 1)
                }
            }
        }
        .frame(height: GridUnit.n(2))
        .accessibilityLabel("level \(level) experience")
    }
}

/// StreakFlameCanvas is a flickering phosphor flame driven by TimelineView.
@MainActor
struct StreakFlameCanvas: View {
    let streak: Int
    let tokens: Int
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let flicker = 0.75 + 0.25 * sin(t * 9)
                let mid = size.width / 2
                var flame = Path()
                flame.move(to: CGPoint(x: mid - 10, y: size.height - 4))
                flame.addLine(to: CGPoint(x: mid - 6 + CGFloat(sin(t * 7) * 2), y: size.height * 0.45))
                flame.addLine(to: CGPoint(x: mid, y: 4 + CGFloat(sin(t * 11) * 2)))
                flame.addLine(to: CGPoint(x: mid + 6 + CGFloat(cos(t * 7) * 2), y: size.height * 0.45))
                flame.addLine(to: CGPoint(x: mid + 10, y: size.height - 4))
                flame.closeSubpath()
                context.fill(flame, with: .color(PhosphorPalette.accent.opacity(flicker)))
                var core = Path()
                core.move(to: CGPoint(x: mid - 4, y: size.height - 6))
                core.addLine(to: CGPoint(x: mid, y: size.height * 0.35))
                core.addLine(to: CGPoint(x: mid + 4, y: size.height - 6))
                core.closeSubpath()
                context.fill(core, with: .color(PhosphorPalette.ink.opacity(0.85)))
            }
        }
        .frame(width: 36, height: 44)
        .accessibilityLabel("streak \(streak), freeze tokens \(tokens)")
    }
}

/// MacroMeterCanvas draws one macro bar inside Canvas.
@MainActor
struct MacroMeterCanvas: View {
    let title: String
    let actual: Double?
    let target: Double
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.7 + 0.3 * sin(t * 3)
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(PhosphorPalette.surface))
                context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(PhosphorPalette.muted), lineWidth: 1)
                let ratio: Double
                if let actual, target > 0 {
                    ratio = min(actual / target, 1.25)
                } else {
                    ratio = 0
                }
                var fill = CGRect(origin: .zero, size: size)
                fill.size.width = size.width * CGFloat(min(ratio, 1))
                let color = ratio > 1 ? PhosphorPalette.accent : PhosphorPalette.ink
                context.fill(Path(fill), with: .color(color.opacity(actual == nil ? 0.15 : pulse)))
                for y in stride(from: 1, to: size.height, by: 4) {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(PhosphorPalette.background.opacity(0.4)), lineWidth: 1)
                }
            }
        }
        .frame(height: GridUnit.n(2))
        .accessibilityLabel("\(title) \(GlyphFormat.macro(actual)) of \(GlyphFormat.macro(target))")
    }
}

/// EnergyGlyphCanvas draws the animated energy readout.
@MainActor
struct EnergyGlyphCanvas: View {
    let value: Double
    let target: Double
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let shown = reduceMotion ? value : interpolated(now: timeline.date)
            Text("\(GlyphFormat.kcal(shown)) kcal")
                .font(GlyphType.font(.hero))
                .foregroundStyle(PhosphorPalette.accent)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("energy \(GlyphFormat.kcal(value)) of \(GlyphFormat.kcal(target))")
    }

    private func interpolated(now: Date) -> Double {
        value
    }
}

/// ScanReticleCanvas draws a pixel-art scan frame and chiptune flash.
@MainActor
struct ScanReticleCanvas: View {
    let flashUntil: Date?
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let flashing = flashUntil.map { $0 > timeline.date } ?? false
                let flash = flashing && !reduceMotion && Int(t * 12) % 2 == 0
                let ink = flash ? PhosphorPalette.accent : PhosphorPalette.ink
                let arm: CGFloat = min(size.width, size.height) * 0.18
                let thick: CGFloat = 6
                let inset: CGFloat = 24
                let corners: [(CGPoint, CGFloat, CGFloat)] = [
                    (CGPoint(x: inset, y: inset), 1, 1),
                    (CGPoint(x: size.width - inset, y: inset), -1, 1),
                    (CGPoint(x: inset, y: size.height - inset), 1, -1),
                    (CGPoint(x: size.width - inset, y: size.height - inset), -1, -1),
                ]
                for (origin, dx, dy) in corners {
                    let h = Path(CGRect(
                        x: dx > 0 ? origin.x : origin.x - arm,
                        y: dy > 0 ? origin.y : origin.y - thick,
                        width: arm,
                        height: thick
                    ))
                    let v = Path(CGRect(
                        x: dx > 0 ? origin.x : origin.x - thick,
                        y: dy > 0 ? origin.y : origin.y - arm,
                        width: thick,
                        height: arm
                    ))
                    context.fill(h, with: .color(ink))
                    context.fill(v, with: .color(ink))
                }
                if flash {
                    for y in stride(from: 0, to: size.height, by: 6) {
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(line, with: .color(PhosphorPalette.accent.opacity(0.35)), lineWidth: 2)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

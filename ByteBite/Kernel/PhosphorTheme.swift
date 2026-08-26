import SwiftUI

/// PhosphorPalette is the only colour accessor. Tokens live in the asset catalog.
enum PhosphorPalette {
    static var background: Color { Color("byb_background") }
    static var surface: Color { Color("byb_surface") }
    static var ink: Color { Color("byb_ink") }
    static var accent: Color { Color("byb_accent") }
    static var muted: Color { Color("byb_muted") }
}

/// GlyphStep is the closed type scale. Six steps, nothing else.
enum GlyphStep: CaseIterable, Sendable {
    case micro, caption, body, title, display, hero

    var size: CGFloat {
        switch self {
        case .micro: 11
        case .caption: 13
        case .body: 16
        case .title: 20
        case .display: 28
        case .hero: 36
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .micro: .caption2
        case .caption: .caption
        case .body: .body
        case .title: .title3
        case .display: .title
        case .hero: .largeTitle
        }
    }
}

/// GlyphType is the only typography accessor. Courier New everywhere.
enum GlyphType {
    static func font(_ step: GlyphStep) -> Font {
        Font.custom("Courier New", size: step.size, relativeTo: step.textStyle)
    }
}

enum GridUnit {
    static let base: CGFloat = 8
    static func n(_ k: Int) -> CGFloat { base * CGFloat(k) }
}

/// MotionCurve is the single shared easing used by every transition.
enum MotionCurve {
    static let duration: Double = 0.28

    static var easing: Animation {
        .easeInOut(duration: duration)
    }

    static func honor(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : easing
    }
}

/// GlyphFormat is the only number formatter seam.
enum GlyphFormat {
    static func kcal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "0"
    }

    static func macro(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "unknown"
    }

    static func grams(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func integer(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func parseDecimal(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: trimmed) else { return nil }
        return number.doubleValue
    }
}

import SwiftUI

/// GlyphThumb is the three-tier product image: remote, shelf asset, placeholder.
@MainActor
struct GlyphThumb: View {
    let record: GlyphRecord
    var side: CGFloat = 48

    var body: some View {
        Group {
            if let path = record.imagePath, let url = URL(string: path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        bundled
                    case .empty:
                        bundled.redacted(reason: .placeholder)
                    @unknown default:
                        bundled
                    }
                }
            } else {
                bundled
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bundled: some View {
        if let asset = record.shelfAsset, !asset.isEmpty {
            Image(asset).resizable().scaledToFill()
        } else {
            Image("byb_ProductPlaceholder").resizable().scaledToFill()
        }
    }
}

/// EmptySignal pairs generated art with a headline, line and a primary action.
@MainActor
struct EmptySignal: View {
    let asset: String
    let headline: String
    let line: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: GridUnit.n(2)) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            Text(headline)
                .font(GlyphType.font(.title))
                .foregroundStyle(PhosphorPalette.ink)
                .multilineTextAlignment(.center)
            Text(line)
                .font(GlyphType.font(.body))
                .foregroundStyle(PhosphorPalette.muted)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(PhosphorButtonStyle())
                .accessibilityLabel(actionTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(GridUnit.n(2))
    }
}

/// PhosphorButtonStyle is the primary 44pt control face.
@MainActor
struct PhosphorButtonStyle: ButtonStyle {
    var destructive = false
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GlyphType.font(.body))
            .foregroundStyle(destructive ? PhosphorPalette.accent : PhosphorPalette.background)
            .frame(minHeight: 44)
            .padding(.horizontal, GridUnit.n(2))
            .frame(maxWidth: .infinity)
            .background(disabled ? PhosphorPalette.muted : PhosphorPalette.accent)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

@MainActor
struct PhosphorGhostStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GlyphType.font(.body))
            .foregroundStyle(PhosphorPalette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, GridUnit.n(1))
            .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

@MainActor
struct TextureBackdrop: View {
    var body: some View {
        PhosphorPalette.background
            .overlay {
                Image("byb_Texture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
    }
}

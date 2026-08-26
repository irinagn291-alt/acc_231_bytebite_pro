import SwiftUI

/// WishRegisterRenderer is the barcode-unique wish card.
@MainActor
struct WishRegisterRenderer: View {
    @ObservedObject var processor: WishRegisterProcessor

    var body: some View {
        render(model: processor.model)
            .onAppear { processor.dispatch(.appear) }
    }

    func render(model: WishRegisterModel) -> some View {
        VStack(alignment: .leading, spacing: GridUnit.n(2)) {
            Text("wish register")
                .font(GlyphType.font(.title))
                .foregroundStyle(PhosphorPalette.ink)

            if model.empty {
                EmptySignal(
                    asset: "byb_EmptyWish",
                    headline: "register empty",
                    line: "bind a packet from the commit card. duplicates update the same row.",
                    actionTitle: "stay"
                ) {}
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: GridUnit.n(1)) {
                        ForEach(model.rows) { row in
                            HStack {
                                GlyphThumb(record: row.product, side: 40)
                                VStack(alignment: .leading) {
                                    Text(row.product.name)
                                        .font(GlyphType.font(.body))
                                        .foregroundStyle(PhosphorPalette.ink)
                                        .lineLimit(1)
                                    Text(row.barcode)
                                        .font(GlyphType.font(.micro))
                                        .foregroundStyle(PhosphorPalette.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("promote") { processor.dispatch(.promote(row.product)) }
                                    .buttonStyle(PhosphorGhostStyle())
                                    .accessibilityLabel("promote \(row.product.name)")
                                Button {
                                    processor.dispatch(.askPurge(row.barcode))
                                } label: {
                                    Image(systemName: "xmark")
                                        .frame(width: 44, height: 44)
                                }
                                .foregroundStyle(PhosphorPalette.ink)
                                .accessibilityLabel("delete wish \(row.product.name)")
                            }
                            .padding(4)
                            .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
                        }
                    }
                }
            }

            if model.pendingPurge != nil {
                confirmBar(
                    copy: "purge this wish row?",
                    confirm: { processor.dispatch(.confirmPurge) },
                    cancel: { processor.dispatch(.cancelPurge) }
                )
            }
        }
        .padding(GridUnit.n(2))
        .background(PhosphorPalette.surface)
    }
}

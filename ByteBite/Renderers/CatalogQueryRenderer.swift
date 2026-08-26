import SwiftUI

/// CatalogQueryRenderer is the full-screen search overlay.
@MainActor
struct CatalogQueryRenderer: View {
    @ObservedObject var processor: CatalogQueryProcessor
    @FocusState private var focused: Bool

    var body: some View {
        render(model: processor.model)
    }

    func render(model: CatalogQueryModel) -> some View {
        VStack(spacing: GridUnit.n(2)) {
            HStack {
                Text("catalog query")
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
                .accessibilityLabel("close search")
            }
            TextField("search terms", text: Binding(
                get: { model.query },
                set: { processor.dispatch(.editQuery($0)) }
            ))
            .font(GlyphType.font(.body))
            .foregroundStyle(PhosphorPalette.ink)
            .padding(GridUnit.n(1))
            .overlay(Rectangle().stroke(PhosphorPalette.muted, lineWidth: 1))
            .focused($focused)
            .frame(minHeight: 44)
            .accessibilityLabel("search terms")

            content(model)
        }
        .padding(GridUnit.n(2))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TextureBackdrop())
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focused = false }
    }

    @ViewBuilder
    private func content(_ model: CatalogQueryModel) -> some View {
        switch model.phase {
        case .idle:
            EmptySignal(
                asset: "byb_EmptySearch",
                headline: "awaiting query",
                line: "type a name. remote hits merge with the local shelf.",
                actionTitle: "scan instead"
            ) { processor.dispatch(.dismiss) }
        case .pending:
            Color.clear.frame(height: 44)
        case .loading:
            ProgressView()
                .tint(PhosphorPalette.ink)
                .frame(height: 44)
                .accessibilityLabel("loading catalog")
        case .results:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: GridUnit.n(1)) {
                    ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                        Button {
                            processor.dispatch(.pick(row))
                        } label: {
                            HStack(spacing: GridUnit.n(1)) {
                                GlyphThumb(record: row)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .font(GlyphType.font(.body))
                                        .foregroundStyle(PhosphorPalette.ink)
                                        .lineLimit(1)
                                    Text(row.brand ?? "unbranded")
                                        .font(GlyphType.font(.caption))
                                        .foregroundStyle(PhosphorPalette.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(row.per100.kcal.map { "\(GlyphFormat.kcal($0))/100g" } ?? "unknown")
                                    .font(GlyphType.font(.caption))
                                    .foregroundStyle(PhosphorPalette.accent)
                                    .lineLimit(1)
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityLabel("\(row.name), \(row.per100.kcal.map { GlyphFormat.kcal($0) } ?? "unknown") kcal per 100 grams")
                        .opacity(1)
                    }
                }
            }
        case .empty:
            EmptySignal(
                asset: "byb_EmptySearch",
                headline: "zero hits",
                line: "remote and shelf both came back empty. try another token.",
                actionTitle: "retry"
            ) { processor.dispatch(.retry) }
        case .fault:
            VStack(spacing: GridUnit.n(2)) {
                Text(model.faultCopy ?? "catalog probe dropped.")
                    .font(GlyphType.font(.body))
                    .foregroundStyle(PhosphorPalette.accent)
                    .multilineTextAlignment(.center)
                Button("retry") { processor.dispatch(.retry) }
                    .buttonStyle(PhosphorButtonStyle())
                    .accessibilityLabel("retry search")
            }
        }
    }
}

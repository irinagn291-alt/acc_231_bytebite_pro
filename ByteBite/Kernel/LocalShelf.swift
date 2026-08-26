import Foundation

/// LocalShelf is the bundled catalog so a search never dead-ends.
enum LocalShelf: Sendable {
    static let records: [GlyphRecord] = [
        make(
            barcode: "0027815995026",
            name: "salmon_fillet",
            brand: "shelf.pkt",
            kcal: 208, protein: 20.4, carbs: 0.0, fat: 13.4,
            asset: "byb_ShelfSalmon"
        ),
        make(
            barcode: "3038350208002",
            name: "couscous_heap",
            brand: "shelf.bin",
            kcal: 376, protein: 12.8, carbs: 77.4, fat: 0.6,
            asset: "byb_ShelfCouscous"
        ),
        make(
            barcode: "0041220016143",
            name: "blueberry_block",
            brand: "shelf.img",
            kcal: 57, protein: 0.7, carbs: 14.5, fat: 0.3,
            asset: "byb_ShelfBerries"
        ),
        make(
            barcode: "3017620422003",
            name: "sardine_tin",
            brand: "shelf.tar",
            kcal: 208, protein: 24.6, carbs: 0.0, fat: 11.5,
            asset: "byb_ShelfSardines"
        ),
        make(
            barcode: "7394376616037",
            name: "oat_milk_stream",
            brand: "shelf.iso",
            kcal: 45, protein: 1.0, carbs: 6.7, fat: 1.5,
            asset: "byb_ShelfOat"
        ),
        make(
            barcode: "3046920029759",
            name: "dark_chocolate_70",
            brand: "shelf.rom",
            kcal: 598, protein: 7.8, carbs: 45.9, fat: 42.6,
            asset: "byb_ShelfChoc"
        ),
    ]

    static func record(_ barcode: String) -> GlyphRecord? {
        let wanted = BarcodeGlyph.candidates(barcode) + [barcode]
        return records.first { item in
            wanted.contains(item.barcode) || BarcodeGlyph.candidates(item.barcode).contains(where: wanted.contains)
        }
    }

    static func match(_ terms: String) -> [GlyphRecord] {
        let needle = terms.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return records }
        return records.filter { record in
            record.name.lowercased().contains(needle)
                || (record.brand?.lowercased().contains(needle) ?? false)
                || record.barcode.contains(needle)
        }
    }

    private static func make(
        barcode: String,
        name: String,
        brand: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        asset: String
    ) -> GlyphRecord {
        GlyphRecord(
            barcode: barcode,
            name: name,
            brand: brand,
            per100: MacroPacket(kcal: kcal, protein: protein, carbs: carbs, fat: fat),
            imagePath: nil,
            shelfAsset: asset,
            refreshedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

import Foundation

/// ProbeFault is the typed catalog error surface.
enum ProbeFault: Error, Sendable, Equatable {
    case transport
    case notFound
    case malformed
}

/// FlexibleNumber accepts a JSON number or a numeric string.
struct FlexibleNumber: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let number = try? container.decode(Int.self) {
            value = Double(number)
        } else if let text = try? container.decode(String.self) {
            value = Double(text.replacingOccurrences(of: ",", with: "."))
        } else {
            value = nil
        }
    }
}

/// OFFNutrimentsDTO mirrors Open Food Facts nutriment keys exactly.
struct OFFNutrimentsDTO: Decodable, Sendable {
    var energyKcal100: FlexibleNumber?
    var energy100: FlexibleNumber?
    var proteins100: FlexibleNumber?
    var carbs100: FlexibleNumber?
    var fat100: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case energyKcal100 = "energy-kcal_100g"
        case energy100 = "energy_100g"
        case proteins100 = "proteins_100g"
        case carbs100 = "carbohydrates_100g"
        case fat100 = "fat_100g"
    }
}

/// OFFItemDTO mirrors one search/product payload.
struct OFFItemDTO: Decodable, Sendable {
    var code: String?
    var productName: String?
    var genericName: String?
    var brands: String?
    var imageFrontSmallURL: String?
    var nutriments: OFFNutrimentsDTO?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case imageFrontSmallURL = "image_front_small_url"
        case nutriments
    }
}

/// OFFSearchDTO mirrors /cgi/search.pl.
struct OFFSearchDTO: Decodable, Sendable {
    var products: [OFFItemDTO]?
}

/// OFFProductDTO mirrors /api/v2/product/<code>.json.
struct OFFProductDTO: Decodable, Sendable {
    var status: Int?
    var code: String?
    var product: OFFItemDTO?
}

/// CatalogPayloadMap lifts DTOs into GlyphRecord. Used by tests.
enum CatalogPayloadMap {
    static func name(from item: OFFItemDTO) -> String? {
        let candidates = [item.productName, item.genericName, item.brands]
        for candidate in candidates {
            guard let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                continue
            }
            return text
        }
        return nil
    }

    static func record(from item: OFFItemDTO, fallbackCode: String?) -> GlyphRecord? {
        let code = (item.code?.isEmpty == false ? item.code : fallbackCode) ?? ""
        guard !code.isEmpty, let name = name(from: item) else { return nil }
        let nuts = item.nutriments
        let kcal = PortionMath.kcal100(
            energyKcal: nuts?.energyKcal100?.value,
            energyKJ: nuts?.energy100?.value
        )
        return GlyphRecord(
            barcode: code,
            name: name,
            brand: item.brands,
            per100: MacroPacket(
                kcal: kcal,
                protein: nuts?.proteins100?.value,
                carbs: nuts?.carbs100?.value,
                fat: nuts?.fat100?.value
            ),
            imagePath: item.imageFrontSmallURL,
            shelfAsset: nil,
            refreshedAt: Date()
        )
    }

    static func decodeSearch(_ data: Data) throws -> [GlyphRecord] {
        let dto = try JSONDecoder().decode(OFFSearchDTO.self, from: data)
        return (dto.products ?? []).compactMap { record(from: $0, fallbackCode: $0.code) }
    }

    static func decodeProduct(_ data: Data) throws -> GlyphRecord {
        let dto = try JSONDecoder().decode(OFFProductDTO.self, from: data)
        if dto.status == 0 { throw ProbeFault.notFound }
        guard let item = dto.product, let record = record(from: item, fallbackCode: dto.code) else {
            throw ProbeFault.notFound
        }
        return record
    }
}

/// CatalogProbe owns both Open Food Facts endpoints.
actor CatalogProbe {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 15
            config.httpAdditionalHeaders = [
                "User-Agent": "ByteBite/1.0 (iOS; +https://bytebite.pro)",
            ]
            self.session = URLSession(configuration: config)
        }
    }

    func search(terms: String) async throws -> [GlyphRecord] {
        var parts = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        parts?.queryItems = [
            URLQueryItem(name: "search_terms", value: terms),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
        ]
        guard let url = parts?.url else { throw ProbeFault.malformed }
        let data = try await fetch(url)
        do {
            return try CatalogPayloadMap.decodeSearch(data)
        } catch is CancellationError {
            throw CancellationError()
        } catch let fault as ProbeFault {
            throw fault
        } catch {
            throw ProbeFault.malformed
        }
    }

    func product(code: String) async throws -> GlyphRecord {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(encoded).json") else {
            throw ProbeFault.malformed
        }
        let data = try await fetch(url)
        do {
            return try CatalogPayloadMap.decodeProduct(data)
        } catch is CancellationError {
            throw CancellationError()
        } catch let fault as ProbeFault {
            throw fault
        } catch {
            throw ProbeFault.malformed
        }
    }

    private func fetch(_ url: URL, retry: Bool = true) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("ByteBite/1.0 (iOS; +https://bytebite.pro)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProbeFault.transport }
            if http.statusCode == 404 { throw ProbeFault.notFound }
            if (500...599).contains(http.statusCode) && retry {
                return try await fetch(url, retry: false)
            }
            guard (200...299).contains(http.statusCode) else { throw ProbeFault.transport }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let fault as ProbeFault {
            throw fault
        } catch {
            if retry { return try await fetch(url, retry: false) }
            throw ProbeFault.transport
        }
    }
}

//
//  OpenFoodFactsClient.swift
//  Solace
//

import Foundation

enum OpenFoodFactsError: Error, Equatable {
    case notFound
    case server(Int)
    case decoding
}

/// Thin client for the Open Food Facts API v3. ODbL-licensed: the app
/// attributes Open Food Facts (see Settings/About) and never mixes this data
/// with another proprietary product database.
enum OpenFoodFactsClient {
    /// Required by OFF's API policy: identifies the app + a contact so
    /// misbehaving clients can be reached, not sent anywhere else.
    static let userAgent = "Solace/1.0 (nandanvarma.me@gmail.com)"

    static func fetchProduct(barcode: String) async throws -> CachedProduct {
        var request = URLRequest(
            url: URL(string: "https://world.openfoodfacts.org/api/v3/product/\(barcode).json")!
        )
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenFoodFactsError.decoding }
        guard (200...299).contains(http.statusCode) else { throw OpenFoodFactsError.server(http.statusCode) }

        return try parse(data, barcode: barcode)
    }

    /// Exposed internally so unit tests can decode a captured fixture
    /// without a live network call.
    static func parse(_ data: Data, barcode: String) throws -> CachedProduct {
        let decoded: DTO.Response
        do {
            decoded = try JSONDecoder().decode(DTO.Response.self, from: data)
        } catch {
            throw OpenFoodFactsError.decoding
        }
        guard let product = decoded.product else { throw OpenFoodFactsError.notFound }
        return product.asCachedProduct(barcode: barcode)
    }

    // MARK: - Wire format

    enum DTO {
        struct Response: Decodable {
            let product: Product?
        }

        struct Product: Decodable {
            let productName: String?
            let brands: String?
            let nutriscoreGrade: String?
            // OFF's API returns this as a string ("2023"), not a number.
            let nutriscoreVersion: String?
            let novaGroup: Int?
            let ecoscoreGrade: String?
            let nutriments: Nutriments?
            let allergensTags: [String]?
            let ingredientsText: String?
            let ingredientsTextEN: String?
            let imageURL: String?

            enum CodingKeys: String, CodingKey {
                case productName = "product_name"
                case brands
                case nutriscoreGrade = "nutriscore_grade"
                case nutriscoreVersion = "nutriscore_version"
                case novaGroup = "nova_group"
                case ecoscoreGrade = "ecoscore_grade"
                case nutriments
                case allergensTags = "allergens_tags"
                case ingredientsText = "ingredients_text"
                case ingredientsTextEN = "ingredients_text_en"
                case imageURL = "image_url"
            }

            func asCachedProduct(barcode: String) -> CachedProduct {
                CachedProduct(
                    barcode: barcode,
                    name: productName,
                    brands: brands,
                    nutriscoreGrade: nutriscoreGrade,
                    nutriscoreVersion: nutriscoreVersion,
                    novaGroup: novaGroup,
                    greenScoreGrade: (ecoscoreGrade == "unknown" || ecoscoreGrade == "not-applicable") ? nil : ecoscoreGrade,
                    energyKcal100g: nutriments?.energyKcal100g,
                    proteins100g: nutriments?.proteins100g,
                    carbohydrates100g: nutriments?.carbohydrates100g,
                    sugars100g: nutriments?.sugars100g,
                    fat100g: nutriments?.fat100g,
                    saturatedFat100g: nutriments?.saturatedFat100g,
                    fiber100g: nutriments?.fiber100g,
                    sodium100g: nutriments?.sodium100g,
                    allergensTagsJSON: (try? String(
                        data: JSONEncoder().encode(allergensTags ?? []), encoding: .utf8
                    )) ?? "[]",
                    ingredientsText: ingredientsText?.isEmpty == false ? ingredientsText : ingredientsTextEN,
                    imageURL: imageURL,
                    fetchedAt: Date()
                )
            }
        }

        struct Nutriments: Decodable {
            let energyKcal100g: Double?
            let proteins100g: Double?
            let carbohydrates100g: Double?
            let sugars100g: Double?
            let fat100g: Double?
            let saturatedFat100g: Double?
            let fiber100g: Double?
            let sodium100g: Double?

            enum CodingKeys: String, CodingKey {
                case energyKcal100g = "energy-kcal_100g"
                case proteins100g = "proteins_100g"
                case carbohydrates100g = "carbohydrates_100g"
                case sugars100g = "sugars_100g"
                case fat100g = "fat_100g"
                case saturatedFat100g = "saturated-fat_100g"
                case fiber100g = "fiber_100g"
                case sodium100g = "sodium_100g"
            }
        }
    }
}

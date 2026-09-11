//
//  USDAClient.swift
//  Solace
//

import Foundation

enum USDAError: Error, Equatable {
    case server(Int)
    case decoding
}

/// Thin client for USDA FoodData Central. Public domain data — no
/// attribution/share-back obligation, but cited in-app anyway. Restricted to
/// Foundation/SR Legacy `dataType`s per the app's "prefer verified data"
/// principle — Branded entries are Open Food Facts' job.
enum USDAClient {
    /// USDA nutrient IDs this app cares about. FDC returns raw nutrient
    /// records, not a clean macros object — this is the mapping table the
    /// spec calls out as something you have to build yourself.
    private enum NutrientID {
        static let energyKcal = 1008
        static let protein = 1003
        static let fat = 1004
        static let carbohydrate = 1005
        static let fiber = 1079
        static let sodiumMg = 1093
    }

    private static var apiKey: String {
        KeychainStore.get(.usdaFDCAPIKey) ?? "DEMO_KEY"
    }

    static func search(query: String, pageSize: Int = 25) async throws -> [CachedGenericFood] {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy"),
            URLQueryItem(name: "api_key", value: apiKey),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { throw USDAError.decoding }
        guard (200...299).contains(http.statusCode) else { throw USDAError.server(http.statusCode) }
        return try parseSearch(data)
    }

    static func parseSearch(_ data: Data) throws -> [CachedGenericFood] {
        let decoded: SearchResponse
        do {
            decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw USDAError.decoding
        }
        return decoded.foods.map { food in
            let values = Dictionary(
                food.foodNutrients.compactMap { n -> (Int, Double)? in
                    guard let id = n.nutrientId, let value = n.value else { return nil }
                    return (id, value)
                },
                uniquingKeysWith: { a, _ in a }
            )
            return CachedGenericFood(
                fdcId: food.fdcId,
                description: food.description,
                dataType: food.dataType,
                energyKcal100g: values[NutrientID.energyKcal],
                proteins100g: values[NutrientID.protein],
                carbohydrates100g: values[NutrientID.carbohydrate],
                fat100g: values[NutrientID.fat],
                fiber100g: values[NutrientID.fiber],
                sodium100g: values[NutrientID.sodiumMg].map { $0 / 1000 },
                fetchedAt: Date()
            )
        }
    }

    static func detail(fdcId: Int) async throws -> CachedGenericFood {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/food/\(fdcId)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { throw USDAError.decoding }
        guard (200...299).contains(http.statusCode) else { throw USDAError.server(http.statusCode) }
        return try parseDetail(data)
    }

    static func parseDetail(_ data: Data) throws -> CachedGenericFood {
        let decoded: DetailResponse
        do {
            decoded = try JSONDecoder().decode(DetailResponse.self, from: data)
        } catch {
            throw USDAError.decoding
        }
        let values = Dictionary(
            decoded.foodNutrients.compactMap { n -> (Int, Double)? in
                guard let id = n.nutrient?.id, let amount = n.amount else { return nil }
                return (id, amount)
            },
            uniquingKeysWith: { a, _ in a }
        )
        return CachedGenericFood(
            fdcId: decoded.fdcId,
            description: decoded.description,
            dataType: decoded.dataType,
            energyKcal100g: values[NutrientID.energyKcal],
            proteins100g: values[NutrientID.protein],
            carbohydrates100g: values[NutrientID.carbohydrate],
            fat100g: values[NutrientID.fat],
            fiber100g: values[NutrientID.fiber],
            sodium100g: values[NutrientID.sodiumMg].map { $0 / 1000 },
            fetchedAt: Date()
        )
    }

    // MARK: - Wire format

    /// `/v1/foods/search` — flat nutrient records.
    struct SearchResponse: Decodable {
        let foods: [SearchFood]
    }

    struct SearchFood: Decodable {
        let fdcId: Int
        let description: String
        let dataType: String
        let foodNutrients: [SearchNutrient]
    }

    struct SearchNutrient: Decodable {
        let nutrientId: Int?
        let value: Double?
    }

    /// `/v1/food/{fdcId}` — nested nutrient records. Same data, different
    /// shape — the "known gotcha" the spec warns about.
    struct DetailResponse: Decodable {
        let fdcId: Int
        let description: String
        let dataType: String
        let foodNutrients: [DetailNutrient]
    }

    struct DetailNutrient: Decodable {
        let nutrient: Nutrient?
        let amount: Double?

        struct Nutrient: Decodable {
            let id: Int?
        }
    }
}

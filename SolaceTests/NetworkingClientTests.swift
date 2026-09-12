//
//  NetworkingClientTests.swift
//  SolaceTests
//
//  Decodes real, captured API responses (see Fixtures/) so the mapping
//  logic is verified without a live network call in CI.
//

import Foundation
import Testing
@testable import Solace

private final class BundleToken {}

private func fixture(_ name: String) -> Data {
    let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")!
    return try! Data(contentsOf: url)
}

struct OpenFoodFactsClientTests {
    @Test func parsesRealProductResponse() throws {
        let product = try OpenFoodFactsClient.parse(fixture("off_nutella"), barcode: "3017620422003")
        #expect(product.barcode == "3017620422003")
        #expect(product.name == "Nutella")
        #expect(product.nutriscoreGrade == "e")
        #expect(product.nutriscoreVersion == "2023")
        #expect(product.novaGroup == 4)
        #expect(product.ecoScoreGrade == nil, "ecoscore_grade is 'unknown' for this product and should map to nil")
        #expect(product.energyKcal100g == 539)
        #expect(product.proteins100g == 6.3)
        #expect(product.allergensTags.contains("en:milk"))
        #expect(product.allergensTags.contains("en:nuts"))
        #expect(product.ingredientsText?.isEmpty == false)
    }

    @Test func notFoundResponseThrows() {
        let missing = Data(#"{"status":"failure","code":"0000000000000"}"#.utf8)
        #expect(throws: OpenFoodFactsError.notFound) {
            try OpenFoodFactsClient.parse(missing, barcode: "0000000000000")
        }
    }
}

struct USDAClientTests {
    @Test func parsesRealSearchResponse() throws {
        let foods = try USDAClient.parseSearch(fixture("fdc_search_banana"))
        let banana = try #require(foods.first { $0.fdcId == 173_944 })
        #expect(banana.description == "Bananas, raw")
        #expect(banana.dataType == "SR Legacy")
        #expect(banana.energyKcal100g == 89)
        #expect(banana.proteins100g == 1.09)
        #expect(banana.fiber100g == 2.6)
        // Sodium arrives from USDA in mg and must be converted to grams to
        // match CachedProduct's sodium100g convention.
        #expect(banana.sodium100g == 0.001)
    }

    @Test func onlyFoundationAndSRLegacyAppearInResults() throws {
        let foods = try USDAClient.parseSearch(fixture("fdc_search_banana"))
        #expect(foods.allSatisfy { $0.dataType == "Foundation" || $0.dataType == "SR Legacy" })
    }
}

//
//  CloudPhotoEstimatorTests.swift
//  SolaceTests
//

import Foundation
import Testing
@testable import Solace

struct CloudPhotoEstimatorTests {
    @Test func parsesAMockedSuccessfulChatCompletion() throws {
        let json = """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"items\\": [{\\"name\\": \\"Grilled Chicken Breast\\", \\"estimatedGrams\\": 160, \\"kcal\\": 264, \\"proteinG\\": 49, \\"carbG\\": 0, \\"fatG\\": 6}], \\"confidence\\": 0.84}"
                  }
                }
              ]
            }
            """
        let result = try CloudPhotoEstimator.parse(Data(json.utf8))
        #expect(result.items.count == 1)
        #expect(result.items[0].name == "Grilled Chicken Breast")
        #expect(result.items[0].estimatedGrams == 160)
        #expect(result.confidence == 0.84)
    }

    @Test func malformedContentThrowsDecodingError() {
        let json = #"{"choices": [{"message": {"content": "not json"}}]}"#
        #expect(throws: CloudPhotoEstimatorError.decoding) {
            try CloudPhotoEstimator.parse(Data(json.utf8))
        }
    }

    @Test func emptyItemsThrowsDecodingError() {
        let json = #"{"choices": [{"message": {"content": "{\"items\": [], \"confidence\": 0.5}"}}]}"#
        #expect(throws: CloudPhotoEstimatorError.decoding) {
            try CloudPhotoEstimator.parse(Data(json.utf8))
        }
    }

    @Test func perGramRescalingKeepsRatesConstant() {
        var item = PhotoEstimateItem(name: "Rice", estimatedGrams: 100, kcal: 130, proteinG: 2.7, carbG: 28, fatG: 0.3)
        let rate = item.perGram
        item.estimatedGrams = 200
        item.kcal = rate.kcal * 200
        #expect(item.kcal == 260)
    }
}

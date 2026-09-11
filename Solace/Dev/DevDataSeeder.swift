//
//  DevDataSeeder.swift
//  Solace
//
//  Debug-only developer tools — compiled out of Release builds entirely via
//  #if DEBUG, so none of this ships to users.
//

#if DEBUG

import Dependencies
import Foundation
import SQLiteData

enum DevDataSeeder {
    /// Populates a default profile (if unset) plus a handful of cached
    /// products/foods and a week of diary entries, so Today/Trends/Search
    /// have real-looking data to develop against without manually scanning
    /// or waiting on network calls.
    static func seedSampleData() async throws {
        @Dependency(\.defaultDatabase) var database

        var profile = try await UserProfileRepository.current()
        if profile.weightKg == nil {
            profile.sex = "male"
            profile.birthYear = 1996
            profile.heightCm = 178
            profile.weightKg = 75
            profile.activityLevel = "moderate"
            try await UserProfileRepository.update(profile)
        }

        let oatMilk = CachedProduct(
            barcode: "0000000000001",
            name: "Barista Oat Milk",
            brands: "Oatly",
            nutriscoreGrade: "b",
            nutriscoreVersion: "2023",
            novaGroup: 3,
            greenScoreGrade: "a",
            energyKcal100g: 59,
            proteins100g: 1.0,
            carbohydrates100g: 6.5,
            sugars100g: 4.0,
            fat100g: 3.0,
            saturatedFat100g: 0.3,
            fiber100g: 0.8,
            sodium100g: 0.04,
            allergensTagsJSON: "[]",
            ingredientsText: "Water, oats, rapeseed oil, calcium carbonate.",
            imageURL: nil,
            fetchedAt: Date()
        )
        let darkChocolate = CachedProduct(
            barcode: "0000000000002",
            name: "Dark Chocolate 85%",
            brands: "Solace Sample Co",
            nutriscoreGrade: "d",
            nutriscoreVersion: "2023",
            novaGroup: 2,
            greenScoreGrade: "b",
            energyKcal100g: 563,
            proteins100g: 7.8,
            carbohydrates100g: 30,
            sugars100g: 15,
            fat100g: 43,
            saturatedFat100g: 25,
            fiber100g: 11,
            sodium100g: 0.01,
            allergensTagsJSON: "[\"en:milk\",\"en:soybeans\"]",
            ingredientsText: "Cocoa mass, sugar, cocoa butter, soya lecithin.",
            imageURL: nil,
            fetchedAt: Date()
        )
        let banana = CachedGenericFood(
            fdcId: 173_944,
            description: "Bananas, raw",
            dataType: "SR Legacy",
            energyKcal100g: 89,
            proteins100g: 1.09,
            carbohydrates100g: 22.84,
            fat100g: 0.33,
            fiber100g: 2.6,
            sodium100g: 0.001,
            fetchedAt: Date()
        )
        let chickenBreast = CachedGenericFood(
            fdcId: 171_077,
            description: "Chicken breast, cooked, roasted",
            dataType: "SR Legacy",
            energyKcal100g: 165,
            proteins100g: 31,
            carbohydrates100g: 0,
            fat100g: 3.6,
            fiber100g: 0,
            sodium100g: 0.074,
            fetchedAt: Date()
        )

        try await database.write { db in
            try CachedProduct.upsert { oatMilk }.execute(db)
            try CachedProduct.upsert { darkChocolate }.execute(db)
            try CachedGenericFood.upsert { banana }.execute(db)
            try CachedGenericFood.upsert { chickenBreast }.execute(db)
        }

        try await DiaryRepository.logGenericFood(banana, quantityGrams: 120, mealSlot: .breakfast)
        try await DiaryRepository.logProduct(oatMilk, quantityGrams: 200, mealSlot: .breakfast)
        try await DiaryRepository.logGenericFood(chickenBreast, quantityGrams: 180, mealSlot: .lunch)
        try await DiaryRepository.logProduct(darkChocolate, quantityGrams: 30, mealSlot: .snack)

        try await seedPastDays()
    }

    /// A handful of backdated entries so the Trends chart has more than a
    /// single bar to look at.
    private static func seedPastDays() async throws {
        @Dependency(\.defaultDatabase) var database
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        try await database.write { db in
            for daysAgo in 1...6 {
                guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
                let kcal = Double.random(in: 1400...2400)
                try DiaryEntry.insert {
                    DiaryEntry(
                        id: UUID(),
                        loggedAt: day.addingTimeInterval(12 * 3600),
                        mealSlot: MealSlot.lunch.rawValue,
                        sourceKind: "genericFood",
                        sourceBarcode: nil,
                        sourceFdcId: 173_944,
                        photoEstimateLabel: nil,
                        photoEstimateConfidence: nil,
                        quantityGrams: 200,
                        energyKcal: kcal,
                        proteinsG: kcal * 0.15 / 4,
                        carbohydratesG: kcal * 0.5 / 4,
                        fatG: kcal * 0.35 / 9,
                        healthKitSampleUUID: nil
                    )
                }
                .execute(db)
            }
        }
    }

    /// Deletes every row in every table and clears both Keychain
    /// credentials, resetting the app to a fresh-install-like state.
    static func wipeAllData() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try DiaryEntry.delete().execute(db)
            try CachedProduct.delete().execute(db)
            try CachedGenericFood.delete().execute(db)
            try UserProfile.delete().execute(db)
            try AIProviderSettings.delete().execute(db)
        }
        KeychainStore.set(nil, for: .aiProviderAPIKey)
        KeychainStore.set(nil, for: .usdaFDCAPIKey)
    }
}

#endif

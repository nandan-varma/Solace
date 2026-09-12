//
//  ProductRepository.swift
//  Solace
//

import Dependencies
import Foundation
import SQLiteData

/// Cache-on-scan, per Section 4: a barcode already in `CachedProduct` is
/// returned without a network call; otherwise it's fetched from Open Food
/// Facts and persisted for next time.
enum ProductRepository {
    static func product(forBarcode barcode: String) async throws -> CachedProduct {
        @Dependency(\.defaultDatabase) var database
        if let cached = try await database.read({ db in
            try CachedProduct.find(barcode).fetchOne(db)
        }) {
            return cached
        }
        let fetched = try await OpenFoodFactsClient.fetchProduct(barcode: barcode)
        try await database.write { db in
            try CachedProduct.upsert { fetched }.execute(db)
        }
        return fetched
    }
}

/// Verified-first generic food search (Section 1): always resolves against
/// USDA, cached locally by `fdcId`.
enum GenericFoodRepository {
    static func search(query: String) async throws -> [CachedGenericFood] {
        @Dependency(\.defaultDatabase) var database
        let results = try await USDAClient.search(query: query)
        try await database.write { db in
            for food in results {
                try CachedGenericFood.upsert { food }.execute(db)
            }
        }
        return results
    }

    /// Cache-miss re-fetch for a `DiaryEntry` that references an `fdcId` this
    /// device never cached locally (e.g. after CloudKit sync from another
    /// device) — used so diary rows resolve real names instead of a
    /// permanent placeholder.
    static func food(forFdcId fdcId: Int) async throws -> CachedGenericFood {
        @Dependency(\.defaultDatabase) var database
        if let cached = try await database.read({ db in
            try CachedGenericFood.find(fdcId).fetchOne(db)
        }) {
            return cached
        }
        let fetched = try await USDAClient.detail(fdcId: fdcId)
        try await database.write { db in
            try CachedGenericFood.upsert { fetched }.execute(db)
        }
        return fetched
    }
}

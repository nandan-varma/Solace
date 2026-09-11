//
//  AIProviderSettingsRepository.swift
//  Solace
//

import Dependencies
import Foundation
import SQLiteData

/// `AIProviderSettings` is a singleton row, same pattern as `UserProfile`.
/// The API key itself never passes through here — Keychain only.
enum AIProviderSettingsRepository {
    /// Fixed rather than random, same reasoning as `UserProfileRepository`'s
    /// singleton id — avoids duplicate rows from concurrent first-run inserts.
    private static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static func current() async throws -> AIProviderSettings {
        @Dependency(\.defaultDatabase) var database
        if let existing = try await database.read({ db in try AIProviderSettings.fetchOne(db) }) {
            return existing
        }
        let created = AIProviderSettings(id: singletonID)
        try await database.write { db in
            try AIProviderSettings.insert { created }.execute(db)
        }
        return created
    }

    static func update(_ settings: AIProviderSettings) async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try AIProviderSettings.upsert { settings }.execute(db)
        }
    }
}

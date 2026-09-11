//
//  UserProfileRepository.swift
//  Solace
//

import Dependencies
import Foundation
import SQLiteData

/// `UserProfile` is a singleton row (Section 3). This creates it on first
/// access with every field left blank, matching the spec's "any blank field
/// means dependent features degrade gracefully" contract.
enum UserProfileRepository {
    /// Fixed rather than random so two devices racing on first launch insert
    /// the *same* row (deduped locally by the primary key's `ON CONFLICT
    /// REPLACE`, and by CloudKit as the same record) instead of each
    /// creating its own profile that never reconciles.
    private static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static func current() async throws -> UserProfile {
        @Dependency(\.defaultDatabase) var database
        if let existing = try await database.read({ db in try UserProfile.fetchOne(db) }) {
            return existing
        }
        let created = UserProfile(id: singletonID)
        try await database.write { db in
            try UserProfile.insert { created }.execute(db)
        }
        return created
    }

    static func update(_ profile: UserProfile) async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try UserProfile.upsert { profile }.execute(db)
        }
    }
}

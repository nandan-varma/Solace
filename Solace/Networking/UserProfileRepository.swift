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
    static func current() async throws -> UserProfile {
        @Dependency(\.defaultDatabase) var database
        if let existing = try await database.read({ db in try UserProfile.fetchOne(db) }) {
            return existing
        }
        let created = UserProfile(id: UUID())
        try await database.write { db in
            try UserProfile.insert { created }.execute(db)
        }
        return created
    }
}

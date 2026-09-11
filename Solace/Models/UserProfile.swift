//
//  UserProfile.swift
//  Solace
//

import Foundation
import SQLiteData

/// Singleton row (one per iCloud account, synced via CloudKit). Any blank
/// field simply means dependent features (targets, safety checks) degrade
/// gracefully rather than block core logging.
@Table("userProfiles")
nonisolated struct UserProfile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var sex: String?
    var birthYear: Int?
    var heightCm: Double?
    var weightKg: Double?
    var activityLevel: String?              // "sedentary" | "light" | "moderate" | "active" | "veryActive"
    var dailyCalorieTargetOverride: Int?
    var allergenExclusionsJSON: String = "[]"
    var dietaryFlagsJSON: String = "[]"      // vegan, vegetarian, halal, kosher, glutenFree...
    var nutriScoreWeight: Double = 0.40
    var novaWeight: Double = 0.25
    var greenScoreWeight: Double = 0.15
    var personalGoalWeight: Double = 0.20
    var healthKitSyncEnabled: Bool = false
    var onDeviceAIEnabled: Bool = true

    var allergenExclusions: [String] {
        get { Self.decodeList(allergenExclusionsJSON) }
        set { allergenExclusionsJSON = Self.encodeList(newValue) }
    }

    var dietaryFlags: [String] {
        get { Self.decodeList(dietaryFlagsJSON) }
        set { dietaryFlagsJSON = Self.encodeList(newValue) }
    }

    static func decodeList(_ json: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }

    static func encodeList(_ list: [String]) -> String {
        (try? String(data: JSONEncoder().encode(list), encoding: .utf8)) ?? "[]"
    }
}

//
//  AIProviderSettings.swift
//  Solace
//

import Foundation
import SQLiteData

/// Singleton row (synced via CloudKit) for the opt-in BYOK cloud AI tier.
/// The API key itself is never stored here — Keychain only, see
/// `KeychainStore`, so it never syncs and never lands in the SQLite file.
@Table("aiProviderSettings")
nonisolated struct AIProviderSettings: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var isEnabled: Bool = false
    var baseURL: String = "https://api.openai.com/v1"
    var modelString: String = ""
}

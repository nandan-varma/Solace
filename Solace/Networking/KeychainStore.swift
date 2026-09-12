//
//  KeychainStore.swift
//  Solace
//

import Foundation
import OSLog
import Security

nonisolated private let logger = Logger(subsystem: "com.nandanvarma.Solace", category: "Keychain")

/// Generic Keychain-only credential storage. Used for the BYOK cloud AI key
/// and the USDA FDC key — neither ever touches SQLite, UserDefaults, or a
/// log statement.
enum KeychainStore {
    enum Key: String {
        case aiProviderAPIKey = "com.nandanvarma.Solace.aiProviderAPIKey"
        case usdaFDCAPIKey = "com.nandanvarma.Solace.usdaFDCAPIKey"
    }

    static func set(_ value: String?, for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            logger.error("SecItemDelete failed for \(key.rawValue, privacy: .public): \(deleteStatus)")
        }

        guard let value, !value.isEmpty else { return }
        var addQuery = query
        addQuery[kSecValueData as String] = Data(value.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("SecItemAdd failed for \(key.rawValue, privacy: .public): \(addStatus)")
        }
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }
}

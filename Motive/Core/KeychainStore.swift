//
//  KeychainStore.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation
import Security

/// Unified Keychain storage that stores all secrets in a single item
/// This ensures only ONE authorization prompt is needed for all API keys
enum KeychainStore {
    
    // MARK: - Unified Storage (Single Keychain Item)
    
    /// The single account name used for all secrets
    private static let unifiedAccount = "secrets"
    
    /// Read a value from the unified keychain storage
    static func read(service: String, account: String) -> String? {
        let allSecrets = readAllSecrets(service: service)
        return allSecrets[account]
    }
    
    /// Write a value to the unified keychain storage
    static func write(service: String, account: String, value: String) {
        var allSecrets = readAllSecrets(service: service)
        allSecrets[account] = value
        writeAllSecrets(service: service, secrets: allSecrets)
    }
    
    /// Delete a value from the unified keychain storage
    static func delete(service: String, account: String) {
        var allSecrets = readAllSecrets(service: service)
        allSecrets.removeValue(forKey: account)
        if allSecrets.isEmpty {
            deleteUnifiedItem(service: service)
        } else {
            writeAllSecrets(service: service, secrets: allSecrets)
        }
    }
    
    /// Delete all secrets for this service
    static func deleteAll(service: String) {
        deleteUnifiedItem(service: service)
    }
    
    // MARK: - Private Implementation
    
    /// Read all secrets from the single keychain item
    private static func readAllSecrets(service: String) -> [String: String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: unifiedAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let secrets = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        
        return secrets
    }
    
    /// Write all secrets to the single keychain item
    private static func writeAllSecrets(service: String, secrets: [String: String]) {
        guard let data = try? JSONEncoder().encode(secrets) else {
            return
        }
        
        // Delete existing item first
        deleteUnifiedItem(service: service)
        
        // Create new item with ACL
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: unifiedAccount,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to create ACL that allows current app without prompts
        if let access = createAccessForCurrentApp(label: "\(service).secrets") {
            query[kSecAttrAccess] = access
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Fallback: try without custom ACL
            query.removeValue(forKey: kSecAttrAccess)
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    /// Delete the unified keychain item
    private static func deleteUnifiedItem(service: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: unifiedAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    /// Create a SecAccess that trusts the current application
    private static func createAccessForCurrentApp(label: String) -> SecAccess? {
        let appPath = Bundle.main.bundlePath
        
        var trustedApp: SecTrustedApplication?
        var status = SecTrustedApplicationCreateFromPath(appPath, &trustedApp)
        
        if status != errSecSuccess {
            status = SecTrustedApplicationCreateFromPath(nil, &trustedApp)
        }
        
        guard status == errSecSuccess, let app = trustedApp else {
            return nil
        }
        
        var access: SecAccess?
        let trustedApps = [app] as CFArray
        status = SecAccessCreate(label as CFString, trustedApps, &access)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return access
    }
    
    // MARK: - Migration
    
    /// Migrate from old per-account storage to unified storage
    /// Call this once during app startup to consolidate old keychain items
    static func migrateToUnifiedStorage(service: String, accounts: [String]) {
        var secrets: [String: String] = [:]
        var hasLegacyItems = false
        
        // Read from legacy per-account items
        for account in accounts {
            if let value = readLegacyItem(service: service, account: account), !value.isEmpty {
                secrets[account] = value
                hasLegacyItems = true
            }
        }
        
        // If we found legacy items, migrate them
        if hasLegacyItems {
            // Merge with any existing unified secrets
            let existing = readAllSecrets(service: service)
            for (key, value) in existing {
                if secrets[key] == nil {
                    secrets[key] = value
                }
            }
            
            // Write to unified storage
            writeAllSecrets(service: service, secrets: secrets)
            
            // Delete legacy items
            for account in accounts {
                deleteLegacyItem(service: service, account: account)
            }
            
            Log.debug("Migrated \(secrets.count) secrets to unified Keychain storage")
        }
    }
    
    /// Read from legacy per-account keychain item
    private static func readLegacyItem(service: String, account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Delete legacy per-account keychain item
    private static func deleteLegacyItem(service: String, account: String) {
        // Don't delete the unified account
        guard account != unifiedAccount else { return }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

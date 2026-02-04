//
//  FileOperationPolicy.swift
//  Motive
//
//  Fine-grained file operation control with configurable policies.
//

import Foundation

// MARK: - File Operation Types

/// Granular classification of file operations
/// Used across the app for permission requests and policy evaluation
enum FileOperation: String, CaseIterable, Codable, Hashable, Sendable {
    case create      // Create a new file
    case delete      // Delete an existing file
    case modify      // Modify file content (partial edits)
    case overwrite   // Replace entire file content
    case rename      // Rename file (same directory)
    case move        // Move file to different directory
    case readBinary  // Read binary/sensitive files
    case execute     // Execute scripts/binaries
    
    var displayName: String {
        switch self {
        case .create:     return "Create File"
        case .delete:     return "Delete File"
        case .modify:     return "Modify Content"
        case .overwrite:  return "Overwrite File"
        case .rename:     return "Rename File"
        case .move:       return "Move File"
        case .readBinary: return "Read Binary"
        case .execute:    return "Execute Script"
        }
    }
    
    var localizedName: String {
        switch self {
        case .create:     return L10n.Settings.opCreate
        case .delete:     return L10n.Settings.opDelete
        case .modify:     return L10n.Settings.opModify
        case .overwrite:  return L10n.Settings.opOverwrite
        case .rename:     return L10n.Settings.opRename
        case .move:       return L10n.Settings.opMove
        case .readBinary: return L10n.Settings.opReadBinary
        case .execute:    return L10n.Settings.opExecute
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .create:     return L10n.Settings.opCreateDesc
        case .delete:     return L10n.Settings.opDeleteDesc
        case .modify:     return L10n.Settings.opModifyDesc
        case .overwrite:  return L10n.Settings.opOverwriteDesc
        case .rename:     return L10n.Settings.opRenameDesc
        case .move:       return L10n.Settings.opMoveDesc
        case .readBinary: return L10n.Settings.opReadBinaryDesc
        case .execute:    return L10n.Settings.opExecuteDesc
        }
    }
    
    var riskLevel: RiskLevel {
        switch self {
        case .create, .modify:
            return .low
        case .rename, .move, .readBinary:
            return .medium
        case .overwrite, .execute:
            return .high
        case .delete:
            return .critical
        }
    }
    
    var systemSymbol: String {
        switch self {
        case .create:     return "doc.badge.plus"
        case .delete:     return "trash"
        case .modify:     return "pencil"
        case .overwrite:  return "arrow.triangle.2.circlepath"
        case .rename:     return "character.cursor.ibeam"
        case .move:       return "folder.badge.arrow.up"
        case .readBinary: return "lock.doc"
        case .execute:    return "terminal"
        }
    }
}

/// Risk levels for file operations
enum RiskLevel: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .low:      return "Low"
        case .medium:   return "Medium"
        case .high:     return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .low:      return "green"
        case .medium:   return "yellow"
        case .high:     return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Permission Policy

/// Policy for how to handle permission requests
enum PermissionPolicy: String, Codable {
    case alwaysAllow    // Auto-approve without asking
    case alwaysAsk      // Always prompt user
    case askOnce        // Ask once per session, remember choice
    case alwaysDeny     // Auto-deny without asking
    
    var displayName: String {
        switch self {
        case .alwaysAllow: return "Always Allow"
        case .alwaysAsk:   return "Always Ask"
        case .askOnce:     return "Ask Once"
        case .alwaysDeny:  return "Always Deny"
        }
    }
    
    var localizedName: String {
        switch self {
        case .alwaysAllow: return L10n.Settings.policyAlwaysAllow
        case .alwaysAsk:   return L10n.Settings.policyAlwaysAsk
        case .askOnce:     return L10n.Settings.policyAskOnce
        case .alwaysDeny:  return L10n.Settings.policyAlwaysDeny
        }
    }
}

// MARK: - Path Rules

/// Rules for specific paths or patterns
struct PathRule: Codable, Identifiable {
    let id: UUID
    let pattern: String        // Glob pattern or exact path
    let operations: Set<FileOperation>
    let policy: PermissionPolicy
    let description: String?
    
    init(pattern: String, operations: Set<FileOperation>, policy: PermissionPolicy, description: String? = nil) {
        self.id = UUID()
        self.pattern = pattern
        self.operations = operations
        self.policy = policy
        self.description = description
    }
    
    /// Check if this rule matches a given path
    func matches(path: String) -> Bool {
        if pattern.contains("*") {
            return matchGlob(pattern: pattern, path: path)
        }
        return path.hasPrefix(pattern) || path == pattern
    }
    
    private func matchGlob(pattern: String, path: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "**", with: "§§")
            .replacingOccurrences(of: "*", with: "[^/]*")
            .replacingOccurrences(of: "§§", with: ".*")
        
        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$") else {
            return false
        }
        
        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}

// MARK: - File Operation Policy Manager

/// Manages file operation policies and permission decisions
@MainActor
final class FileOperationPolicy {
    static let shared = FileOperationPolicy()
    
    /// UserDefaults key for storing operation policies
    private static let policiesKey = "fileOperationPolicies"
    
    /// Default policies for each operation type (used when no saved policy exists)
    private static let defaultPolicies: [FileOperation: PermissionPolicy] = [
        .create:     .alwaysAsk,
        .delete:     .alwaysAsk,
        .modify:     .alwaysAsk,
        .overwrite:  .alwaysAsk,
        .rename:     .alwaysAsk,
        .move:       .alwaysAsk,
        .readBinary: .alwaysAllow,
        .execute:    .alwaysAsk
    ]
    
    /// Current policies for each operation type (persisted)
    private var operationPolicies: [FileOperation: PermissionPolicy]
    
    /// Path-specific rules (evaluated in order)
    private var pathRules: [PathRule] = []
    
    /// Session-level remembered decisions (for askOnce policy)
    private var sessionDecisions: [String: Bool] = [:]
    
    private init() {
        // Load saved policies or use defaults
        operationPolicies = Self.loadPolicies()
        setupDefaultRules()
    }
    
    // MARK: - Persistence
    
    /// Load policies from UserDefaults
    private static func loadPolicies() -> [FileOperation: PermissionPolicy] {
        guard let data = UserDefaults.standard.data(forKey: policiesKey),
              let saved = try? JSONDecoder().decode([String: String].self, from: data) else {
            return defaultPolicies
        }
        
        var policies = defaultPolicies
        for (opRaw, policyRaw) in saved {
            if let operation = FileOperation(rawValue: opRaw),
               let policy = PermissionPolicy(rawValue: policyRaw) {
                policies[operation] = policy
            }
        }
        return policies
    }
    
    /// Save policies to UserDefaults
    private func savePolicies() {
        var dict: [String: String] = [:]
        for (operation, policy) in operationPolicies {
            dict[operation.rawValue] = policy.rawValue
        }
        
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.policiesKey)
        }
    }
    
    /// Reset all policies to defaults
    func resetToDefaults() {
        operationPolicies = Self.defaultPolicies
        savePolicies()
    }
    
    // MARK: - Configuration
    
    /// Setup sensible default path rules
    private func setupDefaultRules() {
        pathRules = [
            // Always protect system directories
            PathRule(
                pattern: "/System/**",
                operations: Set(FileOperation.allCases),
                policy: .alwaysDeny,
                description: "System files are protected"
            ),
            PathRule(
                pattern: "/usr/**",
                operations: [.delete, .overwrite, .modify],
                policy: .alwaysDeny,
                description: "System binaries are protected"
            ),
            PathRule(
                pattern: "/private/**",
                operations: [.delete, .overwrite],
                policy: .alwaysDeny,
                description: "System private directories are protected"
            ),
            
            // Protect sensitive user data
            PathRule(
                pattern: "~/.ssh/**",
                operations: [.delete, .overwrite, .modify],
                policy: .alwaysAsk,
                description: "SSH keys require explicit permission"
            ),
            PathRule(
                pattern: "~/.gnupg/**",
                operations: [.delete, .overwrite, .modify],
                policy: .alwaysAsk,
                description: "GPG keys require explicit permission"
            ),
            PathRule(
                pattern: "**/.env*",
                operations: [.delete, .overwrite, .modify],
                policy: .alwaysAsk,
                description: "Environment files may contain secrets"
            ),
            
            // Common safe operations
            PathRule(
                pattern: "/tmp/**",
                operations: [.create, .modify, .delete],
                policy: .alwaysAllow,
                description: "Temp files can be freely managed"
            ),
            PathRule(
                pattern: "~/Downloads/**",
                operations: [.create, .rename, .move],
                policy: .alwaysAllow,
                description: "Downloads folder allows organization"
            ),
            
            // Project-specific (within working directory)
            PathRule(
                pattern: "**/node_modules/**",
                operations: [.create, .modify, .delete],
                policy: .alwaysAllow,
                description: "Package dependencies"
            ),
            PathRule(
                pattern: "**/.git/**",
                operations: [.delete, .overwrite],
                policy: .alwaysAsk,
                description: "Git objects require explicit permission"
            )
        ]
    }
    
    // MARK: - Policy Evaluation
    
    /// Get the applicable policy for an operation on a path
    func policy(for operation: FileOperation, path: String) -> PermissionPolicy {
        let expandedPath = expandPath(path)
        
        // Check path rules first (in order)
        for rule in pathRules {
            if rule.matches(path: expandedPath) && rule.operations.contains(operation) {
                return rule.policy
            }
        }
        
        // Fall back to operation default
        return operationPolicies[operation] ?? .alwaysAsk
    }
    
    /// Determine if permission should be requested
    /// Returns: (shouldAsk: Bool, defaultAllow: Bool?)
    func shouldRequestPermission(for operation: FileOperation, path: String) -> (shouldAsk: Bool, defaultAllow: Bool?) {
        let policy = policy(for: operation, path: path)
        
        switch policy {
        case .alwaysAllow:
            return (false, true)
        case .alwaysDeny:
            return (false, false)
        case .askOnce:
            let key = "\(operation.rawValue):\(path)"
            if let remembered = sessionDecisions[key] {
                return (false, remembered)
            }
            return (true, nil)
        case .alwaysAsk:
            return (true, nil)
        }
    }
    
    /// Record a session decision (for askOnce policy)
    func recordDecision(for operation: FileOperation, path: String, allowed: Bool) {
        let key = "\(operation.rawValue):\(path)"
        sessionDecisions[key] = allowed
    }
    
    /// Clear session decisions (call on new session)
    func clearSessionDecisions() {
        sessionDecisions.removeAll()
    }
    
    // MARK: - Rule Management
    
    /// Add a custom path rule
    func addRule(_ rule: PathRule) {
        pathRules.insert(rule, at: 0)  // Custom rules take precedence
    }
    
    /// Remove a rule by ID
    func removeRule(id: UUID) {
        pathRules.removeAll { $0.id == id }
    }
    
    /// Update the default policy for an operation
    func setDefaultPolicy(_ policy: PermissionPolicy, for operation: FileOperation) {
        operationPolicies[operation] = policy
        savePolicies()
    }
    
    // MARK: - Helpers
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return (path as NSString).expandingTildeInPath
        }
        return path
    }
    
    /// Generate a human-readable summary of why permission is needed
    func permissionReason(for operation: FileOperation, path: String) -> String {
        let expandedPath = expandPath(path)
        
        for rule in pathRules {
            if rule.matches(path: expandedPath) && rule.operations.contains(operation) {
                if let desc = rule.description {
                    return desc
                }
            }
        }
        
        switch operation.riskLevel {
        case .critical:
            return "This is a potentially destructive operation"
        case .high:
            return "This operation could cause data loss"
        case .medium:
            return "This operation modifies file organization"
        case .low:
            return "Standard file operation"
        }
    }
}


//
//  SkillTypes.swift
//  Motive
//
//  Core data models for OpenClaw-style skills.
//

import Foundation

enum SkillSource: String, Codable, Sendable {
    case bundled
    case managed
    case workspace
    case extra
}

struct SkillFrontmatter: Codable, Equatable, Sendable {
    var name: String = ""
    var description: String = ""
    var metadataRaw: String?
    // Official AgentSkills spec fields
    var license: String?
    var compatibility: String?
    var allowedTools: [String]?
}

struct SkillRequirements: Codable, Equatable, Sendable {
    var bins: [String] = []
    var anyBins: [String] = []
    var env: [String] = []
    var config: [String] = []
}

struct SkillMetadata: Codable, Equatable, Sendable {
    var always: Bool = false
    var os: [String] = []
    var primaryEnv: String?
    var emoji: String?
    var homepage: String?
    var requires: SkillRequirements?
    var skillKey: String?
    var install: [SkillInstallSpec]?
    
    /// Override default enabled state for bundled skills.
    /// - `true`: Skill is enabled by default (system skills)
    /// - `false`: Skill is disabled by default (optional bundled skills)
    /// - `nil`: Use source-based defaults (bundled=enabled, managed=disabled)
    var defaultEnabled: Bool?
}

// MARK: - Install Spec (OpenClaw compatible)

enum InstallKind: String, Codable, Equatable, Sendable {
    case brew
    case node
    case go
    case uv
    case apt
    case download
}

struct SkillInstallSpec: Codable, Equatable, Sendable {
    var id: String?
    var kind: InstallKind
    var label: String?
    var bins: [String]?
    var os: [String]?
    
    // Kind-specific fields
    var formula: String?      // brew
    var package: String?      // node, uv, apt
    var module: String?       // go
    var url: String?          // download
    var archive: String?      // download (tar.gz, tar.bz2, zip)
    var extract: Bool?        // download
    var stripComponents: Int? // download
    var targetDir: String?    // download
}

enum SkillWiring: Equatable, Sendable {
    case mcp(SkillMcpSpec)
    case bin(SkillToolSpec)
    case none
}

struct SkillMcpSpec: Codable, Equatable, Sendable {
    var type: String?
    var command: [String]
    var environment: [String: String] = [:]
    var timeoutMs: Int?
    var enabled: Bool?
}

struct SkillToolSpec: Codable, Equatable, Sendable {
    var command: String
    var args: [String] = []
}

struct SkillEligibility: Equatable, Sendable {
    var isEligible: Bool
    var reasons: [String]
}

struct SkillEntry: Equatable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var description: String
    var filePath: String
    var source: SkillSource
    var frontmatter: SkillFrontmatter
    var metadata: SkillMetadata?
    var wiring: SkillWiring
    var eligibility: SkillEligibility
}

// MARK: - Config

struct SkillsConfig: Codable, Equatable, Sendable {
    var load: SkillsLoadConfig = .init()
    var allowBundled: [String] = []
    var entries: [String: SkillEntryConfig] = [:]
}

struct SkillsLoadConfig: Codable, Equatable, Sendable {
    var extraDirs: [String] = []
    var watch: Bool = true
    var watchDebounceMs: Int = 250
}

struct SkillEntryConfig: Codable, Equatable, Sendable {
    var enabled: Bool?
    var env: [String: String] = [:]
    var apiKey: String?
    var config: [String: String] = [:]
}

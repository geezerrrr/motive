//
//  MigrationTests.swift
//  MotiveTests
//
//  Tests for workspace migration from Application Support to ~/.motive/
//

import Foundation
import Testing
@testable import Motive

@Suite("Migration")
@MainActor
struct MigrationTests {
    
    // MARK: - needsMigration Tests
    
    @Test func needsMigrationReturnsFalseForFreshInstall() async throws {
        try await withTempDirectories { workspace, appSupport in
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            // No legacy config exists, no new config exists
            #expect(manager.needsMigration() == false)
        }
    }
    
    @Test func needsMigrationReturnsTrueWithLegacyConfig() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create legacy config
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            let legacyConfig = legacyConfigDir.appendingPathComponent("opencode.json")
            try "{}".write(to: legacyConfig, atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            #expect(manager.needsMigration() == true)
        }
    }
    
    @Test func needsMigrationReturnsFalseWhenNewConfigExists() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create both legacy and new config
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let newConfigDir = workspace.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: newConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: newConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            #expect(manager.needsMigration() == false)
        }
    }
    
    @Test func needsMigrationReturnsFalseAfterMigration() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create legacy config
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            #expect(manager.needsMigration() == false)
        }
    }
    
    // MARK: - performMigration Tests
    
    @Test func migrationMovesConfigDirectory() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Setup legacy structure
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            let legacyConfig = legacyConfigDir.appendingPathComponent("opencode.json")
            try "{\"test\": true}".write(to: legacyConfig, atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            // Verify moved
            let newConfig = workspace.appendingPathComponent("config/opencode.json")
            #expect(FileManager.default.fileExists(atPath: newConfig.path))
            #expect(!FileManager.default.fileExists(atPath: legacyConfig.path))
            
            // Verify content preserved
            let content = try String(contentsOf: newConfig)
            #expect(content.contains("test"))
        }
    }
    
    @Test func migrationMergesSkillsDirectory() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create existing skill in workspace
            let workspaceSkillDir = workspace.appendingPathComponent("skills/existing")
            try FileManager.default.createDirectory(at: workspaceSkillDir, withIntermediateDirectories: true)
            try "existing".write(to: workspaceSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            
            // Create skill in legacy location
            let legacySkillDir = appSupport.appendingPathComponent("skills/legacy")
            try FileManager.default.createDirectory(at: legacySkillDir, withIntermediateDirectories: true)
            try "legacy".write(to: legacySkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            
            // Create legacy config to enable migration
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            // Both skills should exist in workspace
            #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("skills/existing/SKILL.md").path))
            #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("skills/legacy/SKILL.md").path))
        }
    }
    
    @Test func migrationMovesMcpDirectory() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create MCP in legacy location
            let legacyMcp = appSupport.appendingPathComponent("mcp")
            try FileManager.default.createDirectory(at: legacyMcp, withIntermediateDirectories: true)
            try "server config".write(to: legacyMcp.appendingPathComponent("servers.json"), atomically: true, encoding: .utf8)
            
            // Create legacy config to enable migration
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            // MCP should be in workspace
            #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("mcp/servers.json").path))
            #expect(!FileManager.default.fileExists(atPath: legacyMcp.appendingPathComponent("servers.json").path))
        }
    }
    
    @Test func migrationCreatesBootstrapFiles() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create legacy config to trigger migration
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            // Bootstrap files should be created
            #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("SOUL.md").path))
            #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("IDENTITY.md").path))
            #expect(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("USER.md").path))
        }
    }
    
    @Test func migrationDoesNotOverwriteExistingBootstrapFiles() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create existing SOUL.md in workspace
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            let customSoul = "# Custom Soul"
            try customSoul.write(to: workspace.appendingPathComponent("SOUL.md"), atomically: true, encoding: .utf8)
            
            // Create legacy config to trigger migration
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            // Custom SOUL.md should be preserved
            let content = try String(contentsOf: workspace.appendingPathComponent("SOUL.md"))
            #expect(content == customSoul)
        }
    }
    
    @Test func migrationCreatesRuntimeDirectory() async throws {
        try await withTempDirectories { workspace, appSupport in
            // Create node_modules in legacy location
            let legacyNodeModules = appSupport.appendingPathComponent("node_modules")
            try FileManager.default.createDirectory(at: legacyNodeModules, withIntermediateDirectories: true)
            try "package".write(to: legacyNodeModules.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
            
            // Create legacy config to enable migration
            let legacyConfigDir = appSupport.appendingPathComponent("config")
            try FileManager.default.createDirectory(at: legacyConfigDir, withIntermediateDirectories: true)
            try "{}".write(to: legacyConfigDir.appendingPathComponent("opencode.json"), atomically: true, encoding: .utf8)
            
            let manager = WorkspaceManager(workspaceURL: workspace, appSupportURL: appSupport)
            try await manager.performMigration()
            
            // Runtime directory should be created
            let runtimeDir = appSupport.appendingPathComponent("runtime")
            #expect(FileManager.default.fileExists(atPath: runtimeDir.path))
        }
    }
}

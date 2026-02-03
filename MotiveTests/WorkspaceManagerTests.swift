//
//  WorkspaceManagerTests.swift
//  MotiveTests
//
//  Tests for WorkspaceManager workspace and migration functionality.
//

import Foundation
import Testing
@testable import Motive

@Suite("WorkspaceManager")
@MainActor
struct WorkspaceManagerTests {
    
    // MARK: - URL Tests
    
    @Test func defaultWorkspaceURLPointsToMotive() {
        let url = WorkspaceManager.defaultWorkspaceURL
        #expect(url.lastPathComponent == ".motive")
        #expect(url.path.contains(FileManager.default.homeDirectoryForCurrentUser.path))
    }
    
    @Test func defaultAppSupportURLPointsToMotive() {
        let url = WorkspaceManager.defaultAppSupportURL
        #expect(url != nil)
        #expect(url?.lastPathComponent == "Motive")
    }
    
    // MARK: - Bootstrap Tests
    
    @Test func ensureWorkspaceCreatesDirectory() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            try await manager.ensureWorkspace()
            
            #expect(FileManager.default.fileExists(atPath: tempURL.path))
        }
    }
    
    @Test func ensureWorkspaceCreatesSubdirectories() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            try await manager.ensureWorkspace()
            
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("config").path))
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("skills").path))
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("mcp").path))
        }
    }
    
    @Test func ensureWorkspaceCreatesBootstrapFiles() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            try await manager.ensureWorkspace()
            
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("SOUL.md").path))
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("IDENTITY.md").path))
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("USER.md").path))
            #expect(FileManager.default.fileExists(atPath: tempURL.appendingPathComponent("AGENTS.md").path))
        }
    }
    
    @Test func ensureWorkspaceDoesNotOverwriteExistingFiles() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            
            // Create workspace directory first
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            
            // Create custom SOUL.md
            let customContent = "# My Custom Soul"
            try customContent.write(to: tempURL.appendingPathComponent("SOUL.md"), atomically: true, encoding: .utf8)
            
            // Run bootstrap
            try await manager.ensureWorkspace()
            
            // Verify not overwritten
            let content = try String(contentsOf: tempURL.appendingPathComponent("SOUL.md"))
            #expect(content == customContent)
        }
    }
    
    // MARK: - Load Bootstrap Files Tests
    
    @Test func loadBootstrapFilesReturnsAllPersonaFiles() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            try await manager.ensureWorkspace()
            
            let files = manager.loadBootstrapFiles()
            let names = files.map { $0.name }
            
            #expect(names.contains("SOUL.md"))
            #expect(names.contains("USER.md"))
            #expect(names.contains("AGENTS.md"))
        }
    }
    
    @Test func loadBootstrapFilesIncludesContent() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            try await manager.ensureWorkspace()
            
            let files = manager.loadBootstrapFiles()
            let soulFile = files.first { $0.name == "SOUL.md" }
            
            #expect(soulFile != nil)
            #expect(soulFile?.content.contains("Core Truths") == true)
        }
    }
    
    // MARK: - Load Identity Tests
    
    @Test func loadIdentityReturnsNilWhenNoFile() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            // Don't create any files
            
            let identity = manager.loadIdentity()
            #expect(identity == nil)
        }
    }
    
    @Test func loadIdentityParsesValidFile() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            
            // Create directory and identity file
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            try createTestIdentityFile(at: tempURL.appendingPathComponent("IDENTITY.md"))
            
            let identity = manager.loadIdentity()
            
            #expect(identity != nil)
            #expect(identity?.name == "TestBot")
            #expect(identity?.emoji == "🤖")
        }
    }
    
    @Test func loadIdentityReturnsNilForEmptyIdentity() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            
            // Create directory and empty identity file
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            try createTestIdentityFile(at: tempURL.appendingPathComponent("IDENTITY.md"), name: nil, emoji: nil, creature: nil, vibe: nil)
            
            let identity = manager.loadIdentity()
            
            // Should return nil because no values are set
            #expect(identity == nil)
        }
    }
    
    // MARK: - Needs Bootstrap Tests
    
    @Test func needsBootstrapReturnsTrueForEmptyDirectory() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            #expect(manager.needsBootstrap() == true)
        }
    }
    
    @Test func needsBootstrapReturnsFalseAfterBootstrap() async throws {
        try await withTempWorkspace { tempURL in
            let manager = WorkspaceManager(workspaceURL: tempURL)
            try await manager.ensureWorkspace()
            
            #expect(manager.needsBootstrap() == false)
        }
    }
}

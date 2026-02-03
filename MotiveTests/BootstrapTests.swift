//
//  BootstrapTests.swift
//  MotiveTests
//
//  Tests for workspace bootstrap templates and fallback content.
//

import Foundation
import Testing
@testable import Motive

@Suite("Bootstrap")
@MainActor
struct BootstrapTests {
    
    // MARK: - Fallback Template Tests
    
    @Test func fallbackTemplatesProvideContent() {
        let templates = ["SOUL.md", "IDENTITY.md", "USER.md", "AGENTS.md", "BOOTSTRAP.md"]
        for name in templates {
            let content = FallbackTemplates.content(for: name)
            #expect(!content.isEmpty, "Fallback for \(name) should not be empty")
        }
    }
    
    @Test func fallbackForUnknownFileIsEmpty() {
        let content = FallbackTemplates.content(for: "UNKNOWN.md")
        #expect(content.isEmpty)
    }
    
    @Test func soulTemplateContainsCoreElements() {
        let content = FallbackTemplates.content(for: "SOUL.md")
        #expect(content.contains("Core Truths"))
        #expect(content.contains("Boundaries"))
        #expect(content.contains("helpful"))
    }
    
    @Test func soulTemplateContainsVibeSection() {
        let content = FallbackTemplates.content(for: "SOUL.md")
        #expect(content.contains("Vibe"))
    }
    
    @Test func soulTemplateContainsContinuitySection() {
        let content = FallbackTemplates.content(for: "SOUL.md")
        #expect(content.contains("Continuity"))
    }
    
    @Test func identityTemplateHasRequiredFields() {
        let content = FallbackTemplates.content(for: "IDENTITY.md")
        #expect(content.contains("Name"))
        #expect(content.contains("Emoji"))
        #expect(content.contains("Creature"))
        #expect(content.contains("Vibe"))
    }
    
    @Test func identityTemplateIsMarkdownList() {
        let content = FallbackTemplates.content(for: "IDENTITY.md")
        #expect(content.contains("- **Name:**"))
    }
    
    @Test func userTemplateHasRequiredFields() {
        let content = FallbackTemplates.content(for: "USER.md")
        #expect(content.contains("Name"))
        #expect(content.contains("Timezone"))
        #expect(content.contains("Context"))
    }
    
    @Test func agentsTemplateHasGuidelines() {
        let content = FallbackTemplates.content(for: "AGENTS.md")
        #expect(content.contains("Guidelines"))
        #expect(content.contains("concise"))
    }
    
    @Test func bootstrapTemplateExplainsFiles() {
        let content = FallbackTemplates.content(for: "BOOTSTRAP.md")
        #expect(content.contains("SOUL.md"))
        #expect(content.contains("IDENTITY.md"))
        #expect(content.contains("USER.md"))
        #expect(content.contains("Getting Started"))
    }
    
    // MARK: - Bootstrap File Names Tests
    
    @Test func bootstrapFilesListContainsAllFiles() {
        let files = WorkspaceManager.bootstrapFiles
        #expect(files.contains("SOUL.md"))
        #expect(files.contains("IDENTITY.md"))
        #expect(files.contains("USER.md"))
        #expect(files.contains("AGENTS.md"))
        #expect(files.contains("BOOTSTRAP.md"))
    }
    
    @Test func personaFilesExcludesBootstrap() {
        let files = WorkspaceManager.personaFiles
        #expect(files.contains("SOUL.md"))
        #expect(files.contains("IDENTITY.md"))
        #expect(files.contains("USER.md"))
        #expect(files.contains("AGENTS.md"))
        #expect(!files.contains("BOOTSTRAP.md"))
    }
    
    // MARK: - BootstrapFile Struct Tests
    
    @Test func bootstrapFileHoldsContent() {
        let file = BootstrapFile(
            name: "TEST.md",
            content: "Test content",
            url: URL(fileURLWithPath: "/tmp/TEST.md")
        )
        
        #expect(file.name == "TEST.md")
        #expect(file.content == "Test content")
        #expect(file.url.lastPathComponent == "TEST.md")
    }
}

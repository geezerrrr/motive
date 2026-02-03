//
//  TestHelpers.swift
//  MotiveTests
//
//  Shared test utilities for workspace and file system testing.
//

import Foundation
@testable import Motive

// MARK: - Temporary Directory Helpers

/// Execute test with a temporary directory that is cleaned up after
func withTempDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("MotiveTests")
        .appendingPathComponent(UUID().uuidString)
    
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    return try body(tempDir)
}

/// Execute async test with a temporary directory that is cleaned up after
func withTempDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("MotiveTests")
        .appendingPathComponent(UUID().uuidString)
    
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    return try await body(tempDir)
}

/// Execute test with a temporary workspace directory
func withTempWorkspace<T>(_ body: (URL) async throws -> T) async throws -> T {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("MotiveTests")
        .appendingPathComponent(UUID().uuidString)
    
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    return try await body(tempDir)
}

/// Execute test with temporary workspace and app support directories
func withTempDirectories<T>(_ body: (URL, URL) async throws -> T) async throws -> T {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("MotiveTests")
        .appendingPathComponent(UUID().uuidString)
    
    let workspace = base.appendingPathComponent("workspace")
    let appSupport = base.appendingPathComponent("appsupport")
    
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    
    defer {
        try? FileManager.default.removeItem(at: base)
    }
    
    return try await body(workspace, appSupport)
}

// MARK: - Test Data Helpers

/// Create a test IDENTITY.md file with sample content
func createTestIdentityFile(at url: URL, name: String? = "TestBot", emoji: String? = "🤖", creature: String? = "test assistant", vibe: String? = "helpful") throws {
    var lines: [String] = ["# IDENTITY.md"]
    lines.append("")
    
    if let name = name {
        lines.append("- **Name:** \(name)")
    } else {
        lines.append("- **Name:** ")
    }
    
    if let emoji = emoji {
        lines.append("- **Emoji:** \(emoji)")
    } else {
        lines.append("- **Emoji:** ")
    }
    
    if let creature = creature {
        lines.append("- **Creature:** \(creature)")
    } else {
        lines.append("- **Creature:** ")
    }
    
    if let vibe = vibe {
        lines.append("- **Vibe:** \(vibe)")
    } else {
        lines.append("- **Vibe:** ")
    }
    
    let content = lines.joined(separator: "\n")
    try content.write(to: url, atomically: true, encoding: .utf8)
}

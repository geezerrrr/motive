//
//  PTYProcessTests.swift
//  MotiveTests
//
//  Tests for PTYProcess management.
//

import Testing
@testable import Motive

@Suite("PTYProcess")
struct PTYProcessTests {
    
    // MARK: - Initialization
    
    @Test("creates PTY process instance")
    func createInstance() {
        let pty = PTYProcess()
        #expect(pty.pid == 0)
        #expect(pty.isRunning == false)
    }
    
    // MARK: - Spawn
    
    @Test("spawns echo command successfully")
    func spawnEchoCommand() async throws {
        let pty = PTYProcess()
        
        try pty.spawn(
            executablePath: "/bin/echo",
            arguments: ["hello"],
            environment: [:],
            currentDirectory: "/tmp"
        )
        
        #expect(pty.pid > 0)
        
        // Wait for completion
        let exitCode = pty.waitForExit()
        #expect(exitCode == 0)
        
        pty.cleanup()
    }
    
    @Test("captures output from command")
    func captureOutput() async throws {
        let pty = PTYProcess()
        
        try pty.spawn(
            executablePath: "/bin/echo",
            arguments: ["test output"],
            environment: [:],
            currentDirectory: "/tmp"
        )
        
        var lines: [String] = []
        for try await line in try pty.getLines() {
            lines.append(line)
            if lines.count >= 1 { break }
        }
        
        #expect(lines.first?.contains("test output") == true)
        
        _ = pty.waitForExit()
        pty.cleanup()
    }
    
    // MARK: - Error Handling
    
    @Test("throws when getting lines before spawn")
    func throwsBeforeSpawn() {
        let pty = PTYProcess()
        
        #expect(throws: PTYError.notSpawned) {
            _ = try pty.getLines()
        }
    }
    
    @Test("handles non-existent executable")
    func handleNonExistentExecutable() async throws {
        let pty = PTYProcess()
        
        // Spawning a non-existent path should succeed (fork succeeds)
        // but the child process will fail with exit code 127
        try pty.spawn(
            executablePath: "/nonexistent/path",
            arguments: [],
            environment: [:],
            currentDirectory: "/tmp"
        )
        
        let exitCode = pty.waitForExit()
        #expect(exitCode == 127)
        
        pty.cleanup()
    }
    
    // MARK: - Process Control
    
    @Test("terminates running process")
    func terminateProcess() async throws {
        let pty = PTYProcess()
        
        // Start a long-running process
        try pty.spawn(
            executablePath: "/bin/sleep",
            arguments: ["10"],
            environment: [:],
            currentDirectory: "/tmp"
        )
        
        #expect(pty.isRunning == true)
        
        // Terminate it
        pty.terminate()
        
        let exitCode = pty.waitForExit()
        // SIGTERM causes exit code 128 + 15 = 143
        #expect(exitCode == 143 || exitCode == 15)
        
        pty.cleanup()
    }
    
    @Test("interrupts running process")
    func interruptProcess() async throws {
        let pty = PTYProcess()
        
        // Start a long-running process
        try pty.spawn(
            executablePath: "/bin/sleep",
            arguments: ["10"],
            environment: [:],
            currentDirectory: "/tmp"
        )
        
        #expect(pty.isRunning == true)
        
        // Interrupt it (like Ctrl+C)
        pty.interrupt()
        
        let exitCode = pty.waitForExit()
        // SIGINT causes exit code 128 + 2 = 130
        #expect(exitCode == 130 || exitCode == 2)
        
        pty.cleanup()
    }
    
    // MARK: - Cleanup
    
    @Test("cleanup is idempotent")
    func cleanupIdempotent() {
        let pty = PTYProcess()
        
        // Multiple cleanups should not crash
        pty.cleanup()
        pty.cleanup()
        pty.cleanup()
        
        #expect(pty.isRunning == false)
    }
}

//
//  PTYProcess.swift
//  Motive
//
//  Runs a process in a pseudo-terminal to get unbuffered stdout
//

import Foundation
import Darwin

/// Errors that can occur during PTY process operations
enum PTYError: Error, LocalizedError {
    case notSpawned
    case spawnFailed(errno: Int32)
    case alreadyRunning
    
    var errorDescription: String? {
        switch self {
        case .notSpawned:
            return "PTY process has not been spawned"
        case .spawnFailed(let errno):
            return "Failed to spawn PTY process: \(String(cString: strerror(errno)))"
        case .alreadyRunning:
            return "PTY process is already running"
        }
    }
}

final class PTYProcess: @unchecked Sendable {
    private var masterFd: Int32 = -1
    private(set) var pid: pid_t = 0
    private var fileHandle: FileHandle?
    
    var isRunning: Bool {
        guard pid > 0 else { return false }
        var status: Int32 = 0
        return waitpid(pid, &status, WNOHANG) == 0
    }
    
    /// Spawn process in PTY
    func spawn(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: String
    ) throws {
        var winSize = winsize(ws_row: 30, ws_col: 200, ws_xpixel: 0, ws_ypixel: 0)
        
        pid = forkpty(&masterFd, nil, nil, &winSize)
        
        if pid < 0 {
            throw NSError(domain: "PTYProcess", code: Int(errno),
                         userInfo: [NSLocalizedDescriptionKey: "forkpty failed: \(String(cString: strerror(errno)))"])
        }
        
        if pid == 0 {
            // Child process
            _ = chdir(currentDirectory)
            
            // Set environment (including TERM from caller)
            for (key, value) in environment {
                setenv(key, value, 1)
            }
            // Only set TERM if not already in environment
            if environment["TERM"] == nil {
                setenv("TERM", "dumb", 1)
            }
            
            // Build argv
            var cArgs = [strdup(executablePath)]
            for arg in arguments {
                cArgs.append(strdup(arg))
            }
            cArgs.append(nil)
            
            execvp(executablePath, &cArgs)
            _exit(127)
        }
        
        // Parent - create FileHandle for reading
        fileHandle = FileHandle(fileDescriptor: masterFd, closeOnDealloc: false)
    }
    
    /// Get async line sequence from PTY output
    /// - Throws: PTYError.notSpawned if spawn() has not been called
    func getLines() throws -> AsyncLineSequence<FileHandle.AsyncBytes> {
        guard let fh = fileHandle else {
            throw PTYError.notSpawned
        }
        return fh.bytes.lines
    }
    
    /// Get async line sequence from PTY output (legacy computed property for compatibility)
    /// Note: Prefer using getLines() which properly throws errors
    var lines: AsyncLineSequence<FileHandle.AsyncBytes> {
        get throws {
            try getLines()
        }
    }
    
    /// Write string to PTY stdin
    func write(_ string: String) {
        guard masterFd >= 0, let data = string.data(using: .utf8) else { return }
        data.withUnsafeBytes { buffer in
            _ = Darwin.write(masterFd, buffer.baseAddress, buffer.count)
        }
    }
    
    /// Write string with newline to PTY stdin
    func writeLine(_ string: String) {
        write(string + "\n")
    }
    
    /// Send interrupt signal (Ctrl+C)
    func interrupt() {
        guard pid > 0 else { return }
        kill(pid, SIGINT)
    }
    
    /// Terminate process
    func terminate() {
        guard pid > 0 else { return }
        kill(pid, SIGTERM)
    }
    
    /// Wait for process to exit and return status
    func waitForExit() -> Int32 {
        guard pid > 0 else { return -1 }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        
        // WIFEXITED: (status & 0x7f) == 0
        // WEXITSTATUS: (status >> 8) & 0xff
        // WIFSIGNALED: ((status & 0x7f) + 1) >> 1 > 0
        // WTERMSIG: status & 0x7f
        if (status & 0x7f) == 0 {
            // Normal exit
            return (status >> 8) & 0xff
        } else if ((status & 0x7f) + 1) >> 1 > 0 {
            // Killed by signal
            return 128 + (status & 0x7f)
        }
        return -1
    }
    
    /// Cleanup
    func cleanup() {
        if masterFd >= 0 {
            close(masterFd)
            masterFd = -1
        }
        fileHandle = nil
    }
    
    deinit {
        cleanup()
    }
}

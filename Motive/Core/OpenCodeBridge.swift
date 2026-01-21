//
//  OpenCodeBridge.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation

actor OpenCodeBridge {
    struct Configuration: Sendable {
        let binaryURL: URL
        let environment: [String: String]
        let model: String?  // e.g., "openai/gpt-4o" or "anthropic/claude-sonnet-4-5-20250929"
        let debugMode: Bool
    }

    private var configuration: Configuration?
    private var ptyProcess: PTYProcess?
    private var currentSessionId: String?
    private var readerTask: Task<Void, Never>?
    private let eventHandler: @Sendable (OpenCodeEvent) async -> Void

    init(eventHandler: @escaping @Sendable (OpenCodeEvent) async -> Void) {
        self.eventHandler = eventHandler
    }

    func updateConfiguration(_ configuration: Configuration) {
        self.configuration = configuration
    }

    func startIfNeeded() async {
        // No longer need to pre-start - process starts per task
    }

    func restart() async {
        await stop()
    }

    func stop() async {
        readerTask?.cancel()
        readerTask = nil

        if let pty = ptyProcess, pty.isRunning {
            pty.terminate()
        }
        ptyProcess?.cleanup()
        ptyProcess = nil
    }

    /// Interrupt the current process (like Ctrl+C)
    func interrupt() async {
        guard let pty = ptyProcess, pty.isRunning else { return }
        pty.interrupt()
        Log.bridge("Sent SIGINT to OpenCode process (PID: \(pty.pid))")
    }
    
    /// Send a response to OpenCode via PTY stdin (for AskUserQuestion responses)
    func sendResponse(_ response: String) {
        guard let pty = ptyProcess, pty.isRunning else {
            Log.bridge("Cannot send response: PTY not running")
            return
        }
        Log.bridge("Sending response to OpenCode: \(response)")
        pty.writeLine(response)
    }
    
    /// Get the current OpenCode session ID
    func getSessionId() -> String? {
        return currentSessionId
    }
    
    /// Set the session ID (for switching sessions)
    func setSessionId(_ sessionId: String?) {
        currentSessionId = sessionId
        Log.bridge("Session ID set to: \(sessionId ?? "nil")")
    }
    
    /// Resume an existing session with a new message
    func resumeSession(sessionId: String, text: String, cwd: String) async {
        // Set the session ID before starting
        currentSessionId = sessionId
        await submitIntent(text: text, cwd: cwd)
    }

    /// Submit an intent (run a task)
    /// This starts a new OpenCode process for each task
    func submitIntent(text: String, cwd: String) async {
        guard let configuration else {
            await eventHandler(
                OpenCodeEvent(
                    kind: .unknown,
                    rawJson: "",
                    text: "OpenCode not configured"
                )
            )
            return
        }
        
        // Stop any existing process
        await stop()
        
        // Build command: opencode run "message" --format json [--model provider/model] [--session sessionId]
        let binaryPath = configuration.binaryURL.path
        var args = ["run", text, "--format", "json"]
        
        if configuration.debugMode {
            args.append(contentsOf: ["--print-logs", "--log-level", "DEBUG"])
        }
        
        // Add model if specified
        if let model = configuration.model, !model.isEmpty {
            args.append(contentsOf: ["--model", model])
        }
        
        // Continue session if we have one
        if let sessionId = currentSessionId {
            args.append(contentsOf: ["--session", sessionId])
        }
        
        Log.bridge("Running OpenCode via PTY: \(binaryPath) \(args.prefix(3).joined(separator: " "))...")
        
        let safeCwd = FileManager.default.temporaryDirectory.path
        Log.bridge("Using working directory: \(safeCwd)")
        
        let pty = PTYProcess()
        do {
            try pty.spawn(
                executablePath: binaryPath,
                arguments: args,
                environment: configuration.environment,
                currentDirectory: safeCwd
            )
            Log.bridge("OpenCode PTY process started with PID: \(pty.pid)")
        } catch {
            await eventHandler(
                OpenCodeEvent(
                    kind: .unknown,
                    rawJson: "",
                    text: "OpenCode failed to launch: \(error.localizedDescription)"
                )
            )
            return
        }
        
        self.ptyProcess = pty
        
        // Read PTY output for JSON messages
        readerTask = Task {
            Log.bridge("Starting PTY reader task...")
            await readPTYLines(pty: pty)
            Log.bridge("PTY reader task finished")
            
            // Handle termination
            let exitCode = pty.waitForExit()
            await handleTermination(exitCode: exitCode)
        }
    }
    
    private func readPTYLines(pty: PTYProcess) async {
        do {
            for try await line in pty.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip empty lines and terminal decorations
                guard !trimmed.isEmpty else { continue }
                guard !isTerminalDecoration(trimmed) else { continue }
                
                // Only process JSON lines
                guard trimmed.hasPrefix("{") else {
                    Log.bridge("[pty] Non-JSON: \(trimmed.prefix(80))")
                    continue
                }
                
                Log.bridge("[pty] JSON: \(trimmed.prefix(200))")
                
                let event = OpenCodeEvent(rawJson: trimmed)
                
                // Capture session ID for follow-ups
                if let sessionId = event.sessionId, currentSessionId == nil {
                    currentSessionId = sessionId
                    Log.bridge("Captured session ID: \(sessionId)")
                }
                
                await eventHandler(event)
            }
        } catch {
            if !Task.isCancelled {
                Log.bridge("[pty] stream error: \(error.localizedDescription)")
            }
        }
    }

    private func handleTermination(exitCode: Int32) async {
        Log.bridge("OpenCode process terminated with code: \(exitCode)")
        
        readerTask?.cancel()
        readerTask = nil
        ptyProcess?.cleanup()
        ptyProcess = nil
        
        // Send finish event
        if exitCode == 0 || exitCode == 130 { // 130 = interrupted (SIGINT)
            await eventHandler(
                OpenCodeEvent(
                    kind: .finish,
                    rawJson: "",
                    text: "Task completed"
                )
            )
        } else {
            await eventHandler(
                OpenCodeEvent(
                    kind: .finish,
                    rawJson: "",
                    text: "Task completed with exit code: \(exitCode)"
                )
            )
        }
    }
    
    /// Check if a line is terminal UI decoration (not JSON)
    private func isTerminalDecoration(_ line: String) -> Bool {
        // Box-drawing and UI characters used by the CLI's interactive prompts
        let terminalChars: [Character] = ["│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "─", "◆", "●", "○", "◇", "▄", "█", "▀"]
        
        if let firstChar = line.first, terminalChars.contains(firstChar) {
            return true
        }
        
        // Skip ANSI escape sequences
        if line.hasPrefix("\u{1B}[") || line.hasPrefix("[0m") {
            return true
        }
        
        // Skip "Commands:" help text
        if line.hasPrefix("Commands:") || line.contains("opencode") && line.contains("start") {
            return true
        }
        
        return false
    }
}

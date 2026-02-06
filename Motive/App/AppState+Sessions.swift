//
//  AppState+Sessions.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

extension AppState {
    func submitIntent(_ text: String) {
        submitIntent(text, workingDirectory: nil)
    }

    func submitIntent(_ text: String, workingDirectory: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check provider configuration
        if let configError = configManager.providerConfigurationError {
            lastErrorMessage = configError
            // Update CloudKit if this is a remote command
            if let commandId = currentRemoteCommandId {
                cloudKitManager.failCommand(commandId: commandId, error: configError)
                currentRemoteCommandId = nil
            }
            return
        }

        lastErrorMessage = nil
        // Immediately update status bar so user sees feedback
        menuBarState = .executing
        sessionStatus = .running
        updateStatusBar()
        // Don't hide CommandBar - it will switch to running mode
        // Only ESC or focus loss should hide it
        startNewSession(intent: trimmed)

        // Add user message to conversation
        let userMessage = ConversationMessage(
            type: .user,
            content: trimmed
        )
        messages.append(userMessage)

        // Use provided working directory or configured project directory
        let cwd = workingDirectory ?? configManager.currentProjectURL.path
        Task { await bridge.submitIntent(text: trimmed, cwd: cwd) }
    }

    func sendFollowUp(_ text: String) {
        // Use resumeSession to continue the current session properly
        resumeSession(with: text)
    }

    /// Interrupt the current running session (like Ctrl+C)
    func interruptSession() {
        guard sessionStatus == .running else { return }

        Task {
            await bridge.interrupt()
        }

        sessionStatus = .interrupted
        menuBarState = .idle
        currentToolName = nil

        // Mark all running tool messages as completed (interrupted)
        for i in messages.indices {
            if messages[i].type == .tool && messages[i].status == .running {
                messages[i] = ConversationMessage(
                    id: messages[i].id,
                    type: .tool,
                    content: messages[i].content,
                    timestamp: messages[i].timestamp,
                    toolName: messages[i].toolName,
                    toolInput: messages[i].toolInput,
                    toolOutput: messages[i].toolOutput,
                    toolCallId: messages[i].toolCallId,
                    status: .failed
                )
            }
        }

        // Add system message
        let systemMessage = ConversationMessage(
            type: .system,
            content: "Session interrupted by user"
        )
        messages.append(systemMessage)
    }

    /// Get all sessions sorted by date (newest first)
    func getAllSessions() -> [Session] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Seed recent projects list from stored sessions
    func seedRecentProjectsFromSessions() {
        let sessions = getAllSessions()
        for session in sessions {
            if !session.projectPath.isEmpty {
                configManager.recordRecentProject(session.projectPath)
            }
        }
    }

    /// Switch to a different session
    func switchToSession(_ session: Session) {
        currentSession = session
        sessionStatus = SessionStatus(rawValue: session.status) ?? .completed

        // Sync OpenCodeBridge session ID
        Task { await bridge.setSessionId(session.openCodeSessionId) }

        // Ensure project directory matches the session's original cwd
        if !session.projectPath.isEmpty {
            let defaultPath = ConfigManager.defaultProjectDirectory.path
            if session.projectPath == defaultPath {
                _ = configManager.setProjectDirectory(nil)
            } else {
                _ = configManager.setProjectDirectory(session.projectPath)
            }
        }

        // Rebuild messages from logs
        messages = []

        // Add the initial user intent
        let userMessage = ConversationMessage(
            type: .user,
            content: session.intent,
            timestamp: session.createdAt
        )
        messages.append(userMessage)

        // Replay messages from logs with proper lifecycle handling
        for log in session.logs {
            let event = OpenCodeEvent(rawJson: log.rawJson)

            // Handle TodoWrite during replay
            if event.kind == .tool, let toolName = event.toolName, toolName.isTodoWriteTool {
                let todoItems = parseTodoItemsForReplay(from: event)
                if !todoItems.isEmpty {
                    let summary = "\(todoItems.filter { $0.status == .completed }.count)/\(todoItems.count) tasks completed"
                    if let existingIndex = messages.lastIndex(where: { $0.type == .todo }) {
                        messages[existingIndex] = ConversationMessage(
                            id: messages[existingIndex].id,
                            type: .todo,
                            content: summary,
                            timestamp: messages[existingIndex].timestamp,
                            status: .completed,
                            todoItems: todoItems
                        )
                    } else {
                        messages.append(ConversationMessage(
                            type: .todo,
                            content: summary,
                            status: .completed,
                            todoItems: todoItems
                        ))
                    }
                    continue
                }
            }

            guard let message = event.toMessage() else { continue }

            // Skip redundant completion messages during replay
            if message.type == .system {
                let content = message.content.lowercased()
                let isCompletion = content == "completed" || content == "session idle"
                    || content == "task completed" || content.hasPrefix("task completed with exit code")
                if isCompletion {
                    let alreadyHas = messages.contains { $0.type == .system && $0.content.lowercased() == "completed" }
                    if alreadyHas { continue }
                    // Keep only "Completed", skip the rest
                    if content != "completed" { continue }
                }
            }

            // During replay, all tool messages are completed (historical)
            // Merge by toolCallId to avoid duplicates from separate tool_call + tool_result events
            if message.type == .tool {
                let replayMessage = ConversationMessage(
                    id: message.id,
                    type: .tool,
                    content: message.content,
                    timestamp: message.timestamp,
                    toolName: message.toolName,
                    toolInput: message.toolInput,
                    toolOutput: message.toolOutput,
                    toolCallId: message.toolCallId,
                    status: .completed
                )
                // Merge with existing tool message by toolCallId
                if let callId = replayMessage.toolCallId,
                   let existingIndex = messages.lastIndex(where: { $0.type == .tool && $0.toolCallId == callId }) {
                    let existing = messages[existingIndex]
                    messages[existingIndex] = ConversationMessage(
                        id: existing.id,
                        type: .tool,
                        content: existing.content.isEmpty ? replayMessage.content : existing.content,
                        timestamp: existing.timestamp,
                        toolName: existing.toolName ?? replayMessage.toolName,
                        toolInput: existing.toolInput ?? replayMessage.toolInput,
                        toolOutput: existing.toolOutput ?? replayMessage.toolOutput,
                        toolCallId: callId,
                        status: .completed
                    )
                } else {
                    messages.append(replayMessage)
                }
            } else {
                messages.append(message)
            }
        }
        // @Observable handles change tracking automatically
    }

    /// Start a new empty session (for "New Chat" button)
    func startNewEmptySession() {
        currentSession = nil
        messages = []
        sessionStatus = .idle
        menuBarState = .idle
        currentToolName = nil

        // Clear OpenCodeBridge session ID for fresh start
        Task { await bridge.setSessionId(nil) }
        // @Observable handles change tracking automatically
    }

    /// Clear current session messages without deleting
    func clearCurrentSession() {
        messages = []
        currentSession = nil
        sessionStatus = .idle
        menuBarState = .idle
        currentToolName = nil

        Task { await bridge.setSessionId(nil) }
        // @Observable handles change tracking automatically
    }

    /// Delete a session from storage
    func deleteSession(_ session: Session) {
        guard let modelContext else { return }

        // If deleting current session, clear it first
        if currentSession?.id == session.id {
            clearCurrentSession()
        }

        modelContext.delete(session)
        try? modelContext.save()
        
        // Trigger list refresh so CommandBarView updates
        sessionListRefreshTrigger += 1
        // @Observable handles change tracking automatically
    }

    /// Delete a session by id (robust against stale references)
    func deleteSession(id: UUID) {
        guard let modelContext else { return }

        if currentSession?.id == id {
            clearCurrentSession()
        }

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.id == id }
        )
        if let session = try? modelContext.fetch(descriptor).first {
            modelContext.delete(session)
            try? modelContext.save()
            
            // Trigger list refresh so CommandBarView updates
            sessionListRefreshTrigger += 1
            // @Observable handles change tracking automatically
        }
    }

    /// Switch to a different project directory
    /// This clears the current session to avoid context confusion
    /// - Parameter path: The directory path, or nil to use default ~/.motive
    /// - Returns: true if the directory was set successfully
    @discardableResult
    func switchProjectDirectory(_ path: String?) -> Bool {
        // Clear current session first to avoid mixing contexts
        if sessionStatus == .running {
            interruptSession()
        }
        clearCurrentSession()

        // Set the new directory
        let success = configManager.setProjectDirectory(path)
        // @Observable handles change tracking automatically

        return success
    }

    /// Open a folder picker dialog to select project directory
    func showProjectPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory"
        panel.prompt = "Select"

        // Hide command bar during picker
        hideCommandBar()

        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = panel.url {
                self.switchProjectDirectory(url.path)
            }
            // Reshow command bar after picker closes
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                self.showCommandBar()
            }
        }
    }

    /// Resume a session with a follow-up message
    func resumeSession(with text: String) {
        guard let session = currentSession,
              let openCodeSessionId = session.openCodeSessionId else {
            // No session to resume, start a new one
            submitIntent(text)
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        sessionStatus = .running
        menuBarState = .executing
        session.status = "running"

        // Add user message
        let userMessage = ConversationMessage(
            type: .user,
            content: trimmed
        )
        messages.append(userMessage)

        // Use the project directory that this session was created with
        let cwd = session.projectPath.isEmpty ? configManager.currentProjectURL.path : session.projectPath
        Task { await bridge.resumeSession(sessionId: openCodeSessionId, text: trimmed, cwd: cwd) }
    }

    /// Parse todo items during session replay (simplified version for historical data)
    private func parseTodoItemsForReplay(from event: OpenCodeEvent) -> [TodoItem] {
        if let inputDict = event.toolInputDict,
           let todosArray = inputDict["todos"] as? [[String: Any]] {
            return todosArray.compactMap { TodoItem(from: $0) }
        }
        guard let data = event.rawJson.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let part = object["part"] as? [String: Any] else {
            return []
        }
        // Try tool_call format
        if let input = part["input"] as? [String: Any],
           let todosArray = input["todos"] as? [[String: Any]] {
            return todosArray.compactMap { TodoItem(from: $0) }
        }
        // Try tool_use format
        if let state = part["state"] as? [String: Any],
           let input = state["input"] as? [String: Any],
           let todosArray = input["todos"] as? [[String: Any]] {
            return todosArray.compactMap { TodoItem(from: $0) }
        }
        return []
    }

    private func startNewSession(intent: String) {
        messages = []
        menuBarState = .executing
        sessionStatus = .running
        currentToolName = nil

        // Clear OpenCodeBridge session ID for fresh start
        Task { await bridge.setSessionId(nil) }

        let sessionProjectPath = configManager.currentProjectURL.path
        let session = Session(intent: intent, projectPath: sessionProjectPath)
        currentSession = session
        modelContext?.insert(session)
    }
}

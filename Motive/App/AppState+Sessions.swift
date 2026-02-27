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
        submitIntent(text, workingDirectory: nil, agentOverride: nil)
    }

    func submitIntent(_ text: String, workingDirectory: String?) {
        submitIntent(text, workingDirectory: workingDirectory, agentOverride: nil)
    }

    func submitIntent(_ text: String, workingDirectory: String?, agentOverride: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check provider configuration
        if let configError = configManager.providerConfigurationError {
            lastErrorMessage = configError
            return
        }

        lastErrorMessage = nil
        // Immediately update status bar so user sees feedback
        menuBarState = .executing
        transitionSessionStatus(.running)
        updateStatusBar()
        // Start UI-level session timeout
        resetSessionTimeout()
        // Don't hide CommandBar - it will switch to running mode
        // Only ESC or focus loss should hide it
        startNewSession(intent: trimmed)

        // Add user message to conversation and log it for replay
        let userMessage = ConversationMessage(
            type: .user,
            content: trimmed
        )
        messages.append(userMessage)
        logEvent(OpenCodeEvent(kind: .user, rawJson: "", text: trimmed))

        // Use provided working directory or configured project directory
        let cwd = workingDirectory ?? configManager.currentProjectURL.path
        let agent = agentOverride ?? configManager.currentAgent
        // Enqueue this Session to receive the __session_bind__ from the bridge
        if let session = currentSession {
            enqueuePendingBind(session)
        }
        let sessionCorrelationId = currentSession?.id.uuidString
        bridgeTask?.cancel()
        bridgeTask = Task {
            await bridge.submitIntent(
                text: trimmed,
                cwd: cwd,
                agent: agent,
                forceNewSession: true,
                correlationId: sessionCorrelationId
            )
        }
    }

    /// Submit a prompt from the scheduler and return the created Session if available.
    @discardableResult
    func submitScheduledIntent(
        _ text: String,
        workingDirectory: String?,
        agentOverride: String?
    ) throws -> Session {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "ScheduledTask", code: 1, userInfo: [NSLocalizedDescriptionKey: "Prompt cannot be empty."])
        }
        if let configError = configManager.providerConfigurationError {
            throw NSError(domain: "ScheduledTask", code: 2, userInfo: [NSLocalizedDescriptionKey: configError])
        }
        guard let modelContext else {
            throw NSError(domain: "ScheduledTask", code: 3, userInfo: [NSLocalizedDescriptionKey: "Model context is unavailable."])
        }

        let cwd = workingDirectory ?? configManager.currentProjectURL.path
        let agent = agentOverride ?? configManager.currentAgent
        let session = Session(intent: trimmed, projectPath: cwd)
        transitionSessionStatus(.running, for: session)

        let userMessage = ConversationMessage(type: .user, content: trimmed)
        session.messagesData = ConversationMessage.serializeMessages([userMessage])
        modelContext.insert(session)
        logEvent(OpenCodeEvent(kind: .user, rawJson: "", text: trimmed), session: session)
        enqueuePendingBind(session)
        trySaveContext()

        let correlationId = session.id.uuidString
        Task {
            await bridge.submitIntent(
                text: trimmed,
                cwd: cwd,
                agent: agent,
                forceNewSession: true,
                correlationId: correlationId
            )
        }
        return session
    }

    func sendFollowUp(_ text: String) {
        // Use resumeSession to continue the current session properly
        resumeSession(with: text)
    }

    /// Interrupt the current running session (like Ctrl+C)
    func interruptSession() {
        guard sessionStatus == .running else { return }

        bridgeTask?.cancel()
        bridgeTask = Task { await bridge.interrupt() }

        Task { await BrowserUseBridge.shared.agentCancel() }

        resetTransientState()
        transitionSessionStatus(.interrupted, for: currentSession)
        menuBarState = .idle

        // Mark all running tool messages as completed (user stopped, not a failure)
        for i in messages.indices where messages[i].type == .tool && messages[i].status == .running {
            messages[i] = messages[i].withStatus(.completed)
        }

        // Add system message
        let systemMessage = ConversationMessage(
            type: .system,
            content: L10n.Drawer.interrupted
        )
        messages.append(systemMessage)

        // Persist interrupted status and snapshot messages
        if let session = currentSession {
            session.messagesData = ConversationMessage.serializeMessages(messages)
            if let ocId = session.openCodeSessionId {
                removeSessionFromTracking(ocId)
            }
            trySaveContext()
        }

        // Immediately sync menu bar to idle (before any trailing SSE events arrive)
        updateStatusBar()
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

    /// Switch to a different session.
    /// Saves current session messages if running; loads target from buffer or messagesData.
    func switchToSession(_ session: Session) {
        // Save current session's messages if running (for background event processing)
        saveCurrentSessionToBuffer()

        // Also persist non-running session's messages (they may have changed in UI)
        if let current = currentSession,
           current.sessionStatus != .running
        {
            current.messagesData = ConversationMessage.serializeMessages(messages)
        }

        resetTransientState()
        currentSession = session
        transitionSessionStatus(session.sessionStatus)
        currentContextTokens = session.contextTokens
        resetUsageDeduplication()

        // Sync menuBarState to match the target session's status.
        // Without this, menubar stays stuck on the previous session's state (e.g. tool name "glob").
        if session.sessionStatus == .running {
            menuBarState = .executing
        } else {
            menuBarState = .idle
        }
        updateStatusBar()

        // Sync OpenCodeBridge session ID for interrupt target
        bridgeTask?.cancel()
        bridgeTask = Task { await bridge.setSessionId(session.openCodeSessionId) }

        // Restore project directory for this session
        restoreProjectDirectory(for: session)

        // Load messages: running buffer first, or persisted snapshot
        let ocId = session.openCodeSessionId
        if let ocId {
            currentPlanFilePath = sessionPlanFilePaths[ocId]
        } else {
            currentPlanFilePath = nil
        }
        if let ocId, let running = runningSessionMessages[ocId] {
            messages = running
        } else if let data = session.messagesData,
                  let saved = ConversationMessage.deserializeMessages(data)
        {
            messages = saved
        } else {
            messages = [ConversationMessage(type: .user, content: session.intent, timestamp: session.createdAt)]
        }
    }

    /// Restore the project directory to match the session's original cwd.
    private func restoreProjectDirectory(for session: Session) {
        guard !session.projectPath.isEmpty else { return }
        let defaultPath = ConfigManager.defaultProjectDirectory.path
        if session.projectPath == defaultPath {
            _ = configManager.setProjectDirectory(nil)
        } else {
            _ = configManager.setProjectDirectory(session.projectPath)
        }
    }

    /// Start a new empty session (for "New Chat" button)
    func startNewEmptySession() {
        // Save current session's messages if still running (background continues)
        saveCurrentSessionToBuffer()

        resetTransientState()
        currentSession = nil
        messages = []
        transitionSessionStatus(.idle)
        menuBarState = .idle
        currentContextTokens = nil
        currentSessionAgent = configManager.currentAgent
        currentPlanFilePath = nil
        resetUsageDeduplication()

        bridgeTask?.cancel()
        bridgeTask = Task { await bridge.setSessionId(nil) }
    }

    /// Clear current session messages without deleting
    func clearCurrentSession() {
        // Save current session's messages if still running (background continues)
        saveCurrentSessionToBuffer()

        resetTransientState()
        messages = []
        currentSession = nil
        transitionSessionStatus(.idle)
        menuBarState = .idle
        currentContextTokens = nil
        currentSessionAgent = configManager.currentAgent
        currentPlanFilePath = nil
        resetUsageDeduplication()

        bridgeTask?.cancel()
        bridgeTask = Task { await bridge.setSessionId(nil) }
    }

    /// Delete a session from storage
    func deleteSession(_ session: Session) {
        guard let modelContext else { return }

        // Clean up tracking dicts if the session is still running
        if let ocId = session.openCodeSessionId {
            removeSessionFromTracking(ocId)
        }

        // If deleting current session, clear it first
        if currentSession?.id == session.id {
            clearCurrentSession()
        }

        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            Log.error("Failed to save after deleting session: \(error)")
        }

        // Trigger list refresh so CommandBarView updates
        sessionListRefreshTrigger += 1
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
            // Clean up tracking dicts
            if let ocId = session.openCodeSessionId {
                removeSessionFromTracking(ocId)
            }
            modelContext.delete(session)
            do {
                try modelContext.save()
            } catch {
                Log.error("Failed to save after deleting session by id: \(error)")
            }

            // Trigger list refresh so CommandBarView updates
            sessionListRefreshTrigger += 1
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
        return configManager.setProjectDirectory(path)
    }

    /// Open a folder picker dialog to select project directory
    func showProjectPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory"
        panel.prompt = "Select"
        // NSOpenPanel as a sheet on non-activating KeyablePanel can fail silently.
        // Use modal presentation for reliable folder picking from /project mode.
        hideCommandBar()
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            switchProjectDirectory(url.path)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            showCommandBar()
        }
    }

    /// Resume a session with a follow-up message
    func resumeSession(with text: String) {
        resumeSession(with: text, replacingLastUserMessageID: nil)
    }

    /// Edit the latest user message in-place and regenerate this turn in the same session.
    func resumeSessionReplacingLastUserMessage(id: UUID, with text: String) {
        resumeSession(with: text, replacingLastUserMessageID: id)
    }

    private func resumeSession(with text: String, replacingLastUserMessageID: UUID?) {
        guard let session = currentSession,
              let openCodeSessionId = session.openCodeSessionId
        else {
            // No session to resume, start a new one
            submitIntent(text)
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Guard against double-submission (rapid Enter key)
        guard sessionStatus != .running else {
            Log.debug("Ignoring duplicate resumeSession (already running)")
            return
        }

        // Clear stale UI state from previous turn
        resetTransientState()

        transitionSessionStatus(.running, for: session)
        menuBarState = .executing

        if let replacingLastUserMessageID {
            guard let userIndex = messages.lastIndex(where: { $0.id == replacingLastUserMessageID && $0.type == .user }) else {
                Log.debug("Edited message target not found, falling back to append mode")
                let fallback = ConversationMessage(type: .user, content: trimmed)
                messages.append(fallback)
                logEvent(OpenCodeEvent(kind: .user, rawJson: "", text: trimmed))
                runningSessions[openCodeSessionId] = session
                runningSessionMessages[openCodeSessionId] = messages
                startSnapshotTimerIfNeeded()
                awaitingFirstResponseAfterResume = true
                let cwd = session.projectPath.isEmpty ? configManager.currentProjectURL.path : session.projectPath
                let agent = configManager.currentAgent
                bridgeTask?.cancel()
                bridgeTask = Task { await bridge.resumeSession(sessionId: openCodeSessionId, text: trimmed, cwd: cwd, agent: agent) }
                return
            }
            messages = Array(messages.prefix(userIndex + 1))
            messages[userIndex] = messages[userIndex].withContent(trimmed)
        } else {
            // Add user message first — must be in the array before snapshotting
            let userMessage = ConversationMessage(
                type: .user,
                content: trimmed
            )
            messages.append(userMessage)
        }
        logEvent(OpenCodeEvent(kind: .user, rawJson: "", text: trimmed))

        // Re-register in runningSessions for event routing
        // (finish event removes the session; we must re-add on resume)
        // Snapshot taken AFTER user message so any code reading runningSessionMessages includes it.
        runningSessions[openCodeSessionId] = session
        runningSessionMessages[openCodeSessionId] = messages
        startSnapshotTimerIfNeeded()

        // Guard against stale finish events from the previous turn
        awaitingFirstResponseAfterResume = true

        // Use the project directory that this session was created with
        let cwd = session.projectPath.isEmpty ? configManager.currentProjectURL.path : session.projectPath
        let agent = configManager.currentAgent
        bridgeTask?.cancel()
        bridgeTask = Task { await bridge.resumeSession(sessionId: openCodeSessionId, text: trimmed, cwd: cwd, agent: agent) }
    }

    private func startNewSession(intent: String) {
        // Save current running session's messages before clearing (prevents data loss)
        saveCurrentSessionToBuffer()
        resetTransientState()

        messages = []
        menuBarState = .executing
        transitionSessionStatus(.running)
        currentContextTokens = nil
        currentSessionAgent = configManager.currentAgent
        currentPlanFilePath = nil
        resetUsageDeduplication()

        // NOTE: bridge session clearing is handled atomically by forceNewSession: true in submitIntent

        let sessionProjectPath = configManager.currentProjectURL.path
        let session = Session(intent: intent, projectPath: sessionProjectPath)
        currentSession = session
        modelContext?.insert(session)
    }

    /// Get running sessions (for RunningSessionsBar, status bar, etc.)
    func getRunningSessions() -> [Session] {
        getAllSessions().filter { $0.sessionStatus == .running }
    }
}

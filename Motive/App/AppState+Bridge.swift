//
//  AppState+Bridge.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//
//  Handles OpenCode SSE events routed through OpenCodeBridge.
//  Uses native question/permission system (no MCP sidecar).
//
//  ARCHITECTURE: All sessions (foreground and background) go through
//  the SAME processEvent() method. The only difference is whether
//  transient UI state is updated. This eliminates the dual-path bug class.
//

import Combine
import Foundation
import SwiftData

extension AppState {
    func restartAgent() {
        Task {
            await configureBridge()
            await bridge.restart()
        }
    }

    func configureBridge() async {
        // Get signed binary (will auto-import and sign if needed)
        let resolution = await configManager.getSignedBinaryURL()
        guard let binaryURL = resolution.url else {
            lastErrorMessage = resolution.error ?? "OpenCode binary not found. Check Settings."
            menuBarState = .idle
            return
        }
        let config = OpenCodeBridge.Configuration(
            binaryURL: binaryURL,
            environment: configManager.makeEnvironment(),
            model: configManager.getModelString(),
            modelProviderID: configManager.provider.openCodeProviderName,
            agent: configManager.currentAgent,
            debugMode: configManager.debugMode,
            projectDirectory: configManager.currentProjectURL.path
        )
        await bridge.updateConfiguration(config)

        // Sync browser agent API configuration
        BrowserUseBridge.shared.configureAgentAPIKey(
            envName: configManager.browserAgentProvider.envKeyName,
            apiKey: configManager.browserAgentAPIKey,
            baseUrlEnvName: configManager.browserAgentProvider.baseUrlEnvName,
            baseUrl: configManager.browserAgentBaseUrl
        )
    }

    /// Reset the UI-level session timeout whenever we receive an event
    func resetSessionTimeout() {
        sessionWarningTask?.cancel()
        sessionFailTask?.cancel()

        guard sessionStatus == .running else { return }

        sessionWarningTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.sessionWarningSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Soft warning: still running with no events. Do not terminate yet.
            if sessionStatus == .running {
                let warningSeconds = Int(Self.sessionWarningSeconds)
                let message = "Still waiting for model response (\(warningSeconds)s). Request is still running."
                Log.warning("Session warning: \(message)")
                lastErrorMessage = message
            }
        }

        sessionFailTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.sessionFailSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Hard timeout: terminate state machine if still running.
            if sessionStatus == .running {
                let failSeconds = Int(Self.sessionFailSeconds)
                let sessionID = currentSession?.openCodeSessionId
                let message = """
                No response from OpenCode for \(failSeconds)s.
                Request aborted. Check model/base URL/API key and retry.
                """
                Log.warning("Session hard-timeout: forcing error for session \(sessionID ?? "nil")")
                handle(event: OpenCodeEvent(
                    kind: .error,
                    rawJson: "",
                    text: message,
                    sessionId: sessionID
                ))
            }
        }
    }

    // MARK: - Event Entry Point

    func handle(event: OpenCodeEvent) {
        // Log every event arrival for diagnostics
        Log.bridge("⬇︎ Event: kind=\(event.kind.rawValue) tool=\(event.toolName ?? "-") session=\(event.sessionId ?? "-") text=«\(event.text.prefix(60))»")

        // --- Explicit bind failure before session ID was created ---
        if event.rawJson == "__session_bind_failed__" {
            let session = findPendingSession(correlationId: event.toolCallId)
            if let session {
                let reason = event.text.isEmpty
                    ? "Task failed to start before session binding."
                    : "Task failed to start: \(event.text)"
                failUnboundSession(session, reason: reason)
            }
            return
        }

        // --- Explicit session binding from bridge ---
        if event.rawJson == "__session_bind__", let sid = event.sessionId, !sid.isEmpty {
            let sessionToBind = findPendingSession(correlationId: event.toolCallId) ?? currentSession
            if let session = sessionToBind, session.openCodeSessionId == nil {
                session.openCodeSessionId = sid
                runningSessions[sid] = session
                if currentSession?.id == session.id {
                    runningSessionMessages[sid] = messages
                } else {
                    if let data = session.messagesData,
                       let saved = ConversationMessage.deserializeMessages(data)
                    {
                        runningSessionMessages[sid] = saved
                    } else {
                        runningSessionMessages[sid] = []
                    }
                }
                startSnapshotTimerIfNeeded()
                Log.debug("Bound session ID from bridge: \(sid) to session \(session.id) (current=\(currentSession?.id == session.id))")
            }
            return
        }

        // --- Resolve target session ---
        let targetSession: Session? = if let sid = event.sessionId, !sid.isEmpty {
            if let running = runningSessions[sid] {
                running
            } else if currentSession?.openCodeSessionId == sid {
                currentSession
            } else {
                nil
            }
        } else {
            currentSession
        }

        guard let target = targetSession else {
            Log.debug("Dropping unroutable event: kind=\(event.kind.rawValue) session=\(event.sessionId ?? "nil")")
            return
        }

        // Ignore post-interrupt events for current session
        if sessionStatus == .interrupted, target.id == currentSession?.id {
            logEvent(event)
            return
        }

        // --- Route through UNIFIED processor ---
        let isCurrent = target.id == currentSession?.id
        let sid = event.sessionId ?? ""

        if isCurrent {
            resetSessionTimeout()
            // Process into live messages array (messages is messageStore.messages)
            var liveMessages = messages
            processEvent(event, for: target, into: &liveMessages, sessionId: sid, isCurrentSession: true)
            messages = liveMessages
        } else if !sid.isEmpty {
            var buffer = runningSessionMessages[sid] ?? []
            processEvent(event, for: target, into: &buffer, sessionId: sid, isCurrentSession: false)
            // Write back only if session is still tracked (finish/error removes it)
            if runningSessions[sid] != nil {
                runningSessionMessages[sid] = buffer
            }
        }

        // Keep menubar status aligned with any globally running session,
        // including when the active session is idle but background sessions are still running.
        updateStatusBar()
    }

    // MARK: - Unified Event Processor

    //
    // EVERY session (foreground or background) goes through this SINGLE method.
    // `isCurrentSession` controls ONLY transient UI state updates.
    // Message buffer operations are IDENTICAL for all sessions.

    private func processEvent(
        _ event: OpenCodeEvent,
        for session: Session,
        into buffer: inout [ConversationMessage],
        sessionId: String,
        isCurrentSession: Bool
    ) {
        // --- Agent change tracking ---
        if let agent = event.agent, !agent.isEmpty {
            if isCurrentSession { updateSessionAgent(agent) }
            // Pure agent-change carrier (empty text) — skip message processing
            if event.kind == .assistant, event.text.isEmpty {
                logEvent(event, session: session)
                return
            }
        }

        // --- Stale finish guard (current session only, after resume) ---
        if isCurrentSession, awaitingFirstResponseAfterResume {
            if event.kind == .finish {
                Log.debug("Ignoring stale finish event (awaiting first response after resume)")
                logEvent(event, session: session)
                return
            }
            if event.kind != .usage {
                awaitingFirstResponseAfterResume = false
            }
        }

        // --- Process by event kind ---
        switch event.kind {

        // ── Usage ──────────────────────────────────────────────
        case .usage:
            applyUsageUpdate(event, session: session, isCurrentSession: isCurrentSession)
            logEvent(event, session: session)
            return

        // ── Thought (transient, not stored in buffer) ─────────
        case .thought:
            if isCurrentSession {
                menuBarState = .reasoning
                currentToolName = nil
                currentToolInput = nil
                reasoningDismissTask?.cancel()
                reasoningDismissTask = nil
                if !event.text.isEmpty {
                    currentReasoningText = (currentReasoningText ?? "") + event.text
                }
            }
            logEvent(event, session: session)
            return

        // ── User messages (already in buffer from submitIntent/resumeSession) ──
        case .user:
            logEvent(event, session: session)
            return

        // ── Tool / Call ────────────────────────────────────────
        case .call, .tool:
            // UI state (current session only)
            if isCurrentSession {
                clearReasoningOnStageTransition()
                menuBarState = .executing
                currentToolName = event.toolName ?? "Processing"
                currentToolInput = event.toolInput
            }

            // Native question interception (all sessions)
            if let inputDict = event.toolInputDict,
               inputDict["_isNativeQuestion"] as? Bool == true
            {
                if let planFilePath = inputDict["_planFilePath"] as? String {
                    updatePlanFilePath(planFilePath, for: event.sessionId)
                }
                nativePromptHandler.handleNativeQuestion(inputDict: inputDict, event: event)
                logEvent(event, session: session)
                return
            }
            // Native permission interception (all sessions)
            if let inputDict = event.toolInputDict,
               inputDict["_isNativePermission"] as? Bool == true
            {
                nativePromptHandler.handleNativePermission(inputDict: inputDict, event: event)
                logEvent(event, session: session)
                return
            }
            // Named question/permission result — skip
            if let toolName = event.toolName?.lowercased(),
               toolName == "question" || toolName == "permission"
            {
                logEvent(event, session: session)
                return
            }
            // TodoWrite
            if let toolName = event.toolName, toolName.isTodoWriteTool {
                // OpenCode-compatible todo source-of-truth is the `todowrite` tool stream.
                // Plan markdown frontmatter todos are not consumed by the runtime UI.
                if event.kind == .tool {
                    messageStore.handleTodoWriteEvent(event, buffer: &buffer)
                }
                logEvent(event, session: session)
                return
            }
            // Regular tool — insert
            messageStore.insertEventIntoBuffer(event, buffer: &buffer)
            // If tool has completed but assistant output hasn't started yet,
            // switch back to "thinking" so UI doesn't look stalled.
            if isCurrentSession, event.toolOutput != nil || event.diff != nil {
                menuBarState = .reasoning
                currentToolName = nil
                currentToolInput = nil
            }

        // ── Diff ───────────────────────────────────────────────
        case .diff:
            if isCurrentSession {
                clearReasoningOnStageTransition()
                menuBarState = .executing
                currentToolName = "Editing file"
            }
            messageStore.insertEventIntoBuffer(event, buffer: &buffer)

        // ── Assistant text ─────────────────────────────────────
        case .assistant:
            if isCurrentSession {
                clearReasoningOnStageTransition()
                menuBarState = .responding
                currentToolName = nil
            }
            messageStore.insertEventIntoBuffer(event, buffer: &buffer)

        // ── Finish ─────────────────────────────────────────────
        case .finish:
            // Terminal-state guard:
            // - OpenCode may emit `session.idle` after an error for the same session.
            // - Once failed, the session must NOT transition to completed.
            // - Also dedup repeated finish events.
            if session.sessionStatus == .failed || session.sessionStatus == .completed {
                logEvent(event, session: session)
                return
            }
            messageStore.finalizeRunningMessages(in: &buffer)
            transitionSessionStatus(.completed, for: session)
            // Insert "Completed" system message
            messageStore.insertEventIntoBuffer(event, buffer: &buffer)
            // Persist to SwiftData
            session.messagesData = ConversationMessage.serializeMessages(buffer)
            if let ocId = session.openCodeSessionId {
                removeSessionFromTracking(ocId)
            }
            trySaveContext()
            // UI state
            if isCurrentSession {
                resetEventState()
                menuBarState = .idle
                currentToolName = nil
                currentToolInput = nil
                // Auto-promote next running session to foreground after badge fades
                scheduleAutoPromoteNextRunning()
            }
            // Show completed popup for all sessions (foreground and background)
            statusBarController?.showCompleted()
            updateStatusBar()
            sessionListRefreshTrigger += 1
            logEvent(event, session: session)
            return

        // ── Error ──────────────────────────────────────────────
        case .error:
            messageStore.finalizeRunningMessages(in: &buffer)
            transitionSessionStatus(.failed, for: session)
            markScheduledRunFailedIfNeeded(for: session.id, reason: event.text)
            Task { await BrowserUseBridge.shared.agentCancel() }
            // Insert error system message
            messageStore.insertEventIntoBuffer(event, buffer: &buffer)
            // Persist to SwiftData
            session.messagesData = ConversationMessage.serializeMessages(buffer)
            if let ocId = session.openCodeSessionId {
                removeSessionFromTracking(ocId)
            }
            trySaveContext()
            // UI state
            if isCurrentSession {
                resetEventState()
                lastErrorMessage = event.text
                menuBarState = .idle
                currentToolName = nil
                currentToolInput = nil
                statusBarController?.showError()
                // Auto-promote next running session after error badge fades
                scheduleAutoPromoteNextRunning()
            }
            updateStatusBar()
            sessionListRefreshTrigger += 1
            logEvent(event, session: session)
            return

        // ── Unknown ────────────────────────────────────────────
        case .unknown:
            if !event.text.isEmpty {
                Log.debug("Unknown event: \(event.text.prefix(200))")
            }
            messageStore.insertEventIntoBuffer(event, buffer: &buffer)
        }

        logEvent(event, session: session)
    }

    // MARK: - Helpers (used by processEvent)

    private func updateSessionAgent(_ agent: String) {
        guard currentSessionAgent != agent else { return }
        Log.debug("Agent changed: \(currentSessionAgent) → \(agent)")
        currentSessionAgent = agent
        configManager.currentAgent = agent == "build" ? "agent" : agent
        updatePlanPreviewPolling()
    }

    private func resetEventState() {
        sessionWarningTask?.cancel()
        sessionWarningTask = nil
        sessionFailTask?.cancel()
        sessionFailTask = nil
        reasoningDismissTask?.cancel()
        reasoningDismissTask = nil
        currentReasoningText = nil
    }

    /// Clear reasoning only when we actually transition to a new stage
    /// (tool execution or assistant response). This avoids timer-based gaps
    /// where thinking disappears before the next event arrives.
    private func clearReasoningOnStageTransition() {
        guard currentReasoningText != nil else { return }
        reasoningDismissTask?.cancel()
        reasoningDismissTask = nil
        currentReasoningText = nil
    }

    private func applyUsageUpdate(_ event: OpenCodeEvent, session: Session, isCurrentSession: Bool) {
        guard let usage = event.usage else { return }

        Log.debug("[Usage] model=\(event.model ?? "nil") in=\(usage.input) out=\(usage.output) reason=\(usage.reasoning)")

        if let messageId = event.messageId, let sessionId = event.sessionId {
            if !recordUsageMessageId(sessionId: sessionId, messageId: messageId) { return }
        }

        let model: String
        if let m = event.model, !m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model = m
        } else if let fallback = configManager.getModelString() {
            model = fallback
        } else {
            return
        }

        configManager.recordTokenUsage(model: model, usage: usage, cost: event.cost)

        if usage.input > 0 {
            session.contextTokens = usage.input
            if isCurrentSession { currentContextTokens = usage.input }
        }
    }

    // MARK: - Auto-Promote Next Running Session

    /// After the current foreground session finishes (completed/error), wait for the
    /// status bar badge to fade, then automatically switch to the next running session.
    /// This keeps the menubar reflecting actual running task status.
    private func scheduleAutoPromoteNextRunning() {
        autoPromoteTask?.cancel()
        autoPromoteTask = Task { @MainActor [weak self] in
            // Wait for completion/error badge to fade (matches StatusBarController timing)
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.promoteNextRunningSession()
        }
    }

    /// Switch to the next running session if any remain.
    private func promoteNextRunningSession() {
        // Find the first running session (most recently started)
        guard let nextEntry = runningSessions.first(where: { $0.value.sessionStatus == .running }),
              nextEntry.value.id != currentSession?.id
        else {
            return
        }
        let nextSession = nextEntry.value
        Log.debug("Auto-promoting background session to foreground: \(nextSession.intent.prefix(40))")
        switchToSession(nextSession)
    }

    // MARK: - Log Persistence

    func logEvent(_ event: OpenCodeEvent) {
        logEvent(event, session: currentSession)
    }

    func logEvent(_ event: OpenCodeEvent, session: Session?) {
        guard let session else { return }
        let json = event.toReplayJSON()
        let entry = LogEntry(rawJson: json, kind: event.kind.rawValue)
        modelContext?.insert(entry)
        session.logs.append(entry)
    }

    /// Update question/permission message with user response.
    func updateQuestionMessage(messageId: UUID, response: String, sessionId: String?) {
        let isCurrentSession = sessionId == nil || sessionId == currentSession?.openCodeSessionId
        if isCurrentSession {
            messageStore.updateQuestionMessage(messageId: messageId, response: response)
        } else if let sid = sessionId, var buffer = runningSessionMessages[sid] {
            messageStore.updateQuestionMessage(messageId: messageId, response: response, in: &buffer)
            runningSessionMessages[sid] = buffer
        }
    }
}

//
//  AppState.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum MenuBarState: String, Sendable {
        case idle
        case reasoning
        case executing
        case responding // Model is outputting response text (not thinking)
    }

    @Published var menuBarState: MenuBarState = .idle
    /// The active agent for the current session as reported by the server (e.g. "plan", "build").
    /// Distinct from `configManager.currentAgent` which is the user's selected default.
    @Published var currentSessionAgent: String = "agent"
    /// Plan file path for the currently selected session (when available).
    @Published var currentPlanFilePath: String?
    /// Live markdown tail for the current plan file (used by CommandBar inline preview).
    @Published var currentPlanPreviewText: String?
    let messageStore = MessageStore()
    var messages: [ConversationMessage] {
        get { messageStore.messages }
        set { messageStore.messages = newValue }
    }

    @Published var sessionStatus: SessionStatus = .idle
    @Published var lastErrorMessage: String?
    @Published var currentToolName: String?
    @Published var currentToolInput: String? // Current tool's input (e.g., command, file path)
    @Published var currentContextTokens: Int?
    /// OpenCode sessionId → messages for running sessions (persisted on completion)
    var runningSessionMessages: [String: [ConversationMessage]] = [:]
    /// OpenCode sessionId → Session for event routing and logging
    var runningSessions: [String: Session] = [:]
    /// OpenCode sessionId → plan file path observed from plan_enter/plan_exit prompts.
    var sessionPlanFilePaths: [String: String] = [:]
    /// Transient reasoning text — shown live during thinking, cleared when thinking ends.
    /// Not stored in the messages array.
    @Published var currentReasoningText: String?
    /// Task to dismiss reasoning after a short delay
    var reasoningDismissTask: Task<Void, Never>?
    @Published var commandBarResetTrigger: Int = 0 // Increment to trigger reset
    @Published var sessionListRefreshTrigger: Int = 0 // Increment to refresh session list

    let configManager: ConfigManager
    let bridge: OpenCodeBridge
    /// Task consuming events from the bridge's AsyncStream. Stored for cancellation.
    private var eventConsumerTask: Task<Void, Never>?
    /// Stored reference for the latest bridge operation Task.
    /// Cancels the previous operation before starting a new one,
    /// preventing races when the user switches sessions rapidly.
    var bridgeTask: Task<Void, Never>?
    /// Periodic snapshot timer for crash recovery.
    /// Persists running session message buffers to SwiftData every 30s.
    private var snapshotTimer: Task<Void, Never>?
    var modelContext: ModelContext?
    var currentSession: Session?
    var commandBarController: CommandBarWindowController?
    var statusBarController: StatusBarController?
    var drawerWindowController: DrawerWindowController?
    var quickConfirmController: QuickConfirmWindowController?
    var planPreviewWindowController: PlanPreviewWindowController?
    var hasStarted = false
    private var seenUsageMessageIds = Set<String>()

    /// Native question/permission handler (extracted from AppState+Bridge)
    lazy var nativePromptHandler: NativePromptHandler = .init(appState: self)

    /// UI-level session inactivity timers.
    /// - warning task: user-facing soft warning, does not fail the run.
    /// - fail task: hard timeout that emits an error and terminates running state.
    var sessionWarningTask: Task<Void, Never>?
    var sessionFailTask: Task<Void, Never>?
    static let sessionWarningSeconds: TimeInterval = MotiveConstants.Timeouts.sessionActivityWarning
    static let sessionFailSeconds: TimeInterval = MotiveConstants.Timeouts.sessionActivityFail

    /// Tracks the message ID for the current question/permission so we can update it with the user's response
    var pendingQuestionMessageId: UUID?

    var cancellables = Set<AnyCancellable>()

    /// Set to `true` when `resumeSession` sends a new prompt.
    /// While true, incoming finish events are stale (from the *previous* turn) and must be ignored.
    /// Cleared when the first substantive response event arrives for the new prompt.
    var awaitingFirstResponseAfterResume = false

    /// Queue of Sessions waiting for `__session_bind__` events from the bridge.
    /// Enqueued in `submitIntent`, dequeued in `handle(event:)` when binds arrive.
    /// Uses a FIFO queue because the bridge (actor) processes requests sequentially,
    /// so bind events arrive in the same order as submissions.
    /// Capped at `maxPendingBindSessions` entries; oldest are orphaned if exceeded.
    var pendingBindSessions: [Session] = []
    private static let maxPendingBindSessions = 10
    /// Timer for cleaning up orphaned entries in pendingBindSessions.
    private var bindQueueCleanupTask: Task<Void, Never>?
    /// Polls plan markdown file updates while a plan session is running.
    private var planPreviewTask: Task<Void, Never>?

    /// When true, the agent will auto-restart as soon as the current task finishes.
    @Published var pendingAgentRestart = false
    private var restartObserver: AnyCancellable?

    /// Task for auto-promoting the next running session after the foreground task finishes.
    var autoPromoteTask: Task<Void, Never>?
    /// Scheduler actor for user-configured scheduled tasks.
    var taskScheduler: TaskScheduler?
    /// Executor actor bridging scheduled jobs to AppState session submission.
    var scheduledTaskExecutor: ScheduledTaskExecutor?

    var configManagerRef: ConfigManager {
        configManager
    }

    var commandBarWindowRef: NSWindow? {
        commandBarController?.getWindow()
    }

    var currentSessionRef: Session? {
        currentSession
    }

    init(configManager: ConfigManager) {
        self.configManager = configManager

        // Create AsyncStream channel for bridge → AppState event delivery.
        // The bridge yields events non-blockingly; AppState consumes on MainActor.
        // AsyncStream preserves FIFO ordering, so events arrive in correct sequence.
        let (stream, continuation) = AsyncStream.makeStream(of: OpenCodeEvent.self)
        self.bridge = OpenCodeBridge(eventContinuation: continuation)

        // Forward messageStore changes to AppState's objectWillChange
        messageStore.$messages
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Start consuming bridge events on MainActor
        eventConsumerTask = Task { @MainActor [weak self] in
            for await event in stream {
                self?.handle(event: event)
            }
        }
    }

    /// Lightweight bridge reconfiguration (no server restart).
    /// Used when switching agents to update the Configuration for the next prompt.
    func reconfigureBridge() {
        Task { await configureBridge() }
    }

    /// Schedule an agent restart that respects running tasks.
    /// - If no task is running (`menuBarState == .idle`), restarts immediately.
    /// - If a task is running, defers the restart until it finishes.
    func scheduleAgentRestart() {
        guard menuBarState == .idle else {
            // Task is running — defer restart
            pendingAgentRestart = true
            installRestartObserver()
            return
        }
        // Idle — restart immediately
        pendingAgentRestart = false
        restartAgent()
    }

    /// Observe menuBarState transitions to .idle and auto-restart when pending.
    private func installRestartObserver() {
        // Avoid duplicate observers
        guard restartObserver == nil else { return }
        restartObserver = $menuBarState
            .removeDuplicates()
            .filter { $0 == .idle }
            .sink { [weak self] _ in
                guard let self, self.pendingAgentRestart else { return }
                self.pendingAgentRestart = false
                self.restartObserver = nil
                self.restartAgent()
            }
    }

    // MARK: - Session Lifecycle Helpers

    /// Reset all transient per-turn UI state.
    /// Call when switching sessions, starting new sessions, or cleaning up after interrupts.
    func resetTransientState() {
        awaitingFirstResponseAfterResume = false
        // NOTE: pendingBindSessions is NOT cleared here — it's a cross-turn binding queue,
        // not transient UI state. Clearing it would orphan sessions waiting for IDs.
        currentReasoningText = nil
        reasoningDismissTask?.cancel()
        reasoningDismissTask = nil
        sessionWarningTask?.cancel()
        sessionWarningTask = nil
        sessionFailTask?.cancel()
        sessionFailTask = nil
        autoPromoteTask?.cancel()
        autoPromoteTask = nil
        currentToolName = nil
        currentToolInput = nil
        lastErrorMessage = nil
        updatePlanPreviewPolling()
    }

    /// Save the current session's live messages for backgrounding.
    /// Call before `messages = []` or switching sessions to avoid data loss.
    func saveCurrentSessionToBuffer() {
        guard let session = currentSession,
              session.sessionStatus == .running else { return }
        if let ocId = session.openCodeSessionId {
            // Session already bound — save to in-memory buffer for live event appending
            runningSessionMessages[ocId] = messages
        } else {
            // Binding hasn't arrived yet — persist to SwiftData so the binding handler
            // can retrieve messages when it eventually fires.
            session.messagesData = ConversationMessage.serializeMessages(messages)
        }
    }

    /// Remove a session from all in-memory tracking dictionaries AND the bridge's active set.
    /// This is the SINGLE cleanup path for completed/failed/interrupted sessions.
    func removeSessionFromTracking(_ openCodeId: String) {
        runningSessions.removeValue(forKey: openCodeId)
        runningSessionMessages.removeValue(forKey: openCodeId)
        sessionPlanFilePaths.removeValue(forKey: openCodeId)
        if currentSession?.openCodeSessionId == openCodeId {
            currentPlanFilePath = nil
        }
        // Tell the bridge to stop tracking this session (stops SSE event forwarding)
        Task { await bridge.removeActiveSession(openCodeId) }
        // Stop the snapshot timer if no more running sessions
        stopSnapshotTimerIfNeeded()
    }

    /// Update the plan file path for an OpenCode session and sync current-session UI.
    func updatePlanFilePath(_ path: String, for openCodeSessionID: String?) {
        guard let openCodeSessionID,
              !openCodeSessionID.isEmpty,
              !path.isEmpty else { return }
        sessionPlanFilePaths[openCodeSessionID] = path
        if currentSession?.openCodeSessionId == openCodeSessionID {
            currentPlanFilePath = path
            updatePlanPreviewPolling()
        }
    }

    /// Persist current session's messages to SwiftData and clean up tracking.
    /// Call after all message content has been inserted (including system messages).
    func persistAndCleanupCurrentSession() {
        guard let session = currentSession else { return }
        session.messagesData = ConversationMessage.serializeMessages(messages)
        if let ocId = session.openCodeSessionId {
            removeSessionFromTracking(ocId)
        }
        trySaveContext()
    }

    // MARK: - Bind Queue Management

    /// Find and remove a pending session by its correlation ID.
    /// Falls back to FIFO if no correlation ID is provided (backward compatibility).
    func findPendingSession(correlationId: String?) -> Session? {
        if let correlationId, let uuid = UUID(uuidString: correlationId),
           let idx = pendingBindSessions.firstIndex(where: { $0.id == uuid })
        {
            return pendingBindSessions.remove(at: idx)
        }
        if !pendingBindSessions.isEmpty {
            return pendingBindSessions.removeFirst()
        }
        return nil
    }

    /// Add a session to the pending bind queue with overflow protection.
    func enqueuePendingBind(_ session: Session) {
        if pendingBindSessions.count >= Self.maxPendingBindSessions {
            let dropped = pendingBindSessions.removeFirst()
            Log.warning("Bind queue overflow: dropping oldest pending session \(dropped.id)")
            failUnboundSession(
                dropped,
                reason: "Session binding queue overflow. Request did not start; please retry."
            )
        }
        pendingBindSessions.append(session)
        startBindQueueCleanup()
    }

    /// Start a cleanup timer that removes orphaned bind entries after 30s.
    private func startBindQueueCleanup() {
        guard bindQueueCleanupTask == nil else { return }
        bindQueueCleanupTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { break }
                self.cleanupStaleBindEntries()
                if self.pendingBindSessions.isEmpty {
                    self.bindQueueCleanupTask = nil
                    break
                }
            }
        }
    }

    /// Remove sessions that have been waiting for a bind for too long (>30s).
    private func cleanupStaleBindEntries() {
        let cutoff = Date().addingTimeInterval(-30)
        let stale = pendingBindSessions.filter { $0.createdAt < cutoff }
        for session in stale {
            Log.warning("Bind queue: orphaned session \(session.id) (created \(session.createdAt)), marking failed")
            failUnboundSession(
                session,
                reason: "Task failed to start (no session binding within 30 seconds). Please retry."
            )
        }
        pendingBindSessions.removeAll { $0.createdAt < cutoff }
    }

    /// Finalize a session that never received a bind event.
    func failUnboundSession(_ session: Session, reason: String) {
        transitionSessionStatus(.failed, for: session)

        var buffer: [ConversationMessage] = if let data = session.messagesData,
                                               let saved = ConversationMessage.deserializeMessages(data)
        {
            saved
        } else {
            [ConversationMessage(type: .user, content: session.intent, timestamp: session.createdAt)]
        }
        buffer.append(ConversationMessage(type: .system, content: reason))
        session.messagesData = ConversationMessage.serializeMessages(buffer)
        markScheduledRunFailedIfNeeded(for: session.id, reason: reason)

        if currentSession?.id == session.id {
            messages = buffer
            lastErrorMessage = reason
            menuBarState = .idle
            updateStatusBar()
        }
        sessionListRefreshTrigger += 1
        trySaveContext()
    }

    func markScheduledRunFailedIfNeeded(for sessionID: UUID, reason: String) {
        guard let modelContext else { return }
        let sid = sessionID.uuidString
        let descriptor = FetchDescriptor<ScheduledTaskRun>(
            predicate: #Predicate { run in
                run.sessionID == sid && run.status == "submitted"
            },
            sortBy: [SortDescriptor(\.triggeredAt, order: .reverse)]
        )
        guard let run = try? modelContext.fetch(descriptor).first else { return }
        run.runStatus = .failed
        run.errorMessage = reason
    }

    // MARK: - Centralized Status Transition

    /// Centralized status transition for session lifecycle.
    /// Updates both the Session model AND AppState.sessionStatus if the session is the current one.
    /// - Parameters:
    ///   - newStatus: The target status.
    ///   - session: The Session model to update. If `nil`, only AppState.sessionStatus is updated.
    func transitionSessionStatus(_ newStatus: SessionStatus, for session: Session? = nil) {
        session?.sessionStatus = newStatus
        if session == nil || session?.id == currentSession?.id {
            sessionStatus = newStatus
        }
        updatePlanPreviewPolling()
    }

    /// Attempt to save the SwiftData context. Logs on failure.
    func trySaveContext() {
        do {
            try modelContext?.save()
        } catch {
            Log.error("Failed to save model context: \(error)")
        }
    }

    // MARK: - Crash Recovery Snapshot Timer

    /// Start periodic snapshotting of running session message buffers.
    /// Called when the first session starts running; stopped when no sessions remain.
    func startSnapshotTimerIfNeeded() {
        guard snapshotTimer == nil else { return }
        snapshotTimer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                self?.snapshotRunningSessionMessages()
            }
        }
    }

    /// Stop the periodic snapshot timer.
    func stopSnapshotTimerIfNeeded() {
        guard runningSessions.isEmpty else { return }
        snapshotTimer?.cancel()
        snapshotTimer = nil
    }

    /// Persist all running session message buffers to SwiftData.
    /// This is a crash-recovery measure — if the app terminates unexpectedly,
    /// messages are recoverable from `session.messagesData`.
    private func snapshotRunningSessionMessages() {
        var snapshotCount = 0
        for (sessionId, buffer) in runningSessionMessages {
            guard let session = runningSessions[sessionId] else { continue }
            session.messagesData = ConversationMessage.serializeMessages(buffer)
            snapshotCount += 1
        }
        if snapshotCount > 0 {
            trySaveContext()
            Log.debug("Snapshot: persisted \(snapshotCount) running session buffers")
        }
    }

    func resetUsageDeduplication() {
        seenUsageMessageIds.removeAll()
    }

    // MARK: - Plan Preview

    /// Opens a centered markdown preview window for the current plan file.
    func showPlanPreview(path: String?) {
        guard let resolvedPath = resolvePlanPreviewPath(path), !resolvedPath.isEmpty else { return }
        if planPreviewWindowController == nil {
            planPreviewWindowController = PlanPreviewWindowController()
        }
        planPreviewWindowController?.show(planFilePath: resolvedPath)
    }

    /// Starts/stops polling for live plan markdown preview based on session state.
    func updatePlanPreviewPolling() {
        let shouldPoll = sessionStatus == .running
            && currentSessionAgent == "plan"
            && resolvePlanPreviewPath(currentPlanFilePath) != nil

        if shouldPoll {
            guard planPreviewTask == nil else { return }
            planPreviewTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    self?.refreshPlanPreviewText()
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
            return
        }

        planPreviewTask?.cancel()
        planPreviewTask = nil
        currentPlanPreviewText = nil
    }

    private func refreshPlanPreviewText() {
        guard let resolvedPath = resolvePlanPreviewPath(currentPlanFilePath),
              let content = try? String(contentsOfFile: resolvedPath, encoding: .utf8)
        else {
            currentPlanPreviewText = nil
            return
        }
        let tailLimit = 1600
        currentPlanPreviewText = if content.count > tailLimit {
            String(content.suffix(tailLimit))
        } else {
            content
        }
    }

    private func resolvePlanPreviewPath(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: path) ? path : nil
        }
        let cwd = if let sessionPath = currentSession?.projectPath, !sessionPath.isEmpty {
            sessionPath
        } else {
            configManager.currentProjectURL.path
        }
        let absolute = URL(fileURLWithPath: cwd).appendingPathComponent(path).path
        return FileManager.default.fileExists(atPath: absolute) ? absolute : nil
    }

    func recordUsageMessageId(sessionId: String, messageId: String) -> Bool {
        let key = "\(sessionId)::\(messageId)"
        if seenUsageMessageIds.contains(key) {
            return false
        }
        seenUsageMessageIds.insert(key)
        return true
    }
}

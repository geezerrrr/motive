//
//  AppState+Lifecycle.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

extension AppState {
    func attachModelContext(_ context: ModelContext) {
        modelContext = context
        createCommandBarIfNeeded()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // Detect and reset stale UserDefaults if user deleted data directories
        // MUST run BEFORE ensureDefaultProjectDirectory() which creates ~/.motive/
        configManager.detectAndResetStaleState()

        // Ensure workspace exists (creates bootstrap files for fresh install)
        Task { @MainActor in
            do {
                try await WorkspaceManager.shared.ensureWorkspace()
            } catch {
                Log.config("Failed to ensure workspace: \(error)")
            }
        }

        // Ensure default project directory exists
        configManager.ensureDefaultProjectDirectory()
        configManager.ensureCurrentProjectInRecents()

        // Preload API keys early to trigger Keychain prompts at startup
        // This avoids scattered prompts during usage
        configManager.preloadAPIKeys()

        // Initialize SkillManager with ConfigManager to enable browser automation skill
        SkillManager.shared.setConfigManager(configManager)
        SkillRegistry.shared.setConfigManager(configManager)

        // Migrate legacy "motive" agent name to "agent"
        configManager.migrateAgentNameIfNeeded()

        observeMenuBarState()
        Task {
            await configureBridge()
            await bridge.startIfNeeded()
        }
        ensureStatusBar()
        drawerWindowController = DrawerWindowController(
            rootView: DrawerView()
                .environmentObject(self)
                .environmentObject(configManager)
        )
        // Configure settings window controller
        SettingsWindowController.shared.configure(configManager: configManager, appState: self)
        startScheduledTaskSystemIfNeeded()
        updateStatusBar()
    }

    func ensureStatusBar() {
        if statusBarController == nil {
            statusBarController = StatusBarController(delegate: self)
            statusBarController?.configure(configManager: configManager)
        }
        updateStatusBar()
    }

    func updateStatusBar() {
        let resolved = resolvedStatusBarState()
        let isWaiting = pendingQuestionMessageId != nil
        let inputType = "Question"
        statusBarController?.update(
            state: resolved.state,
            toolName: resolved.toolName,
            isWaitingForInput: isWaiting,
            inputType: inputType
        )
    }

    private func observeMenuBarState() {
        // Debounce menu bar state updates to avoid "multiple times per frame" warning
        $menuBarState
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main) // ~1 frame at 60fps
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusBar()
            }
            .store(in: &cancellables)
    }

    /// Resolve the effective status bar presentation.
    /// Priority:
    /// 1) Current running session (foreground transient state)
    /// 2) Any other running session (derived from buffered messages)
    /// 3) Idle
    private func resolvedStatusBarState() -> (state: MenuBarState, toolName: String?) {
        if currentSession?.sessionStatus == .running {
            if menuBarState != .idle {
                return (menuBarState, currentToolName)
            }
            let activeBuffer = if let sid = currentSession?.openCodeSessionId {
                runningSessionMessages[sid] ?? messages
            } else {
                messages
            }
            return derivedRunningState(from: activeBuffer) ?? (.executing, nil)
        }

        let running = runningSessions.values
            .filter { $0.sessionStatus == .running }
            .sorted { $0.createdAt > $1.createdAt }

        for session in running {
            guard let sid = session.openCodeSessionId,
                  let buffer = runningSessionMessages[sid]
            else {
                return (.executing, nil)
            }
            if let derived = derivedRunningState(from: buffer) {
                return derived
            }
            return (.executing, nil)
        }

        return (.idle, nil)
    }

    /// Best-effort stage inference for background running sessions from stored messages.
    private func derivedRunningState(from buffer: [ConversationMessage]) -> (state: MenuBarState, toolName: String?)? {
        if let runningTool = buffer.last(where: { $0.type == .tool && $0.status == .running }) {
            return (.executing, runningTool.toolName?.simplifiedToolName)
        }
        if buffer.last(where: { $0.type == .reasoning }) != nil {
            return (.reasoning, nil)
        }
        if buffer.last(where: { $0.type == .assistant }) != nil {
            return (.responding, nil)
        }
        return nil
    }

    private func createCommandBarIfNeeded() {
        guard commandBarController == nil, let modelContext else { return }
        let rootView = CommandBarView()
            .environmentObject(self)
            .environmentObject(configManager)
            .environment(\.modelContext, modelContext)
        commandBarController = CommandBarWindowController(rootView: rootView, configManager: configManager)
        // No pre-warm needed - window uses defer:true and alpha:0
        // First show will be slightly slower but avoids visual glitches
    }
}

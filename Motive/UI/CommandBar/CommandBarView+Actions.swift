//
//  CommandBarView+Actions.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import SwiftUI

extension CommandBarView {
    func handleOnAppear() {
        // Window-level animation is handled by CommandBarWindowController
        // Just focus the input field
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            isInputFocused = true
        }
    }

    func confirmDeleteSession() {
        guard selectedHistoryIndex < filteredHistorySessions.count else { return }
        let deleteId = filteredHistorySessions[selectedHistoryIndex].id
        removeHistorySession(id: deleteId, preferredIndex: selectedHistoryIndex)
        appState.deleteSession(id: deleteId)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            refreshHistorySessions(preferredIndex: selectedHistoryIndex)
        }
    }

    func showDeleteAlert() {
        let targetIndex = deleteCandidateIndex ?? selectedHistoryIndex
        guard targetIndex < filteredHistorySessions.count else {
            showDeleteConfirmation = false
            return
        }

        let sessionName = filteredHistorySessions[targetIndex].intent

        // Suppress auto-hide while alert is showing
        appState.setCommandBarAutoHideSuppressed(true)

        // Use NSAlert for better focus control
        let alert = NSAlert()
        alert.messageText = L10n.Alert.deleteSessionTitle
        alert.informativeText = String(format: L10n.Alert.deleteSessionMessage, sessionName)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.CommandBar.delete)
        alert.addButton(withTitle: L10n.CommandBar.cancel)

        // Show alert attached to command bar window
        if let window = appState.commandBarWindowRef {
            // Capture values needed in closure (struct cannot use weak self)
            let deleteId = deleteCandidateId ?? filteredHistorySessions[targetIndex].id
            let preferredIndex = deleteCandidateIndex ?? targetIndex
            let appStateRef = appState

            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Delete the session and refresh list/selection immediately
                    Task { @MainActor in
                        removeHistorySession(id: deleteId, preferredIndex: preferredIndex)
                        appStateRef.deleteSession(id: deleteId)
                        // Sync with persisted state after deletion
                        try? await Task.sleep(for: .milliseconds(50))
                        refreshHistorySessions(preferredIndex: selectedHistoryIndex)
                    }
                }

                // Reset state and restore focus
                appStateRef.setCommandBarAutoHideSuppressed(false)

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    appStateRef.refocusCommandBar()
                }
            }

            // Reset the flag (will be handled after alert closes)
            showDeleteConfirmation = false
            deleteCandidateIndex = nil
            deleteCandidateId = nil
        } else {
            showDeleteConfirmation = false
            deleteCandidateIndex = nil
            deleteCandidateId = nil
            appState.setCommandBarAutoHideSuppressed(false)
        }
    }

    // MARK: - Keyboard Navigation

    func handleUpArrow() {
        // File completion takes priority
        if showFileCompletion && !fileCompletion.items.isEmpty {
            if selectedFileIndex > 0 {
                selectedFileIndex -= 1
            }
            return
        }

        if mode.isCommand {
            if selectedCommandIndex > 0 {
                selectedCommandIndex -= 1
            }
        } else if mode.isHistory {
            if selectedHistoryIndex > 0 {
                selectedHistoryIndex -= 1
            }
            if selectedHistoryIndex < filteredHistorySessions.count {
                selectedHistoryId = filteredHistorySessions[selectedHistoryIndex].id
            }
        } else if mode.isProjects {
            if selectedProjectIndex > 0 {
                selectedProjectIndex -= 1
            }
        }
    }

    func handleDownArrow() {
        // File completion takes priority
        if showFileCompletion && !fileCompletion.items.isEmpty {
            if selectedFileIndex < fileCompletion.items.count - 1 {
                selectedFileIndex += 1
            }
            return
        }

        if mode.isCommand {
            if selectedCommandIndex < filteredCommands.count - 1 {
                selectedCommandIndex += 1
            }
        } else if mode.isHistory {
            if selectedHistoryIndex < filteredHistorySessions.count - 1 {
                selectedHistoryIndex += 1
            }
            if selectedHistoryIndex < filteredHistorySessions.count {
                selectedHistoryId = filteredHistorySessions[selectedHistoryIndex].id
            }
        } else if mode.isProjects {
            // 2 fixed items (Choose folder + Default) + recent projects
            let totalItems = 2 + configManager.recentProjects.count
            if selectedProjectIndex < totalItems - 1 {
                selectedProjectIndex += 1
            }
        }
    }

    func handleTab() {
        // File completion takes priority
        if showFileCompletion && !fileCompletion.items.isEmpty {
            if selectedFileIndex < fileCompletion.items.count {
                selectFileCompletion(fileCompletion.items[selectedFileIndex])
            }
            return
        }

        // Tab completion: complete the autocomplete hint
        if let hint = autocompleteHint {
            inputText = hint
        }
    }

    func handleCmdN() {
        // Cmd+N to create new session (works in any mode)
        appState.startNewEmptySession()
        inputText = ""
        mode = .completed  // Show "New Task" status
    }

    func handleCmdDelete() {
        // Cmd+Delete to delete selected session in history mode
        if mode.isHistory && selectedHistoryIndex < filteredHistorySessions.count {
            deleteCandidateIndex = selectedHistoryIndex
            deleteCandidateId = filteredHistorySessions[selectedHistoryIndex].id
            selectedHistoryId = filteredHistorySessions[selectedHistoryIndex].id
            showDeleteConfirmation = true
        }
    }

    // MARK: - State Handlers

    func handleInputChange(_ newValue: String) {
        // Always check for @ file completion
        checkForAtCompletion(newValue)

        // If @ completion is showing, do not change mode/height here.
        // Height is handled in checkForAtCompletion / hideFileCompletion.
        if showFileCompletion {
            return
        }

        // In history/projects mode, input is used for filtering, don't change mode
        if mode.isHistory || mode.isProjects {
            return
        }

        // In running mode, ignore input changes
        if mode == .running {
            return
        }

        // Track if we're coming from a session state
        let isInSession = mode == .completed || mode == .running || mode.isFromSession

        // Allow "/" command trigger from any state (including completed/error)
        if newValue.hasPrefix("/") {
            if !mode.isCommand {
                mode = .command(fromSession: isInSession || !appState.messages.isEmpty)
                selectedCommandIndex = 0
            }
        } else if mode.isCommand && !newValue.hasPrefix("/") {
            // Exiting command mode - return to previous session state or idle
            if mode.isFromSession || !appState.messages.isEmpty {
                mode = .completed
            } else {
                mode = newValue.isEmpty ? .idle : .input
            }
        } else if case .completed = mode {
            // In completed, typing non-command text stays in current mode (for follow-up)
            return
        } else if case .error = mode {
            // In error, typing non-command text stays in current mode (for follow-up)
            return
        } else if !newValue.isEmpty {
            mode = .input
        } else {
            mode = .idle
        }
    }

    func handleModeChange(from oldMode: CommandBarMode, to newMode: CommandBarMode) {
        // Update window height for new mode
        applyCommandBarHeight()

        // Load data when entering specific modes
        if newMode.isHistory {
            loadHistorySessions()
        }

        // Keep input focused in all modes
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            isInputFocused = true
        }
    }

    func handleSessionStatusChange(_ status: AppState.SessionStatus) {
        // Don't change mode if user is browsing commands/history/projects
        if mode.isCommand || mode.isHistory || mode.isProjects {
            return
        }

        switch status {
        case .running:
            mode = .running
        case .completed:
            mode = .completed
        case .failed:
            mode = .error(appState.lastErrorMessage ?? "An error occurred")
        case .idle, .interrupted:
            if mode == .running {
                mode = .idle
            }
        }
    }

    func handleSubmit() {
        // File completion takes priority
        if showFileCompletion && !fileCompletion.items.isEmpty {
            if selectedFileIndex < fileCompletion.items.count {
                selectFileCompletion(fileCompletion.items[selectedFileIndex])
            }
            return
        }

        if mode.isCommand {
            // Check if input has arguments (e.g., "/project /path/to/dir")
            let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("/project ") || text.hasPrefix("/p ") {
                // Extract path argument
                let pathArg = text.replacingOccurrences(of: "^/p(roject)?\\s+", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !pathArg.isEmpty {
                    if appState.switchProjectDirectory(pathArg) {
                        inputText = ""
                        mode = .idle
                    } else {
                        // Directory doesn't exist - show error briefly then stay in command mode
                        inputText = ""
                        mode = .error("Directory not found: \(pathArg)")
                    }
                    return
                }
            }
            executeSelectedCommand()
        } else if mode.isHistory {
            // Select the highlighted session
            if selectedHistoryIndex < filteredHistorySessions.count {
                selectHistorySession(filteredHistorySessions[selectedHistoryIndex])
            }
        } else if mode.isProjects {
            // Select the highlighted project
            if selectedProjectIndex == 0 {
                // "Choose folder..." option
                appState.showProjectPicker()
            } else if selectedProjectIndex == 1 {
                // Default ~/.motive
                selectProject(nil)
            } else {
                // Recent project
                let projectIndex = selectedProjectIndex - 2
                if projectIndex < configManager.recentProjects.count {
                    selectProject(configManager.recentProjects[projectIndex].path)
                }
            }
        } else if case .completed = mode {
            sendFollowUp()
        } else {
            submitIntent()
        }
    }

    func handleEscape() {
        // File completion: ESC closes it first
        if showFileCompletion {
            hideFileCompletion()
            return
        }

        if mode.isCommand || mode.isHistory || mode.isProjects {
            // Return to previous mode (session or idle)
            if appState.sessionStatus == .running {
                mode = .running
            } else if mode.isFromSession || !appState.messages.isEmpty {
                mode = .completed
            } else {
                mode = .idle
            }
            inputText = ""
        } else {
            // ESC = hide CommandBar (task continues running in background)
            appState.hideCommandBar()
        }
    }

    func submitIntent() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.submitIntent(text)
        // Mode will change to .running via sessionStatus observer
        // CommandBar stays visible - only ESC or focus loss hides it
    }

    func executeSelectedCommand() {
        guard selectedCommandIndex < filteredCommands.count else { return }
        executeCommand(filteredCommands[selectedCommandIndex])
    }

    func executeCommand(_ command: CommandDefinition) {
        let wasFromSession = mode.isFromSession || !appState.messages.isEmpty
        switch command.id {
        case "project":
            inputText = ""
            configManager.ensureCurrentProjectInRecents()
            appState.seedRecentProjectsFromSessions()
            mode = .projects(fromSession: wasFromSession)
            selectedProjectIndex = 0
        case "history":
            inputText = ""
            showFileCompletion = false  // Ensure file completion doesn't intercept keyboard
            mode = .history(fromSession: wasFromSession)
            selectedHistoryIndex = 0
        case "settings":
            inputText = ""
            appState.hideCommandBar()
            SettingsWindowController.shared.show(tab: .general)
        case "new":
            inputText = ""
            appState.startNewEmptySession()
            mode = .idle
        case "clear":
            inputText = ""
            appState.clearCurrentSession()
            mode = .idle
        default:
            break
        }
    }

    func sendFollowUp() {
        // Use the main inputText for follow-up messages
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.resumeSession(with: text)
        // CommandBar stays visible - mode will change to .running via sessionStatus observer
    }

    /// Re-center window and refocus input when CommandBar is shown
    /// Syncs mode with current session state
    func recenterAndFocus() {
        // Sync mode with current session status (unless user is mid-action)
        if !mode.isCommand && !mode.isHistory && !mode.isProjects {
            switch appState.sessionStatus {
            case .running:
                mode = .running
            case .completed:
                mode = .completed
            case .failed:
                mode = .error(appState.lastErrorMessage ?? "An error occurred")
            case .idle, .interrupted:
                // If there's a current session with messages, show completed
                if appState.currentSessionRef != nil && !appState.messages.isEmpty {
                    mode = .completed
                } else {
                    mode = .idle
                }
            }
        }

        // Update window height to match current mode
        applyCommandBarHeight()

        // Refocus input
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isInputFocused = true
        }
    }

    // MARK: - Histories

    func requestDeleteHistorySession(at index: Int) {
        guard index < filteredHistorySessions.count else { return }
        // Set the selected index to the one being deleted
        selectedHistoryIndex = index
        deleteCandidateIndex = index
        deleteCandidateId = filteredHistorySessions[index].id
        selectedHistoryId = filteredHistorySessions[index].id
        // Show confirmation dialog
        showDeleteConfirmation = true
    }

    var filteredHistorySessions: [Session] {
        if inputText.isEmpty {
            return Array(historySessions.prefix(20))
        }
        return historySessions.filter { $0.intent.localizedCaseInsensitiveContains(inputText) }.prefix(20).map { $0 }
    }

    func loadHistorySessions() {
        refreshHistorySessions(preferredIndex: nil)
    }

    func applyCommandBarHeight() {
        let newHeight = currentHeight
        if abs(newHeight - lastHeightApplied) < 0.5 { return }
        lastHeightApplied = newHeight
        DispatchQueue.main.async {
            appState.updateCommandBarHeight(to: newHeight)
        }
    }

    func refreshHistorySessions(preferredIndex: Int?) {
        historySessions = appState.getAllSessions()
        let list = filteredHistorySessions
        guard !list.isEmpty else {
            selectedHistoryIndex = 0
            selectedHistoryId = nil
            return
        }

        if let selectedHistoryId,
           let index = list.firstIndex(where: { $0.id == selectedHistoryId }) {
            selectedHistoryIndex = index
            return
        }

        if let preferredIndex {
            selectedHistoryIndex = min(preferredIndex, list.count - 1)
            selectedHistoryId = list[selectedHistoryIndex].id
            return
        }

        // Select current session if exists, otherwise default to first
        if let currentSession = appState.currentSessionRef,
           let index = list.firstIndex(where: { $0.id == currentSession.id }) {
            selectedHistoryIndex = index
            selectedHistoryId = currentSession.id
        } else {
            selectedHistoryIndex = 0
            selectedHistoryId = list[0].id
        }
    }

    func selectHistorySession(_ session: Session) {
        appState.switchToSession(session)
        inputText = ""
        if let index = filteredHistorySessions.firstIndex(where: { $0.id == session.id }) {
            selectedHistoryIndex = index
        }
        selectedHistoryId = session.id
        // Stay in CommandBar, switch to appropriate mode based on session status
        if appState.sessionStatus == .running {
            mode = .running
        } else {
            mode = .completed
        }
    }

    func deleteHistorySession(at index: Int) {
        guard index < filteredHistorySessions.count else { return }
        let deleteId = filteredHistorySessions[index].id
        removeHistorySession(id: deleteId, preferredIndex: index)
        appState.deleteSession(id: deleteId)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            refreshHistorySessions(preferredIndex: selectedHistoryIndex)
        }
    }

    func removeHistorySession(id: UUID, preferredIndex: Int) {
        historySessions.removeAll { $0.id == id }
        let list = filteredHistorySessions
        if list.isEmpty {
            selectedHistoryIndex = 0
            selectedHistoryId = nil
        } else {
            selectedHistoryIndex = min(preferredIndex, list.count - 1)
            selectedHistoryId = list[selectedHistoryIndex].id
        }
    }

    // MARK: - Projects

    func selectProject(_ path: String?) {
        appState.switchProjectDirectory(path)
        inputText = ""
        mode = .idle
    }
}

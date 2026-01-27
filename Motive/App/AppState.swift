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
    enum MenuBarState: String {
        case idle
        case reasoning
        case executing
    }

    enum SessionStatus: String {
        case idle
        case running
        case completed
        case failed
        case interrupted
    }

    @Published var menuBarState: MenuBarState = .idle
    @Published var messages: [ConversationMessage] = []
    @Published var sessionStatus: SessionStatus = .idle
    @Published var lastErrorMessage: String?
    @Published var currentToolName: String?
    @Published var commandBarResetTrigger: Int = 0  // Increment to trigger reset
    @Published var sessionListRefreshTrigger: Int = 0  // Increment to refresh session list

    private let configManager: ConfigManager
    private lazy var bridge: OpenCodeBridge = {
        OpenCodeBridge { [weak self] event in
            await MainActor.run { self?.handle(event: event) }
        }
    }()
    private var modelContext: ModelContext?
    private var currentSession: Session?
    private var commandBarController: CommandBarWindowController?
    private var statusBarController: StatusBarController?
    private var drawerWindowController: DrawerWindowController?
    private var quickConfirmController: QuickConfirmWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    var configManagerRef: ConfigManager { configManager }

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func attachModelContext(_ context: ModelContext) {
        modelContext = context
        createCommandBarIfNeeded()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        
        // Preload API keys early to trigger Keychain prompts at startup
        // This avoids scattered prompts during usage
        configManager.preloadAPIKeys()
        
        // Initialize SkillManager with ConfigManager to enable browser automation skill
        SkillManager.shared.setConfigManager(configManager)
        
        PermissionManager.shared.startServers()
        observePermissionRequests()
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
        updateStatusBar()
    }
    
    private func observeMenuBarState() {
        // Debounce menu bar state updates to avoid "multiple times per frame" warning
        $menuBarState
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main) // ~1 frame at 60fps
            .sink { [weak self] state in
                guard let self else { return }
                let isWaiting = PermissionManager.shared.isShowingRequest
                let inputType = PermissionManager.shared.currentRequest?.type == .question ? "Question" : "Permission"
                self.statusBarController?.update(
                    state: state,
                    toolName: self.currentToolName,
                    isWaitingForInput: isWaiting,
                    inputType: inputType
                )
            }
            .store(in: &cancellables)
    }
    
    /// Update status bar with current state
    private func updateStatusBar() {
        let isWaiting = PermissionManager.shared.isShowingRequest
        let inputType = PermissionManager.shared.currentRequest?.type == .question ? "Question" : "Permission"
        statusBarController?.update(
            state: menuBarState,
            toolName: currentToolName,
            isWaitingForInput: isWaiting,
            inputType: inputType
        )
    }

    private func observePermissionRequests() {
        PermissionManager.shared.$currentRequest
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                guard let self else { return }
                
                if let request = request {
                    // If drawer is visible, let it handle the request
                    // Otherwise show quick confirm panel
                    if self.drawerWindowController?.isVisible == true {
                        // Drawer will handle it via its own UI
                    } else {
                        self.showQuickConfirm(for: request)
                    }
                } else {
                    // Dismiss quick confirm if request is cleared
                    self.quickConfirmController?.dismiss()
                }
                
                // Update status bar to show waiting state
                self.updateStatusBar()
            }
            .store(in: &cancellables)
    }
    
    private func showQuickConfirm(for request: PermissionRequest) {
        if quickConfirmController == nil {
            quickConfirmController = QuickConfirmWindowController()
        }
        
        // Get status bar button frame for positioning
        let anchorFrame = statusBarController?.buttonFrame
        
        quickConfirmController?.show(
            request: request,
            anchorFrame: anchorFrame,
            onResponse: { [weak self] response in
                // Handle the response
                let permResponse: PermissionResponse
                if request.type == .question {
                    permResponse = PermissionResponse(
                        requestId: request.id,
                        taskId: request.taskId,
                        decision: .allow,
                        selectedOptions: [response],
                        customText: response
                    )
                } else {
                    let approved = response == "approved"
                    permResponse = PermissionResponse(
                        requestId: request.id,
                        taskId: request.taskId,
                        decision: approved ? .allow : .deny
                    )
                }
                PermissionManager.shared.respond(with: permResponse)
                self?.updateStatusBar()
            },
            onCancel: { [weak self] in
                // Cancel/deny the request
                let permResponse = PermissionResponse(
                    requestId: request.id,
                    taskId: request.taskId,
                    decision: .deny
                )
                PermissionManager.shared.respond(with: permResponse)
                self?.updateStatusBar()
            }
        )
    }

    func ensureStatusBar() {
        if statusBarController == nil {
            statusBarController = StatusBarController(delegate: self)
            statusBarController?.configure(configManager: configManager)
        }
        updateStatusBar()
    }
    
    func restartAgent() {
        Task {
            await configureBridge()
            await bridge.restart()
        }
    }

    func submitIntent(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Check provider configuration
        if let configError = configManager.providerConfigurationError {
            lastErrorMessage = configError
            // Don't hide - let user see the error
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

        let cwd = FileManager.default.currentDirectoryPath
        Task { await bridge.submitIntent(text: trimmed, cwd: cwd) }
    }
    
    func sendFollowUp(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard sessionStatus == .completed || sessionStatus == .interrupted else { return }
        
        lastErrorMessage = nil
        sessionStatus = .running
        menuBarState = .executing
        
        // Add user message
        let userMessage = ConversationMessage(
            type: .user,
            content: trimmed
        )
        messages.append(userMessage)

        let cwd = FileManager.default.currentDirectoryPath
        Task { await bridge.submitIntent(text: trimmed, cwd: cwd) }
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
        
        // Add system message
        let systemMessage = ConversationMessage(
            type: .system,
            content: "Session interrupted by user"
        )
        messages.append(systemMessage)
    }

    var commandBarWindowRef: NSWindow? { commandBarController?.getWindow() }
    
    /// Reference to current session (for UI to check current selection)
    var currentSessionRef: Session? { currentSession }

    func showCommandBar() {
        guard let commandBarController else {
            Log.debug("commandBarController is nil!")
            return
        }
        Log.debug("Showing command bar window")
        // Trigger SwiftUI state reset
        commandBarResetTrigger += 1
        commandBarController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak commandBarController] in
            commandBarController?.focusFirstResponder()
        }
    }

    func hideCommandBar() {
        Log.debug("Hiding command bar window")
        commandBarController?.hide()
    }
    
    func updateCommandBarHeight(for modeName: String) {
        // Disable window animation to prevent height jitter
        commandBarController?.updateHeightForMode(modeName, animated: false)
    }
    
    /// Suppress or allow auto-hide when command bar loses focus
    func setCommandBarAutoHideSuppressed(_ suppressed: Bool) {
        commandBarController?.suppressAutoHide = suppressed
    }
    
    /// Refocus the command bar input field
    func refocusCommandBar() {
        commandBarController?.focusFirstResponder()
    }

    private func createCommandBarIfNeeded() {
        guard commandBarController == nil, let modelContext else { return }
        let rootView = CommandBarView()
            .environmentObject(self)
            .environmentObject(configManager)
            .environment(\.modelContext, modelContext)
        commandBarController = CommandBarWindowController(rootView: rootView)
        
        // Pre-warm the window to avoid first-show delay
        // Show briefly off-screen then hide
        if let controller = commandBarController {
            let window = controller.getWindow()
            window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.orderOut(nil)
            }
        }
    }

    func toggleDrawer() {
        Log.debug("toggleDrawer called, drawerWindowController exists: \(drawerWindowController != nil)")
        guard let drawerWindowController else {
            Log.debug("drawerWindowController is nil!")
            return
        }
        if drawerWindowController.isVisible {
            Log.debug("Hiding drawer")
            drawerWindowController.hide()
        } else {
            Log.debug("Showing drawer")
            // Pass status bar button position for proper positioning
            drawerWindowController.updateStatusBarButtonFrame(statusBarController?.buttonFrame)
            drawerWindowController.show()
        }
    }
    
    func hideDrawer() {
        drawerWindowController?.hide()
    }
    
    /// Get the Drawer window for showing alerts as sheets
    var drawerWindowRef: NSWindow? {
        drawerWindowController?.getWindow()
    }
    
    /// Temporarily suppress auto-hide for Drawer (e.g., during alert display)
    func setDrawerAutoHideSuppressed(_ suppressed: Bool) {
        drawerWindowController?.suppressAutoHide = suppressed
    }

    private func configureBridge() async {
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
            debugMode: configManager.debugMode
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

    private func startNewSession(intent: String) {
        messages = []
        menuBarState = .executing
        sessionStatus = .running
        currentToolName = nil
        
        // Clear OpenCodeBridge session ID for fresh start
        Task { await bridge.setSessionId(nil) }
        
        let session = Session(intent: intent)
        currentSession = session
        modelContext?.insert(session)
    }
    
    // MARK: - Session Management
    
    /// Get all sessions sorted by date (newest first)
    func getAllSessions() -> [Session] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Switch to a different session
    func switchToSession(_ session: Session) {
        currentSession = session
        sessionStatus = SessionStatus(rawValue: session.status) ?? .completed
        
        // Sync OpenCodeBridge session ID
        Task { await bridge.setSessionId(session.openCodeSessionId) }
        
        // Rebuild messages from logs
        messages = []
        
        // Add the initial user intent
        let userMessage = ConversationMessage(
            type: .user,
            content: session.intent,
            timestamp: session.createdAt
        )
        messages.append(userMessage)
        
        // Add messages from logs
        for log in session.logs {
            let event = OpenCodeEvent(rawJson: log.rawJson)
            if let message = event.toMessage() {
                messages.append(message)
            }
        }
        
        objectWillChange.send()
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
        
        objectWillChange.send()
    }
    
    /// Clear current session messages without deleting
    func clearCurrentSession() {
        messages = []
        currentSession = nil
        sessionStatus = .idle
        menuBarState = .idle
        currentToolName = nil
        
        Task { await bridge.setSessionId(nil) }
        objectWillChange.send()
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
        objectWillChange.send()
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
        
        let cwd = FileManager.default.currentDirectoryPath
        Task { await bridge.resumeSession(sessionId: openCodeSessionId, text: trimmed, cwd: cwd) }
    }

    private func handle(event: OpenCodeEvent) {
        // Update UI state based on event kind
        switch event.kind {
        case .thought:
            menuBarState = .reasoning
            currentToolName = nil
        case .call, .tool:
            menuBarState = .executing
            currentToolName = event.toolName ?? "Processing"
            
            // Intercept AskUserQuestion tool calls
            if event.toolName == "AskUserQuestion", let inputDict = event.toolInputDict {
                handleAskUserQuestion(input: inputDict)
                return  // Don't add to message list
            }
        case .diff:
            menuBarState = .executing
            currentToolName = "Editing file"
        case .finish:
            menuBarState = .idle
            sessionStatus = .completed
            currentToolName = nil
            // Update session status
            if let session = currentSession {
                session.status = "completed"
            }
            // Show completion in status bar
            statusBarController?.showCompleted()
        case .assistant:
            menuBarState = .reasoning
            currentToolName = nil
        case .user:
            // User messages are added directly in submitIntent
            return
        case .unknown:
            // Check for various error patterns
            let errorText = detectError(in: event.text, rawJson: event.rawJson)
            if let error = errorText {
                lastErrorMessage = error
                sessionStatus = .failed
                if let session = currentSession {
                    session.status = "failed"
                }
                // Show error in status bar
                statusBarController?.showError()
            }
        }
        
        // Process event content (save session ID, add messages)
        processEventContent(event)
    }
    
    /// Handle AskUserQuestion tool call - show popup and send response via PTY
    private func handleAskUserQuestion(input: [String: Any]) {
        Log.debug("Intercepted AskUserQuestion tool call")
        
        // Parse questions from input
        guard let questions = input["questions"] as? [[String: Any]],
              let firstQuestion = questions.first else {
            Log.debug("AskUserQuestion: no questions found in input")
            return
        }
        
        let questionText = firstQuestion["question"] as? String ?? "Question from AI"
        let header = firstQuestion["header"] as? String ?? "Question"
        let multiSelect = firstQuestion["multiSelect"] as? Bool ?? false
        
        // Parse options
        var options: [PermissionRequest.QuestionOption] = []
        if let rawOptions = firstQuestion["options"] as? [[String: Any]] {
            options = rawOptions.map { opt in
                PermissionRequest.QuestionOption(
                    label: opt["label"] as? String ?? "",
                    description: opt["description"] as? String
                )
            }
        }
        
        // If no options provided, add default Yes/No/Other
        if options.isEmpty {
            options = [
                PermissionRequest.QuestionOption(label: "Yes"),
                PermissionRequest.QuestionOption(label: "No"),
                PermissionRequest.QuestionOption(label: "Other", description: "Custom response")
            ]
        }
        
        let requestId = "askuser_\(UUID().uuidString)"
        let request = PermissionRequest(
            id: requestId,
            taskId: requestId,
            type: .question,
            question: questionText,
            header: header,
            options: options,
            multiSelect: multiSelect
        )
        
        // Show quick confirm with custom handlers for AskUserQuestion
        if quickConfirmController == nil {
            quickConfirmController = QuickConfirmWindowController()
        }
        
        let anchorFrame = statusBarController?.buttonFrame
        
        quickConfirmController?.show(
            request: request,
            anchorFrame: anchorFrame,
            onResponse: { [weak self] (response: String) in
                // Send response to OpenCode via PTY stdin
                Log.debug("AskUserQuestion response: \(response)")
                Task { [weak self] in
                    await self?.bridge.sendResponse(response)
                }
                self?.updateStatusBar()
            },
            onCancel: { [weak self] in
                // User cancelled - send empty response
                Log.debug("AskUserQuestion cancelled")
                Task { [weak self] in
                    await self?.bridge.sendResponse("")
                }
                self?.updateStatusBar()
            }
        )
    }
    
    /// Detect errors from OpenCode output
    private func detectError(in text: String, rawJson: String) -> String? {
        let lowerText = text.lowercased()
        let lowerJson = rawJson.lowercased()
        
        // Check for API authentication errors
        if lowerText.contains("authentication") || lowerText.contains("unauthorized") ||
           lowerText.contains("invalid api key") || lowerText.contains("401") {
            return "API authentication failed. Check your API key in Settings."
        }
        
        // Check for rate limiting
        if lowerText.contains("rate limit") || lowerText.contains("429") || lowerText.contains("too many requests") {
            return "Rate limit exceeded. Please wait and try again."
        }
        
        // Check for model not found
        if lowerText.contains("model not found") || lowerText.contains("does not exist") ||
           lowerText.contains("invalid model") {
            return "Model not found. Check your model name in Settings."
        }
        
        // Check for connection errors
        if lowerText.contains("connection") && (lowerText.contains("refused") || lowerText.contains("failed")) {
            return "Connection failed. Check your Base URL or network."
        }
        
        if lowerText.contains("econnrefused") || lowerText.contains("network error") {
            return "Network error. Check your internet connection."
        }
        
        // Check for Ollama specific errors
        if lowerText.contains("ollama") && (lowerText.contains("not running") || lowerText.contains("not found")) {
            return "Ollama is not running. Start Ollama and try again."
        }
        
        // Generic error detection
        if lowerText.contains("error") || lowerJson.contains("\"error\"") {
            // Extract a meaningful error message if possible
            if text.count < 200 {
                return text
            }
            return "An error occurred. Check the console for details."
        }
        
        return nil
    }
    
    private func processEventContent(_ event: OpenCodeEvent) {
        // Save OpenCode session ID to our session for resume capability
        if let sessionId = event.sessionId, let session = currentSession, session.openCodeSessionId == nil {
            session.openCodeSessionId = sessionId
            Log.debug("Saved OpenCode session ID to session: \(sessionId)")
        }
        
        // Convert event to conversation message and add to list
        guard let message = event.toMessage() else {
            // Log the event but don't add to UI
            if let session = currentSession {
                let entry = LogEntry(rawJson: event.rawJson, kind: event.kind.rawValue)
                modelContext?.insert(entry)
                session.logs.append(entry)
            }
            return
        }
        
        // Merge consecutive assistant messages (streaming text)
        if message.type == .assistant,
           let lastIndex = messages.lastIndex(where: { $0.type == .assistant }),
           lastIndex == messages.count - 1 {
            // Append to last assistant message
            let lastMessage = messages[lastIndex]
            let mergedContent = lastMessage.content + message.content
            messages[lastIndex] = ConversationMessage(
                id: lastMessage.id,
                type: .assistant,
                content: mergedContent,
                timestamp: lastMessage.timestamp
            )
        } else {
            messages.append(message)
        }
        
        // Force SwiftUI to update (NSHostingView may not auto-refresh)
        objectWillChange.send()

        if let session = currentSession {
            let entry = LogEntry(rawJson: event.rawJson, kind: event.kind.rawValue)
            modelContext?.insert(entry)
            session.logs.append(entry)
        }
    }
}

extension AppState: StatusBarControllerDelegate {
    func statusBarDidRequestSettings() {
        SettingsWindowController.shared.show()
    }

    func statusBarDidRequestQuit() {
        NSApp.terminate(nil)
    }

    func statusBarDidRequestToggleDrawer() {
        toggleDrawer()
    }

    func statusBarDidRequestCommandBar() {
        showCommandBar()
    }
}

// MARK: - NSView Extension

extension NSView {
    func findFirstTextField() -> NSTextField? {
        if let textField = self as? NSTextField, textField.isEditable {
            return textField
        }
        for subview in subviews {
            if let found = subview.findFirstTextField() {
                return found
            }
        }
        return nil
    }
}

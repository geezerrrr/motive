//
//  AppState+Bridge.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
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

    func handle(event: OpenCodeEvent) {
        // Update UI state based on event kind
        switch event.kind {
        case .thought:
            menuBarState = .reasoning
            currentToolName = nil
            currentToolInput = nil
            // Update CloudKit for remote commands
            updateRemoteCommandStatus(toolName: "Thinking...")

        case .call, .tool:
            menuBarState = .executing
            currentToolName = event.toolName ?? "Processing"
            currentToolInput = event.toolInput  // Store tool input immediately

            // Intercept AskUserQuestion tool calls
            if isAskUserQuestionTool(event.toolName) {
                if let inputDict = event.toolInputDict ?? extractAskUserQuestionInput(from: event.rawJson) {
                    handleAskUserQuestion(input: inputDict)
                    return  // Don't add to message list
                }
                Log.debug("AskUserQuestion: matched tool name but no input payload")
            }
            // Update CloudKit for remote commands
            updateRemoteCommandStatus(toolName: event.toolName)

        case .diff:
            menuBarState = .executing
            currentToolName = "Editing file"
            updateRemoteCommandStatus(toolName: "Editing file")

        case .finish:
            // --- Finish deduplication ---
            // Secondary finish events (session.idle, process exit) are silently absorbed
            // when a primary finish (step_finish) has already been processed.
            // This prevents the "Completed / Session idle / Task completed" triple-spam.
            if event.isSecondaryFinish && sessionStatus == .completed {
                // Already completed — just ensure cleanup, don't add another message
                Log.debug("Ignoring secondary finish event (already completed)")
                return
            }

            menuBarState = .idle
            sessionStatus = .completed
            currentToolName = nil
            currentToolInput = nil

            // Mark all running tool messages as completed (cleanup)
            finalizeRunningMessages()

            // Update session status
            if let session = currentSession {
                session.status = "completed"
            }
            // Show completion in status bar
            statusBarController?.showCompleted()
            // Complete remote command in CloudKit
            if let commandId = currentRemoteCommandId {
                let resultMessage = messages.last(where: { $0.type == .assistant })?.content ?? "Task completed"
                cloudKitManager.completeCommand(commandId: commandId, result: resultMessage)
                currentRemoteCommandId = nil
            }

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
                menuBarState = .idle
                currentToolName = nil
                if let session = currentSession {
                    session.status = "failed"
                }
                // Show error in status bar
                statusBarController?.showError()
                // Fail remote command in CloudKit
                if let commandId = currentRemoteCommandId {
                    cloudKitManager.failCommand(commandId: commandId, error: error)
                    currentRemoteCommandId = nil
                }
            }
        }

        // Process event content (save session ID, add messages)
        processEventContent(event)
    }

    // MARK: - Tool Lifecycle Helpers

    /// When a step/task finishes, mark any still-running tool messages as completed.
    private func finalizeRunningMessages() {
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
                    status: .completed
                )
            }
        }
    }

    // MARK: - AskUserQuestion

    private func isAskUserQuestionTool(_ toolName: String?) -> Bool {
        guard let toolName else { return false }
        let normalized = normalizeToolName(toolName)
        if normalized == "askuserquestion" { return true }
        return normalized.hasSuffix("askuserquestion")
    }

    private func normalizeToolName(_ toolName: String) -> String {
        let base = toolName
            .components(separatedBy: ["/", ":", "."])
            .last ?? toolName
        let lowered = base.lowercased()
        let stripped = lowered.filter { $0.isLetter || $0.isNumber }
        return stripped
    }

    private func extractAskUserQuestionInput(from rawJson: String) -> [String: Any]? {
        guard let data = rawJson.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let part = object["part"] as? [String: Any] else {
            return nil
        }

        if let input = extractInputDict(from: part) {
            return input
        }
        if let state = part["state"] as? [String: Any],
           let input = extractInputDict(from: state) {
            return input
        }
        return nil
    }

    private func extractInputDict(from container: [String: Any]) -> [String: Any]? {
        if let dict = container["input"] as? [String: Any] {
            return dict
        }
        if let dict = container["arguments"] as? [String: Any] {
            return dict
        }
        if let dict = container["args"] as? [String: Any] {
            return dict
        }
        if let inputStr = container["input"] as? String,
           let data = inputStr.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        if let inputStr = container["arguments"] as? String,
           let data = inputStr.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        return nil
    }

    /// Update remote command status in CloudKit
    private func updateRemoteCommandStatus(toolName: String?) {
        guard let commandId = currentRemoteCommandId else { return }
        cloudKitManager.updateProgress(commandId: commandId, toolName: toolName)
    }

    /// Handle AskUserQuestion tool call - show popup and send response via PTY
    private func handleAskUserQuestion(input: [String: Any]) {
        Log.debug("Intercepted AskUserQuestion tool call")

        // Parse questions from input (supports both "questions" and single "question" shapes)
        let questions: [[String: Any]]
        if let rawQuestions = input["questions"] as? [[String: Any]] {
            questions = rawQuestions
        } else if let question = input["question"] as? String {
            var single: [String: Any] = [
                "question": question
            ]
            if let header = input["header"] as? String {
                single["header"] = header
            }
            if let options = input["options"] {
                single["options"] = options
            }
            if let multiSelect = input["multiSelect"] {
                single["multiSelect"] = multiSelect
            }
            questions = [single]
        } else {
            Log.debug("AskUserQuestion: no questions found in input")
            return
        }
        guard let firstQuestion = questions.first else {
            Log.debug("AskUserQuestion: empty questions array")
            return
        }

        let questionText = firstQuestion["question"] as? String ?? "Question from AI"
        let header = firstQuestion["header"] as? String ?? "Question"
        let multiSelect = firstQuestion["multiSelect"] as? Bool ?? false

        // Parse options
        var options: [PermissionRequest.QuestionOption] = []
        var optionLabels: [String] = []
        if let rawOptions = firstQuestion["options"] as? [[String: Any]] {
            options = rawOptions.map { opt in
                let label = opt["label"] as? String ?? ""
                optionLabels.append(label)
                return PermissionRequest.QuestionOption(
                    label: label,
                    description: opt["description"] as? String
                )
            }
        } else if let rawOptions = firstQuestion["options"] as? [String] {
            options = rawOptions.map { label in
                optionLabels.append(label)
                return PermissionRequest.QuestionOption(label: label)
            }
        }

        // If no options provided, add default Yes/No/Other
        if options.isEmpty {
            options = [
                PermissionRequest.QuestionOption(label: "Yes"),
                PermissionRequest.QuestionOption(label: "No"),
                PermissionRequest.QuestionOption(label: "Other", description: "Custom response")
            ]
            optionLabels = ["Yes", "No", "Other"]
        }

        // If this is a remote command, send question to iOS via CloudKit
        if let commandId = currentRemoteCommandId {
            Log.debug("Sending question to iOS via CloudKit for remote command: \(commandId)")
            Task {
                let response = await cloudKitManager.sendPermissionRequest(
                    commandId: commandId,
                    question: "\(header): \(questionText)",
                    options: optionLabels
                )
                
                if let response = response {
                    Log.debug("Got response from iOS: \(response)")
                    await bridge.sendResponse(response)
                } else {
                    Log.debug("No response from iOS, sending empty response")
                    await bridge.sendResponse("")
                }
                updateStatusBar()
            }
            return  // Don't show local QuickConfirm for remote commands
        }

        // For local commands, show QuickConfirm as usual
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

        // Check for OpenCode not configured (binary not found or bridge not initialized)
        if lowerText.contains("opencode not configured") || lowerText.contains("not configured") {
            return text
        }

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

        // Check for encrypted content verification errors (session/project mismatch)
        if lowerText.contains("encrypted content") && (lowerText.contains("could not be verified") || lowerText.contains("invalid_encrypted_content")) {
            // Clear session ID and retry as new session
            if let session = currentSession {
                Log.debug("Encrypted content verification failed - clearing session ID (likely project mismatch)")
                session.openCodeSessionId = nil
            }
            Task { await bridge.setSessionId(nil) }
            return "Session context mismatch. Please try again - a new session will be started."
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

    // MARK: - Event Content Processing

    private func processEventContent(_ event: OpenCodeEvent) {
        // Save OpenCode session ID to our session for resume capability
        if let sessionId = event.sessionId, let session = currentSession, session.openCodeSessionId == nil {
            session.openCodeSessionId = sessionId
            Log.debug("Saved OpenCode session ID to session: \(sessionId)")
        }

        // --- Tool event lifecycle logging ---
        if event.kind == .tool || event.kind == .call {
            let hasOutput = event.toolOutput != nil
            let phase = hasOutput ? "result" : "call"
            Log.debug("Tool event [\(phase)]: \(event.toolName ?? "?") callId=\(event.toolCallId ?? "nil") hasOutput=\(hasOutput)")
        }

        // --- TodoWrite interception ---
        if event.kind == .tool, let toolName = event.toolName, toolName.isTodoWriteTool {
            handleTodoWriteEvent(event)
            logEvent(event)
            return
        }

        // Convert event to conversation message and add to list
        guard let message = event.toMessage() else {
            logEvent(event)
            return
        }

        // --- Finish event handling ---
        // Secondary finish events with empty text are silent (just for state cleanup)
        if message.type == .system && event.isSecondaryFinish {
            if message.content.isEmpty {
                // Silent cleanup finish — don't add any message
                logEvent(event)
                return
            }
            // Non-empty secondary finish (e.g., first finish was session.idle before step_finish)
            // Only add if no completion message exists yet
            let hasCompletionMessage = messages.contains { $0.type == .system && isCompletionText($0.content) }
            if hasCompletionMessage {
                logEvent(event)
                return
            }
        }

        // --- Primary finish: only add if no completion message already ---
        if message.type == .system && isCompletionText(message.content) {
            let hasCompletionMessage = messages.contains { $0.type == .system && isCompletionText($0.content) }
            if hasCompletionMessage {
                logEvent(event)
                return
            }
        }

        // --- Assistant message streaming merge ---
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
        }
        // --- Tool message lifecycle merge ---
        else if message.type == .tool {
            processToolMessage(message)
        }
        // --- Everything else: append ---
        else {
            messages.append(message)
        }

        // @Observable handles change tracking automatically
        logEvent(event)
    }

    /// Process tool messages with proper lifecycle: running → completed
    private func processToolMessage(_ message: ConversationMessage) {
        // Strategy 1: Merge by toolCallId (most reliable)
        if let toolCallId = message.toolCallId,
           let existingIndex = messages.lastIndex(where: { $0.type == .tool && $0.toolCallId == toolCallId }) {
            let existing = messages[existingIndex]
            let mergedContent = existing.content.isEmpty ? message.content : existing.content
            // When result arrives, transition from .running → .completed
            let mergedStatus: ConversationMessage.Status =
                (message.toolOutput != nil) ? .completed : existing.status
            Log.debug("Tool merge [callId]: \(existing.toolName ?? "?") \(existing.status.rawValue) → \(mergedStatus.rawValue)")
            messages[existingIndex] = ConversationMessage(
                id: existing.id,
                type: .tool,
                content: mergedContent,
                timestamp: existing.timestamp,
                toolName: existing.toolName ?? message.toolName,
                toolInput: existing.toolInput ?? message.toolInput,
                toolOutput: existing.toolOutput ?? message.toolOutput,
                toolCallId: existing.toolCallId ?? message.toolCallId,
                status: mergedStatus
            )
        }
        // Strategy 2: Merge consecutive tool messages (fallback for missing toolCallId)
        else if let lastIndex = messages.lastIndex(where: { $0.type == .tool }),
                lastIndex == messages.count - 1,
                messages[lastIndex].toolOutput == nil,
                message.toolOutput != nil,
                (message.toolName == "Result" || message.toolName == messages[lastIndex].toolName) {
            let lastMessage = messages[lastIndex]
            let mergedContent = lastMessage.content.isEmpty ? message.content : lastMessage.content
            Log.debug("Tool merge [consecutive]: \(lastMessage.toolName ?? "?") → completed")
            messages[lastIndex] = ConversationMessage(
                id: lastMessage.id,
                type: .tool,
                content: mergedContent,
                timestamp: lastMessage.timestamp,
                toolName: lastMessage.toolName,
                toolInput: lastMessage.toolInput,
                toolOutput: message.toolOutput,
                toolCallId: lastMessage.toolCallId ?? message.toolCallId,
                status: .completed  // Result arrived → completed
            )
        }
        // No merge target — append as new message
        else {
            Log.debug("Tool append [new]: \(message.toolName ?? "?") status=\(message.status.rawValue) hasOutput=\(message.toolOutput != nil)")
            messages.append(message)
        }
    }

    /// Check if text represents a completion message
    private func isCompletionText(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower == "completed"
            || lower == "session idle"
            || lower == "task completed"
            || lower.hasPrefix("task completed with exit code")
    }

    // MARK: - TodoWrite Handling

    /// Intercept TodoWrite tool calls and create/update a dedicated todo message
    private func handleTodoWriteEvent(_ event: OpenCodeEvent) {
        // Parse todo items from the tool input
        let todoItems = parseTodoItems(from: event)
        guard !todoItems.isEmpty else {
            // If we can't parse todos, fall back to normal tool display
            if let message = event.toMessage() {
                processToolMessage(message)
            }
            return
        }

        // Determine if we should merge with existing todo message
        let merge = parseTodoMerge(from: event)

        // Find existing todo message to update
        if let existingIndex = messages.lastIndex(where: { $0.type == .todo }) {
            let existing = messages[existingIndex]
            let finalItems: [TodoItem]
            if merge, let existingItems = existing.todoItems {
                // Merge: update existing items by ID, add new ones
                var itemMap: [String: TodoItem] = [:]
                for item in existingItems {
                    itemMap[item.id] = item
                }
                for item in todoItems {
                    itemMap[item.id] = item
                }
                finalItems = Array(itemMap.values).sorted { $0.id < $1.id }
            } else {
                // Replace: new todo list
                finalItems = todoItems
            }

            let summary = todoSummary(finalItems)
            messages[existingIndex] = ConversationMessage(
                id: existing.id,
                type: .todo,
                content: summary,
                timestamp: existing.timestamp,
                status: .completed,
                todoItems: finalItems
            )
        } else {
            // Create new todo message
            let summary = todoSummary(todoItems)
            let todoMessage = ConversationMessage(
                type: .todo,
                content: summary,
                status: .completed,
                todoItems: todoItems
            )
            messages.append(todoMessage)
        }
    }

    /// Parse todo items from a TodoWrite event
    private func parseTodoItems(from event: OpenCodeEvent) -> [TodoItem] {
        // Try toolInputDict first (parsed from tool_call)
        if let inputDict = event.toolInputDict {
            return parseTodoItemsFromDict(inputDict)
        }

        // Try parsing from rawJson (fallback)
        guard let data = event.rawJson.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let part = object["part"] as? [String: Any] else {
            return []
        }

        // tool_call format
        if let input = extractInputDict(from: part) {
            return parseTodoItemsFromDict(input)
        }

        // tool_use format
        if let state = part["state"] as? [String: Any],
           let input = extractInputDict(from: state) {
            return parseTodoItemsFromDict(input)
        }

        return []
    }

    /// Parse the "merge" flag from a TodoWrite event
    private func parseTodoMerge(from event: OpenCodeEvent) -> Bool {
        if let inputDict = event.toolInputDict {
            return inputDict["merge"] as? Bool ?? false
        }
        return false
    }

    /// Parse todo items from a dictionary
    private func parseTodoItemsFromDict(_ dict: [String: Any]) -> [TodoItem] {
        guard let todosArray = dict["todos"] as? [[String: Any]] else {
            return []
        }
        return todosArray.compactMap { TodoItem(from: $0) }
    }

    /// Generate a summary string for todo items
    private func todoSummary(_ items: [TodoItem]) -> String {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        return "\(completed)/\(total) tasks completed"
    }

    // MARK: - Log Persistence

    private func logEvent(_ event: OpenCodeEvent) {
        if let session = currentSession {
            let entry = LogEntry(rawJson: event.rawJson, kind: event.kind.rawValue)
            modelContext?.insert(entry)
            session.logs.append(entry)
        }
    }
}

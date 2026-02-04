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
            menuBarState = .idle
            sessionStatus = .completed
            currentToolName = nil
            currentToolInput = nil
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
        } else if message.type == .tool {
            if let toolCallId = message.toolCallId,
               let existingIndex = messages.lastIndex(where: { $0.type == .tool && $0.toolCallId == toolCallId }) {
                let existing = messages[existingIndex]
                let mergedContent = existing.content.isEmpty ? message.content : existing.content
                messages[existingIndex] = ConversationMessage(
                    id: existing.id,
                    type: .tool,
                    content: mergedContent,
                    timestamp: existing.timestamp,
                    toolName: existing.toolName ?? message.toolName,
                    toolInput: existing.toolInput ?? message.toolInput,
                    toolOutput: existing.toolOutput ?? message.toolOutput,
                    toolCallId: existing.toolCallId ?? message.toolCallId,
                    isStreaming: existing.isStreaming
                )
            } else if let lastIndex = messages.lastIndex(where: { $0.type == .tool }),
                      lastIndex == messages.count - 1,
                      messages[lastIndex].toolOutput == nil,
                      message.toolOutput != nil,
                      (message.toolName == "Result" || message.toolName == messages[lastIndex].toolName) {
                let lastMessage = messages[lastIndex]
                let mergedContent = lastMessage.content.isEmpty ? message.content : lastMessage.content
                messages[lastIndex] = ConversationMessage(
                    id: lastMessage.id,
                    type: .tool,
                    content: mergedContent,
                    timestamp: lastMessage.timestamp,
                    toolName: lastMessage.toolName,
                    toolInput: lastMessage.toolInput,
                    toolOutput: message.toolOutput,
                    toolCallId: lastMessage.toolCallId ?? message.toolCallId,
                    isStreaming: lastMessage.isStreaming
                )
            } else {
                messages.append(message)
            }
        } else {
            messages.append(message)
        }

        // @Observable handles change tracking automatically

        if let session = currentSession {
            let entry = LogEntry(rawJson: event.rawJson, kind: event.kind.rawValue)
            modelContext?.insert(entry)
            session.logs.append(entry)
        }
    }
}

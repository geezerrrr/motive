//
//  OpenCodeEvent.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation

// MARK: - Tool Name Display Mapping

extension String {
    /// Simplify tool names for better UI display
    var simplifiedToolName: String {
        switch self {
        case "AskUserQuestion": return "Question"
        case "request_file_permission": return "Permission"
        case "ReadFile", "Read": return "Read"
        case "WriteFile", "Write": return "Write"
        case "EditFile", "Edit": return "Edit"
        case "DeleteFile", "Delete": return "Delete"
        case "ListFiles", "Glob": return "List"
        case "SearchFiles", "Grep": return "Search"
        case "Shell", "Bash": return "Shell"
        case "TodoWrite", "todo_write": return "Todo"
        default: return self
        }
    }

    /// Whether this tool name represents a TodoWrite operation
    var isTodoWriteTool: Bool {
        let normalized = self.lowercased().filter { $0.isLetter || $0.isNumber }
        return normalized == "todowrite" || normalized.hasSuffix("todowrite")
    }
}

// MARK: - Todo Item Model

struct TodoItem: Identifiable, Sendable, Equatable {
    let id: String
    let content: String
    let status: Status

    enum Status: String, Sendable {
        case pending
        case inProgress = "in_progress"
        case completed
        case cancelled
    }

    /// Parse from dictionary (agent tool input format)
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let content = dict["content"] as? String else {
            return nil
        }
        self.id = id
        self.content = content
        let statusStr = dict["status"] as? String ?? "pending"
        self.status = Status(rawValue: statusStr) ?? .pending
    }

    init(id: String, content: String, status: Status) {
        self.id = id
        self.content = content
        self.status = status
    }
}

// MARK: - Message Type for Conversation UI

struct ConversationMessage: Identifiable, Sendable {
    enum MessageType: String, Sendable {
        case user
        case assistant
        case tool
        case system
        case todo       // Dedicated type for todo list display
    }

    enum Status: String, Sendable {
        case pending    // Created, not yet started
        case running    // In progress (tool executing, step processing)
        case completed  // Finished successfully
        case failed     // Finished with error
    }

    let id: UUID
    let type: MessageType
    let content: String
    let timestamp: Date
    let toolName: String?
    let toolInput: String?
    let toolOutput: String?
    let toolCallId: String?
    let status: Status          // Lifecycle status (replaces isStreaming)
    let todoItems: [TodoItem]?  // Parsed todo items for .todo type

    init(
        id: UUID = UUID(),
        type: MessageType,
        content: String,
        timestamp: Date = Date(),
        toolName: String? = nil,
        toolInput: String? = nil,
        toolOutput: String? = nil,
        toolCallId: String? = nil,
        status: Status = .completed,
        todoItems: [TodoItem]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolOutput = toolOutput
        self.toolCallId = toolCallId
        self.status = status
        self.todoItems = todoItems
    }
}

// MARK: - OpenCode Event

struct OpenCodeEvent: Sendable, Identifiable {
    enum Kind: String, Sendable {
        case thought
        case call
        case diff
        case finish
        case unknown
        case user
        case assistant  // text message from AI
        case tool       // tool_call / tool_use
    }

    let id: UUID
    let kind: Kind
    let rawJson: String
    let text: String
    let toolName: String?
    let toolInput: String?
    let toolInputDict: [String: Any]?  // Full tool input for AskUserQuestion/TodoWrite parsing
    let toolOutput: String?
    let toolCallId: String?
    let sessionId: String?
    /// Whether this is a secondary/redundant finish event (session.idle, process exit)
    let isSecondaryFinish: Bool

    init(id: UUID = UUID(), kind: Kind, rawJson: String, text: String, toolName: String? = nil, toolInput: String? = nil, toolInputDict: [String: Any]? = nil, toolOutput: String? = nil, toolCallId: String? = nil, sessionId: String? = nil, isSecondaryFinish: Bool = false) {
        self.id = id
        self.kind = kind
        self.rawJson = rawJson
        self.text = text
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolInputDict = toolInputDict
        self.toolOutput = toolOutput
        self.toolCallId = toolCallId
        self.sessionId = sessionId
        self.isSecondaryFinish = isSecondaryFinish
    }

    /// Parse OpenCode CLI JSON output
    /// Based on: https://github.com/accomplish-ai/openwork/blob/main/packages/shared/src/types/opencode.ts
    init(rawJson: String) {
        let trimmed = rawJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip non-JSON lines (terminal decorations, etc.)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            self.init(kind: .unknown, rawJson: rawJson, text: trimmed.isEmpty ? "" : trimmed)
            return
        }

        // Get message type
        let messageType = object["type"] as? String ?? ""
        let part = object["part"] as? [String: Any]
        let sessionId = part?["sessionID"] as? String ?? object["sessionID"] as? String
        
        switch messageType {
        case "text":
            // AI text response: { type: "text", part: { text: "..." } }
            let text = part?["text"] as? String ?? ""
            self.init(kind: .assistant, rawJson: rawJson, text: text, sessionId: sessionId)
            
        case "tool_call":
            // Tool call: { type: "tool_call", part: { tool: "Read", input: {...} } }
            let toolName = part?["tool"] as? String ?? "Tool"
            var inputStr: String? = nil
            let inputDict = OpenCodeEvent.extractToolInputDict(from: part)
            let toolCallId = OpenCodeEvent.extractToolCallId(from: part)
            if let inputDict {
                // Extract meaningful info from tool input
                if let path = inputDict["filePath"] as? String {
                    inputStr = path
                } else if let path = inputDict["path"] as? String {
                    inputStr = path
                } else if let command = inputDict["command"] as? String {
                    inputStr = command
                } else if let description = inputDict["description"] as? String {
                    inputStr = description
                }
            }
            self.init(kind: .tool, rawJson: rawJson, text: inputStr ?? "", toolName: toolName, toolInput: inputStr, toolInputDict: inputDict, toolCallId: toolCallId, sessionId: sessionId)
            
        case "tool_use":
            // Tool use (combined): { type: "tool_use", part: { tool: "Read", state: { status, input, output } } }
            let toolName = part?["tool"] as? String ?? "Tool"
            var inputStr: String? = nil
            let state = part?["state"] as? [String: Any]
            let inputDict = OpenCodeEvent.extractToolInputDict(from: state)
            let outputStr = state?["output"] as? String
            let toolCallId = OpenCodeEvent.extractToolCallId(from: state) ?? OpenCodeEvent.extractToolCallId(from: part)
            if let inputDict {
                if let path = inputDict["filePath"] as? String {
                    inputStr = path
                } else if let path = inputDict["path"] as? String {
                    inputStr = path
                } else if let command = inputDict["command"] as? String {
                    inputStr = command
                }
            }
            let label = OpenCodeEvent.toolDisplayLabel(toolInput: inputStr)
            self.init(kind: .tool, rawJson: rawJson, text: label, toolName: toolName, toolInput: inputStr, toolInputDict: inputDict, toolOutput: outputStr, toolCallId: toolCallId, sessionId: sessionId)
            
        case "tool_result":
            // Tool result: { type: "tool_result", part: { output: "..." } }
            let output = part?["output"] as? String ?? ""
            let toolCallId = OpenCodeEvent.extractToolCallId(from: part)
            // text is empty — output is accessed via toolOutputSummary + expand
            self.init(kind: .tool, rawJson: rawJson, text: "", toolName: "Result", toolOutput: output, toolCallId: toolCallId, sessionId: sessionId)
            
        case "step_start":
            // Step started
            self.init(kind: .thought, rawJson: rawJson, text: "Processing...", sessionId: sessionId)
            
        case "step_finish":
            // Step finished
            let reason = part?["reason"] as? String ?? "done"
            if reason == "stop" || reason == "end_turn" {
                self.init(kind: .finish, rawJson: rawJson, text: "Completed", sessionId: sessionId)
            } else {
                self.init(kind: .thought, rawJson: rawJson, text: "", sessionId: sessionId)
            }
            
        case "error":
            // Error message
            let errorText = object["error"] as? String ?? "Unknown error"
            self.init(kind: .unknown, rawJson: rawJson, text: errorText, sessionId: sessionId)
            
        default:
            // Unknown message type - try to extract any useful text
            let message = OpenCodeEvent.extractString(from: object, keys: ["message", "text", "content", "summary", "detail"])
            self.init(kind: .unknown, rawJson: rawJson, text: message ?? "", sessionId: sessionId)
        }
    }

    private static func extractString(from object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
            if let value = object[key] as? [String: Any],
               let nested = value["text"] as? String,
               !nested.isEmpty {
                return nested
            }
        }
        return nil
    }

    private static func extractToolInputDict(from container: [String: Any]?) -> [String: Any]? {
        guard let container else { return nil }
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

    private static func extractToolCallId(from container: [String: Any]?) -> String? {
        guard let container else { return nil }
        if let id = container["id"] as? String, !id.isEmpty {
            return id
        }
        if let id = container["toolCallId"] as? String, !id.isEmpty {
            return id
        }
        if let id = container["toolCallID"] as? String, !id.isEmpty {
            return id
        }
        if let id = container["callId"] as? String, !id.isEmpty {
            return id
        }
        return nil
    }

    /// Extract a display label for the tool message `text` field.
    /// This ONLY returns the tool input (path, command, etc.) — never raw output content.
    /// Output summarization is handled separately by `toolOutputSummary`.
    private static func toolDisplayLabel(toolInput: String?) -> String {
        guard let toolInput = toolInput, !toolInput.isEmpty else { return "" }
        return toolInput
    }
    
    /// Convert to ConversationMessage for UI display
    func toMessage() -> ConversationMessage? {
        // Skip empty messages and step events
        if text.isEmpty && kind != .finish {
            if case .tool = kind, toolName != nil {
                // Allow tool messages with empty input so we can show "tool started"
            } else {
                return nil
            }
        }
        if text.isEmpty && kind != .finish && kind != .tool {
            return nil
        }
        
        let messageType: ConversationMessage.MessageType
        let messageStatus: ConversationMessage.Status
        
        switch kind {
        case .user:
            messageType = .user
            messageStatus = .completed
        case .assistant:
            messageType = .assistant
            messageStatus = .completed
        case .tool, .call:
            // Tool calls without output are still running
            // Tool calls with output (tool_use) are completed
            messageType = .tool
            messageStatus = toolOutput != nil ? .completed : .running
        case .thought:
            return nil // Don't show thought events as messages
        case .diff:
            messageType = .tool
            messageStatus = .completed
        case .finish:
            messageType = .system
            messageStatus = .completed
        case .unknown:
            if text.isEmpty { return nil }
            messageType = .system
            messageStatus = .completed
        }
        
        return ConversationMessage(
            id: id,
            type: messageType,
            content: text,
            toolName: toolName ?? (kind == .call ? "Command" : nil),
            toolInput: toolInput,
            toolOutput: toolOutput,
            toolCallId: toolCallId,
            status: messageStatus
        )
    }
}

extension ConversationMessage {
    /// Uniform output summary — always "Output · N lines", never raw content.
    /// Clicking "Show" in the UI reveals the actual output.
    var toolOutputSummary: String? {
        guard let toolOutput = toolOutput, !toolOutput.isEmpty else { return nil }
        let trimmed = toolOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Prefer explicit line-count marker from OpenCode (e.g., Read tool)
        if let range = trimmed.range(of: "End of file - total ") {
            let suffix = trimmed[range.upperBound...]
            let countStr = suffix.prefix { $0.isNumber }
            if let count = Int(countStr) {
                return "Output · \(count) lines"
            }
        }

        // Count actual lines — always show as "N lines"
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = max(lines.count, 1)
        return "Output · \(lineCount) \(lineCount == 1 ? "line" : "lines")"
    }
}

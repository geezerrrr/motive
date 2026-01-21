//
//  OpenCodeEvent.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation

// MARK: - Message Type for Conversation UI

struct ConversationMessage: Identifiable, Sendable {
    enum MessageType: String, Sendable {
        case user
        case assistant
        case tool
        case system
    }
    
    let id: UUID
    let type: MessageType
    let content: String
    let timestamp: Date
    let toolName: String?
    let toolInput: String?
    let isStreaming: Bool
    
    init(
        id: UUID = UUID(),
        type: MessageType,
        content: String,
        timestamp: Date = Date(),
        toolName: String? = nil,
        toolInput: String? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.toolName = toolName
        self.toolInput = toolInput
        self.isStreaming = isStreaming
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
    let toolInputDict: [String: Any]?  // Full tool input for AskUserQuestion parsing
    let sessionId: String?

    init(id: UUID = UUID(), kind: Kind, rawJson: String, text: String, toolName: String? = nil, toolInput: String? = nil, toolInputDict: [String: Any]? = nil, sessionId: String? = nil) {
        self.id = id
        self.kind = kind
        self.rawJson = rawJson
        self.text = text
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolInputDict = toolInputDict
        self.sessionId = sessionId
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
            let inputDict = part?["input"] as? [String: Any]
            if let inputDict = inputDict {
                // Extract meaningful info from tool input
                if let path = inputDict["path"] as? String {
                    inputStr = path
                } else if let command = inputDict["command"] as? String {
                    inputStr = command
                } else if let description = inputDict["description"] as? String {
                    inputStr = description
                }
            }
            self.init(kind: .tool, rawJson: rawJson, text: inputStr ?? "", toolName: toolName, toolInput: inputStr, toolInputDict: inputDict, sessionId: sessionId)
            
        case "tool_use":
            // Tool use (combined): { type: "tool_use", part: { tool: "Read", state: { status, input, output } } }
            let toolName = part?["tool"] as? String ?? "Tool"
            var inputStr: String? = nil
            let state = part?["state"] as? [String: Any]
            let inputDict = state?["input"] as? [String: Any]
            if let state = state {
                if let output = state["output"] as? String, !output.isEmpty {
                    // Tool completed with output
                    inputStr = String(output.prefix(100))
                } else if let inputDict = inputDict {
                    if let path = inputDict["path"] as? String {
                        inputStr = path
                    } else if let command = inputDict["command"] as? String {
                        inputStr = command
                    }
                }
            }
            self.init(kind: .tool, rawJson: rawJson, text: inputStr ?? "", toolName: toolName, toolInput: inputStr, toolInputDict: inputDict, sessionId: sessionId)
            
        case "tool_result":
            // Tool result: { type: "tool_result", part: { output: "..." } }
            let output = part?["output"] as? String ?? ""
            self.init(kind: .tool, rawJson: rawJson, text: String(output.prefix(200)), toolName: "Result", sessionId: sessionId)
            
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
    
    /// Convert to ConversationMessage for UI display
    func toMessage() -> ConversationMessage? {
        // Skip empty messages and step events
        if text.isEmpty && kind != .finish {
            return nil
        }
        
        let messageType: ConversationMessage.MessageType
        switch kind {
        case .user:
            messageType = .user
        case .assistant:
            messageType = .assistant
        case .tool, .call:
            messageType = .tool
        case .thought:
            return nil // Don't show thought events as messages
        case .diff:
            messageType = .tool
        case .finish:
            messageType = .system
        case .unknown:
            if text.isEmpty { return nil }
            messageType = .system
        }
        
        return ConversationMessage(
            id: id,
            type: messageType,
            content: text,
            toolName: toolName ?? (kind == .call ? "Command" : nil),
            toolInput: toolInput
        )
    }
}

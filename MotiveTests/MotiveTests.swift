//
//  MotiveTests.swift
//  MotiveTests
//
//  Created by geezerrrr on 2026/1/19.
//

import Testing
@testable import Motive

struct MotiveTests {

    @Test func parsesAssistantTextEvent() async throws {
        let json = #"{"type":"text","part":{"text":"Hello"},"sessionID":"session-1"}"#
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .assistant)
        #expect(event.text == "Hello")
        #expect(event.sessionId == "session-1")
    }
    
    @Test func parsesToolCallWithPath() async throws {
        let json = #"{"type":"tool_call","part":{"tool":"Read","input":{"path":"/tmp/file.txt"}}}"#
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .tool)
        #expect(event.toolName == "Read")
        #expect(event.toolInput == "/tmp/file.txt")
        #expect(event.text == "/tmp/file.txt")
    }
    
    @Test func parsesStepFinishAsCompletion() async throws {
        let json = #"{"type":"step_finish","part":{"reason":"stop"}}"#
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .finish)
        #expect(event.text == "Completed")
        #expect(event.isSecondaryFinish == false)
    }
    
    @Test func simplifiedToolNameMapsKnownTools() async throws {
        #expect("ReadFile".simplifiedToolName == "Read")
        #expect("Write".simplifiedToolName == "Write")
        #expect("AskUserQuestion".simplifiedToolName == "Question")
        #expect("Shell".simplifiedToolName == "Shell")
        #expect("TodoWrite".simplifiedToolName == "Todo")
    }
    
    @Test func toMessageSkipsThoughtEvents() async throws {
        let json = #"{"type":"step_start","part":{"text":"Thinking"}}"#
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .thought)
        #expect(event.toMessage() == nil)
    }
    
    @Test func toMessageMapsToolCall() async throws {
        let json = #"{"type":"tool_call","part":{"tool":"Write","input":{"path":"/tmp/a.txt"}}}"#
        let event = OpenCodeEvent(rawJson: json)
        let message = event.toMessage()
        
        #expect(message?.type == .tool)
        #expect(message?.toolName == "Write")
        #expect(message?.toolInput == "/tmp/a.txt")
        #expect(message?.content == "/tmp/a.txt")
    }

    // MARK: - Tool Status Lifecycle

    @Test func toolCallStartsAsRunning() async throws {
        let json = #"{"type":"tool_call","part":{"tool":"Read","input":{"path":"/tmp/test.txt"}}}"#
        let event = OpenCodeEvent(rawJson: json)
        let message = event.toMessage()

        #expect(message?.status == .running)
    }

    @Test func toolUseWithOutputIsCompleted() async throws {
        let json = #"{"type":"tool_use","part":{"tool":"Read","state":{"input":{"path":"/tmp/test.txt"},"output":"contents"}}}"#
        let event = OpenCodeEvent(rawJson: json)
        let message = event.toMessage()

        #expect(message?.status == .completed)
    }

    // MARK: - TodoItem Parsing

    @Test func parsesTodoItem() async throws {
        let dict: [String: Any] = [
            "id": "1",
            "content": "Fix the bug",
            "status": "in_progress"
        ]
        let item = TodoItem(from: dict)

        #expect(item != nil)
        #expect(item?.id == "1")
        #expect(item?.content == "Fix the bug")
        #expect(item?.status == .inProgress)
    }

    @Test func parsesTodoItemDefaultStatus() async throws {
        let dict: [String: Any] = [
            "id": "2",
            "content": "Write docs"
        ]
        let item = TodoItem(from: dict)

        #expect(item != nil)
        #expect(item?.status == .pending)
    }

    @Test func todoWriteToolNameDetection() async throws {
        #expect("TodoWrite".isTodoWriteTool == true)
        #expect("todo_write".isTodoWriteTool == true)
        #expect("mcp/TodoWrite".isTodoWriteTool == false) // isTodoWriteTool checks lowercased filter
        #expect("Read".isTodoWriteTool == false)
    }

    // MARK: - Secondary Finish

    @Test func secondaryFinishIsMarked() async throws {
        let event = OpenCodeEvent(
            kind: .finish,
            rawJson: "",
            text: "Session idle",
            isSecondaryFinish: true
        )

        #expect(event.isSecondaryFinish == true)
        #expect(event.kind == .finish)
    }

    @Test func primaryFinishIsNotSecondary() async throws {
        let json = #"{"type":"step_finish","part":{"reason":"end_turn"}}"#
        let event = OpenCodeEvent(rawJson: json)

        #expect(event.kind == .finish)
        #expect(event.isSecondaryFinish == false)
    }
}

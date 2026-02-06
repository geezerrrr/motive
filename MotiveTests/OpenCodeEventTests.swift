//
//  OpenCodeEventTests.swift
//  MotiveTests
//
//  Tests for OpenCodeEvent JSON parsing.
//

import Testing
@testable import Motive

@Suite("OpenCodeEvent Parsing")
struct OpenCodeEventTests {
    
    // MARK: - Text Message Parsing
    
    @Test("parses text message correctly")
    func parseTextMessage() {
        let json = """
        {"type":"text","part":{"text":"Hello, world!","sessionID":"abc123"}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .assistant)
        #expect(event.text == "Hello, world!")
        #expect(event.sessionId == "abc123")
    }
    
    @Test("parses empty text message")
    func parseEmptyTextMessage() {
        let json = """
        {"type":"text","part":{"text":"","sessionID":"abc123"}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .assistant)
        #expect(event.text == "")
    }
    
    // MARK: - Tool Call Parsing
    
    @Test("parses tool_call with path input")
    func parseToolCallWithPath() {
        let json = """
        {"type":"tool_call","part":{"tool":"Read","input":{"path":"/tmp/test.txt"}}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .tool)
        #expect(event.toolName == "Read")
        #expect(event.toolInput == "/tmp/test.txt")
    }
    
    @Test("parses tool_call with command input")
    func parseToolCallWithCommand() {
        let json = """
        {"type":"tool_call","part":{"tool":"Shell","input":{"command":"ls -la"}}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .tool)
        #expect(event.toolName == "Shell")
        #expect(event.toolInput == "ls -la")
    }
    
    // MARK: - Tool Use Parsing
    
    @Test("parses tool_use with output")
    func parseToolUseWithOutput() {
        let json = """
        {"type":"tool_use","part":{"tool":"Read","state":{"status":"complete","input":{"path":"/tmp/test.txt"},"output":"file contents"}}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .tool)
        #expect(event.toolName == "Read")
        #expect(event.toolOutput == "file contents")
    }
    
    // MARK: - Step Events
    
    @Test("parses step_start event")
    func parseStepStart() {
        let json = """
        {"type":"step_start","part":{}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .thought)
    }
    
    @Test("parses step_finish with stop reason")
    func parseStepFinishStop() {
        let json = """
        {"type":"step_finish","part":{"reason":"stop"}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .finish)
        #expect(event.isSecondaryFinish == false)
    }
    
    @Test("parses step_finish with end_turn reason")
    func parseStepFinishEndTurn() {
        let json = """
        {"type":"step_finish","part":{"reason":"end_turn"}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .finish)
        #expect(event.isSecondaryFinish == false)
    }
    
    // MARK: - Error Parsing
    
    @Test("parses error event")
    func parseError() {
        let json = """
        {"type":"error","error":"Something went wrong"}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        
        #expect(event.kind == .unknown)
        #expect(event.text == "Something went wrong")
    }
    
    // MARK: - Invalid JSON
    
    @Test("handles invalid JSON gracefully")
    func handleInvalidJson() {
        let notJson = "This is not JSON"
        
        let event = OpenCodeEvent(rawJson: notJson)
        
        #expect(event.kind == .unknown)
    }
    
    @Test("handles empty input")
    func handleEmptyInput() {
        let event = OpenCodeEvent(rawJson: "")
        
        #expect(event.kind == .unknown)
        #expect(event.text == "")
    }
    
    // MARK: - Message Conversion
    
    @Test("converts text event to message")
    func convertTextToMessage() {
        let json = """
        {"type":"text","part":{"text":"Hello!"}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        let message = event.toMessage()
        
        #expect(message != nil)
        #expect(message?.type == .assistant)
        #expect(message?.content == "Hello!")
        #expect(message?.status == .completed)
    }
    
    @Test("converts tool event to message with running status")
    func convertToolToMessage() {
        let json = """
        {"type":"tool_call","part":{"tool":"Read","input":{"path":"/tmp/test.txt"}}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        let message = event.toMessage()
        
        #expect(message != nil)
        #expect(message?.type == .tool)
        #expect(message?.toolName == "Read")
        #expect(message?.status == .running)
    }
    
    @Test("skips thought events in message conversion")
    func skipThoughtEvents() {
        let json = """
        {"type":"step_start","part":{}}
        """
        
        let event = OpenCodeEvent(rawJson: json)
        let message = event.toMessage()
        
        #expect(message == nil)
    }

    // MARK: - Tool Lifecycle Status

    @Test("tool_call creates running message, tool_use creates completed message")
    func toolLifecycleStatus() {
        let callJson = """
        {"type":"tool_call","part":{"tool":"Shell","input":{"command":"echo hi"}}}
        """
        let callEvent = OpenCodeEvent(rawJson: callJson)
        let callMessage = callEvent.toMessage()
        #expect(callMessage?.status == .running)

        let useJson = """
        {"type":"tool_use","part":{"tool":"Shell","state":{"input":{"command":"echo hi"},"output":"hi"}}}
        """
        let useEvent = OpenCodeEvent(rawJson: useJson)
        let useMessage = useEvent.toMessage()
        #expect(useMessage?.status == .completed)
    }

    // MARK: - TodoItem Parsing

    @Test("parses todo items from dict")
    func parseTodoItems() {
        let dict: [String: Any] = [
            "id": "task-1",
            "content": "Implement feature X",
            "status": "completed"
        ]
        let item = TodoItem(from: dict)

        #expect(item != nil)
        #expect(item?.id == "task-1")
        #expect(item?.content == "Implement feature X")
        #expect(item?.status == .completed)
    }

    @Test("rejects invalid todo item")
    func rejectInvalidTodo() {
        let dict: [String: Any] = [
            "id": "task-1"
            // Missing "content"
        ]
        let item = TodoItem(from: dict)
        #expect(item == nil)
    }

    @Test("detects TodoWrite tool names")
    func detectTodoWriteToolNames() {
        #expect("TodoWrite".isTodoWriteTool == true)
        #expect("Read".isTodoWriteTool == false)
        #expect("Shell".isTodoWriteTool == false)
    }
}

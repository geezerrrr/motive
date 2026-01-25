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
    }
    
    @Test func simplifiedToolNameMapsKnownTools() async throws {
        #expect("ReadFile".simplifiedToolName == "Read")
        #expect("Write".simplifiedToolName == "Write")
        #expect("AskUserQuestion".simplifiedToolName == "Question")
        #expect("Shell".simplifiedToolName == "Shell")
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

}

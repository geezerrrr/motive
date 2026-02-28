@testable import Motive
import Testing

struct SSEClientTests {

    // MARK: - SSE Event Parsing

    @Test func parsesTextDeltaEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "messageID": "msg-1",
                    "type": "text"
                },
                "delta": "Hello "
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .textDelta(info) = event else {
            Issue.record("Expected textDelta event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.delta == "Hello ")
    }

    @Test func parsesTextCompleteEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "messageID": "msg-1",
                    "type": "text",
                    "text": "Hello world",
                    "time": {"start": 1234, "end": 5678}
                }
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .textComplete(info) = event else {
            Issue.record("Expected textComplete event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.text == "Hello world")
    }

    @Test func parsesToolRunningEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "tool",
                    "state": {
                        "tool": "Read",
                        "status": "running",
                        "id": "call-1",
                        "input": {"path": "/tmp/test.txt"}
                    }
                }
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .toolRunning(info) = event else {
            Issue.record("Expected toolRunning event")
            return
        }
        #expect(info.toolName == "Read")
        #expect(info.toolCallID == "call-1")
        #expect(info.inputSummary == "/tmp/test.txt")
    }

    @Test func parsesToolCompletedEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "tool",
                    "state": {
                        "tool": "Read",
                        "status": "completed",
                        "id": "call-1",
                        "output": "file contents here"
                    }
                }
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .toolCompleted(info) = event else {
            Issue.record("Expected toolCompleted event")
            return
        }
        #expect(info.toolName == "Read")
        #expect(info.output == "file contents here")
    }

    @Test func parsesPlanExitCompletedAsBuildAgentChange() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "tool",
                    "state": {
                        "tool": "plan_exit",
                        "status": "completed"
                    }
                }
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .agentChanged(info) = event else {
            Issue.record("Expected agentChanged event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.agent == "build")
    }

    @Test func parsesPlanEnterCompletedAsPlanAgentChange() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "tool",
                    "state": {
                        "tool": "plan_enter",
                        "status": "completed"
                    }
                }
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .agentChanged(info) = event else {
            Issue.record("Expected agentChanged event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.agent == "plan")
    }

    @Test func parsesSessionIdleEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "session.status",
            "properties": {
                "sessionID": "session-1",
                "status": {"type": "idle"}
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .sessionIdle(sessionID) = event else {
            Issue.record("Expected sessionIdle event")
            return
        }
        #expect(sessionID == "session-1")
    }

    @Test func parsesQuestionAskedEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "question.asked",
            "properties": {
                "id": "q-1",
                "sessionID": "session-1",
                "questions": [
                    {
                        "question": "How should I organize?",
                        "options": [
                            {"label": "By type", "description": "Group by file type"},
                            {"label": "By date", "description": "Group by date"}
                        ],
                        "multiple": false,
                        "custom": true
                    }
                ]
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .questionAsked(request) = event else {
            Issue.record("Expected questionAsked event")
            return
        }
        #expect(request.id == "q-1")
        #expect(request.sessionID == "session-1")
        #expect(request.questions.count == 1)
        #expect(request.questions[0].question == "How should I organize?")
        #expect(request.questions[0].options.count == 2)
        #expect(request.questions[0].options[0].label == "By type")
        #expect(request.questions[0].custom == true)
    }

    @Test func parsesPermissionAskedEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "permission.asked",
            "properties": {
                "id": "p-1",
                "sessionID": "session-1",
                "permission": "edit",
                "patterns": ["src/main.ts"],
                "metadata": {"diff": "removed line"},
                "always": ["src/**"]
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .permissionAsked(request) = event else {
            Issue.record("Expected permissionAsked event")
            return
        }
        #expect(request.id == "p-1")
        #expect(request.sessionID == "session-1")
        #expect(request.permission == "edit")
        #expect(request.patterns == ["src/main.ts"])
        #expect(request.metadata["diff"] == "removed line")
        #expect(request.always == ["src/**"])
    }

    @Test func parsesConnectedEvent() async {
        let client = SSEClient()
        let json = """
        {"type": "server.connected", "properties": {}}
        """

        let event = await client.parseSSEData(json)
        guard case .connected = event else {
            Issue.record("Expected connected event")
            return
        }
    }

    @Test func parsesHeartbeatEvent() async {
        let client = SSEClient()
        let json = """
        {"type": "server.heartbeat", "properties": {}}
        """

        let event = await client.parseSSEData(json)
        guard case .heartbeat = event else {
            Issue.record("Expected heartbeat event")
            return
        }
    }

    @Test func parsesGlobalEnvelopeWithDirectory() async {
        let client = SSEClient()
        let json = """
        {
            "directory": "/Users/geezerrrr/Workspace/OpenSources/motive-web",
            "payload": {
                "type": "session.status",
                "properties": {
                    "sessionID": "session-1",
                    "status": {"type": "idle"}
                }
            }
        }
        """

        let scoped = await client.parseGlobalSSEData(json)
        #expect(scoped?.directory == "/Users/geezerrrr/Workspace/OpenSources/motive-web")
        guard case let .sessionIdle(sessionID) = scoped?.event else {
            Issue.record("Expected sessionIdle event inside global envelope")
            return
        }
        #expect(sessionID == "session-1")
    }

    @Test func parsesGlobalEnvelopeWithoutDirectory() async {
        let client = SSEClient()
        let json = """
        {
            "payload": {
                "type": "server.connected",
                "properties": {}
            }
        }
        """

        let scoped = await client.parseGlobalSSEData(json)
        #expect(scoped?.directory == nil)
        guard case .connected = scoped?.event else {
            Issue.record("Expected connected event inside global envelope")
            return
        }
    }

    @Test func returnsNilForInvalidJSON() async {
        let client = SSEClient()
        let result = await client.parseSSEData("not json")
        #expect(result == nil)
    }

    @Test func returnsNilForUnknownEventType() async {
        let client = SSEClient()
        let json = """
        {"type": "unknown.event", "properties": {}}
        """
        let result = await client.parseSSEData(json)
        #expect(result == nil)
    }

    // MARK: - Tool Error Parsing

    @Test func parsesToolErrorEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "tool",
                    "state": {
                        "tool": "Bash",
                        "status": "error",
                        "id": "call-2",
                        "error": "Permission denied"
                    }
                }
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .toolError(info) = event else {
            Issue.record("Expected toolError event")
            return
        }
        #expect(info.toolName == "Bash")
        #expect(info.error == "Permission denied")
        #expect(info.toolCallID == "call-2")
    }

    // MARK: - Reasoning Delta

    @Test func parsesReasoningDeltaEvent() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "reasoning"
                },
                "delta": "Let me think about this..."
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .reasoningDelta(info) = event else {
            Issue.record("Expected reasoningDelta event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.delta == "Let me think about this...")
    }

    // MARK: - Session Status Parsing

    @Test func parsesSessionBusyStatus() async {
        let client = SSEClient()
        let json = """
        {
            "type": "session.status",
            "properties": {
                "sessionID": "session-1",
                "status": {"type": "busy"}
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .sessionStatus(info) = event else {
            Issue.record("Expected sessionStatus event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.status == "busy")
    }

    // MARK: - Question with Multiple Options

    @Test func parsesQuestionWithMultipleSelectAndNoCustom() async {
        let client = SSEClient()
        let json = """
        {
            "type": "question.asked",
            "properties": {
                "id": "q-2",
                "sessionID": "session-1",
                "questions": [
                    {
                        "question": "Select files to include:",
                        "options": [
                            {"label": "README.md"},
                            {"label": "CHANGELOG.md"},
                            {"label": "LICENSE"}
                        ],
                        "multiple": true,
                        "custom": false
                    }
                ]
            }
        }
        """

        let event = await client.parseSSEData(json)
        guard case let .questionAsked(request) = event else {
            Issue.record("Expected questionAsked event")
            return
        }
        #expect(request.questions[0].multiple == true)
        #expect(request.questions[0].custom == false)
        #expect(request.questions[0].options.count == 3)
        #expect(request.questions[0].options[2].label == "LICENSE")
        #expect(request.questions[0].options[0].description == nil)
    }

    // MARK: - Edge Cases

    @Test func handlesEmptyPropertiesGracefully() async {
        let client = SSEClient()
        let json = """
        {"type": "session.status", "properties": {}}
        """

        let event = await client.parseSSEData(json)
        // Should return sessionStatus (not idle since empty type)
        guard case let .sessionStatus(info) = event else {
            Issue.record("Expected sessionStatus event")
            return
        }
        #expect(info.sessionID == "")
        #expect(info.status == "")
    }

    @Test func parsesTextPartWithoutDeltaOrEndTime() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "type": "text"
                }
            }
        }
        """

        // No delta, no end time → should return nil
        let event = await client.parseSSEData(json)
        #expect(event == nil)
    }

    @Test func parsesTextSnapshotAsIncrementalDelta() async {
        let client = SSEClient()
        let first = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "id": "prt-1",
                    "sessionID": "session-1",
                    "messageID": "msg-1",
                    "type": "text",
                    "text": "Hello"
                }
            }
        }
        """
        let second = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "id": "prt-1",
                    "sessionID": "session-1",
                    "messageID": "msg-1",
                    "type": "text",
                    "text": "Hello world"
                }
            }
        }
        """

        let firstEvent = await client.parseSSEData(first)
        guard case let .textDelta(firstInfo) = firstEvent else {
            Issue.record("Expected textDelta for first full-text snapshot")
            return
        }
        #expect(firstInfo.delta == "Hello")

        let secondEvent = await client.parseSSEData(second)
        guard case let .textDelta(secondInfo) = secondEvent else {
            Issue.record("Expected textDelta for second full-text snapshot")
            return
        }
        #expect(secondInfo.delta == " world")
    }

    // MARK: - User Message Filtering

    @Test func skipsTextDeltaForUserMessages() async {
        let client = SSEClient()

        // First, a message.updated with role "user" registers the message ID
        let messageUpdated = """
        {
            "type": "message.updated",
            "properties": {
                "info": {
                    "id": "msg-user-1",
                    "sessionID": "session-1",
                    "role": "user"
                }
            }
        }
        """
        let updateEvent = await client.parseSSEData(messageUpdated)
        #expect(updateEvent == nil)

        // Then, a text part update for this user message should be skipped
        let textPart = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "messageID": "msg-user-1",
                    "type": "text"
                },
                "delta": "Hello, do this for me"
            }
        }
        """
        let textEvent = await client.parseSSEData(textPart)
        #expect(textEvent == nil)
    }

    @Test func allowsTextDeltaForAssistantMessages() async {
        let client = SSEClient()

        // message.updated with role "assistant"
        let messageUpdated = """
        {
            "type": "message.updated",
            "properties": {
                "info": {
                    "id": "msg-asst-1",
                    "sessionID": "session-1",
                    "role": "assistant"
                }
            }
        }
        """
        _ = await client.parseSSEData(messageUpdated)

        // Text part for assistant message should NOT be skipped
        let textPart = """
        {
            "type": "message.part.updated",
            "properties": {
                "part": {
                    "sessionID": "session-1",
                    "messageID": "msg-asst-1",
                    "type": "text"
                },
                "delta": "Sure, I can help"
            }
        }
        """
        let textEvent = await client.parseSSEData(textPart)
        guard case let .textDelta(info) = textEvent else {
            Issue.record("Expected textDelta event for assistant message")
            return
        }
        #expect(info.delta == "Sure, I can help")
    }

    @Test func parsesMessageUpdatedUsage() async {
        let client = SSEClient()
        let json = """
        {
            "type": "message.updated",
            "properties": {
                "info": {
                    "id": "msg-1",
                    "sessionID": "session-1",
                    "model": "openai/gpt-4o",
                    "cost": 0.02,
                    "tokens": {
                        "input": 1200,
                        "output": 300,
                        "reasoning": 50,
                        "cache": {"read": 10, "write": 5}
                    }
                }
            }
        }
        """
        let event = await client.parseSSEData(json)
        guard case let .usageUpdated(info) = event else {
            Issue.record("Expected usageUpdated event")
            return
        }
        #expect(info.sessionID == "session-1")
        #expect(info.model == "openai/gpt-4o")
        #expect(info.usage.input == 1200)
        #expect(info.usage.cacheRead == 10)
    }
}

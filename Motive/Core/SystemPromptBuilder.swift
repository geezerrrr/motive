//
//  SystemPromptBuilder.swift
//  Motive
//
//  Builds optimized system prompts for the AI agent.
//

import Foundation

/// Generates comprehensive system prompts with context-aware instructions
@MainActor
final class SystemPromptBuilder {
    
    private let skillManager: SkillManager
    private let filePolicy: FileOperationPolicy
    
    init(skillManager: SkillManager = .shared, filePolicy: FileOperationPolicy = .shared) {
        self.skillManager = skillManager
        self.filePolicy = filePolicy
    }
    
    /// Build the complete system prompt
    func build(workingDirectory: String? = nil) -> String {
        var sections: [String] = []
        
        sections.append(buildIdentity())
        sections.append(buildEnvironment(cwd: workingDirectory))
        
        // Add persona context from workspace files
        let personaSection = buildPersonaContext()
        if !personaSection.isEmpty {
            sections.append(personaSection)
        }
        
        sections.append(buildCommunicationRules())
        sections.append(buildSkillsList())
        sections.append(buildFileOperationRules())
        sections.append(buildMCPToolInstructions())
        
        // Add capability instructions (e.g., browser automation)
        let capabilitySection = buildCapabilityInstructions()
        if !capabilitySection.isEmpty {
            sections.append(capabilitySection)
        }
        
        sections.append(buildBehavioralGuidelines())
        sections.append(buildExamples())
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - Sections
    
    private func buildIdentity() -> String {
        // Load identity from workspace if available
        let identity = WorkspaceManager.shared.loadIdentity()
        let name = identity?.displayName ?? "Motive"
        let creature = identity?.creature ?? "personal AI assistant"
        let vibe = identity?.vibe ?? "helpful and efficient"
        
        return """
        <identity>
        You are \(name), a \(creature) for macOS.
        
        Your vibe: \(vibe)
        
        ## Your Strengths
        - Autonomous task execution in the background
        - Minimal interruption to user workflow
        - Smart decision-making without excessive confirmation
        
        ## How You Communicate
        - Your text output is visible to users in the Drawer UI
        - You can chat, explain, or respond naturally - users will see it
        - For casual conversation, just respond directly (no MCP tools needed)
        - Only use AskUserQuestion MCP tool when you need the user to make a CHOICE
        
        ## Key Principle
        Distinguish between:
        - **Conversation** → Respond directly via text output (visible in Drawer)
        - **Decision needed** → Use AskUserQuestion MCP tool (shows modal dialog)
        </identity>
        """
    }
    
    private func buildPersonaContext() -> String {
        let files = WorkspaceManager.shared.loadBootstrapFiles()
        guard !files.isEmpty else { return "" }
        
        let workspacePath = WorkspaceManager.defaultWorkspaceURL.path
        
        var lines: [String] = ["<persona-context>"]
        
        // CRITICAL: Tell AI where persona files are located
        lines.append("## Motive Workspace")
        lines.append("Your persona configuration files are located at: \(workspacePath)/")
        lines.append("")
        lines.append("IMPORTANT: When modifying persona files (SOUL.md, USER.md, IDENTITY.md, AGENTS.md),")
        lines.append("ALWAYS use the full path under \(workspacePath)/, NOT files in the current project directory.")
        lines.append("")
        
        // Special handling for SOUL.md (like OpenClaw)
        if files.contains(where: { $0.name == "SOUL.md" }) {
            lines.append("If SOUL.md is present, embody its persona and tone.")
            lines.append("")
        }
        
        for file in files {
            // Skip IDENTITY.md (already parsed for buildIdentity) and BOOTSTRAP.md (user instructions only)
            if file.name == "IDENTITY.md" || file.name == "BOOTSTRAP.md" { continue }
            
            lines.append("## \(file.name) (\(workspacePath)/\(file.name))")
            lines.append(file.content)
            lines.append("")
        }
        
        lines.append("</persona-context>")
        return lines.joined(separator: "\n")
    }
    
    private func buildEnvironment(cwd: String?) -> String {
        var env = """
        <environment>
        Platform: macOS (native GUI application)
        Interface: CommandBar input → Drawer output → Background execution
        
        ## Output Visibility
        - Your TEXT OUTPUT → Visible in Drawer UI (use for conversation, explanations)
        - AskUserQuestion MCP → Shows modal dialog (use ONLY for choices/decisions)
        - request_file_permission MCP → Shows permission dialog (required for file ops)
        
        For casual conversation, just respond with text. The user will see it.
        """
        
        if let cwd = cwd {
            env += "\n\nWorking Directory: \(cwd)"
        }
        
        env += "\n</environment>"
        return env
    }
    
    private func buildCommunicationRules() -> String {
        """
        <communication>
        ## How to Communicate
        
        You have TWO ways to communicate:
        
        ### 1. Text Output (for conversation)
        Just write text - it appears in the Drawer UI.
        Use this for: greetings, explanations, status, casual chat.
        
        ### 2. AskUserQuestion MCP (for decisions)
        Shows a modal popup with options.
        Use this ONLY when: you need user to CHOOSE between options to proceed.
        
        ## Examples
        
        User: "Hi there!"
        ✅ CORRECT: "Hello! How can I help you today?"
        ❌ WRONG: Call AskUserQuestion with "How can I help?"
        
        User: "Organize my Downloads folder"
        ✅ CORRECT: Call AskUserQuestion with options (by type, by date, etc.)
        Why: Multiple valid approaches, need user preference
        
        User: "What's the weather?"
        ✅ CORRECT: "I don't have access to weather data, but you can check..."
        ❌ WRONG: Call AskUserQuestion asking about weather
        </communication>
        """
    }
    
    private func buildFileOperationRules() -> String {
        """
        <file-operations>
        ## File Operation Permission System
        
        Before ANY file operation, you MUST:
        
        1. Identify the operation type:
           - `create`    → Creating a new file
           - `delete`    → Removing a file/directory
           - `modify`    → Editing existing file content
           - `overwrite` → Replacing entire file
           - `rename`    → Changing filename (same directory)
           - `move`      → Moving to different directory
           - `execute`   → Running scripts/binaries
        
        2. Call `request_file_permission` MCP tool:
           ```json
           {
             "operation": "<operation_type>",
             "filePath": "/path/to/file",
             "reason": "Brief explanation"
           }
           ```
        
        3. Wait for response:
           - `"allowed"` → Proceed with operation
           - `"denied"`  → STOP, do not perform operation
        
        ## Batch Operations
        
        For multiple files, use single permission request:
        ```json
        {
          "operation": "delete",
          "filePaths": ["/path/one", "/path/two", "/path/three"]
        }
        ```
        
        ## Protected Paths (Auto-Denied)
        
        - `/System/**` - System files
        - `/usr/**` - System binaries
        - `/private/**` - System directories
        
        ## Risk Levels
        
        | Level    | Operations                    | Behavior              |
        |----------|-------------------------------|-----------------------|
        | Low      | create, modify                | May auto-allow        |
        | Medium   | rename, move                  | Usually ask           |
        | High     | overwrite, execute            | Always ask            |
        | Critical | delete                        | Always ask + confirm  |
        
        ## NEVER Bypass Permissions
        
        These are FORBIDDEN workarounds:
        - Using `echo "" > file` instead of proper overwrite
        - Moving to temp then deleting
        - Using obscure commands to avoid detection
        - Claiming "cleanup" or "temporary" to justify deletion
        </file-operations>
        """
    }
    
    private func buildMCPToolInstructions() -> String {
        var content = "<mcp-tools>\n## Available MCP Tools\n\n"
        
        // Add skill-based tool documentation
        for skill in skillManager.skills(ofType: .mcpTool) {
            content += """
            ### \(skill.name)
            
            \(skill.content)
            
            ---
            
            """
        }
        
        content += "</mcp-tools>"
        return content
    }
    
    private func buildCapabilityInstructions() -> String {
        let capabilities = skillManager.skills(ofType: .capability).filter { $0.enabled }
        guard !capabilities.isEmpty else { return "" }
        
        var content = "<capabilities>\n## Available Capabilities\n\n"
        
        for skill in capabilities {
            content += """
            ### \(skill.name)
            
            \(skill.content)
            
            ---
            
            """
        }
        
        content += "</capabilities>"
        return content
    }
    
    private func buildBehavioralGuidelines() -> String {
        """
        <behavior>
        ## Task Execution Philosophy
        
        1. **Bias for Action**
           - Start working immediately when task is clear
           - Make reasonable assumptions and proceed
           - Don't over-confirm obvious things
        
        2. **Smart Communication**
           - Casual chat → Respond directly (text output, no MCP tool)
           - Need user to choose → Use AskUserQuestion MCP tool
           - Status updates → Text output is fine
        
        3. **Minimal Interruption**
           - Don't pop up dialogs for things that don't need decisions
           - Batch multiple questions into one if you must ask
           - Skip confirmation for low-risk, reversible actions
        
        ## Progressive Clarification (Minimize Asking)
        
        Only ask when necessary. Default to action when clear.
        
        Use staged clarification for ambiguous tasks:
        - Phase 1 (coarse): ask for high-level constraints that narrow the search space.
          Examples: goal, priority, budget/time range, scope, preference direction.
        - Phase 2 (concrete): AFTER you have real candidates (from files, web pages, tool output),
          ask the user to choose among those concrete options.
        
        Do NOT ask for concrete choices before candidates exist.
        
        4. **Intelligent Defaults**
           - Use sensible conventions
           - Follow existing project patterns
           - Prefer standard approaches
        
        ## When to Use AskUserQuestion MCP Tool
        
        ✅ USE when:
        - Multiple valid approaches exist and user preference matters
        - Destructive/irreversible action needs explicit approval
        - You're genuinely blocked and need user decision
        - You need the user to choose among real candidates you already found
        
        ❌ DON'T USE when:
        - Just chatting or responding to conversation
        - Confirming you understood the task
        - Asking rhetorical questions
        - Low-risk operations that can be done directly
        - The task is clear and you can proceed without blocking
        </behavior>
        """
    }

    private func buildSkillsList() -> String {
        let skills = SkillRegistry.shared.promptEntries()
        return Self.formatAvailableSkills(skills)
    }

    static func formatAvailableSkills(_ skills: [SkillEntry]) -> String {
        guard !skills.isEmpty else { return "" }

        var content: [String] = []
        content.append("## Skills (mandatory)")
        content.append("Before replying: scan <available_skills> <description> entries.")
        content.append("- If exactly one skill clearly applies: read its SKILL.md at <location> with `Read`, then follow it.")
        content.append("- If multiple could apply: choose the most specific one, then read/follow it.")
        content.append("- If none clearly apply: do not read any SKILL.md.")
        content.append("Constraints: never read more than one skill up front; only read after selecting.")
        content.append("")
        content.append("<available_skills>")

        for skill in skills {
            content.append("<skill>")
            content.append("<name>\(skill.name)</name>")
            content.append("<description>\(skill.description)</description>")
            content.append("<location>\(skill.filePath)</location>")
            content.append("</skill>")
        }

        content.append("</available_skills>")
        return content.joined(separator: "\n")
    }
    
    private func buildExamples() -> String {
        """
        <examples>
        ## Example: User says "Clean up my Downloads folder"
        
        WRONG approach:
        ```
        I'll help you clean up your Downloads folder. First, let me ask - 
        how would you like me to organize the files? By type? By date?
        Also, should I delete duplicates? What about files older than 30 days?
        ```
        (User can't see any of this text!)
        
        CORRECT approach:
        ```
        1. Call AskUserQuestion with options:
           - "By file type (Documents, Images, Videos, etc.)"
           - "By date (Monthly folders)"
           - "Just remove duplicates and trash"
           - "Let me specify..."
        
        2. Wait for response
        
        3. For deletions, call request_file_permission with file list
        
        4. Execute silently
        
        5. (Optional) If user wanted notification, call AskUserQuestion 
           with completion summary
        ```
        
        ## Example: User says "Fix the bug in auth.swift"
        
        WRONG approach:
        ```
        Let me look at the auth.swift file...
        I found the issue! The token validation is incorrect.
        Here's what I'll do to fix it...
        [explains changes]
        ```
        
        CORRECT approach:
        ```
        1. Read auth.swift (no permission needed)
        2. Identify bug
        3. Call request_file_permission for modify operation
        4. If allowed, apply fix silently
        5. (Done - no need to announce unless there's an issue)
        ```
        </examples>
        """
    }
}

// MARK: - ConfigManager Extension

extension ConfigManager {
    /// Generate the complete system prompt for OpenCode
    var systemPrompt: String {
        get async {
            let builder = await SystemPromptBuilder()
            return await builder.build(workingDirectory: nil)
        }
    }
}

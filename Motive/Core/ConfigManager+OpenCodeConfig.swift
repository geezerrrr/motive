import Foundation

@MainActor
extension ConfigManager {
    /// Sync ALL provider API keys to OpenCode's auth.json
    /// Path: ~/.local/share/opencode/auth.json
    func syncToOpenCodeAuth() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let authDir = homeDir.appendingPathComponent(".local/share/opencode")
        let authPath = authDir.appendingPathComponent("auth.json")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        
        // Read existing auth.json or create new
        var auth: [String: [String: String]] = [:]
        if let data = try? Data(contentsOf: authPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            auth = existing
        }
        
        // Only sync current provider's API key (to avoid multiple keychain prompts)
        let providerName = provider.openCodeProviderName
        
        // Use the cached apiKey property instead of direct keychain read
        let apiKeyValue = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKeyValue.isEmpty && provider.requiresAPIKey {
            auth[providerName] = [
                "type": "api",
                "key": apiKeyValue
            ]
            Log.config(" Synced \(providerName) API key to auth.json")
        }
        
        // Write back
        if let jsonData = try? JSONSerialization.data(withJSONObject: auth, options: .prettyPrinted) {
            try? jsonData.write(to: authPath)
            Log.config(" Synced auth.json to \(authPath.path)")
        }
    }
    
    /// Generate opencode.json config file
    /// Path: ~/.motive/config/opencode.json
    ///
    /// IMPORTANT: This must ALWAYS be generated to set permission: "allow"
    /// Without this, OpenCode CLI blocks waiting for permission prompts that never show in GUI
    func generateOpenCodeConfig() {
        // Config now goes to workspace directory (~/.motive/config/)
        let configDir = workspaceDirectory.appendingPathComponent("config")
        let configPath = configDir.appendingPathComponent("opencode.json")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        // Determine provider name for OpenCode
        let providerName = provider.openCodeProviderName
        
        let baseURLValue = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // MCP scripts stay in workspace for user access
        let mcpDir = workspaceDirectory.appendingPathComponent("mcp")
        let mcpScripts = McpScriptManager.ensureScripts(in: mcpDir)
        let nodePath = resolveNodePath()
        if let nodePath {
            Log.config(" Resolved node path for MCP: \(nodePath)")
        } else {
            Log.config(" WARNING - Node not found in PATH. MCP will use /usr/bin/env node")
        }
        
        // System prompt - build using SkillManager for capability instructions
        let builder = SystemPromptBuilder()
        let fullSystemPrompt = builder.build()
        
        // Add critical GUI communication rules at the beginning
        let systemPrompt = """
<important name="user-communication">
CRITICAL: The user CANNOT see your text output or CLI prompts!
You are running in a GUI app where terminal output is hidden.

To ask ANY question or get user input, you MUST use the AskUserQuestion MCP tool.

MANDATORY: You MUST ALWAYS include the "options" array when calling AskUserQuestion.
The user interface REQUIRES options to display properly. Questions without options will fail.

Rules for AskUserQuestion:
1. ALWAYS include "options" array with 2-4 choices - THIS IS REQUIRED, NOT OPTIONAL
2. ALWAYS include an "Other" option for custom input
3. Keep headers short (max 12 characters)
4. Each option must have "label" and optionally "description"

CORRECT example (with options - REQUIRED):
{
  "questions": [{
    "question": "How should I rename the files?",
    "header": "Rename",
    "options": [
      { "label": "Keep original", "description": "Keep the original filename" },
      { "label": "Use English", "description": "Translate to English names" },
      { "label": "Add prefix", "description": "Add a prefix like file_001" },
      { "label": "Other", "description": "Let me specify custom naming" }
    ],
    "multiSelect": false
  }]
}

WRONG example (missing options - DO NOT DO THIS):
{
  "questions": [{
    "question": "How should I rename?",
    "header": "Rename"
  }]
}

Before WRITE operations (create, delete, rename, move, modify, overwrite),
you MUST call the request_file_permission tool and wait for the response.

IMPORTANT: Reading files does NOT require permission. Do not call request_file_permission for Read, Glob, Grep, or any read-only operation.

Never attempt to prompt via CLI or rely on terminal prompts - they will not work!
</important>

\(fullSystemPrompt)
"""
        
        // Build skill permissions using WHITELIST approach
        // Default: deny all, then explicitly allow enabled skills
        var skillPermissions: [String: String] = ["*": "deny"]
        
        // Get enabled skills and add them to allow list
        let skillsConfig = self.skillsConfig
        for entry in SkillRegistry.shared.entries {
            let skillKey = entry.metadata?.skillKey ?? entry.name
            let entryConfig = skillsConfig.entries[skillKey] ?? skillsConfig.entries[entry.name]
            
            // Check if skill is enabled using priority:
            // 1. User explicit config > 2. metadata.defaultEnabled (defaults to false)
            let isEnabled: Bool
            if let explicitEnabled = entryConfig?.enabled {
                isEnabled = explicitEnabled
            } else {
                // Use metadata.defaultEnabled, defaulting to false if not specified
                isEnabled = entry.metadata?.defaultEnabled ?? false
            }
            
            if isEnabled {
                skillPermissions[entry.name] = "allow"
                Log.config(" Skill '\(entry.name)' is enabled -> allow")
            }
        }
        
        // Build config - always include permission: "allow"
        let permissionRules: [String: Any] = [
            "*": "allow",
            // Allow external directories to avoid CLI prompts (e.g., ~/Downloads)
            "external_directory": "allow",
            // Block OpenCode's built-in question prompt (CLI-only),
            // but keep MCP ask-user-question available via skills.
            "question": "deny",
            // Skill-level permissions using WHITELIST (deny all, allow specific)
            "skill": skillPermissions
        ]
        var config: [String: Any] = [
            "$schema": "https://opencode.ai/config.json",
            "default_agent": "motive",
            "enabled_providers": [providerName],
            // CRITICAL: Auto-allow all permissions - CLI prompts don't show in GUI
            "permission": permissionRules,
            "agent": [
                "motive": [
                    "description": "Motive default agent with UI permission flow",
                    "prompt": systemPrompt,
                    "mode": "primary",
                    // Explicitly allow question/tool permissions for UI prompts
                    "permission": permissionRules,
                    // Disable OpenCode built-in question tool (CLI-only)
                    "tools": [
                        "question": false
                    ]
                ]
            ]
        ]
        
        // Add provider options (baseURL) if configured
        // Per OpenCode docs: set options.baseURL on the provider directly
        if !baseURLValue.isEmpty {
            config["provider"] = [
                providerName: [
                    "options": [
                        "baseURL": baseURLValue
                    ]
                ]
            ]
            Log.config(" Provider '\(providerName)' configured with baseURL: \(baseURLValue)")
        }

        if let mcpScripts {
            let filePermissionCommand: [String]
            let askUserCommand: [String]
            if let nodePath {
                filePermissionCommand = [nodePath, mcpScripts.filePermission]
                askUserCommand = [nodePath, mcpScripts.askUserQuestion]
                Log.config(" MCP using node at: \(nodePath)")
            } else {
                filePermissionCommand = ["/usr/bin/env", "node", mcpScripts.filePermission]
                askUserCommand = ["/usr/bin/env", "node", mcpScripts.askUserQuestion]
                Log.config(" MCP using /usr/bin/env node (node not found in PATH)")
            }
            Log.config(" MCP file-permission script: \(mcpScripts.filePermission)")
            Log.config(" MCP ask-user-question script: \(mcpScripts.askUserQuestion)")
            
            // Verify scripts exist
            if FileManager.default.fileExists(atPath: mcpScripts.filePermission) {
                Log.config(" MCP file-permission script EXISTS")
            } else {
                Log.config(" WARNING - MCP file-permission script NOT FOUND")
            }
            if FileManager.default.fileExists(atPath: mcpScripts.askUserQuestion) {
                Log.config(" MCP ask-user-question script EXISTS")
            } else {
                Log.config(" WARNING - MCP ask-user-question script NOT FOUND")
            }
            
            config["mcp"] = [
                "file-permission": [
                    "type": "local",
                    "command": filePermissionCommand,
                    "enabled": true,
                    "environment": [
                        "PERMISSION_API_PORT": "9226"
                    ],
                    "timeout": 10000
                ],
                "ask-user-question": [
                    "type": "local",
                    "command": askUserCommand,
                    "enabled": true,
                    "environment": [
                        "QUESTION_API_PORT": "9227"
                    ],
                    "timeout": 10000
                ]
            ]
        } else {
            Log.config(" WARNING - MCP scripts not created!")
        }

        // Merge MCP tools from skills (if enabled)
        if skillsSystemEnabled {
            let skillMcp = SkillRegistry.shared.buildMcpConfigEntries()
            if !skillMcp.isEmpty {
                var existing = config["mcp"] as? [String: Any] ?? [:]
                for (key, value) in skillMcp where existing[key] == nil {
                    existing[key] = value
                }
                config["mcp"] = existing
            }
        }
        
        // Write config
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try jsonData.write(to: configPath)
            Log.config(" Generated OpenCode config at \(configPath.path)")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Log.config(" Config content: \(jsonString.prefix(500))")
            }
            
            // Store config path for environment variable
            openCodeConfigPath = configPath.path
            openCodeConfigDir = workspaceDirectory.path
            
            // Write SKILL.md files for OpenCode to discover MCP tools
            // OpenCode looks for skills at $OPENCODE_CONFIG_DIR/skills/<name>/SKILL.md
            SkillManager.shared.writeSkillFiles(to: workspaceDirectory)
        } catch {
            Log.config(" ERROR - Failed to write OpenCode config: \(error)")
        }
    }

    func resolveNodePath() -> String? {
        let path = buildExtendedPath(base: ProcessInfo.processInfo.environment["PATH"])
        let candidates = path.split(separator: ":").map { "\($0)/node" }
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

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

        // Read existing auth.json or create new.
        // Entries are kept as untyped JSON: OAuth entries contain non-string values
        // (e.g. numeric `expires`) and must be preserved as-is.
        var auth: [String: Any] = [:]
        if let data = try? Data(contentsOf: authPath), !data.isEmpty {
            guard let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Log.config(" Skipped auth.json sync: existing file at \(authPath.path) could not be parsed")
                return
            }
            auth = existing
        }

        // Only sync current provider's API key (to avoid multiple keychain prompts)
        let providerName = provider.openCodeProviderName

        // Use the cached apiKey property instead of direct keychain read
        let apiKeyValue = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // Sync API key for providers that require it, OR for providers with optional auth (e.g. LM Studio with auth enabled)
        if !apiKeyValue.isEmpty, provider.requiresAPIKey || provider.allowsOptionalAPIKey {
            auth[providerName] = [
                "type": "api",
                "key": apiKeyValue
            ]
            Log.config(" Synced \(providerName) API key to auth.json")
        }

        // Legacy provider ID cleanup (provider removed from UI/config).
        if auth["openai-compatible"] != nil {
            auth.removeValue(forKey: "openai-compatible")
            Log.config(" Removed legacy 'openai-compatible' entry from auth.json")
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
    /// Uses ToolPermissionPolicy for permission rules and OpenCode's
    /// native question/permission system (no MCP sidecar needed).
    func generateOpenCodeConfig() {
        let promptBuilder = SystemPromptBuilder()
        let permissionPolicy = ToolPermissionPolicy.shared

        // Build agent configurations
        var agents: [OpenCodeConfigGenerator.AgentConfig] = []
        let systemPrompt = promptBuilder.build()
        let permissionRules = permissionPolicy.toOpenCodePermissionRules()

        // Primary agent
        agents.append(OpenCodeConfigGenerator.AgentConfig(
            name: "agent",
            description: "Default agent - full tool access",
            prompt: systemPrompt,
            mode: "primary",
            permission: permissionRules
        ))

        // Plan agent (read-only analysis)
        let planPrompt = promptBuilder.build(sessionType: .plan)
        var readOnlyRules = permissionRules
        readOnlyRules["edit"] = "deny"
        readOnlyRules["bash"] = "ask"
        agents.append(OpenCodeConfigGenerator.AgentConfig(
            name: "plan",
            description: "Read-only analysis and planning",
            prompt: planPrompt,
            mode: "primary",
            permission: readOnlyRules
        ))

        let inputs = OpenCodeConfigGenerator.Inputs(
            providerName: provider.openCodeProviderName,
            provider: provider,
            baseURL: normalizedBaseURL,
            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            workspaceDirectory: workspaceDirectory,
            skillsSystemEnabled: skillsSystemEnabled,
            compactionEnabled: compactionEnabled,
            memoryEnabled: memoryEnabled,
            agents: agents,
            defaultAgent: currentAgent
        )
        let result = OpenCodeConfigGenerator.generate(
            inputs: inputs,
            permissionPolicy: permissionPolicy,
            skillRegistry: SkillRegistry.shared,
            skillManager: SkillManager.shared,
            promptBuilder: promptBuilder
        )
        openCodeConfigPath = result.configPath
        openCodeConfigDir = result.configDir
    }
}

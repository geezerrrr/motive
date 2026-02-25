//
//  ConfigManager.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class ConfigManager: ObservableObject, SkillConfigProvider {
    enum Provider: String, CaseIterable, Identifiable {
        // Primary providers (most common)
        case claude
        case openai
        case gemini
        case ollama

        // Cloud providers
        case openrouter
        case mistral
        case groq
        case xai
        case cohere
        case deepinfra
        case deepseek
        case minimax
        case alibaba
        case moonshotai
        case zhipuai
        case perplexity

        /// Enterprise / Cloud
        case bedrock

        /// Local OpenAI-compatible endpoint
        case lmstudio

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .claude: "Claude"
            case .openai: "OpenAI"
            case .gemini: "Gemini"
            case .ollama: "Ollama"
            case .openrouter: "OpenRouter"
            case .mistral: "Mistral"
            case .groq: "Groq"
            case .xai: "xAI"
            case .cohere: "Cohere"
            case .deepinfra: "DeepInfra"
            case .deepseek: "DeepSeek"
            case .minimax: "MiniMax"
            case .alibaba: "Alibaba"
            case .moonshotai: "Moonshot"
            case .zhipuai: "Zhipu"
            case .perplexity: "Perplexity"
            case .bedrock: "Bedrock"
            case .lmstudio: "LM Studio"
            }
        }

        /// OpenCode provider name used in config
        var openCodeProviderName: String {
            switch self {
            case .claude: "anthropic"
            case .openai: "openai"
            case .gemini: "google"
            case .ollama: "ollama"
            case .openrouter: "openrouter"
            case .mistral: "mistral"
            case .groq: "groq"
            case .xai: "xai"
            case .cohere: "cohere"
            case .deepinfra: "deepinfra"
            case .deepseek: "deepseek"
            case .minimax: "minimax"
            case .alibaba: "alibaba"
            case .moonshotai: "moonshotai"
            case .zhipuai: "zhipuai"
            case .perplexity: "perplexity"
            case .bedrock: "amazon-bedrock"
            case .lmstudio: "lmstudio"
            }
        }

        /// Candidate provider IDs used to match OpenCode `/provider` registry entries.
        /// Includes aliases because upstream IDs can vary across versions.
        var modelRegistryProviderIDs: [String] {
            switch self {
            case .claude: ["anthropic", "claude"]
            case .openai: ["openai"]
            case .gemini: ["google", "gemini"]
            case .ollama: ["ollama"]
            case .openrouter: ["openrouter"]
            case .mistral: ["mistral"]
            case .groq: ["groq"]
            case .xai: ["xai"]
            case .cohere: ["cohere"]
            case .deepinfra: ["deepinfra"]
            case .deepseek: ["deepseek"]
            case .minimax: ["minimax"]
            case .alibaba: ["alibaba", "dashscope"]
            case .moonshotai: ["moonshotai", "moonshotai-cn", "kimi-for-coding"]
            case .zhipuai: ["zhipuai", "zai", "zai-coding-plan", "zhipuai-coding-plan"]
            case .perplexity: ["perplexity"]
            case .bedrock: ["amazon-bedrock", "bedrock"]
            case .lmstudio: ["lmstudio", "openai-compatible", "openai"]
            }
        }

        /// Whether this provider requires an API key
        var requiresAPIKey: Bool {
            switch self {
            case .ollama: false
            default: true
            }
        }

        /// Whether this provider supports an optional API key (e.g. LM Studio/Ollama with auth enabled)
        var allowsOptionalAPIKey: Bool {
            switch self {
            case .lmstudio, .ollama: true
            default: false
            }
        }

        /// Environment variable name for API key
        var envKeyName: String {
            switch self {
            case .claude: "ANTHROPIC_API_KEY"
            case .openai: "OPENAI_API_KEY"
            case .gemini: "GOOGLE_GENERATIVE_AI_API_KEY"
            case .ollama: ""
            case .lmstudio: "OPENAI_API_KEY"
            case .openrouter: "OPENROUTER_API_KEY"
            case .mistral: "MISTRAL_API_KEY"
            case .groq: "GROQ_API_KEY"
            case .xai: "XAI_API_KEY"
            case .cohere: "COHERE_API_KEY"
            case .deepinfra: "DEEPINFRA_API_KEY"
            case .deepseek: "DEEPSEEK_API_KEY"
            case .minimax: "MINIMAX_API_KEY"
            case .alibaba: "DASHSCOPE_API_KEY"
            case .moonshotai: "MOONSHOT_API_KEY"
            case .zhipuai: "ZHIPU_API_KEY"
            case .perplexity: "PERPLEXITY_API_KEY"
            case .bedrock: "AWS_ACCESS_KEY_ID"
            }
        }

        /// Default model for the provider
        var defaultModel: String {
            switch self {
            case .claude: "claude-sonnet-4-5-20250929"
            case .openai: "gpt-5.1-codex"
            case .gemini: "gemini-3-pro-preview"
            case .ollama: "llama3"
            case .openrouter: "anthropic/claude-sonnet-4"
            case .mistral: "mistral-large-latest"
            case .groq: "llama-3.3-70b-versatile"
            case .xai: "grok-3-mini"
            case .cohere: "command-r-plus"
            case .deepinfra: "meta-llama/Llama-3.3-70B-Instruct"
            case .deepseek: "deepseek-chat"
            case .minimax: "MiniMax-M1"
            case .alibaba: "qwen3-coder-480b-a35b-instruct"
            case .moonshotai: "kimi-k2.5"
            case .zhipuai: "glm-5"
            case .perplexity: "llama-3.1-sonar-large-128k-online"
            case .bedrock: "anthropic.claude-3-5-sonnet-20241022-v2:0"
            case .lmstudio: "default"
            }
        }
    }

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var localizedName: String {
            switch self {
            case .system: L10n.Settings.themeSystem
            case .light: L10n.Settings.themeLight
            case .dark: L10n.Settings.themeDark
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum LiquidGlassMode: String, CaseIterable, Identifiable {
        case clear
        case tinted

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .clear: L10n.Settings.liquidGlassClear
            case .tinted: L10n.Settings.liquidGlassTinted
            }
        }
    }

    enum CommandBarPosition: String, CaseIterable, Identifiable {
        case center
        case topLeading
        case topMiddle
        case topTrailing
        case bottomLeading
        case bottomMiddle
        case bottomTrailing

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .center: L10n.Settings.positionCenter
            case .topLeading: L10n.Settings.positionTopLeading
            case .topMiddle: L10n.Settings.positionTopMiddle
            case .topTrailing: L10n.Settings.positionTopTrailing
            case .bottomLeading: L10n.Settings.positionBottomLeading
            case .bottomMiddle: L10n.Settings.positionBottomMiddle
            case .bottomTrailing: L10n.Settings.positionBottomTrailing
            }
        }

        var isBottom: Bool {
            switch self {
            case .bottomLeading, .bottomMiddle, .bottomTrailing: true
            default: false
            }
        }
    }

    @AppStorage("provider") var providerRawValue: String = Provider.claude.rawValue

    @AppStorage("openCodeBinarySourcePath") var openCodeBinarySourcePath: String = ""
    @AppStorage("debugMode") var debugMode: Bool = false
    @AppStorage("launchAtLoginStorage") private var launchAtLoginStorage: Bool = false
    @AppStorage("languageRawValue") var languageRawValue: String = Language.system.rawValue

    // Browser automation settings (browser-use-sidecar)
    @AppStorage("browserUseEnabled") var browserUseEnabled: Bool = false
    @AppStorage("browserUseHeadedMode") var browserUseHeadedMode: Bool = true // Show browser window by default
    @AppStorage("browserAgentProvider") var browserAgentProviderRaw: String = "anthropic"
    var cachedBrowserAgentAPIKey: String?
    @AppStorage("browserAgentBaseUrl_anthropic") var browserAgentBaseUrlAnthropic: String = ""
    @AppStorage("browserAgentBaseUrl_openai") var browserAgentBaseUrlOpenAI: String = ""

    // Skills system (OpenClaw-style)
    @AppStorage("skillsSystemEnabled") var skillsSystemEnabled: Bool = true
    @AppStorage("skillsConfigJSON") var skillsConfigJSON: String = ""

    /// Context compaction
    @AppStorage("compactionEnabled") var compactionEnabled: Bool = true

    /// Memory system
    @AppStorage("memoryEnabled") var memoryEnabled: Bool = true

    /// Multi-agent
    @AppStorage("currentAgent") var currentAgent: String = "agent"

    /// Trust level — controls how aggressively the AI operates
    @AppStorage("trustLevel") var trustLevelRawValue: String = TrustLevel.balanced.rawValue

    /// Token usage totals (per model)
    @AppStorage("tokenUsageTotalsJSON") var tokenUsageTotalsJSON: String = "{}"

    @AppStorage("commandBarPosition") var commandBarPositionRaw: String = CommandBarPosition.center.rawValue

    var commandBarPosition: CommandBarPosition {
        get { CommandBarPosition(rawValue: commandBarPositionRaw) ?? .center }
        set { commandBarPositionRaw = newValue.rawValue }
    }

    var trustLevel: TrustLevel {
        get { TrustLevel(rawValue: trustLevelRawValue) ?? .balanced }
        set {
            trustLevelRawValue = newValue.rawValue
            ToolPermissionPolicy.shared.applyTrustLevel(newValue)
            generateOpenCodeConfig()
        }
    }

    @AppStorage("hotkey") var hotkey: String = "⌥Space"
    @AppStorage("appearanceMode") var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage("liquidGlassMode") var liquidGlassModeRaw: String = LiquidGlassMode.clear.rawValue

    var liquidGlassMode: LiquidGlassMode {
        get { LiquidGlassMode(rawValue: liquidGlassModeRaw) ?? .clear }
        set { liquidGlassModeRaw = newValue.rawValue }
    }

    /// Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // Project directory
    @AppStorage("currentProjectPath") var currentProjectPath: String = ""
    @AppStorage("recentProjectsJSON") var recentProjectsJSON: String = "[]"

    /// Launch at Login with actual ServiceManagement implementation
    var launchAtLogin: Bool {
        get { launchAtLoginStorage }
        set {
            launchAtLoginStorage = newValue
            updateLaunchAtLogin(newValue)
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                Log.config(" Registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                Log.config(" Unregistered from launch at login")
            }
        } catch {
            Log.config(" Failed to update launch at login: \(error)")
        }
    }

    let providerConfigStore = ProviderConfigStore()

    // MARK: - Extracted Managers

    lazy var binaryManager: BinaryManager = .init(
        getSourcePath: { [weak self] in self?.openCodeBinarySourcePath ?? "" },
        setSourcePath: { [weak self] in self?.openCodeBinarySourcePath = $0 },
        setBinaryStatus: { [weak self] in self?.binaryStatus = $0 }
    )

    lazy var usageTracker: UsageTracker = .init(
        getJSON: { [weak self] in self?.tokenUsageTotalsJSON ?? "{}" },
        setJSON: { [weak self] in self?.tokenUsageTotalsJSON = $0 }
    )

    lazy var projectManager: ProjectManager = .init(
        getCurrentPath: { [weak self] in self?.currentProjectPath ?? "" },
        setCurrentPath: { [weak self] in self?.currentProjectPath = $0 },
        getRecentJSON: { [weak self] in self?.recentProjectsJSON ?? "[]" },
        setRecentJSON: { [weak self] in self?.recentProjectsJSON = $0 }
    )

    let keychainService = "com.velvet.motive"

    // Cache API keys and base URLs per provider
    var cachedAPIKeys: [Provider: String] = [:]
    var cachedBaseURLs: [Provider: String] = [:]

    /// Migrate legacy per-account keychain items to unified storage
    /// This ensures only ONE authorization prompt for all API keys
    private func migrateKeychainIfNeeded() {
        // Build list of all possible legacy account names
        var legacyAccounts: [String] = []

        // AI provider accounts
        for provider in Provider.allCases {
            legacyAccounts.append("opencode.api.key.\(provider.rawValue)")
        }

        // Browser agent accounts
        for provider in Provider.allCases {
            legacyAccounts.append("browser.agent.api.key.\(provider.rawValue)")
        }

        KeychainStore.migrateToUnifiedStorage(service: keychainService, accounts: legacyAccounts)
    }

    /// Preload current provider's API key and base URL into cache.
    /// Call this once at startup to trigger Keychain prompt early.
    /// Now triggers only ONE prompt thanks to unified storage.
    func preloadAPIKeys() {
        // First, migrate any legacy keychain items (one-time)
        migrateKeychainIfNeeded()

        // Migrate base URLs from UserDefaults to Keychain (one-time)
        migrateBaseURLsIfNeeded()

        // Read current provider's key (single unified Keychain read)
        let account = "opencode.api.key.\(provider.rawValue)"
        let value = KeychainStore.read(service: keychainService, account: account) ?? ""
        cachedAPIKeys[provider] = value

        // Preload base URL
        let baseURLAccount = "opencode.base.url.\(provider.rawValue)"
        let baseURLValue = KeychainStore.read(service: keychainService, account: baseURLAccount)
            ?? providerConfigStore.defaultBaseURL(for: provider)
        cachedBaseURLs[provider] = baseURLValue

        // Read browser agent key from the same unified storage (no additional prompt)
        if browserUseEnabled {
            let browserAccount = "browser.agent.api.key.\(browserAgentProvider.rawValue)"
            let browserValue = KeychainStore.read(service: keychainService, account: browserAccount) ?? ""
            cachedBrowserAgentAPIKey = browserValue
        }
    }

    /// One-time migration of base URLs from UserDefaults to Keychain.
    private func migrateBaseURLsIfNeeded() {
        let migrationKey = "baseURLMigratedToKeychain"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        for p in Provider.allCases {
            let legacyValue = providerConfigStore.baseURL(for: p)
            let defaultValue = providerConfigStore.defaultBaseURL(for: p)
            // Only migrate non-default, non-empty values
            if !legacyValue.isEmpty, legacyValue != defaultValue {
                let account = "opencode.base.url.\(p.rawValue)"
                KeychainStore.write(service: keychainService, account: account, value: legacyValue)
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Status for UI
    var binaryStatus: BinaryStatus = .notConfigured

    enum BinaryStatus: Equatable {
        case notConfigured
        case ready(String) // path
        case error(String)
    }

    var provider: Provider {
        get { Provider(rawValue: providerRawValue) ?? .claude }
        set {
            providerRawValue = newValue.rawValue
            // @Observable handles change tracking automatically
        }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRawValue) ?? .system }
        set {
            appearanceModeRawValue = newValue.rawValue
            applyAppearance(newValue)
        }
    }

    /// Apply the appearance mode to the application
    func applyAppearance(_ mode: AppearanceMode? = nil) {
        let targetMode = mode ?? appearanceMode
        switch targetMode {
        case .system:
            NSApp.appearance = nil // Follow system
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Path to generated opencode.json config
    @AppStorage("openCodeConfigPath") var openCodeConfigPath: String = ""
    @AppStorage("openCodeConfigDir") var openCodeConfigDir: String = ""

    // MARK: - Stale State Detection

    /// Detect and reset stale UserDefaults when data directories were deleted.
    ///
    /// UserDefaults (plist at ~/Library/Preferences/) survives even when users
    /// delete ~/.motive/ and ~/Library/Application Support/Motive/.
    /// This causes stale project paths, usage stats, and skill configs to persist
    /// after a "clean reinstall", leading to confusing behavior.
    ///
    /// Detection: if ~/.motive/ doesn't exist but hasCompletedOnboarding is true,
    /// the user deleted data directories and expects a fresh start.
    func detectAndResetStaleState() {
        let workspaceDir = WorkspaceManager.defaultWorkspaceURL
        let workspaceExists = FileManager.default.fileExists(atPath: workspaceDir.path)

        guard !workspaceExists, hasCompletedOnboarding else {
            return // Normal state: workspace exists, or first-ever launch
        }

        Log.config("Detected stale UserDefaults: ~/.motive/ missing but onboarding completed. Resetting data-dependent state.")

        // Reset data-tied state (these reference deleted directories or sessions)
        currentProjectPath = ""
        recentProjectsJSON = "[]"
        tokenUsageTotalsJSON = "{}"

        // Reset onboarding so user goes through setup again
        hasCompletedOnboarding = false

        // Note: we intentionally KEEP user preferences:
        // - provider, model, baseURL (user's AI configuration)
        // - skillsConfigJSON (user's skill enable/disable choices)
        // - hotkey, appearanceMode, language (UI preferences)
        // - browserUseEnabled, trustLevel (feature preferences)
        // - API keys (stored in Keychain, not affected by plist)

        Log.config("Stale state reset complete. User will see onboarding on next launch.")
    }

    // MARK: - Migration

    /// Migrate legacy "motive" agent name to "agent"
    func migrateAgentNameIfNeeded() {
        if currentAgent == "motive" {
            Log.config("Migrating agent name: motive → agent")
            currentAgent = "agent"
        }
    }

    // MARK: - Errors

    enum BinaryError: LocalizedError {
        case noAppSupport
        case sourceNotFound(String)
        case signingFailed(String)
        case directoryCreationFailed(String, String)
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAppSupport:
                "Cannot access storage directory"
            case let .sourceNotFound(path):
                "Binary not found at: \(path)"
            case let .signingFailed(message):
                "Failed to sign binary: \(message)"
            case let .directoryCreationFailed(path, reason):
                "Cannot create directory at \(path): \(reason)"
            case let .copyFailed(reason):
                "Failed to copy binary: \(reason)"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

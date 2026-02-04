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
final class ConfigManager: ObservableObject {
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
        case togetherai
        case perplexity
        case cerebras
        
        // Enterprise / Cloud
        case azure
        case bedrock
        case googleVertex
        
        // OpenAI-compatible endpoints
        case openaiCompatible

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .claude: return "Claude"
            case .openai: return "OpenAI"
            case .gemini: return "Gemini"
            case .ollama: return "Ollama"
            case .openrouter: return "OpenRouter"
            case .mistral: return "Mistral"
            case .groq: return "Groq"
            case .xai: return "xAI"
            case .cohere: return "Cohere"
            case .deepinfra: return "DeepInfra"
            case .togetherai: return "Together"
            case .perplexity: return "Perplexity"
            case .cerebras: return "Cerebras"
            case .azure: return "Azure"
            case .bedrock: return "Bedrock"
            case .googleVertex: return "Vertex AI"
            case .openaiCompatible: return "OpenAI Compatible"
            }
        }
        
        /// OpenCode provider name used in config
        var openCodeProviderName: String {
            switch self {
            case .claude: return "anthropic"
            case .openai: return "openai"
            case .gemini: return "google"
            case .ollama: return "ollama"
            case .openrouter: return "openrouter"
            case .mistral: return "mistral"
            case .groq: return "groq"
            case .xai: return "xai"
            case .cohere: return "cohere"
            case .deepinfra: return "deepinfra"
            case .togetherai: return "togetherai"
            case .perplexity: return "perplexity"
            case .cerebras: return "cerebras"
            case .azure: return "azure"
            case .bedrock: return "amazon-bedrock"
            case .googleVertex: return "google-vertex"
            case .openaiCompatible: return "openai-compatible"
            }
        }
        
        /// Whether this provider requires an API key
        var requiresAPIKey: Bool {
            switch self {
            case .ollama: return false
            default: return true
            }
        }
        
        /// Environment variable name for API key
        var envKeyName: String {
            switch self {
            case .claude: return "ANTHROPIC_API_KEY"
            case .openai: return "OPENAI_API_KEY"
            case .gemini: return "GOOGLE_GENERATIVE_AI_API_KEY"
            case .ollama: return ""
            case .openrouter: return "OPENROUTER_API_KEY"
            case .mistral: return "MISTRAL_API_KEY"
            case .groq: return "GROQ_API_KEY"
            case .xai: return "XAI_API_KEY"
            case .cohere: return "COHERE_API_KEY"
            case .deepinfra: return "DEEPINFRA_API_KEY"
            case .togetherai: return "TOGETHER_API_KEY"
            case .perplexity: return "PERPLEXITY_API_KEY"
            case .cerebras: return "CEREBRAS_API_KEY"
            case .azure: return "AZURE_OPENAI_API_KEY"
            case .bedrock: return "AWS_ACCESS_KEY_ID"
            case .googleVertex: return "GOOGLE_CLOUD_PROJECT"
            case .openaiCompatible: return "OPENAI_API_KEY"
            }
        }
        
        /// Default model for the provider
        var defaultModel: String {
            switch self {
            case .claude: return "claude-sonnet-4-5-20250929"
            case .openai: return "gpt-5.1-codex"
            case .gemini: return "gemini-3-pro-preview"
            case .ollama: return "llama3"
            case .openrouter: return "anthropic/claude-sonnet-4"
            case .mistral: return "mistral-large-latest"
            case .groq: return "llama-3.3-70b-versatile"
            case .xai: return "grok-2"
            case .cohere: return "command-r-plus"
            case .deepinfra: return "meta-llama/Llama-3.3-70B-Instruct"
            case .togetherai: return "meta-llama/Llama-3.3-70B-Instruct-Turbo"
            case .perplexity: return "llama-3.1-sonar-large-128k-online"
            case .cerebras: return "llama3.1-70b"
            case .azure: return "gpt-4o"
            case .bedrock: return "anthropic.claude-3-5-sonnet-20241022-v2:0"
            case .googleVertex: return "gemini-2.0-flash-001"
            case .openaiCompatible: return "gpt-4o"
            }
        }
    }

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        var localizedName: String {
            switch self {
            case .system: return L10n.Settings.themeSystem
            case .light: return L10n.Settings.themeLight
            case .dark: return L10n.Settings.themeDark
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    @AppStorage("provider") var providerRawValue: String = Provider.claude.rawValue
    
    // Per-provider configurations - Primary providers
    @AppStorage("claude.baseURL") var claudeBaseURL: String = ""
    @AppStorage("claude.modelName") var claudeModelName: String = ""
    @AppStorage("openai.baseURL") var openaiBaseURL: String = ""
    @AppStorage("openai.modelName") var openaiModelName: String = ""
    @AppStorage("gemini.baseURL") var geminiBaseURL: String = ""
    @AppStorage("gemini.modelName") var geminiModelName: String = ""
    @AppStorage("ollama.baseURL") var ollamaBaseURL: String = "http://localhost:11434"
    @AppStorage("ollama.modelName") var ollamaModelName: String = ""
    
    // Per-provider configurations - Cloud providers
    @AppStorage("openrouter.baseURL") var openrouterBaseURL: String = ""
    @AppStorage("openrouter.modelName") var openrouterModelName: String = ""
    @AppStorage("mistral.baseURL") var mistralBaseURL: String = ""
    @AppStorage("mistral.modelName") var mistralModelName: String = ""
    @AppStorage("groq.baseURL") var groqBaseURL: String = ""
    @AppStorage("groq.modelName") var groqModelName: String = ""
    @AppStorage("xai.baseURL") var xaiBaseURL: String = ""
    @AppStorage("xai.modelName") var xaiModelName: String = ""
    @AppStorage("cohere.baseURL") var cohereBaseURL: String = ""
    @AppStorage("cohere.modelName") var cohereModelName: String = ""
    @AppStorage("deepinfra.baseURL") var deepinfraBaseURL: String = ""
    @AppStorage("deepinfra.modelName") var deepinfraModelName: String = ""
    @AppStorage("togetherai.baseURL") var togetheraiBaseURL: String = ""
    @AppStorage("togetherai.modelName") var togetheraiModelName: String = ""
    @AppStorage("perplexity.baseURL") var perplexityBaseURL: String = ""
    @AppStorage("perplexity.modelName") var perplexityModelName: String = ""
    @AppStorage("cerebras.baseURL") var cerebrasBaseURL: String = ""
    @AppStorage("cerebras.modelName") var cerebrasModelName: String = ""
    
    // Per-provider configurations - Enterprise / Cloud
    @AppStorage("azure.baseURL") var azureBaseURL: String = ""
    @AppStorage("azure.modelName") var azureModelName: String = ""
    @AppStorage("bedrock.baseURL") var bedrockBaseURL: String = ""
    @AppStorage("bedrock.modelName") var bedrockModelName: String = ""
    @AppStorage("googleVertex.baseURL") var googleVertexBaseURL: String = ""
    @AppStorage("googleVertex.modelName") var googleVertexModelName: String = ""
    
    // Per-provider configurations - OpenAI-compatible
    @AppStorage("openaiCompatible.baseURL") var openaiCompatibleBaseURL: String = ""
    @AppStorage("openaiCompatible.modelName") var openaiCompatibleModelName: String = ""
    
    @AppStorage("openCodeBinarySourcePath") var openCodeBinarySourcePath: String = ""
    @AppStorage("debugMode") var debugMode: Bool = false
    @AppStorage("launchAtLoginStorage") private var launchAtLoginStorage: Bool = false
    @AppStorage("languageRawValue") var languageRawValue: String = Language.system.rawValue
    
    // Browser automation settings (browser-use-sidecar)
    @AppStorage("browserUseEnabled") var browserUseEnabled: Bool = false
    @AppStorage("browserUseHeadedMode") var browserUseHeadedMode: Bool = true  // Show browser window by default
    @AppStorage("browserAgentProvider") var browserAgentProviderRaw: String = "anthropic"
    var cachedBrowserAgentAPIKey: String?
    @AppStorage("browserAgentBaseUrl_anthropic") var browserAgentBaseUrlAnthropic: String = ""
    @AppStorage("browserAgentBaseUrl_openai") var browserAgentBaseUrlOpenAI: String = ""

    // Skills system (OpenClaw-style)
    @AppStorage("skillsSystemEnabled") var skillsSystemEnabled: Bool = true
    @AppStorage("skillsConfigJSON") var skillsConfigJSON: String = ""
    

    @AppStorage("hotkey") var hotkey: String = "⌥Space"
    @AppStorage("appearanceMode") var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    
    // Onboarding
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

    let keychainService = "com.velvet.motive"
    
    // Cache API keys per provider
    var cachedAPIKeys: [Provider: String] = [:]
    
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
    
    /// Preload current provider's API key into cache
    /// Call this once at startup to trigger Keychain prompt early
    /// Now triggers only ONE prompt thanks to unified storage
    func preloadAPIKeys() {
        // First, migrate any legacy keychain items (one-time)
        migrateKeychainIfNeeded()
        
        // Read current provider's key (single unified Keychain read)
        let account = "opencode.api.key.\(provider.rawValue)"
        let value = KeychainStore.read(service: keychainService, account: account) ?? ""
        cachedAPIKeys[provider] = value
        
        // Read browser agent key from the same unified storage (no additional prompt)
        if browserUseEnabled {
            let browserAccount = "browser.agent.api.key.\(browserAgentProvider.rawValue)"
            let browserValue = KeychainStore.read(service: keychainService, account: browserAccount) ?? ""
            cachedBrowserAgentAPIKey = browserValue
        }
    }
    
    // Status for UI
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
        DispatchQueue.main.async {
            switch targetMode {
            case .system:
                NSApp.appearance = nil  // Follow system
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    /// Path to generated opencode.json config
    @AppStorage("openCodeConfigPath") var openCodeConfigPath: String = ""
    @AppStorage("openCodeConfigDir") var openCodeConfigDir: String = ""

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
                return "Cannot access storage directory"
            case .sourceNotFound(let path):
                return "Binary not found at: \(path)"
            case .signingFailed(let message):
                return "Failed to sign binary: \(message)"
            case .directoryCreationFailed(let path, let reason):
                return "Cannot create directory at \(path): \(reason)"
            case .copyFailed(let reason):
                return "Failed to copy binary: \(reason)"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

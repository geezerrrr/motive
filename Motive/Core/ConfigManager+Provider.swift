//
//  ConfigManager+Provider.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation

extension ConfigManager {
    // MARK: - Per-Provider Configuration Accessors
    
    /// Base URL for current provider
    var baseURL: String {
        get {
            switch provider {
            case .claude: return claudeBaseURL
            case .openai: return openaiBaseURL
            case .gemini: return geminiBaseURL
            case .ollama: return ollamaBaseURL
            }
        }
        set {
            switch provider {
            case .claude: claudeBaseURL = newValue
            case .openai: openaiBaseURL = newValue
            case .gemini: geminiBaseURL = newValue
            case .ollama: ollamaBaseURL = newValue
            }
        }
    }
    
    /// Model name for current provider
    var modelName: String {
        get {
            switch provider {
            case .claude: return claudeModelName
            case .openai: return openaiModelName
            case .gemini: return geminiModelName
            case .ollama: return ollamaModelName
            }
        }
        set {
            switch provider {
            case .claude: claudeModelName = newValue
            case .openai: openaiModelName = newValue
            case .gemini: geminiModelName = newValue
            case .ollama: ollamaModelName = newValue
            }
        }
    }
    
    /// API Key for current provider (stored in Keychain per-provider)
    var apiKey: String {
        get {
            if let cached = cachedAPIKeys[provider] {
                return cached
            }
            let account = "opencode.api.key.\(provider.rawValue)"
            let value = KeychainStore.read(service: keychainService, account: account) ?? ""
            cachedAPIKeys[provider] = value
            return value
        }
        set {
            cachedAPIKeys[provider] = newValue
            let account = "opencode.api.key.\(provider.rawValue)"
            if newValue.isEmpty {
                KeychainStore.delete(service: keychainService, account: account)
            } else {
                KeychainStore.write(service: keychainService, account: account, value: newValue)
            }
        }
    }

    var hasAPIKey: Bool {
        // Ollama doesn't require API key
        if provider == .ollama { return true }
        // Check cache first to avoid Keychain prompt
        if let cached = cachedAPIKeys[provider] {
            return !cached.isEmpty
        }
        // Fall back to full check (will trigger Keychain if needed)
        return !apiKey.isEmpty
    }
    
    /// Check if current provider is properly configured
    var isProviderConfigured: Bool {
        switch provider {
        case .claude, .openai:
            return hasAPIKey
        case .gemini:
            return hasAPIKey
        case .ollama:
            return !baseURL.isEmpty
        }
    }
    
    /// Get configuration error message for current provider
    var providerConfigurationError: String? {
        switch provider {
        case .claude:
            if apiKey.isEmpty { return "Claude API Key not configured" }
        case .openai:
            if apiKey.isEmpty { return "OpenAI API Key not configured" }
        case .gemini:
            if apiKey.isEmpty { return "Gemini API Key not configured" }
        case .ollama:
            if baseURL.isEmpty { return "Ollama Base URL not configured" }
        }
        return nil
    }
    
    /// Get the model string in format "provider/model" for OpenCode CLI
    func getModelString() -> String? {
        let modelValue = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Determine provider prefix
        let providerPrefix: String
        let defaultModel: String
        switch provider {
        case .claude:
            providerPrefix = "anthropic"
            defaultModel = "claude-sonnet-4-5-20250929"
        case .openai:
            providerPrefix = "openai"
            defaultModel = "gpt-5.1-codex"
        case .gemini:
            providerPrefix = "google"
            defaultModel = "gemini-3-pro-preview"
        case .ollama:
            providerPrefix = "ollama"
            defaultModel = "llama3"
        }
        
        // If model name is provided, use it
        if !modelValue.isEmpty {
            // If model already has provider prefix, use as-is
            if modelValue.contains("/") {
                return modelValue
            }
            // Otherwise add provider prefix
            return "\(providerPrefix)/\(modelValue)"
        }
        
        // Use default model for provider
        return "\(providerPrefix)/\(defaultModel)"
    }
}

//
//  ConfigManager+BrowserUse.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation

extension ConfigManager {
    /// Browser Agent LLM provider for autonomous tasks
    enum BrowserAgentProvider: String, CaseIterable {
        case anthropic = "anthropic"
        case openai = "openai"
        case browserUse = "browser-use"
        
        var displayName: String {
            switch self {
            case .anthropic: return "Anthropic (Claude)"
            case .openai: return "OpenAI (GPT-4)"
            case .browserUse: return "Browser Use (ChatBrowserUse)"
            }
        }
        
        var envKeyName: String {
            switch self {
            case .anthropic: return "ANTHROPIC_API_KEY"
            case .openai: return "OPENAI_API_KEY"
            case .browserUse: return "BROWSER_USE_API_KEY"
            }
        }
        
        var baseUrlEnvName: String? {
            switch self {
            case .anthropic: return "ANTHROPIC_BASE_URL"
            case .openai: return "OPENAI_BASE_URL"
            case .browserUse: return nil  // browser-use doesn't support custom base URL
            }
        }
        
        var supportsBaseUrl: Bool {
            baseUrlEnvName != nil
        }
    }
    
    var browserAgentProvider: BrowserAgentProvider {
        get { BrowserAgentProvider(rawValue: browserAgentProviderRaw) ?? .anthropic }
        set { browserAgentProviderRaw = newValue.rawValue }
    }
    
    var browserAgentAPIKey: String {
        get {
            if let cached = cachedBrowserAgentAPIKey {
                return cached
            }
            let account = "browser.agent.api.key.\(browserAgentProvider.rawValue)"
            let value = KeychainStore.read(service: keychainService, account: account) ?? ""
            cachedBrowserAgentAPIKey = value
            return value
        }
        set {
            cachedBrowserAgentAPIKey = newValue
            let account = "browser.agent.api.key.\(browserAgentProvider.rawValue)"
            if newValue.isEmpty {
                KeychainStore.delete(service: keychainService, account: account)
            } else {
                KeychainStore.write(service: keychainService, account: account, value: newValue)
            }
        }
    }
    
    /// Check if browser agent has API key configured
    /// Uses cache to avoid triggering Keychain prompt
    var hasBrowserAgentAPIKey: Bool {
        // Check cache first
        if let cached = cachedBrowserAgentAPIKey {
            return !cached.isEmpty
        }
        // Fall back to full check (will trigger Keychain if needed)
        return !browserAgentAPIKey.isEmpty
    }
    
    var browserAgentBaseUrl: String {
        get {
            switch browserAgentProvider {
            case .anthropic: return browserAgentBaseUrlAnthropic
            case .openai: return browserAgentBaseUrlOpenAI
            case .browserUse: return ""  // Not supported
            }
        }
        set {
            switch browserAgentProvider {
            case .anthropic: browserAgentBaseUrlAnthropic = newValue
            case .openai: browserAgentBaseUrlOpenAI = newValue
            case .browserUse: break  // Not supported
            }
        }
    }
    
    /// Clear cached browser agent API key (call when provider changes)
    func clearBrowserAgentAPIKeyCache() {
        cachedBrowserAgentAPIKey = nil
    }
    
    /// Browser automation status
    enum BrowserUseStatus {
        case ready                    // Sidecar binary available
        case binaryNotFound           // Binary not in bundle
        case disabled                 // Feature disabled in settings
        
        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
        
        var description: String {
            switch self {
            case .ready: return "Ready"
            case .binaryNotFound: return "Binary not found in bundle"
            case .disabled: return "Disabled"
            }
        }
    }
    
    /// Check browser automation status
    var browserUseStatus: BrowserUseStatus {
        guard browserUseEnabled else { return .disabled }
        
        // Check if sidecar binary is bundled (supports both --onedir and --onefile builds)
        if let dirURL = Bundle.main.url(forResource: "browser-use-sidecar", withExtension: nil) {
            // Try --onedir structure first
            let binaryURL = dirURL.appendingPathComponent("browser-use-sidecar")
            if FileManager.default.isExecutableFile(atPath: binaryURL.path) {
                return .ready
            }
            // Fallback to --onefile structure
            if FileManager.default.isExecutableFile(atPath: dirURL.path) {
                return .ready
            }
        }
        
        return .binaryNotFound
    }
}

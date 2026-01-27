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
        case claude
        case openai
        case gemini
        case ollama

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .claude: return "Claude"
            case .openai: return "OpenAI"
            case .gemini: return "Gemini"
            case .ollama: return "Ollama"
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
    
    // Per-provider configurations
    @AppStorage("claude.baseURL") var claudeBaseURL: String = ""
    @AppStorage("claude.modelName") var claudeModelName: String = ""
    @AppStorage("openai.baseURL") var openaiBaseURL: String = ""
    @AppStorage("openai.modelName") var openaiModelName: String = ""
    @AppStorage("gemini.baseURL") var geminiBaseURL: String = ""
    @AppStorage("gemini.modelName") var geminiModelName: String = ""
    @AppStorage("ollama.baseURL") var ollamaBaseURL: String = "http://localhost:11434"
    @AppStorage("ollama.modelName") var ollamaModelName: String = ""
    
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
    

    @AppStorage("hotkey") var hotkey: String = "⌥Space"
    @AppStorage("appearanceMode") var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    
    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
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
    
    // Published status for UI
    @Published var binaryStatus: BinaryStatus = .notConfigured
    
    enum BinaryStatus: Equatable {
        case notConfigured
        case ready(String) // path
        case error(String)
    }

    var provider: Provider {
        get { Provider(rawValue: providerRawValue) ?? .claude }
        set { 
            providerRawValue = newValue.rawValue
            objectWillChange.send()
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
    
    // MARK: - Binary Storage Directory
    
    /// Get the directory for storing the signed binary
    /// Tries Application Support first, falls back to temp directory
    private var binaryStorageDirectory: URL? {
        let fileManager = FileManager.default
        
        // Try Application Support first
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let motiveDir = appSupport.appendingPathComponent("Motive")
            
            // Try to create directory
            if !fileManager.fileExists(atPath: motiveDir.path) {
                do {
                    try fileManager.createDirectory(at: motiveDir, withIntermediateDirectories: true, attributes: nil)
                    Log.config(" Created directory at \(motiveDir.path)")
                    return motiveDir
                } catch {
                    Log.config(" Failed to create Application Support directory: \(error)")
                    // Fall through to temp directory
                }
            } else {
                return motiveDir
            }
        }
        
        // Fallback to temp directory with a persistent subfolder
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("Motive")
        if !fileManager.fileExists(atPath: tempDir.path) {
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        }
        Log.config(" Using temp directory at \(tempDir.path)")
        return tempDir
    }
    
    /// Path to the signed opencode binary
    private var signedBinaryPath: URL? {
        binaryStorageDirectory?.appendingPathComponent("opencode")
    }
    
    // MARK: - Binary Management
    
    /// Import and sign an external opencode binary
    /// This copies the binary to a local directory and signs it
    func importBinary(from sourceURL: URL) async throws {
        let fileManager = FileManager.default
        
        guard let destURL = signedBinaryPath else {
            throw BinaryError.noAppSupport
        }
        
        // Ensure parent directory exists
        if let parentDir = signedBinaryPath?.deletingLastPathComponent() {
            if !fileManager.fileExists(atPath: parentDir.path) {
                do {
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    throw BinaryError.directoryCreationFailed(parentDir.path, error.localizedDescription)
                }
            }
        }
        
        // Verify source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw BinaryError.sourceNotFound(sourceURL.path)
        }
        
        Log.config(" Importing binary from \(sourceURL.path) to \(destURL.path)")
        
        // Remove existing binary if present
        if fileManager.fileExists(atPath: destURL.path) {
            do {
                try fileManager.removeItem(at: destURL)
            } catch {
                Log.config(" Failed to remove existing binary: \(error)")
            }
        }
        
        // Copy binary
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw BinaryError.copyFailed(error.localizedDescription)
        }
        
        // Make executable
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)
        } catch {
            Log.config(" Failed to set permissions: \(error)")
        }
        
        // Sign the binary (like openwork does)
        try await signBinary(at: destURL)
        
        // Save the source path for reference
        openCodeBinarySourcePath = sourceURL.path
        
        // Update status
        binaryStatus = .ready(destURL.path)
        
        Log.config(" Binary imported and signed successfully at \(destURL.path)")
    }
    
    /// Sign a binary using ad-hoc signature (same as openwork)
    private func signBinary(at url: URL) async throws {
        Log.config(" Signing binary at \(url.path)")
        
        // First, remove any quarantine attributes
        let xattrProcess = Process()
        xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattrProcess.arguments = ["-cr", url.path]
        try? xattrProcess.run()
        xattrProcess.waitUntilExit()
        Log.config(" Cleared extended attributes")
        
        // Then sign with ad-hoc signature
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", url.path]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        try process.run()
        process.waitUntilExit()
        
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrMessage = String(data: stderrData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            Log.config(" codesign failed with status \(process.terminationStatus): \(stderrMessage)")
            throw BinaryError.signingFailed(stderrMessage)
        }
        
        // Verify the signature
        let verifyProcess = Process()
        verifyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verifyProcess.arguments = ["-v", "--verbose=4", url.path]
        let verifyPipe = Pipe()
        verifyProcess.standardError = verifyPipe
        try? verifyProcess.run()
        verifyProcess.waitUntilExit()
        let verifyOutput = String(data: verifyPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        Log.config(" Signature verification: \(verifyOutput)")
        
        Log.config(" Binary signed successfully")
    }
    
    /// Resolve the OpenCode binary path
    /// Priority:
    /// 1. Signed binary in Application Support (if exists)
    /// 2. Auto-import from nvm installations
    /// 3. Auto-import from global installations
    /// 4. Bundled binary in app resources
    func resolveBinary() -> (url: URL?, error: String?) {
        let fileManager = FileManager.default
        
        // 1. Check for signed binary in Application Support
        if let signedPath = signedBinaryPath, fileManager.fileExists(atPath: signedPath.path) {
            Log.config(" Using signed binary: \(signedPath.path)")
            binaryStatus = .ready(signedPath.path)
            return (signedPath, nil)
        }
        
        // 2. Try to auto-import from nvm
        if let nvmPath = findNvmOpenCode() {
            Log.config(" Found nvm OpenCode at \(nvmPath.path), will import on first use")
            // Return the source path, but note we'll need to import it
            return (nvmPath, nil)
        }
        
        // 3. Try global installations
        let globalPaths = [
            "/usr/local/bin/opencode",
            "/opt/homebrew/bin/opencode"
        ]
        for path in globalPaths {
            if fileManager.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                Log.config(" Found global OpenCode at \(path), will import on first use")
                return (url, nil)
            }
        }
        
        // 4. Bundled binary
        if let bundledURL = Bundle.main.url(forResource: "opencode", withExtension: nil) {
            if fileManager.fileExists(atPath: bundledURL.path) {
                Log.config(" Using bundled OpenCode: \(bundledURL.path)")
                binaryStatus = .ready(bundledURL.path)
                return (bundledURL, nil)
            }
        }
        
        binaryStatus = .notConfigured
        return (nil, "OpenCode CLI not found. Install via npm: npm install -g opencode-ai")
    }
    
    /// Get the binary URL, importing and signing if necessary
    func getSignedBinaryURL() async -> (url: URL?, error: String?) {
        let fileManager = FileManager.default
        
        // Check for already signed binary
        if let signedPath = signedBinaryPath, fileManager.fileExists(atPath: signedPath.path) {
            return (signedPath, nil)
        }
        
        // Try to find and import a binary
        let (sourceURL, error) = resolveBinary()
        guard let source = sourceURL else {
            return (nil, error)
        }
        
        // If it's already in Application Support (signed), return it
        if let signedPath = signedBinaryPath, source.path == signedPath.path {
            return (source, nil)
        }
        
        // Import and sign the binary
        do {
            try await importBinary(from: source)
            return (signedBinaryPath, nil)
        } catch {
            let errorMsg = "Failed to import binary: \(error.localizedDescription)"
            binaryStatus = .error(errorMsg)
            return (nil, errorMsg)
        }
    }
    
    /// Scan nvm versions directory to find OpenCode installations
    private func findNvmOpenCode() -> URL? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let nvmVersionsDir = "\(homeDir)/.nvm/versions/node"
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: nvmVersionsDir) else {
            return nil
        }
        
        do {
            let versions = try fileManager.contentsOfDirectory(atPath: nvmVersionsDir)
            for version in versions.sorted().reversed() { // Prefer newer versions
                // Check for the actual binary in opencode-darwin-arm64 package
                let platformBinaryPath = "\(nvmVersionsDir)/\(version)/lib/node_modules/opencode-ai/node_modules/opencode-darwin-arm64/bin/opencode"
                if fileManager.fileExists(atPath: platformBinaryPath) {
                    return URL(fileURLWithPath: platformBinaryPath)
                }
                
                // Fallback to the npm shim script
                let shimPath = "\(nvmVersionsDir)/\(version)/bin/opencode"
                if fileManager.fileExists(atPath: shimPath) {
                    return URL(fileURLWithPath: shimPath)
                }
            }
        } catch {
            Log.config(" Error scanning nvm directory: \(error)")
        }
        
        return nil
    }

    func makeEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let apiKeyValue = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove proxy environment variables to avoid SOCKS proxy errors with browser-use
        // browser-use uses httpx which doesn't have socksio installed by default
        let proxyKeys = ["ALL_PROXY", "all_proxy", "HTTP_PROXY", "http_proxy", 
                         "HTTPS_PROXY", "https_proxy", "NO_PROXY", "no_proxy",
                         "SOCKS_PROXY", "socks_proxy"]
        for key in proxyKeys {
            environment.removeValue(forKey: key)
        }
        
        // Extend PATH with common Node.js installation paths
        // This is critical because /bin/sh doesn't load user's shell config
        environment["PATH"] = buildExtendedPath(base: environment["PATH"])
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        environment["FORCE_COLOR"] = "0"
        environment["CI"] = "1"
        environment["OPENCODE_NO_INTERACTIVE"] = "1"
        
        // Sync API keys to OpenCode's auth.json
        syncToOpenCodeAuth()
        
        // ALWAYS generate config (sets permission: "allow" to avoid blocking)
        generateOpenCodeConfig()
        
        if !apiKeyValue.isEmpty {
            // Also set environment variables as backup
            switch provider {
            case .claude:
                environment["ANTHROPIC_API_KEY"] = apiKeyValue
                Log.config(" Using Anthropic API key: \(apiKeyValue.prefix(10))...")
            case .openai:
                environment["OPENAI_API_KEY"] = apiKeyValue
                Log.config(" Using OpenAI API key: \(apiKeyValue.prefix(10))...")
            case .gemini:
                environment["GOOGLE_API_KEY"] = apiKeyValue
                Log.config(" Using Google API key: \(apiKeyValue.prefix(10))...")
            case .ollama:
                Log.config(" Using Ollama (no API key needed)")
            }
        } else {
            Log.config(" WARNING - No API key configured!")
        }
        
        // Note: baseURL is configured via opencode.json provider.options.baseURL
        // Environment variables are not needed as OpenCode reads from config file
        
        if debugMode {
            environment["DEBUG"] = "1"
        }
        
        // Set Browser Agent API key for browser-use-sidecar agent_task
        // Only use cached value to avoid triggering additional Keychain prompts
        if browserUseEnabled, let cachedKey = cachedBrowserAgentAPIKey, !cachedKey.isEmpty {
            let envKeyName = browserAgentProvider.envKeyName
            environment[envKeyName] = cachedKey
            Log.config(" Browser Agent API key (\(envKeyName)): \(cachedKey.prefix(10))...")
            
            // Set base URL if configured
            if let baseUrlEnvName = browserAgentProvider.baseUrlEnvName, !browserAgentBaseUrl.isEmpty {
                environment[baseUrlEnvName] = browserAgentBaseUrl
                Log.config(" Browser Agent Base URL (\(baseUrlEnvName)): \(browserAgentBaseUrl)")
            }
        }
        
        // Set OPENCODE_CONFIG if we generated a config file
        if !openCodeConfigPath.isEmpty {
            environment["OPENCODE_CONFIG"] = openCodeConfigPath
            Log.config(" Using OpenCode config: \(openCodeConfigPath)")
            
            // Verify the config file exists
            if FileManager.default.fileExists(atPath: openCodeConfigPath) {
                Log.config(" Config file verified at: \(openCodeConfigPath)")
            } else {
                Log.config(" WARNING - Config file NOT found at: \(openCodeConfigPath)")
            }
            
            if !openCodeConfigDir.isEmpty {
                environment["OPENCODE_CONFIG_DIR"] = openCodeConfigDir
                Log.config(" Using OpenCode config dir: \(openCodeConfigDir)")
            }
        } else {
            Log.config(" WARNING - openCodeConfigPath is empty!")
        }
        
        return environment
    }
    
    /// Build extended PATH with common Node.js installation paths
    /// This is needed because /bin/sh doesn't load user's shell config (.zshrc etc)
    private func buildExtendedPath(base: String?) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var pathParts: [String] = []
        
        // Add App Bundle Resources path for bundled binaries (browser-use-sidecar)
        if let resourcesPath = Bundle.main.resourcePath {
            pathParts.append(resourcesPath)
        }
        
        // NVM paths (dynamic - check all installed versions)
        let nvmVersionsDir = "\(homeDir)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsDir) {
            let sortedVersions = versions
                .filter { $0.hasPrefix("v") }
                .sorted { v1, v2 in
                    // Sort by version (descending - newest first)
                    let parse: (String) -> Int = { v in
                        let parts = v.dropFirst().split(separator: ".").compactMap { Int($0) }
                        let major = parts.count > 0 ? parts[0] : 0
                        let minor = parts.count > 1 ? parts[1] : 0
                        let patch = parts.count > 2 ? parts[2] : 0
                        return major * 10000 + minor * 100 + patch
                    }
                    return parse(v1) > parse(v2)
                }
            for version in sortedVersions {
                let binPath = "\(nvmVersionsDir)/\(version)/bin"
                if FileManager.default.fileExists(atPath: binPath) {
                    pathParts.append(binPath)
                }
            }
        }
        
        // Common Node.js paths
        let commonPaths = [
            "/opt/homebrew/bin",           // Apple Silicon Homebrew
            "/usr/local/bin",              // Intel Mac / general
            "\(homeDir)/.volta/bin",       // Volta
            "\(homeDir)/.asdf/shims",      // asdf
            "\(homeDir)/.fnm/current/bin", // fnm
            "\(homeDir)/.nodenv/shims",    // nodenv
            "\(homeDir)/.local/bin",       // pip/pipx style
            "/opt/local/bin",              // MacPorts
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) && !pathParts.contains(path) {
                pathParts.append(path)
            }
        }
        
        // Add system PATH from path_helper
        if let systemPath = getSystemPath() {
            for path in systemPath.split(separator: ":").map(String.init) {
                if !pathParts.contains(path) {
                    pathParts.append(path)
                }
            }
        }
        
        // Add base PATH
        if let base = base {
            for path in base.split(separator: ":").map(String.init) {
                if !pathParts.contains(path) {
                    pathParts.append(path)
                }
            }
        }
        
        let result = pathParts.joined(separator: ":")
        Log.config(" Extended PATH: \(result.prefix(200))...")
        return result
    }
    
    /// Get system PATH from macOS path_helper utility
    private func getSystemPath() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/libexec/path_helper")
        task.arguments = ["-s"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse: PATH="..."; export PATH;
                if let match = output.range(of: #"PATH="([^"]+)""#, options: .regularExpression) {
                    let pathValue = output[match]
                        .dropFirst(6) // Remove PATH="
                        .dropLast(1)  // Remove trailing "
                    return String(pathValue)
                }
            }
        } catch {
            Log.config(" path_helper failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - OpenCode Auth & Config Sync
    
    /// Sync ALL provider API keys to OpenCode's auth.json
    /// Path: ~/.local/share/opencode/auth.json
    private func syncToOpenCodeAuth() {
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
        let providerName: String
        switch provider {
        case .claude:
            providerName = "anthropic"
        case .openai:
            providerName = "openai"
        case .gemini:
            providerName = "google"
        case .ollama:
            providerName = "ollama"
        }
        
        // Use the cached apiKey property instead of direct keychain read
        let apiKeyValue = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKeyValue.isEmpty && provider != .ollama {
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
    /// Path: ~/Library/Application Support/Motive/opencode/opencode.json
    /// 
    /// IMPORTANT: This must ALWAYS be generated to set permission: "allow"
    /// Without this, OpenCode CLI blocks waiting for permission prompts that never show in GUI
    private func generateOpenCodeConfig() {
        guard let appSupport = binaryStorageDirectory else { return }
        let configDir = appSupport.appendingPathComponent("config")
        let configPath = configDir.appendingPathComponent("opencode.json")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        // Determine provider name for OpenCode
        let providerName: String
        switch provider {
        case .claude:
            providerName = "anthropic"
        case .openai:
            providerName = "openai"
        case .gemini:
            providerName = "google"
        case .ollama:
            providerName = "ollama"
        }
        
        let baseURLValue = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let mcpDir = appSupport.appendingPathComponent("mcp")
        let mcpScripts = ensureMcpScripts(in: mcpDir)
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
        
        // Build config - always include permission: "allow"
        var config: [String: Any] = [
            "$schema": "https://opencode.ai/config.json",
            "default_agent": "motive",
            "enabled_providers": [providerName],
            // CRITICAL: Auto-allow all permissions - CLI prompts don't show in GUI
            "permission": "allow",
            "agent": [
                "motive": [
                    "description": "Motive default agent with UI permission flow",
                    "prompt": systemPrompt,
                    "mode": "primary"
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
            openCodeConfigDir = appSupport.path
            
            // Write SKILL.md files for OpenCode to discover MCP tools
            // OpenCode looks for skills at $OPENCODE_CONFIG_DIR/skills/<name>/SKILL.md
            SkillManager.shared.writeSkillFiles(to: appSupport)
        } catch {
            Log.config(" ERROR - Failed to write OpenCode config: \(error)")
        }
    }

    private func resolveNodePath() -> String? {
        let path = buildExtendedPath(base: ProcessInfo.processInfo.environment["PATH"])
        let candidates = path.split(separator: ":").map { "\($0)/node" }
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
    
    private func ensureMcpScripts(in directory: URL) -> (filePermission: String, askUserQuestion: String)? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Log.config(" Failed to create MCP scripts directory: \(error)")
            return nil
        }
        
        let filePermissionPath = directory.appendingPathComponent("file-permission.js")
        let askUserPath = directory.appendingPathComponent("ask-user-question.js")
        
        let filePermissionScript = """
#!/usr/bin/env node
const PERMISSION_API_PORT = process.env.PERMISSION_API_PORT || '9226';
const PERMISSION_API_URL = `http://localhost:${PERMISSION_API_PORT}/permission`;

process.stdin.setEncoding('utf8');
let buffer = '';

function send(id, result, error) {
  const response = { jsonrpc: '2.0', id };
  if (error) {
    response.error = error;
  } else {
    response.result = result;
  }
  process.stdout.write(JSON.stringify(response) + '\\n');
}

async function handleMessage(message) {
  if (!message || typeof message !== 'object') return;
  const { id, method, params } = message;
  if (!method) return;
  if (method === 'initialize') {
    send(id, {
      protocolVersion: '2024-10-07',
      capabilities: { tools: {} },
      serverInfo: { name: 'motive-file-permission', version: '1.0.0' }
    });
    return;
  }
  if (method === 'tools/list') {
    send(id, {
      tools: [{
        name: 'request_file_permission',
        description: 'Request user permission before performing file operations.',
        inputSchema: {
          type: 'object',
          properties: {
            operation: { type: 'string', enum: ['create','delete','rename','move','modify','overwrite'] },
            filePath: { type: 'string' },
            filePaths: { type: 'array', items: { type: 'string' } },
            targetPath: { type: 'string' },
            contentPreview: { type: 'string' }
          },
          required: ['operation']
        }
      }]
    });
    return;
  }
  if (method === 'tools/call') {
    const toolName = params?.name;
    if (toolName !== 'request_file_permission') {
      send(id, { content: [{ type: 'text', text: `Error: Unknown tool: ${toolName}` }], isError: true });
      return;
    }
    try {
      const response = await fetch(PERMISSION_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params?.arguments || {})
      });
      if (!response.ok) {
        const text = await response.text();
        send(id, { content: [{ type: 'text', text: `Error: Permission API returned ${response.status}: ${text}` }], isError: true });
        return;
      }
      const result = await response.json();
      const allowed = !!result.allowed;
      send(id, { content: [{ type: 'text', text: allowed ? 'allowed' : 'denied' }] });
    } catch (err) {
      const message = err && err.message ? err.message : String(err);
      send(id, { content: [{ type: 'text', text: `Error: Failed to request permission: ${message}` }], isError: true });
    }
    return;
  }
}

function onLine(line) {
  const trimmed = line.trim();
  if (!trimmed) return;
  let message = null;
  try {
    message = JSON.parse(trimmed);
  } catch {
    return;
  }
  if (message && message.method === 'notifications/initialized') {
    return;
  }
  handleMessage(message);
}

process.stdin.on('data', chunk => {
  buffer += chunk;
  const lines = buffer.split('\\n');
  buffer = lines.pop() || '';
  for (const line of lines) {
    onLine(line);
  }
});
"""
        
        let askUserScript = """
#!/usr/bin/env node
const QUESTION_API_PORT = process.env.QUESTION_API_PORT || '9227';
const QUESTION_API_URL = `http://localhost:${QUESTION_API_PORT}/question`;

process.stdin.setEncoding('utf8');
let buffer = '';

function send(id, result, error) {
  const response = { jsonrpc: '2.0', id };
  if (error) {
    response.error = error;
  } else {
    response.result = result;
  }
  process.stdout.write(JSON.stringify(response) + '\\n');
}

async function handleMessage(message) {
  if (!message || typeof message !== 'object') return;
  const { id, method, params } = message;
  if (!method) return;
  if (method === 'initialize') {
    send(id, {
      protocolVersion: '2024-10-07',
      capabilities: { tools: {} },
      serverInfo: { name: 'motive-ask-user-question', version: '1.0.0' }
    });
    return;
  }
  if (method === 'tools/list') {
    send(id, {
      tools: [{
        name: 'AskUserQuestion',
        description: 'Ask the user a question and wait for their response.',
        inputSchema: {
          type: 'object',
          properties: {
            questions: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  question: { type: 'string' },
                  header: { type: 'string' },
                  options: { type: 'array', items: { type: 'object' } },
                  multiSelect: { type: 'boolean' }
                },
                required: ['question']
              },
              minItems: 1,
              maxItems: 4
            }
          },
          required: ['questions']
        }
      }]
    });
    return;
  }
  if (method === 'tools/call') {
    const toolName = params?.name;
    if (toolName !== 'AskUserQuestion') {
      send(id, { content: [{ type: 'text', text: `Error: Unknown tool: ${toolName}` }], isError: true });
      return;
    }
    try {
      const args = params?.arguments || {};
      const questions = Array.isArray(args.questions) ? args.questions : [];
      const question = questions[0] || {};
      const response = await fetch(QUESTION_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          question: question.question,
          header: question.header,
          options: question.options,
          multiSelect: question.multiSelect
        })
      });
      if (!response.ok) {
        const text = await response.text();
        send(id, { content: [{ type: 'text', text: `Error: Question API returned ${response.status}: ${text}` }], isError: true });
        return;
      }
      const result = await response.json();
      if (result.denied) {
        send(id, { content: [{ type: 'text', text: 'User declined to answer the question.' }] });
        return;
      }
      if (Array.isArray(result.selectedOptions) && result.selectedOptions.length > 0) {
        send(id, { content: [{ type: 'text', text: `User selected: ${result.selectedOptions.join(', ')}` }] });
        return;
      }
      if (result.customText) {
        send(id, { content: [{ type: 'text', text: `User responded: ${result.customText}` }] });
        return;
      }
      send(id, { content: [{ type: 'text', text: 'User provided no response.' }] });
    } catch (err) {
      const message = err && err.message ? err.message : String(err);
      send(id, { content: [{ type: 'text', text: `Error: Failed to ask question: ${message}` }], isError: true });
    }
    return;
  }
}

function onLine(line) {
  const trimmed = line.trim();
  if (!trimmed) return;
  let message = null;
  try {
    message = JSON.parse(trimmed);
  } catch {
    return;
  }
  if (message && message.method === 'notifications/initialized') {
    return;
  }
  handleMessage(message);
}

process.stdin.on('data', chunk => {
  buffer += chunk;
  const lines = buffer.split('\\n');
  buffer = lines.pop() || '';
  for (const line of lines) {
    onLine(line);
  }
});
"""
        
        do {
            try filePermissionScript.write(to: filePermissionPath, atomically: true, encoding: .utf8)
            try askUserScript.write(to: askUserPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: filePermissionPath.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: askUserPath.path)
        } catch {
            Log.config(" Failed to write MCP scripts: \(error)")
            return nil
        }
        
        return (filePermissionPath.path, askUserPath.path)
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

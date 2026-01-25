//
//  BrowserUseBridge.swift
//  Motive
//
//  Bridge for communicating with browser-use-sidecar binary.
//  Provides browser automation capabilities via a bundled standalone executable.
//

import Foundation
import Combine

/// Result of a browser automation command
struct BrowserResult: Codable {
    let success: Bool
    let data: BrowserResultData?
    let error: String?
}

/// Flexible data container for various command results
struct BrowserResultData: Codable {
    // Common fields
    let url: String?
    let title: String?
    let message: String?
    let path: String?
    let text: String?
    let key: String?
    let direction: String?
    
    // State command fields
    let elementCount: Int?
    let elements: [String]?
    let elementsRaw: [[String: AnyCodable]]?
    
    // Click/input fields
    let clicked: String?
    let element: String?
    
    // Sessions fields
    let sessions: [[String: AnyCodable]]?
    
    enum CodingKeys: String, CodingKey {
        case url, title, message, path, text, key, direction
        case elementCount = "element_count"
        case elements
        case elementsRaw = "elements_raw"
        case clicked, element, sessions
    }
}

/// Helper type for handling arbitrary JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

/// Browser automation bridge using bundled sidecar binary
@MainActor
final class BrowserUseBridge: ObservableObject {
    
    /// Shared instance
    static let shared = BrowserUseBridge()
    
    /// Whether browser is currently active
    @Published private(set) var isActive: Bool = false
    
    /// Current session name
    @Published private(set) var currentSession: String = "default"
    
    /// Last error message
    @Published private(set) var lastError: String?
    
    /// Browser Agent API configuration (set from ConfigManager)
    var agentAPIKeyEnvName: String?
    var agentAPIKey: String?
    var agentBaseUrlEnvName: String?
    var agentBaseUrl: String?
    
    /// Configure agent API key and base URL (call this when settings change)
    func configureAgentAPIKey(envName: String?, apiKey: String?, baseUrlEnvName: String? = nil, baseUrl: String? = nil) {
        self.agentAPIKeyEnvName = envName
        self.agentAPIKey = apiKey
        self.agentBaseUrlEnvName = baseUrlEnvName
        self.agentBaseUrl = baseUrl
    }
    
    /// Path to the bundled browser-use-sidecar binary
    /// Now looks for browser-use-sidecar/browser-use-sidecar (directory structure from PyInstaller --onedir)
    private var binaryPath: String? {
        // First try the new directory structure (--onedir build)
        if let dirURL = Bundle.main.url(forResource: "browser-use-sidecar", withExtension: nil) {
            let binaryURL = dirURL.appendingPathComponent("browser-use-sidecar")
            if FileManager.default.isExecutableFile(atPath: binaryURL.path) {
                return binaryURL.path
            }
            // Fallback to the URL itself if it's a single file (--onefile build)
            if FileManager.default.isExecutableFile(atPath: dirURL.path) {
                return dirURL.path
            }
        }
        return nil
    }
    
    /// Check if the sidecar binary is available
    var isAvailable: Bool {
        guard let path = binaryPath else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }
    
    private init() {}
    
    // MARK: - Browser Commands
    
    /// Open a URL in the browser
    /// - Parameters:
    ///   - url: URL to navigate to
    ///   - headed: Whether to show the browser window
    ///   - session: Session name for persistence
    /// - Returns: Result containing URL and title
    func open(url: String, headed: Bool = true, session: String = "default") async throws -> BrowserResult {
        var args = ["open", url]
        if headed {
            args.append("--headed")
        }
        args.append(contentsOf: ["--session", session])
        
        let result = try await execute(args)
        if result.success {
            isActive = true
            currentSession = session
        }
        return result
    }
    
    /// Get current page state with interactive elements
    /// - Parameter session: Session name
    /// - Returns: Result containing elements list
    func state(session: String = "default") async throws -> BrowserResult {
        return try await execute(["state", "--session", session])
    }
    
    /// Click an element by index
    /// - Parameters:
    ///   - index: Element index from state command
    ///   - session: Session name
    func click(index: Int, session: String = "default") async throws -> BrowserResult {
        return try await execute(["click", String(index), "--session", session])
    }
    
    /// Input text into an element
    /// - Parameters:
    ///   - index: Element index from state command
    ///   - text: Text to input
    ///   - session: Session name
    func input(index: Int, text: String, session: String = "default") async throws -> BrowserResult {
        return try await execute(["input", String(index), text, "--session", session])
    }
    
    /// Type text without targeting specific element
    /// - Parameters:
    ///   - text: Text to type
    ///   - session: Session name
    func type(text: String, session: String = "default") async throws -> BrowserResult {
        return try await execute(["type", text, "--session", session])
    }
    
    /// Scroll the page
    /// - Parameters:
    ///   - direction: Scroll direction (up, down, left, right)
    ///   - session: Session name
    func scroll(direction: String, session: String = "default") async throws -> BrowserResult {
        return try await execute(["scroll", direction, "--session", session])
    }
    
    /// Press keyboard keys
    /// - Parameters:
    ///   - key: Key to press (e.g., "Enter", "Tab", "Escape")
    ///   - session: Session name
    func keys(_ key: String, session: String = "default") async throws -> BrowserResult {
        return try await execute(["keys", key, "--session", session])
    }
    
    /// Take a screenshot
    /// - Parameters:
    ///   - filename: Optional filename to save to
    ///   - session: Session name
    /// - Returns: Result containing screenshot path
    func screenshot(filename: String? = nil, session: String = "default") async throws -> BrowserResult {
        var args = ["screenshot"]
        if let filename = filename {
            args.append(filename)
        }
        args.append(contentsOf: ["--session", session])
        return try await execute(args)
    }
    
    /// Go back in browser history
    /// - Parameter session: Session name
    func back(session: String = "default") async throws -> BrowserResult {
        return try await execute(["back", "--session", session])
    }
    
    /// Close the browser
    /// - Parameter session: Session name
    func close(session: String = "default") async throws -> BrowserResult {
        let result = try await execute(["close", "--session", session])
        if result.success {
            isActive = false
        }
        return result
    }
    
    /// List active browser sessions
    func sessions() async throws -> BrowserResult {
        return try await execute(["sessions"])
    }
    
    // MARK: - Private
    
    /// Execute a browser-use-sidecar command
    private func execute(_ arguments: [String]) async throws -> BrowserResult {
        guard let binaryPath = binaryPath else {
            throw BrowserUseError.binaryNotFound
        }
        
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw BrowserUseError.binaryNotExecutable
        }
        
        Log.debug("[BrowserUse] Executing: \(binaryPath) \(arguments.joined(separator: " "))")
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set up environment with API keys for agent mode
            var env = ProcessInfo.processInfo.environment
            env["PYTHONUNBUFFERED"] = "1"
            
            // Add browser agent API key if configured
            if let envName = self.agentAPIKeyEnvName,
               let apiKey = self.agentAPIKey,
               !apiKey.isEmpty {
                env[envName] = apiKey
            }
            
            // Add browser agent base URL if configured
            if let baseUrlEnvName = self.agentBaseUrlEnvName,
               let baseUrl = self.agentBaseUrl,
               !baseUrl.isEmpty {
                env[baseUrlEnvName] = baseUrl
            }
            
            process.environment = env
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BrowserUseError.executionFailed(error.localizedDescription))
                return
            }
            
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            Log.debug("[BrowserUse] Output: \(output.prefix(500))")
            if !errorOutput.isEmpty {
                Log.debug("[BrowserUse] Stderr: \(errorOutput.prefix(500))")
            }
            
            // Parse JSON result
            guard !output.isEmpty else {
                if !errorOutput.isEmpty {
                    continuation.resume(throwing: BrowserUseError.executionFailed(errorOutput))
                } else {
                    continuation.resume(throwing: BrowserUseError.emptyResponse)
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(BrowserResult.self, from: Data(output.utf8))
                
                // Update error state
                Task { @MainActor in
                    self.lastError = result.error
                }
                
                continuation.resume(returning: result)
            } catch {
                Log.debug("[BrowserUse] JSON parse error: \(error)")
                continuation.resume(throwing: BrowserUseError.invalidResponse(output))
            }
        }
    }
}

/// Browser automation errors
enum BrowserUseError: LocalizedError {
    case binaryNotFound
    case binaryNotExecutable
    case executionFailed(String)
    case emptyResponse
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "browser-use-sidecar binary not found in bundle"
        case .binaryNotExecutable:
            return "browser-use-sidecar binary is not executable"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .emptyResponse:
            return "Empty response from browser-use-sidecar"
        case .invalidResponse(let output):
            return "Invalid JSON response: \(output.prefix(200))"
        }
    }
}

import Foundation

@MainActor
extension ConfigManager {
    // MARK: - Directory Management
    
    /// User workspace directory (~/.motive/)
    var workspaceDirectory: URL {
        WorkspaceManager.defaultWorkspaceURL
    }
    
    /// App support directory for runtime files (~/Library/Application Support/Motive/)
    var appSupportDirectory: URL? {
        let fileManager = FileManager.default
        
        // Try Application Support
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
    
    /// Runtime directory for node_modules, browser-use, etc.
    var runtimeDirectory: URL? {
        appSupportDirectory?.appendingPathComponent("runtime")
    }
    
    /// Binary storage directory (kept in Application Support for signing)
    var binaryStorageDirectory: URL? {
        appSupportDirectory
    }
    
    /// Path to the signed opencode binary
    private var signedBinaryPath: URL? {
        binaryStorageDirectory?.appendingPathComponent("opencode")
    }
    
    /// Directory containing managed skills (now in workspace)
    var skillsManagedDirectoryURL: URL? {
        workspaceDirectory.appendingPathComponent("skills")
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
        
        // 3. Try global and common installations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let globalPaths = [
            "\(homeDir)/.opencode/bin/opencode",  // OpenCode self-install location
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
}

//
//  ConfigManager+Project.swift
//  Motive
//
//  Project directory management for OpenCode integration
//

import Foundation

extension ConfigManager {
    // MARK: - Project Directory Management
    
    /// Default global working directory when no project is selected
    static var defaultProjectDirectory: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".motive")
    }
    
    /// Maximum number of recent projects to keep
    static let maxRecentProjects = 10
    
    /// Get the current project directory URL
    /// Returns ~/.motive if not configured
    var currentProjectURL: URL {
        if currentProjectPath.isEmpty {
            return Self.defaultProjectDirectory
        }
        return URL(fileURLWithPath: currentProjectPath)
    }
    
    /// Get the display name for current project
    var currentProjectDisplayName: String {
        if currentProjectPath.isEmpty {
            return "~/.motive"
        }
        let url = URL(fileURLWithPath: currentProjectPath)
        return url.lastPathComponent
    }
    
    /// Get shortened path for display (replaces home with ~)
    var currentProjectShortPath: String {
        if currentProjectPath.isEmpty {
            return "~/.motive"
        }
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if currentProjectPath.hasPrefix(homeDir) {
            return "~" + currentProjectPath.dropFirst(homeDir.count)
        }
        return currentProjectPath
    }
    
    /// Recent projects list
    var recentProjects: [RecentProject] {
        get {
            guard let data = recentProjectsJSON.data(using: .utf8),
                  let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
                return []
            }
            return projects
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                recentProjectsJSON = json
            }
        }
    }
    
    /// Set the current project directory
    /// - Parameter path: The directory path, or nil to use default
    /// - Returns: true if the directory exists and was set successfully
    @discardableResult
    func setProjectDirectory(_ path: String?) -> Bool {
        guard let path = path, !path.isEmpty else {
            currentProjectPath = ""
            Log.config("Project directory reset to default (~/.motive)")
            return true
        }
        
        // Expand ~ to home directory
        var expandedPath = path
        if expandedPath.hasPrefix("~") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            expandedPath = homeDir + expandedPath.dropFirst()
        }
        
        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            Log.config("Project directory does not exist: \(expandedPath)")
            return false
        }
        
        currentProjectPath = expandedPath
        addToRecentProjects(expandedPath)
        Log.config("Project directory set to: \(expandedPath)")
        return true
    }
    
    /// Add a project to the recent list
    private func addToRecentProjects(_ path: String) {
        var projects = recentProjects
        
        // Remove if already exists (will re-add at top)
        projects.removeAll { $0.path == path }
        
        // Add at the beginning
        let project = RecentProject(
            path: path,
            name: URL(fileURLWithPath: path).lastPathComponent,
            lastUsed: Date()
        )
        projects.insert(project, at: 0)
        
        // Keep only the most recent
        if projects.count > Self.maxRecentProjects {
            projects = Array(projects.prefix(Self.maxRecentProjects))
        }
        
        recentProjects = projects
    }

    /// Record a recent project without changing current project
    func recordRecentProject(_ path: String) {
        guard !path.isEmpty else { return }

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        addToRecentProjects(path)
    }

    /// Ensure the current project is included in recent projects
    func ensureCurrentProjectInRecents() {
        guard !currentProjectPath.isEmpty else { return }
        addToRecentProjects(currentProjectPath)
    }
    
    /// Ensure the default project directory exists
    func ensureDefaultProjectDirectory() {
        let defaultDir = Self.defaultProjectDirectory
        if !FileManager.default.fileExists(atPath: defaultDir.path) {
            do {
                try FileManager.default.createDirectory(at: defaultDir, withIntermediateDirectories: true)
                Log.config("Created default project directory: \(defaultDir.path)")
            } catch {
                Log.config("Failed to create default project directory: \(error)")
            }
        }
    }
}

// MARK: - Recent Project Model

struct RecentProject: Codable, Identifiable, Equatable, Sendable {
    var id: String { path }
    let path: String
    let name: String
    let lastUsed: Date
    
    /// Get shortened path for display (replaces home with ~)
    var shortPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }
}

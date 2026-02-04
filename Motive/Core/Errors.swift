//
//  Errors.swift
//  Motive
//
//  Domain-specific error types for the application.
//  Each error carries enough context for debugging and user-facing messages.
//

import Foundation

// MARK: - Bridge Errors

/// Errors that can occur during OpenCode bridge operations
enum BridgeError: Error, LocalizedError, Sendable {
    case notConfigured
    case processSpawnFailed(underlying: Error)
    case sessionNotFound(id: String)
    case invalidResponse(message: String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenCode bridge is not configured"
        case .processSpawnFailed(let underlying):
            return "Failed to spawn OpenCode process: \(underlying.localizedDescription)"
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        case .invalidResponse(let message):
            return "Invalid response from OpenCode: \(message)"
        case .timeout:
            return "OpenCode operation timed out"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Please configure the OpenCode binary in Settings."
        case .processSpawnFailed:
            return "Check that the OpenCode binary is installed and accessible."
        case .sessionNotFound:
            return "The session may have been deleted. Try starting a new session."
        case .invalidResponse:
            return "Try restarting the agent."
        case .timeout:
            return "The operation took too long. Try again or check your network connection."
        }
    }
}

// MARK: - Session Errors

/// Errors that can occur during session management
enum SessionError: Error, LocalizedError, Sendable {
    case invalidIntent
    case notFound(id: UUID)
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case contextNotAttached
    
    var errorDescription: String? {
        switch self {
        case .invalidIntent:
            return "Invalid session intent"
        case .notFound(let id):
            return "Session not found: \(id)"
        case .saveFailed(let underlying):
            return "Failed to save session: \(underlying.localizedDescription)"
        case .loadFailed(let underlying):
            return "Failed to load session: \(underlying.localizedDescription)"
        case .contextNotAttached:
            return "Model context is not attached"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidIntent:
            return "Please enter a valid command or question."
        case .notFound:
            return "The session may have been deleted."
        case .saveFailed, .loadFailed:
            return "Try restarting the application."
        case .contextNotAttached:
            return "The application is not fully initialized."
        }
    }
}

// MARK: - Skill Errors

/// Errors that can occur during skill operations
enum SkillError: Error, LocalizedError, Sendable {
    case notFound(name: String)
    case invalidFormat(reason: String)
    case installFailed(name: String, reason: String)
    case loadFailed(path: String, reason: String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return "Skill not found: \(name)"
        case .invalidFormat(let reason):
            return "Invalid skill format: \(reason)"
        case .installFailed(let name, let reason):
            return "Failed to install skill '\(name)': \(reason)"
        case .loadFailed(let path, let reason):
            return "Failed to load skill from \(path): \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "Check the skill name and try again."
        case .invalidFormat:
            return "Ensure the skill follows the correct SKILL.md format."
        case .installFailed:
            return "Check your internet connection and try again."
        case .loadFailed:
            return "Verify the skill file exists and is readable."
        }
    }
}

// MARK: - Workspace Errors

/// Errors that can occur during workspace operations
enum WorkspaceError: Error, LocalizedError, Sendable {
    case directoryCreationFailed(path: String, reason: String)
    case fileNotFound(path: String)
    case readFailed(path: String, reason: String)
    case writeFailed(path: String, reason: String)
    case migrationFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path, let reason):
            return "Failed to create directory at \(path): \(reason)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .readFailed(let path, let reason):
            return "Failed to read \(path): \(reason)"
        case .writeFailed(let path, let reason):
            return "Failed to write \(path): \(reason)"
        case .migrationFailed(let reason):
            return "Workspace migration failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .directoryCreationFailed:
            return "Check that you have write permissions to the directory."
        case .fileNotFound:
            return "The file may have been moved or deleted."
        case .readFailed, .writeFailed:
            return "Check file permissions and available disk space."
        case .migrationFailed:
            return "Try manually moving your files to ~/.motive/"
        }
    }
}

// MARK: - Permission Errors

/// Errors that can occur during permission operations
enum PermissionError: Error, LocalizedError, Sendable {
    case denied(operation: String, path: String)
    case timeout(operation: String)
    case serverError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .denied(let operation, let path):
            return "Permission denied for \(operation) on \(path)"
        case .timeout(let operation):
            return "Permission request timed out for \(operation)"
        case .serverError(let message):
            return "Permission server error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .denied:
            return "Grant the permission in the dialog or update your permission policy."
        case .timeout:
            return "Try the operation again."
        case .serverError:
            return "Restart the application and try again."
        }
    }
}

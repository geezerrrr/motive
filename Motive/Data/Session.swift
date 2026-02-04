//
//  Session.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import Foundation
import SwiftData

// MARK: - Session Status Enum

/// Type-safe session status
enum SessionStatus: String, Codable, Sendable {
    case running
    case completed
    case failed
    case interrupted
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .interrupted: return "Interrupted"
        }
    }
    
    var isActive: Bool {
        self == .running
    }
}

// MARK: - Session Model

@Model
final class Session {
    var id: UUID
    var intent: String
    var createdAt: Date
    var openCodeSessionId: String?  // OpenCode CLI session ID for resuming
    /// Raw status string for persistence (use sessionStatus computed property for type-safe access)
    var status: String = "completed"  // running, completed, failed, interrupted (default for migration)
    /// Project directory used when the session was created (resolved path)
    var projectPath: String = ""
    @Relationship(deleteRule: .cascade) var logs: [LogEntry]
    
    /// Type-safe accessor for session status
    var sessionStatus: SessionStatus {
        get { SessionStatus(rawValue: status) ?? .completed }
        set { status = newValue.rawValue }
    }

    init(id: UUID = UUID(), intent: String, createdAt: Date = Date(), openCodeSessionId: String? = nil, status: SessionStatus = .running, projectPath: String = "", logs: [LogEntry] = []) {
        self.id = id
        self.intent = intent
        self.createdAt = createdAt
        self.openCodeSessionId = openCodeSessionId
        self.status = status.rawValue
        self.projectPath = projectPath
        self.logs = logs
    }
}

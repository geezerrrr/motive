//
//  AgentIdentity.swift
//  Motive
//
//  Model for agent identity parsed from IDENTITY.md
//

import Foundation

/// Agent identity parsed from IDENTITY.md
struct AgentIdentity: Codable, Sendable, Equatable {
    var name: String?
    var emoji: String?
    var creature: String?
    var vibe: String?
    var avatar: String?
    
    init(name: String? = nil, emoji: String? = nil, creature: String? = nil, vibe: String? = nil, avatar: String? = nil) {
        self.name = name
        self.emoji = emoji
        self.creature = creature
        self.vibe = vibe
        self.avatar = avatar
    }
    
    /// Check if any identity values are set
    func hasValues() -> Bool {
        name != nil || emoji != nil || creature != nil || vibe != nil
    }
    
    /// Display name with fallback to "Motive"
    var displayName: String {
        name ?? "Motive"
    }
    
    /// Display emoji with fallback to "✦"
    var displayEmoji: String {
        emoji ?? "✦"
    }
}

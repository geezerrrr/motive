//
//  IdentityParser.swift
//  Motive
//
//  Parses IDENTITY.md markdown format to extract agent identity.
//

import Foundation

/// Parser for IDENTITY.md markdown format
/// Follows OpenClaw patterns for parsing identity files
enum IdentityParser {
    /// Parse IDENTITY.md content and extract identity fields
    /// - Parameter content: The markdown content of IDENTITY.md
    /// - Returns: Parsed AgentIdentity
    static func parse(_ content: String) -> AgentIdentity {
        var identity = AgentIdentity()
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and headers
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("*") else { continue }
            
            // Parse "- **Key:** Value" or "- Key: Value" format
            if let (key, value) = parseListItem(trimmed) {
                let cleanKey = key.lowercased()
                let cleanValue = filterPlaceholder(value)
                
                guard let cleanValue = cleanValue else { continue }
                
                // First value wins for duplicate keys
                switch cleanKey {
                case "name":
                    if identity.name == nil { identity.name = cleanValue }
                case "emoji":
                    if identity.emoji == nil { identity.emoji = cleanValue }
                case "creature":
                    if identity.creature == nil { identity.creature = cleanValue }
                case "vibe":
                    if identity.vibe == nil { identity.vibe = cleanValue }
                case "avatar":
                    if identity.avatar == nil { identity.avatar = cleanValue }
                default:
                    break
                }
            }
        }
        
        return identity
    }
    
    /// Parse a list item line and extract key-value pair
    /// Handles formats like:
    /// - "- **Name:** Value"
    /// - "- Name: Value"
    /// - "* **Name:** Value"
    private static func parseListItem(_ line: String) -> (key: String, value: String)? {
        // Remove list marker (- or *)
        var content = line
        if content.hasPrefix("-") {
            content = String(content.dropFirst())
        } else if content.hasPrefix("*") && !content.hasPrefix("**") {
            content = String(content.dropFirst())
        }
        content = content.trimmingCharacters(in: .whitespaces)
        
        // Find the colon separator
        guard let colonIndex = content.firstIndex(of: ":") else { return nil }
        
        var key = String(content[..<colonIndex])
        var value = String(content[content.index(after: colonIndex)...])
        
        // Strip markdown formatting from key and value
        key = stripMarkdown(key)
        value = stripMarkdown(value)
        
        guard !key.isEmpty else { return nil }
        
        return (key, value)
    }
    
    /// Strip markdown formatting (bold, italic)
    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        
        // Remove ** bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        
        // Remove * italic markers (but not **)
        result = result.replacingOccurrences(of: "*", with: "")
        
        // Remove _ italic/bold markers
        result = result.replacingOccurrences(of: "_", with: "")
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Filter out placeholder values
    /// Returns nil if the value is a placeholder or empty
    private static func filterPlaceholder(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // Empty value
        guard !trimmed.isEmpty else { return nil }
        
        // Check for placeholder patterns
        let placeholderPatterns = [
            "(pick something",
            "(choose",
            "(your",
            "(fill",
            "[pick",
            "[choose",
            "[your",
            "[fill",
            "...",
            "___"
        ]
        
        let lowercased = trimmed.lowercased()
        for pattern in placeholderPatterns {
            if lowercased.contains(pattern) {
                return nil
            }
        }
        
        // Check if it's just parentheses or brackets with content
        if (trimmed.hasPrefix("(") && trimmed.hasSuffix(")")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            return nil
        }
        
        return trimmed
    }
}

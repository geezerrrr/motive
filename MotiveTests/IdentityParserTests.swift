//
//  IdentityParserTests.swift
//  MotiveTests
//
//  Tests for IdentityParser markdown parsing functionality.
//

import Foundation
import Testing
@testable import Motive

@Suite("IdentityParser")
@MainActor
struct IdentityParserTests {
    
    // MARK: - Standard Format Tests
    
    @Test func parsesStandardBoldFormat() {
        let content = """
        # IDENTITY.md
        - **Name:** Aria
        - **Emoji:** 🌸
        - **Creature:** helpful spirit
        - **Vibe:** calm and thoughtful
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
        #expect(identity.emoji == "🌸")
        #expect(identity.creature == "helpful spirit")
        #expect(identity.vibe == "calm and thoughtful")
    }
    
    @Test func parsesWithoutBoldMarkers() {
        let content = """
        - Name: Aria
        - Emoji: 🌸
        - Creature: helpful spirit
        - Vibe: calm
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
        #expect(identity.emoji == "🌸")
        #expect(identity.creature == "helpful spirit")
        #expect(identity.vibe == "calm")
    }
    
    @Test func parsesWithAsteriskListMarker() {
        let content = """
        * **Name:** Aria
        * **Emoji:** 🌸
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
        #expect(identity.emoji == "🌸")
    }
    
    @Test func parsesWithMixedFormatting() {
        let content = """
        - **Name:** Aria
        - _Emoji:_ 🌸
        - Creature: helpful spirit
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
        #expect(identity.creature == "helpful spirit")
    }
    
    // MARK: - Placeholder Filtering Tests
    
    @Test func filtersParenthesisPlaceholders() {
        let content = """
        - **Name:** (pick something you like)
        - **Emoji:** (choose an emoji)
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == nil)
        #expect(identity.emoji == nil)
    }
    
    @Test func filtersBracketPlaceholders() {
        let content = """
        - **Name:** [your name here]
        - **Emoji:** [pick one]
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == nil)
        #expect(identity.emoji == nil)
    }
    
    @Test func filtersEmptyValues() {
        let content = """
        - **Name:** 
        - **Emoji:** 
        - **Creature:** 
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == nil)
        #expect(identity.emoji == nil)
        #expect(identity.creature == nil)
    }
    
    @Test func filtersDotsPlaceholder() {
        let content = """
        - **Name:** ...
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test func handlesExtraWhitespace() {
        let content = """
        -    **Name:**     Aria   
        -   **Emoji:**   🌸  
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
        #expect(identity.emoji == "🌸")
    }
    
    @Test func ignoresNonListLines() {
        let content = """
        # IDENTITY.md
        
        *Some italic text*
        
        - **Name:** Aria
        
        Some paragraph text
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
    }
    
    @Test func handlesCaseInsensitiveKeys() {
        let content = """
        - **name:** Aria
        - **NAME:** Should be ignored (first wins)
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
    }
    
    @Test func preservesValueCase() {
        let content = """
        - **Name:** Aria the Great
        - **Vibe:** Calm AND Thoughtful
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria the Great")
        #expect(identity.vibe == "Calm AND Thoughtful")
    }
    
    @Test func handlesUnknownKeys() {
        let content = """
        - **Name:** Aria
        - **Unknown:** Some value
        - **Emoji:** 🌸
        """
        
        let identity = IdentityParser.parse(content)
        
        #expect(identity.name == "Aria")
        #expect(identity.emoji == "🌸")
    }
}

@Suite("AgentIdentity")
@MainActor
struct AgentIdentityTests {
    
    @Test func hasValuesReturnsFalseForEmpty() {
        let identity = AgentIdentity()
        #expect(!identity.hasValues())
    }
    
    @Test func hasValuesReturnsTrueWithName() {
        let identity = AgentIdentity(name: "Test")
        #expect(identity.hasValues())
    }
    
    @Test func hasValuesReturnsTrueWithEmoji() {
        let identity = AgentIdentity(emoji: "🌸")
        #expect(identity.hasValues())
    }
    
    @Test func hasValuesReturnsTrueWithCreature() {
        let identity = AgentIdentity(creature: "helper")
        #expect(identity.hasValues())
    }
    
    @Test func hasValuesReturnsTrueWithVibe() {
        let identity = AgentIdentity(vibe: "calm")
        #expect(identity.hasValues())
    }
    
    @Test func displayNameFallsBackToMotive() {
        let identity = AgentIdentity()
        #expect(identity.displayName == "Motive")
    }
    
    @Test func displayNameReturnsSetName() {
        let identity = AgentIdentity(name: "Aria")
        #expect(identity.displayName == "Aria")
    }
    
    @Test func displayEmojiFallsBackToStar() {
        let identity = AgentIdentity()
        #expect(identity.displayEmoji == "✦")
    }
    
    @Test func displayEmojiReturnsSetEmoji() {
        let identity = AgentIdentity(emoji: "🌸")
        #expect(identity.displayEmoji == "🌸")
    }
}

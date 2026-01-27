//
//  CommandBarCompletedView.swift
//  Motive
//
//  Aurora Design System - Completed State View
//  Shows task summary and follow-up input
//

import SwiftUI

struct CommandBarCompletedView: View {
    let messages: [ConversationMessage]
    @Binding var followUpText: String
    @FocusState.Binding var isFollowUpFocused: Bool
    let onSendFollowUp: () -> Void
    let onOpenDrawer: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with completion status
            headerView
            
            Divider().background(Color.Aurora.border)
            
            // Summary content
            summaryView
            
            Divider().background(Color.Aurora.border)
            
            // Follow-up input
            followUpInputView
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: AuroraSpacing.space3) {
            // Completed icon
            ZStack {
                Circle()
                    .fill(Color.Aurora.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.Aurora.accent)
            }
            
            VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                Text("Completed")
                    .font(.Aurora.bodySmall.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(completionSummary)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            
            Spacer()
            
            // Expand/Drawer button
            Button(action: onOpenDrawer) {
                HStack(spacing: AuroraSpacing.space2) {
                    Image(systemName: "rectangle.expand.vertical")
                        .font(.system(size: 11, weight: .medium))
                    Text("Drawer")
                        .font(.Aurora.caption.weight(.medium))
                }
                .foregroundColor(Color.Aurora.textSecondary)
                .padding(.horizontal, AuroraSpacing.space3)
                .padding(.vertical, AuroraSpacing.space2)
                .background(Color.Aurora.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.Aurora.border, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AuroraSpacing.space5)
        .padding(.vertical, AuroraSpacing.space4)
    }
    
    // MARK: - Summary View
    
    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
                // Show the last assistant message as summary
                if let lastAssistant = lastAssistantMessage {
                    Text(lastAssistant.content)
                        .font(.Aurora.bodySmall)
                        .foregroundColor(Color.Aurora.textPrimary)
                        .lineLimit(isExpanded ? nil : 4)
                }
                
                // Show modified files if any
                if !modifiedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                        Text("Modified files:")
                            .font(.Aurora.caption.weight(.medium))
                            .foregroundColor(Color.Aurora.textSecondary)
                        
                        ForEach(modifiedFiles.prefix(5), id: \.self) { file in
                            HStack(spacing: AuroraSpacing.space2) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.Aurora.accent)
                                
                                Text(file)
                                    .font(.Aurora.monoSmall)
                                    .foregroundColor(Color.Aurora.textMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        if modifiedFiles.count > 5 {
                            Text("+\(modifiedFiles.count - 5) more files")
                                .font(.Aurora.caption)
                                .foregroundColor(Color.Aurora.textMuted)
                        }
                    }
                    .padding(AuroraSpacing.space3)
                    .background(Color.Aurora.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
                }
            }
            .padding(.horizontal, AuroraSpacing.space5)
            .padding(.vertical, AuroraSpacing.space3)
        }
        .frame(maxHeight: 120)
    }
    
    // MARK: - Follow-up Input
    
    private var followUpInputView: some View {
        HStack(spacing: AuroraSpacing.space3) {
            TextField("Follow up…", text: $followUpText)
                .textFieldStyle(.plain)
                .font(.Aurora.body)
                .foregroundColor(Color.Aurora.textPrimary)
                .focused($isFollowUpFocused)
                .onSubmit {
                    if !followUpText.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSendFollowUp()
                    }
                }
            
            // Send button
            Button(action: onSendFollowUp) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        followUpText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AnyShapeStyle(Color.Aurora.textMuted)
                            : AnyShapeStyle(Color.Aurora.auroraGradient)
                    )
            }
            .buttonStyle(.plain)
            .disabled(followUpText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, AuroraSpacing.space5)
        .padding(.vertical, AuroraSpacing.space4)
    }
    
    // MARK: - Computed Properties
    
    private var completionSummary: String {
        let toolCount = messages.filter { $0.type == .tool }.count
        if toolCount > 0 {
            return "\(toolCount) tool\(toolCount > 1 ? "s" : "") executed"
        }
        return "Task finished"
    }
    
    private var lastAssistantMessage: ConversationMessage? {
        messages.last { $0.type == .assistant }
    }
    
    private var modifiedFiles: [String] {
        // Extract file paths from tool messages
        var files: [String] = []
        for message in messages where message.type == .tool {
            if let toolName = message.toolName?.lowercased() {
                if toolName.contains("write") || toolName.contains("edit") {
                    // Try to extract file path from content
                    let content = message.content
                    if content.contains("/") {
                        // Simple extraction - take the first path-like string
                        let words = content.components(separatedBy: .whitespaces)
                        for word in words {
                            if word.contains("/") && !word.hasPrefix("http") {
                                let cleanPath = word.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`,;:"))
                                if !cleanPath.isEmpty {
                                    files.append(shortenPath(cleanPath))
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        return Array(Set(files)) // Remove duplicates
    }
    
    private func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 3 {
            return "…/" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

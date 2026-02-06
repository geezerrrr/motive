//
//  CommandBarRunningView.swift
//  Motive
//
//  Aurora Design System - Running State View
//  Shows progress, current tool, and activity log
//

import SwiftUI

struct CommandBarRunningView: View {
    let toolName: String?
    let onStop: () -> Void
    let onOpenDrawer: () -> Void
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var progressPhase: CGFloat = 0
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status and stop button
            headerView
            
            // Progress bar
            progressBarView
            
            Divider().background(Color.Aurora.border)
            
            // Activity log (recent tool calls)
            activityLogView
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: AuroraSpacing.space3) {
            // Status icon
            ZStack {
                Circle()
                    .fill(Color.Aurora.auroraGradient.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: toolIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.Aurora.auroraGradient)
            }
            
            VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                Text(statusTitle)
                    .font(.Aurora.bodySmall.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)
                    .auroraShimmer(isDark: isDark)
                
                Text(statusDetail)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .auroraShimmer(isDark: isDark)
            }
            
            Spacer()
            
            // Stop button
            Button(action: onStop) {
                HStack(spacing: AuroraSpacing.space2) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Stop")
                        .font(.Aurora.caption.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, AuroraSpacing.space3)
                .padding(.vertical, AuroraSpacing.space2)
                .background(Color.Aurora.error)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AuroraSpacing.space5)
        .padding(.vertical, AuroraSpacing.space4)
    }
    
    // MARK: - Progress Bar
    
    private var progressBarView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Aurora.surface)
                    .frame(height: 4)
                
                // Indeterminate progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Aurora.auroraGradient)
                    .frame(width: geometry.size.width * 0.3, height: 4)
                    .offset(x: progressPhase * (geometry.size.width * 0.7))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, AuroraSpacing.space5)
        .padding(.bottom, AuroraSpacing.space3)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                progressPhase = 1
            }
        }
    }
    
    // MARK: - Activity Log
    
    private var activityLogView: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            // Show recent tool messages
            let toolMessages = recentToolMessages
            
            if toolMessages.isEmpty {
                HStack(spacing: AuroraSpacing.space2) {
                    AuroraLoadingDots()
                    Text("Starting…")
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textMuted)
                }
                .padding(.horizontal, AuroraSpacing.space5)
                .padding(.vertical, AuroraSpacing.space3)
            } else {
                ForEach(toolMessages.prefix(3), id: \.id) { message in
                    ActivityLogItem(message: message)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AuroraSpacing.space2)
    }
    
    // MARK: - Helpers
    
    /// Title - overall task state (always "Running")
    private var statusTitle: String {
        L10n.CommandBar.running
    }
    
    /// Detail - current action (thinking or tool name with details)
    private var statusDetail: String {
        // When AI is thinking/reasoning
        if appState.menuBarState == .reasoning {
            return L10n.Drawer.thinking
        }
        
        // When executing a tool, show tool name and details
        if let name = toolName {
            let simpleName = name.simplifiedToolName
            
            // Use currentToolInput directly (set when tool_call is received)
            if let input = appState.currentToolInput, !input.isEmpty {
                return "\(simpleName): \(input)"
            }
            
            return simpleName
        }
        
        // Default to thinking
        return L10n.Drawer.thinking
    }
    
    private var toolIcon: String {
        guard let tool = toolName?.lowercased() else { return "bolt.fill" }
        
        switch tool {
        case let t where t.contains("read"): return "doc.text"
        case let t where t.contains("write"): return "square.and.pencil"
        case let t where t.contains("edit"): return "pencil"
        case let t where t.contains("bash"), let t where t.contains("shell"): return "terminal"
        case let t where t.contains("glob"), let t where t.contains("search"): return "magnifyingglass"
        case let t where t.contains("grep"): return "text.magnifyingglass"
        case let t where t.contains("task"), let t where t.contains("agent"): return "brain"
        default: return "bolt.fill"
        }
    }
    
    private var recentToolMessages: [ConversationMessage] {
        appState.messages.filter { $0.type == .tool }.suffix(3).reversed()
    }
}

// MARK: - Activity Log Item

private struct ActivityLogItem: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack(spacing: AuroraSpacing.space2) {
            // Status-aware icon
            statusIcon
                .frame(width: 16)
            
            Text(message.toolName?.simplifiedToolName ?? "Tool")
                .font(.Aurora.caption.weight(.medium))
                .foregroundColor(Color.Aurora.textSecondary)
            
            // Show tool input (path/command), then output summary — never raw output
            if let input = message.toolInput, !input.isEmpty {
                Text(input)
                    .font(.Aurora.monoSmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let outputSummary = message.toolOutputSummary {
                Text(outputSummary)
                    .font(.Aurora.micro)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, AuroraSpacing.space5)
        .padding(.vertical, AuroraSpacing.space1)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .running:
            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.primary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.error)
        case .pending:
            Image(systemName: iconForTool)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.accent)
        }
    }
    
    private var iconForTool: String {
        guard let tool = message.toolName?.lowercased() else { return "wrench" }
        
        switch tool {
        case let t where t.contains("read"): return "doc.text"
        case let t where t.contains("write"): return "square.and.pencil"
        case let t where t.contains("bash"): return "terminal"
        case let t where t.contains("glob"): return "folder"
        default: return "wrench"
        }
    }
}

// Note: AuroraLoadingDots is defined in DrawerComponents.swift

//
//  DrawerComponents.swift
//  Motive
//
//  Aurora Design System - Drawer Components
//

import SwiftUI
import MarkdownUI

// MARK: - Session List Item

struct SessionListItem: View {
    let session: Session
    var isDark: Bool = true
    let onSelect: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AuroraSpacing.space3) {
                // Status indicator with gradient for active
                Circle()
                    .fill(statusGradient)
                    .frame(width: 6, height: 6)
                
                // Content
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    Text(session.intent)
                        .font(.Aurora.bodySmall.weight(.medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                        .lineLimit(1)
                    
                    Text(timeAgo)
                        .font(.Aurora.micro)
                        .foregroundColor(Color.Aurora.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.Aurora.textMuted)
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, AuroraSpacing.space3)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(isHovering ? Color.Aurora.surfaceElevated : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.auroraFast) {
                isHovering = hovering
            }
        }
    }
    
    private var statusGradient: AnyShapeStyle {
        switch session.status {
        case "running":
            return AnyShapeStyle(Color.Aurora.primary)
        case "completed":
            return AnyShapeStyle(Color.Aurora.accent)
        case "failed":
            return AnyShapeStyle(Color.Aurora.error)
        default:
            return AnyShapeStyle(Color.Aurora.textMuted)
        }
    }
    
    private var timeAgo: String {
        let now = Date()
        let diff = now.timeIntervalSince(session.createdAt)
        
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isOutputExpanded = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        HStack {
            if message.type == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 0) {
                ZStack(alignment: message.type == .user ? .topTrailing : .topLeading) {
                    // Message content
                    Group {
                        switch message.type {
                        case .user:
                            userBubble
                        case .assistant:
                            assistantBubble
                        case .tool:
                            toolBubble
                        case .system:
                            systemBubble
                        }
                    }
                    
                    // Timestamp overlay on hover
                    if isHovering {
                        timestampBadge
                    }
                }
            }
            .animation(.auroraFast, value: isHovering)
            
            if message.type != .user {
                Spacer(minLength: 40)
            }
        }
        .onHover { isHovering = $0 }
    }
    
    // MARK: - User Bubble
    
    private var userBubble: some View {
        Text(message.content)
            .font(.Aurora.body)
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space3)
            .background(Color.Aurora.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
            .textSelection(.enabled)
    }
    
    // MARK: - Assistant Bubble (Dark with amber accent)
    
    /// Get agent identity for display
    private var agentIdentity: AgentIdentity? {
        WorkspaceManager.shared.loadIdentity()
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            // Avatar row - use identity if configured
            HStack(spacing: AuroraSpacing.space2) {
                if let identity = agentIdentity, identity.hasValues(), let emoji = identity.emoji {
                    // Use configured emoji
                    Text(emoji)
                        .font(.system(size: 12))
                } else {
                    // Default sparkle icon
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.Aurora.primary)
                }
                
                Text(agentIdentity?.displayName ?? L10n.Drawer.assistant)
                    .font(.Aurora.micro.weight(.semibold))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            
            // Render markdown content
            Markdown(message.content)
                .markdownTextStyle {
                    FontSize(14)
                    ForegroundColor(Color.Aurora.textPrimary)
                }
                .markdownBlockStyle(\.codeBlock) { configuration in
                    configuration.label
                        .padding(8)
                        .background(Color.Aurora.backgroundDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .textSelection(.enabled)
        }
        .padding(AuroraSpacing.space3)
        .background(Color.Aurora.primaryDark.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
        .overlay(
            // Left accent border - amber
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Aurora.primary)
                    .frame(width: 3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 0.5)
        )
    }
    
    // MARK: - Tool Bubble (Compact inline)
    
    private var toolBubble: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
            HStack(spacing: AuroraSpacing.space2) {
                Image(systemName: toolIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.Aurora.accent)
                
                Text(message.toolName?.simplifiedToolName ?? L10n.Drawer.tool)
                    .font(.Aurora.caption.weight(.medium))
                    .foregroundColor(Color.Aurora.textSecondary)
                
                Spacer()
                
                if message.toolOutput != nil {
                    Button(action: { withAnimation(.auroraFast) { isOutputExpanded.toggle() } }) {
                        Text(isOutputExpanded ? "Hide" : "Show")
                            .font(.Aurora.micro.weight(.medium))
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let toolInput = message.toolInput, !toolInput.isEmpty {
                Text(toolInput)
                    .font(.Aurora.monoSmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if !message.content.isEmpty && message.content != "…" {
                Text(message.content)
                    .font(.Aurora.monoSmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(2)
            }
            
            if let outputSummary = message.toolOutputSummary {
                Text(outputSummary)
                    .font(.Aurora.micro)
                    .foregroundColor(Color.Aurora.textMuted)
            }
            
            if isOutputExpanded, let output = message.toolOutput, !output.isEmpty {
                ScrollView {
                    Text(output)
                        .font(.Aurora.monoSmall)
                        .foregroundColor(Color.Aurora.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .padding(.top, AuroraSpacing.space1)
                .background(
                    RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous)
                        .fill(Color.Aurora.surface.opacity(0.4))
                )
            }
        }
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .fill(Color.Aurora.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .stroke(Color.Aurora.accent.opacity(0.15), lineWidth: 0.5)
        )
    }
    
    // MARK: - System Bubble
    
    private var systemBubble: some View {
        HStack(spacing: AuroraSpacing.space2) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(Color.Aurora.textMuted)
            
            Text(message.content)
                .font(.Aurora.bodySmall)
                .foregroundColor(Color.Aurora.textMuted)
        }
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
    }
    
    // MARK: - Timestamp Badge
    
    private var timestampBadge: some View {
        Text(message.timestamp, style: .time)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, AuroraSpacing.space2)
            .padding(.vertical, AuroraSpacing.space1)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
            )
            .offset(
                x: message.type == .user ? -8 : 8,
                y: -8
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Tool Icon
    
    private var toolIcon: String {
        guard let toolName = message.toolName?.lowercased() else { return "terminal" }
        
        switch toolName {
        case "read", "read_file": return "doc.text"
        case "write", "write_file": return "square.and.pencil"
        case "edit", "edit_file": return "pencil"
        case "bash", "shell", "command": return "terminal"
        case "glob", "find", "search": return "magnifyingglass"
        case "grep": return "text.magnifyingglass"
        case "task", "agent": return "brain"
        default: return "wrench"
        }
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    let toolName: String?
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        HStack(spacing: AuroraSpacing.space2) {
            // Aurora animated dots
            AuroraLoadingDots()
            
            Text(toolName?.simplifiedToolName ?? L10n.Drawer.thinking)
                .font(.Aurora.caption.weight(.medium))
                .foregroundColor(Color.Aurora.textSecondary)
                .auroraShimmer(isDark: isDark)
        }
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .fill(Color.Aurora.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Aurora Loading Dots

struct AuroraLoadingDots: View {
    @State private var animationPhase: Int = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.Aurora.primary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animationPhase == index ? 1.3 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.4)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Session Status Badge

struct SessionStatusBadge: View {
    let status: AppState.SessionStatus
    let currentTool: String?
    
    var body: some View {
        HStack(spacing: AuroraSpacing.space1) {
            statusIcon
                .font(.system(size: 10, weight: .bold))
            
            Text(statusText)
                .font(.Aurora.micro.weight(.semibold))
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, AuroraSpacing.space2)
        .padding(.vertical, AuroraSpacing.space1)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous)
                .fill(backgroundColor)
        )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "circle")
        case .running:
            Image(systemName: "circle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "xmark.circle.fill")
        case .interrupted:
            Image(systemName: "pause.circle.fill")
        }
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return L10n.StatusBar.idle
        case .running:
            return currentTool?.simplifiedToolName ?? L10n.Drawer.running
        case .completed:
            return L10n.Drawer.completed
        case .failed:
            return L10n.Drawer.failed
        case .interrupted:
            return L10n.Drawer.interrupted
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .idle: return Color.Aurora.textMuted
        case .running: return Color.Aurora.primary  // Amber for active state
        case .completed: return Color.Aurora.success
        case .failed: return Color.Aurora.error
        case .interrupted: return Color.Aurora.warning
        }
    }
    
    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

// MARK: - Shimmer Text Effect

struct ShimmerText: View {
    let text: String
    var isDark: Bool = true
    @State private var offset: CGFloat = -1
    
    var body: some View {
        Text(text)
            .font(.Aurora.caption.weight(.medium))
            .foregroundColor(Color.Aurora.textSecondary)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: shimmerColor.opacity(0.5), location: 0.4),
                            .init(color: shimmerColor.opacity(0.7), location: 0.5),
                            .init(color: shimmerColor.opacity(0.5), location: 0.6),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + offset * geometry.size.width * 2)
                }
                .mask(
                    Text(text)
                        .font(.Aurora.caption.weight(.medium))
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    offset = 1
                }
            }
    }
    
    private var shimmerColor: Color {
        isDark ? Color.Aurora.accentMid : Color.Aurora.accentStart
    }
}

//
//  DrawerComponents.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

// MARK: - Session List Item

struct SessionListItem: View {
    let session: Session
    var isDark: Bool = true
    let onSelect: () -> Void
    @State private var isHovering = false
    
    private var hoverBackground: Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.intent)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.Velvet.textPrimary)
                        .lineLimit(1)
                    
                    Text(timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(Color.Velvet.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.Velvet.textMuted)
                    .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovering ? hoverBackground : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var statusColor: Color {
        // 保留彩色以区分状态
        switch session.status {
        case "running": return .blue
        case "completed": return .green
        case "failed": return .red
        default: return Color.Velvet.textMuted
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
    
    private var isDark: Bool { colorScheme == .dark }
    
    // Adaptive colors for bubbles
    private var bubbleBackground: Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04)
    }
    private var bubbleBorder: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }
    
    var body: some View {
        HStack {
            if message.type == .user {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 0) {
                // Message content with overlay timestamp
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
                    
                    // Timestamp overlay (show on hover)
                    if isHovering {
                        Text(message.timestamp, style: .time)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                            )
                            .offset(
                                x: message.type == .user ? -6 : 6,
                                y: -6
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovering)
            
            if message.type != .user {
                Spacer(minLength: 30)
            }
        }
        .onHover { isHovering = $0 }
    }
    
    private var userBubble: some View {
        Text(message.content)
            .font(.system(size: 13))
            .foregroundColor(isDark ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDark ? Color.white : Color.black)
            )
            .textSelection(.enabled)
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Avatar
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.purple)
                
                Text(L10n.Drawer.assistant)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.Velvet.textSecondary)
            }
            
            Text(message.content)
                .font(.system(size: 13))
                .foregroundColor(Color.Velvet.textPrimary)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bubbleBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(bubbleBorder, lineWidth: 0.5)
        )
    }
    
    private var toolBubble: some View {
        HStack(spacing: 8) {
            Image(systemName: toolIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.toolName?.simplifiedToolName ?? L10n.Drawer.tool)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.Velvet.textSecondary)
                
                if !message.content.isEmpty && message.content != "…" {
                    Text(message.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.Velvet.textMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.green.opacity(0.15), lineWidth: 0.5)
        )
    }
    
    private var systemBubble: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(Color.Velvet.textMuted)
            
            Text(message.content)
                .font(.system(size: 11))
                .foregroundColor(Color.Velvet.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
    
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
        ShimmerText(
            text: toolName?.simplifiedToolName ?? L10n.Drawer.thinking,
            isDark: isDark
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04))
        )
    }
}

// MARK: - Session Status Badge

struct SessionStatusBadge: View {
    let status: AppState.SessionStatus
    let currentTool: String?
    
    var body: some View {
        HStack(spacing: 5) {
            statusIcon
                .font(.system(size: 9, weight: .bold))
            
            Text(statusText)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var statusIcon: some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "circle")
            case .running:
                Image(systemName: "circle.fill")
                    .foregroundColor(.blue)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
            case .failed:
                Image(systemName: "xmark.circle.fill")
            case .interrupted:
                Image(systemName: "pause.circle.fill")
            }
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
    
    private var statusColor: Color {
        // 保留彩色以区分状态
        switch status {
        case .idle:
            return Color.Velvet.textMuted
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .interrupted:
            return .orange
        }
    }
}

// MARK: - Shimmer Text Effect

struct ShimmerText: View {
    let text: String
    var isDark: Bool = true
    @State private var offset: CGFloat = -1
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isDark ? .white.opacity(0.6) : .black.opacity(0.6))
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: shimmerColor, location: 0.4),
                                .init(color: shimmerColor.opacity(0.5), location: 0.5),
                                .init(color: shimmerColor, location: 0.6),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: offset * 200)
                    .mask(
                        Text(text)
                            .font(.system(size: 12, weight: .medium))
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    offset = 2
                }
            }
    }
    
    private var shimmerColor: Color {
        isDark ? .white : .black
    }
}

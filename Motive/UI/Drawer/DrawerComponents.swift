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
            return AnyShapeStyle(Color.Aurora.success)
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
                        case .todo:
                            todoBubble
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
            .background(Color.Aurora.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
            .textSelection(.enabled)
    }
    
    // MARK: - Assistant Bubble (Dark with amber accent)
    
    /// Get agent identity for display
    private var agentIdentity: AgentIdentity? {
        WorkspaceManager.shared.loadIdentity()
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            HStack(spacing: AuroraSpacing.space2) {
                if let identity = agentIdentity, identity.hasValues(), let emoji = identity.emoji {
                    Text(emoji)
                        .font(.system(size: 12))
                } else {
                    Circle()
                        .fill(Color.Aurora.primary)
                        .frame(width: 6, height: 6)
                }
                
                Text(agentIdentity?.displayName ?? L10n.Drawer.assistant)
                    .font(.Aurora.micro.weight(.semibold))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            
            Markdown(message.content)
                .markdownTextStyle {
                    FontSize(13)
                    ForegroundColor(Color.Aurora.textPrimary)
                }
                .markdownBlockStyle(\.codeBlock) { configuration in
                    configuration.label
                        .padding(8)
                        .background(Color.Aurora.backgroundDeep.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .textSelection(.enabled)
        }
        .padding(AuroraSpacing.space3)
        .background(Color.Aurora.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }
    
    // MARK: - Tool Bubble (with lifecycle status indicator)
    
    private var toolBubble: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
            HStack(spacing: AuroraSpacing.space2) {
                // Status-aware icon
                toolStatusIcon
                
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
                    .accessibilityLabel(isOutputExpanded ? "Hide output" : "Show output")
                }
            }
            
            // Tool input label (path, command, description — never raw output)
            if let toolInput = message.toolInput, !toolInput.isEmpty {
                Text(toolInput)
                    .font(.Aurora.monoSmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // Uniform output summary: always "Output · N lines", click Show for details
            if let outputSummary = message.toolOutputSummary {
                Text(outputSummary)
                    .font(.Aurora.micro)
                    .foregroundColor(Color.Aurora.textMuted)
            } else if message.status == .running {
                // Tool is still executing — show processing hint
                Text("Processing…")
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
                        .fill(Color.Aurora.surface.opacity(0.7))
                )
            }
        }
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .fill(Color.Aurora.surface.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .strokeBorder(toolBorderColor.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    /// Status-aware icon for tool bubble: spinner when running, checkmark when done
    @ViewBuilder
    private var toolStatusIcon: some View {
        switch message.status {
        case .running:
            ToolRunningIndicator()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.Aurora.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.Aurora.error)
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.Aurora.textMuted)
        }
    }
    
    /// Border color that reflects tool status
    private var toolBorderColor: Color {
        switch message.status {
        case .running: return Color.Aurora.primary
        case .completed: return Color.Aurora.border
        case .failed: return Color.Aurora.error
        case .pending: return Color.Aurora.border
        }
    }
    
    // MARK: - System Bubble
    
    private var systemBubble: some View {
        HStack(spacing: AuroraSpacing.space2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(Color.Aurora.success)
            
            Text(message.content)
                .font(.Aurora.bodySmall)
                .foregroundColor(Color.Aurora.textMuted)
        }
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
    }
    
    // MARK: - Todo Bubble
    
    private var todoBubble: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            // Header
            HStack(spacing: AuroraSpacing.space2) {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Aurora.primary)
                
                Text("Tasks")
                    .font(.Aurora.caption.weight(.semibold))
                    .foregroundColor(Color.Aurora.textSecondary)
                
                Spacer()
                
                // Progress summary
                if let items = message.todoItems {
                    let completed = items.filter { $0.status == .completed }.count
                    Text("\(completed)/\(items.count)")
                        .font(.Aurora.micro.weight(.medium))
                        .foregroundColor(Color.Aurora.textMuted)
                }
            }
            
            // Todo items list
            if let items = message.todoItems {
                // Progress bar
                todoProgressBar(items: items)
                
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    ForEach(items) { item in
                        todoItemRow(item)
                    }
                }
            }
        }
        .padding(AuroraSpacing.space3)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .fill(Color.Aurora.surface.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .strokeBorder(Color.Aurora.primary.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    /// Progress bar showing overall todo completion
    private func todoProgressBar(items: [TodoItem]) -> some View {
        let completed = Double(items.filter { $0.status == .completed }.count)
        let total = Double(items.count)
        let progress = total > 0 ? completed / total : 0
        
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Aurora.surface)
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(progress >= 1.0 ? Color.Aurora.success : Color.Aurora.primary)
                    .frame(width: geometry.size.width * progress, height: 3)
                    .animation(.auroraSpring, value: progress)
            }
        }
        .frame(height: 3)
    }
    
    /// Single todo item row with status icon
    private func todoItemRow(_ item: TodoItem) -> some View {
        HStack(spacing: AuroraSpacing.space2) {
            todoStatusIcon(item.status)
            
            Text(item.content)
                .font(.Aurora.caption)
                .foregroundColor(todoTextColor(item.status))
                .strikethrough(item.status == .completed || item.status == .cancelled,
                               color: Color.Aurora.textMuted.opacity(0.5))
                .lineLimit(2)
        }
        .padding(.vertical, 1)
    }
    
    /// Icon for todo item status
    @ViewBuilder
    private func todoStatusIcon(_ status: TodoItem.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.textMuted)
        case .inProgress:
            Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.Aurora.primary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.success)
        case .cancelled:
            Image(systemName: "xmark.circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.Aurora.textMuted)
        }
    }
    
    /// Text color based on todo status
    private func todoTextColor(_ status: TodoItem.Status) -> Color {
        switch status {
        case .pending: return Color.Aurora.textSecondary
        case .inProgress: return Color.Aurora.textPrimary
        case .completed: return Color.Aurora.textMuted
        case .cancelled: return Color.Aurora.textMuted
        }
    }
    
    // MARK: - Timestamp Badge
    
    private var timestampBadge: some View {
        Text(message.timestamp, style: .time)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(Color.Aurora.textSecondary)
            .padding(.horizontal, AuroraSpacing.space2)
            .padding(.vertical, AuroraSpacing.space1)
            .background(
                Capsule()
                    .fill(Color.Aurora.surfaceElevated)
            )
            .offset(
                x: message.type == .user ? -8 : 8,
                y: -8
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Tool Icon (legacy fallback)
    
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

// MARK: - Tool Running Indicator (small spinner for tool bubble)

struct ToolRunningIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "arrow.trianglehead.2.counterclockwise")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.Aurora.primary)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
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
                .fill(Color.Aurora.surfaceElevated)
        )
    }
}

// MARK: - Aurora Loading Dots

struct AuroraLoadingDots: View {
    @State private var animationPhase: Int = 0
    @State private var animationTask: Task<Void, Never>?
    
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
            animationTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animationPhase = (animationPhase + 1) % 3
                    }
                }
            }
        }
        .onDisappear {
            animationTask?.cancel()
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
        case .running: return Color.Aurora.primary
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

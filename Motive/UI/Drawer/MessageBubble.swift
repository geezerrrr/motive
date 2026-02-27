//
//  MessageBubble.swift
//  Motive
//
//  Aurora Design System - Drawer Components
//

import SwiftUI

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage
    let isFinalAssistantResult: Bool
    let isEditableLastUserMessage: Bool
    let onEditLastUserMessage: ((ConversationMessage) -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    /// Unified expand/collapse for tool output, diff details, and error details.
    @State private var isDetailExpanded = false

    private var isDark: Bool {
        colorScheme == .dark
    }

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
                            UserBubble(
                                message: message,
                                isDark: isDark,
                                canEdit: isEditableLastUserMessage,
                                onEdit: isEditableLastUserMessage ? { onEditLastUserMessage?(message) } : nil
                            )
                        case .assistant:
                            AssistantBubble(
                                message: message,
                                isDark: isDark,
                                showCopyAction: isFinalAssistantResult
                            )
                        case .tool:
                            ToolBubble(message: message, isDark: isDark, isDetailExpanded: $isDetailExpanded)
                        case .system:
                            SystemErrorBubble(message: message, isDark: isDark, isDetailExpanded: $isDetailExpanded)
                        case .todo:
                            TodoBubble(message: message, isDark: isDark)
                        case .reasoning:
                            EmptyView()
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

    // MARK: - Timestamp Badge

    private var timestampBadge: some View {
        Text(message.timestamp, style: .time)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(Color.Aurora.textSecondary)
            .padding(.horizontal, AuroraSpacing.space2)
            .padding(.vertical, AuroraSpacing.space1)
            .background(
                Capsule()
                    .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.10 : 0.12))
            )
            .offset(
                x: message.type == .user ? -8 : 8,
                y: -8
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

//
//  UserBubble.swift
//  Motive
//
//  Aurora Design System - User message bubble component
//

import SwiftUI

struct UserBubble: View {
    let message: ConversationMessage
    let isDark: Bool
    let canEdit: Bool
    let onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .trailing, spacing: AuroraSpacing.space1) {
            if canEdit, let onEdit {
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.Aurora.micro.weight(.semibold))
                        Text(L10n.edit)
                            .font(.Aurora.micro.weight(.medium))
                    }
                    .foregroundColor(Color.Aurora.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Drawer.editLastMessage)
            }

            Text(message.content)
                .font(.Aurora.body)
                .foregroundColor(Color.Aurora.textPrimary)
                .padding(.horizontal, AuroraSpacing.space4)
                .padding(.vertical, AuroraSpacing.space3)
                .background(Color.Aurora.glassOverlay.opacity(isDark ? 0.10 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous)
                        .strokeBorder(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.08), lineWidth: 0.5)
                )
                .textSelection(.enabled)
        }
    }
}

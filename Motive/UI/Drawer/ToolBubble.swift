//
//  ToolBubble.swift
//  Motive
//
//  Aurora Design System - Tool call message bubble component
//

import SwiftUI

struct ToolBubble: View {
    let message: ConversationMessage
    let isDark: Bool
    @Binding var isDetailExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
            HStack(spacing: AuroraSpacing.space2) {
                // Status-aware icon
                toolStatusIcon

                MetallicShimmerText(
                    text: message.toolName?.simplifiedToolName ?? L10n.Drawer.tool,
                    font: .Aurora.caption.weight(.medium),
                    baseColor: Color.Aurora.textSecondary,
                    isActive: message.status == .running
                )

                Spacer()

                if message.toolOutput != nil {
                    Button(action: { withAnimation(.auroraFast) { isDetailExpanded.toggle() } }) {
                        Text(isDetailExpanded ? L10n.hide : L10n.show)
                            .font(.Aurora.micro.weight(.medium))
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isDetailExpanded ? L10n.Drawer.hideOutput : L10n.Drawer.showOutput)
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

            // Inline diff preview for file-editing tools (always visible, no click needed)
            if let diff = message.diffContent, !diff.isEmpty {
                DiffPreviewView(diff: diff, isDark: isDark, isDetailExpanded: $isDetailExpanded)
            }

            // Uniform output summary: always "Output · N lines", click Show for details
            if let outputSummary = message.toolOutputSummary {
                Text(outputSummary)
                    .font(.Aurora.micro)
                    .foregroundColor(Color.Aurora.textMuted)
            } else if message.status == .running {
                // Tool is still executing — show processing hint
                Text(L10n.Drawer.processing)
                    .font(.Aurora.micro)
                    .foregroundColor(Color.Aurora.textMuted)
            }

            if isDetailExpanded, let output = message.toolOutput, !output.isEmpty {
                ScrollView {
                    OutputFormatter.formattedOutput(output, toolName: message.toolName, isDark: isDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 300)
                .padding(.top, AuroraSpacing.space2)
            }
        }
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.04 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
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
        case .running: Color.Aurora.primary
        case .completed: Color.Aurora.border
        case .failed: Color.Aurora.error
        case .pending: Color.Aurora.border
        }
    }
}

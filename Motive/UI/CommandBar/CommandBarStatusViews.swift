//
//  CommandBarStatusViews.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

extension CommandBarView {
    // MARK: - Running Status (above input)

    var runningStatusView: some View {
        HStack(spacing: AuroraSpacing.space3) {
            AuroraPulsingDot()

            VStack(alignment: .leading, spacing: 2) {
                MetallicShimmerText(
                    text: runningStatusTitle,
                    font: .Aurora.caption.weight(.semibold),
                    baseColor: Color.Aurora.textSecondary,
                    isActive: true
                )

                MetallicShimmerText(
                    text: runningStatusDetail,
                    font: .Aurora.caption,
                    baseColor: Color.Aurora.textSecondary,
                    isActive: true
                )
                .lineLimit(1)
                .truncationMode(.middle)
            }

            Spacer()

            // Stop button
            Button(action: { appState.interruptSession() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.Aurora.error)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop")
            .accessibilityHint("Interrupts the current task")

            // Open drawer button
            Button(action: {
                appState.showDrawer()
                appState.hideCommandBar()
            }) {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.Aurora.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.Aurora.glassOverlay.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open conversation")
            .accessibilityHint("Opens the conversation drawer")
        }
        .padding(.horizontal, AuroraSpacing.space6)
        .padding(.vertical, AuroraSpacing.space3)
    }

    /// Title for running status - overall task state
    private var runningStatusTitle: String {
        L10n.CommandBar.running // Always "Running" as the task is in progress
    }

    /// Detail for running status - current action (thinking or tool execution)
    private var runningStatusDetail: String {
        if appState.currentSessionAgent == "plan",
           let planPreview = appState.currentPlanPreviewText,
           !planPreview.isEmpty
        {
            let latestLine = planPreview
                .split(separator: "\n", omittingEmptySubsequences: true)
                .last
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let latestLine, !latestLine.isEmpty {
                return latestLine
            }
        }

        // When AI is thinking/reasoning
        if appState.menuBarState == .reasoning {
            return L10n.Drawer.thinking
        }

        // When executing a tool, show tool name and details
        if let toolName = appState.currentToolName {
            let simpleName = toolName.simplifiedToolName

            // Use currentToolInput directly (set when tool_call is received)
            if let input = appState.currentToolInput, !input.isEmpty {
                return "\(simpleName): \(input)"
            }

            return simpleName
        }

        // Default to thinking if no tool info
        return L10n.Drawer.thinking
    }

    // MARK: - Completed Summary (above input)

    var completedSummaryView: some View {
        let isNewSession = appState.messages.isEmpty
        let statusTitle = isNewSession ? L10n.CommandBar.newTask : L10n.CommandBar.completed
        let statusIcon = isNewSession ? "plus.circle.fill" : "checkmark.circle.fill"
        let statusColor = isNewSession ? Color.Aurora.primary : Color.Aurora.accent

        return HStack(spacing: AuroraSpacing.space3) {
            Image(systemName: statusIcon)
                .font(.system(size: 16))
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.Aurora.caption.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)

                if let lastAssistant = appState.messages.last(where: { $0.type == .assistant }) {
                    Text(lastAssistant.content.prefix(60) + (lastAssistant.content.count > 60 ? "..." : ""))
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textMuted)
                        .lineLimit(1)
                } else {
                    Text(L10n.CommandBar.typeRequest)
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Open drawer button
            Button(action: {
                appState.showDrawer()
                appState.hideCommandBar()
            }) {
                HStack(spacing: 4) {
                    Text(L10n.CommandBar.details)
                        .font(.Aurora.caption)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.Aurora.textSecondary)
                .padding(.horizontal, AuroraSpacing.space3)
                .padding(.vertical, AuroraSpacing.space2)
                .background(Color.Aurora.glassOverlay.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.Aurora.glassOverlay.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AuroraSpacing.space6)
        .padding(.vertical, AuroraSpacing.space3)
    }

    // MARK: - Error Status (above input)

    func errorStatusView(message: String) -> some View {
        HStack(spacing: AuroraSpacing.space3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.Aurora.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.CommandBar.error)
                    .font(.Aurora.caption.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)

                Text(message)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { showErrorDetailsPopover.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.Aurora.textSecondary)
                    .padding(.horizontal, AuroraSpacing.space2)
                    .padding(.vertical, AuroraSpacing.space2)
                    .background(Color.Aurora.glassOverlay.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.Aurora.glassOverlay.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show error details")
            .popover(isPresented: $showErrorDetailsPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.CommandBar.error)
                        .font(.Aurora.body.weight(.semibold))
                        .foregroundColor(Color.Aurora.textPrimary)
                    ScrollView {
                        Text(message)
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 420, height: 180)

                    HStack {
                        Spacer()
                        Button(L10n.CommandBar.dismiss) {
                            showErrorDetailsPopover = false
                        }
                        .buttonStyle(.plain)
                        .font(.Aurora.caption.weight(.semibold))
                        .foregroundColor(Color.Aurora.textSecondary)
                    }
                }
                .padding(12)
            }

            Button(action: { mode = .idle }) {
                Text(L10n.CommandBar.dismiss)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .padding(.horizontal, AuroraSpacing.space3)
                    .padding(.vertical, AuroraSpacing.space2)
                    .background(Color.Aurora.glassOverlay.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.Aurora.glassOverlay.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AuroraSpacing.space6)
        .padding(.vertical, AuroraSpacing.space3)
    }
}

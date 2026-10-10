//
//  DrawerHeader.swift
//  Motive
//
//  Aurora Design System - Drawer header with session dropdown
//

import SwiftUI

struct DrawerHeader: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configManager: ConfigManager
    @Binding var showSessionPicker: Bool
    let onLoadSessions: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Session dropdown button
                Button(action: {
                    onLoadSessions()
                    withAnimation(.auroraFast) {
                        showSessionPicker.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.Aurora.textSecondary)

                        Text(currentSessionTitle)
                            .font(.Aurora.bodySmall.weight(.semibold))
                            .foregroundColor(Color.Aurora.textPrimary)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.Aurora.micro.weight(.bold))
                            .foregroundColor(Color.Aurora.textMuted)
                            .rotationEffect(.degrees(showSessionPicker ? 180 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                            .fill(Color.Aurora.glassOverlay.opacity(showSessionPicker ? 0.10 : 0.06))
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                // Running count badge (other sessions still running)
                if runningOtherCount > 0 {
                    RunningCountBadge(count: runningOtherCount) {
                        onLoadSessions()
                        withAnimation(.auroraFast) {
                            showSessionPicker = true
                        }
                    }
                }

                // Status badge
                SessionStatusBadge(
                    status: appState.sessionStatus,
                    currentTool: appState.currentToolName,
                    isThinking: appState.menuBarState == .reasoning,
                    agent: appState.currentSessionAgent
                )

                // New chat button
                Button(action: {
                    appState.startNewEmptySession()
                    onLoadSessions()
                }) {
                    Image(systemName: "plus")
                        .font(.Aurora.micro.weight(.bold))
                        .foregroundColor(Color.Aurora.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.Aurora.glassOverlay.opacity(isDark ? 0.08 : 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                                .strokeBorder(Color.Aurora.glassOverlay.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.Drawer.newChat)
                .accessibilityLabel(L10n.Drawer.newChat)

                // Pin button
                Button(action: { appState.setDrawerPinned(!configManager.drawerPinned) }) {
                    Image(systemName: configManager.drawerPinned ? "pin.fill" : "pin")
                        .font(.Aurora.micro.weight(.bold))
                        .foregroundColor(configManager.drawerPinned ? Color.Aurora.primary : Color.Aurora.textMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.Aurora.glassOverlay.opacity(isDark ? 0.08 : 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                                .strokeBorder(Color.Aurora.glassOverlay.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(configManager.drawerPinned ? L10n.Drawer.unpin : L10n.Drawer.pin)
                .accessibilityLabel(configManager.drawerPinned ? L10n.Drawer.unpin : L10n.Drawer.pin)

                // Close button
                Button(action: { appState.hideDrawer() }) {
                    Image(systemName: "xmark")
                        .font(.Aurora.micro.weight(.bold))
                        .foregroundColor(Color.Aurora.textMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.Aurora.glassOverlay.opacity(isDark ? 0.08 : 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                                .strokeBorder(Color.Aurora.glassOverlay.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.Drawer.close)
                .accessibilityLabel(L10n.Drawer.close)
            }

            if let planPath = appState.currentPlanFilePath, !planPath.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.Aurora.textMuted)
                    Text("Plan file: \(displayPlanPath(planPath))")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.Aurora.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.top, 6)
            }
        }
    }

    /// Count of running sessions that are NOT the current session
    private var runningOtherCount: Int {
        let running = appState.getRunningSessions()
        let currentId = appState.currentSession?.id
        return running.count(where: { $0.id != currentId })
    }

    private var currentSessionTitle: String {
        if appState.messages.isEmpty {
            return L10n.Drawer.newChat
        }
        if let firstUser = appState.messages.first(where: { $0.type == .user }) {
            let text = firstUser.content
            return String(text.prefix(24)) + (text.count > 24 ? "..." : "")
        }
        return L10n.Drawer.conversation
    }

    private func displayPlanPath(_ path: String) -> String {
        if path.hasPrefix("/") {
            let cwd = appState.configManager.currentProjectURL.path
            if path.hasPrefix(cwd + "/") {
                return String(path.dropFirst(cwd.count + 1))
            }
        }
        return path
    }
}

// MARK: - Running Count Badge

/// Compact pill showing the count of other running sessions with a pulsing dot.
private struct RunningCountBadge: View {
    let count: Int
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.Aurora.success)
                    .frame(width: 6, height: 6)
                    .opacity(isPulsing ? 0.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.Aurora.success)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.Aurora.success.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.Aurora.success.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help("\(count) other session\(count == 1 ? "" : "s") running")
        .accessibilityLabel("\(count) other session\(count == 1 ? "" : "s") running. Tap to view.")
        .onAppear { isPulsing = true }
    }
}

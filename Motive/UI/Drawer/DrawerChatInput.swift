//
//  DrawerChatInput.swift
//  Motive
//
//  Aurora Design System - Drawer chat input area
//

import SwiftUI

struct DrawerChatInput: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configManager: ConfigManager
    @Binding var inputText: String
    var isInputFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onTextChange: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var textViewHeight: CGFloat = 26

    private static let maxLines = 5

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        let isRunning = appState.sessionStatus == .running

        VStack(spacing: 0) {
            HStack(spacing: AuroraSpacing.space2) {
                Image(systemName: "folder")
                    .font(.Aurora.micro.weight(.medium))
                    .foregroundColor(Color.Aurora.textMuted)

                Text(configManager.currentProjectShortPath)
                    .font(.Aurora.micro)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let contextTokens = appState.currentContextTokens {
                    ContextSizeBadge(tokens: contextTokens)
                        .fixedSize(horizontal: true, vertical: true)
                }

                AgentModeToggle(
                    currentAgent: configManager.currentAgent,
                    isRunning: isRunning,
                    onChange: { newAgent in
                        configManager.currentAgent = newAgent
                        appState.currentSessionAgent = newAgent
                        configManager.generateOpenCodeConfig()
                        appState.reconfigureBridge()
                    }
                )
                .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space2)

            Rectangle()
                .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.12))
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: AuroraSpacing.space3) {
                HStack(alignment: .center, spacing: AuroraSpacing.space2) {
                    GrowingTextView(
                        text: $inputText,
                        placeholder: L10n.Drawer.messagePlaceholder,
                        font: .systemFont(ofSize: 13),
                        textColor: NSColor(Color.Aurora.textPrimary),
                        placeholderColor: NSColor(Color.Aurora.textMuted),
                        maxLines: Self.maxLines,
                        isDisabled: isRunning,
                        onSubmit: onSubmit,
                        onTextChange: onTextChange,
                        height: $textViewHeight
                    )
                    .focused(isInputFocused)
                    .frame(height: textViewHeight)

                    if isRunning {
                        Button(action: { appState.interruptSession() }) {
                            Image(systemName: "stop.fill")
                                .font(.Aurora.micro.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.Aurora.error)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Drawer.stop)
                    } else {
                        Button(action: onSubmit) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.Aurora.title1.weight(.medium))
                                .foregroundColor(
                                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.Aurora.textMuted : Color.Aurora.microAccent
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel(L10n.CommandBar.submit)
                    }
                }
                .padding(.horizontal, AuroraSpacing.space4)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            isInputFocused.wrappedValue && !isRunning
                                ? Color.Aurora.microAccentSoft.opacity(isDark ? 0.25 : 0.15)
                                : (isDark ? Color.Aurora.glassOverlay.opacity(0.04) : Color.white.opacity(0.5))
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isInputFocused.wrappedValue && !isRunning
                                ? Color.Aurora.microAccent.opacity(0.4)
                                : Color.Aurora.glassOverlay.opacity(isDark ? 0.1 : 0.15),
                            lineWidth: 0.5
                        )
                )
                .animation(.auroraFast, value: isInputFocused.wrappedValue)
            }
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space3)
            .background(Color.Aurora.glassOverlay.opacity(isDark ? 0.04 : 0.08))
        }
    }
}

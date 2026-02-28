//
//  CommandBarInput.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

extension CommandBarView {
    // MARK: - Input Area (Always Visible - No icons, status shown above)

    /// Single-line text view height for the command bar font (17pt).
    static let singleLineInputHeight: CGFloat = 30

    var inputAreaView: some View {
        HStack(alignment: .bottom, spacing: AuroraSpacing.space3) {
            ZStack(alignment: .leading) {
                // Autocomplete hint (gray completion text) — only for single-line
                if inputHeight <= Self.singleLineInputHeight + 2, let completion = autocompleteCompletion {
                    HStack(spacing: 0) {
                        Text(inputText)
                            .font(.Aurora.headline.weight(.regular))
                            .opacity(0)

                        Text(completion)
                            .font(.Aurora.headline.weight(.regular))
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                }

                CommandBarTextField(
                    text: $inputText,
                    placeholder: placeholderText,
                    isDisabled: mode == .running,
                    onSubmit: handleSubmit,
                    onCmdDelete: {
                        if mode.isHistory {
                            handleCmdDelete()
                        }
                    },
                    onCmdN: handleCmdN,
                    onCmdReturn: nil,
                    onEscape: handleEscape,
                    inputHeight: $inputHeight
                )
                .focused($isInputFocused)
                .accessibilityLabel("Command input")
                .accessibilityHint("Type a command or question. Shift+Return for new line, Return to submit.")
            }

            // Tab hint when autocomplete is available
            if autocompleteCompletion != nil {
                Text("Tab")
                    .font(.Aurora.micro.weight(.medium))
                    .foregroundColor(Color.Aurora.microAccent)
                    .padding(.horizontal, AuroraSpacing.space2)
                    .padding(.vertical, AuroraSpacing.space1)
                    .background(
                        RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous)
                            .fill(Color.Aurora.microAccentSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous)
                            .strokeBorder(Color.Aurora.microAccent.opacity(0.35), lineWidth: 0.5)
                    )
            }

            actionButton
        }
        .padding(.vertical, 12)
        .padding(.horizontal, AuroraSpacing.space6)
    }

    var placeholderText: String {
        switch mode {
        case .command:
            "Type a command..."
        case .history:
            "Search sessions..."
        case .running, .completed, .error:
            "Follow up..."
        default:
            L10n.CommandBar.placeholder
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    var actionButton: some View {
        if !configManager.hasAPIKey {
            Button(action: {
                appState.hideCommandBar()
                SettingsWindowController.shared.show(tab: .model)
            }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.Aurora.body.weight(.medium))
                    .foregroundColor(Color.Aurora.warning)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("API key required")
            .accessibilityHint("Opens settings to configure API key")
        } else if case .error = mode {
            Button(action: { mode = .idle }) {
                Image(systemName: "arrow.clockwise")
                    .font(.Aurora.body.weight(.medium))
                    .foregroundColor(Color.Aurora.error)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry")
            .accessibilityHint("Clears the error and allows you to try again")
        } else {
            let canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isCommandInput = inputText.hasPrefix("/")
            if canSend, !isCommandInput {
                Button(action: handleSubmit) {
                    Image(systemName: "return")
                        .font(.Aurora.bodySmall.weight(.medium))
                        .foregroundColor(Color.Aurora.microAccent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Submit")
                .accessibilityHint("Sends your command to the AI assistant")
            } else {
                EmptyView()
            }
        }
    }
}

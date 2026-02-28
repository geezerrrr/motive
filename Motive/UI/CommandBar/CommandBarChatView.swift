//
//  CommandBarChatView.swift
//  Motive
//
//  Inline chat panel embedded inside the Command Bar popup.
//  Shows conversation content with a pop-out button to open the floating Drawer.
//

import SwiftUI

struct CommandBarChatView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.colorScheme) var colorScheme

    var onPopOut: () -> Void
    var onDismiss: () -> Void

    @State private var inputText = ""
    @State private var showSessionPicker = false
    @State private var sessions: [Session] = []
    @StateObject private var fileCompletion = FileCompletionManager()
    @State private var showFileCompletion = false
    @State private var selectedFileIndex = 0
    @State private var atQueryRange: Range<String.Index>? = nil
    @State private var streamingScrollTask: Task<Void, Never>? = nil
    @FocusState private var isInputFocused: Bool

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            Rectangle()
                .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.12))
                .frame(height: 0.5)

            // Content
            if appState.messages.isEmpty {
                emptyState
            } else {
                DrawerConversationContent(
                    showContent: true,
                    streamingScrollTask: $streamingScrollTask,
                    onEditLastUserMessage: { _ in },
                    enablesUserMessageEditing: false
                )
            }

            Rectangle()
                .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.12))
                .frame(height: 0.5)

            chatInputBar
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 8) {
            // Back to command bar
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Back to Command Bar")

            // Session picker
            Button(action: {
                loadSessions()
                withAnimation(.auroraFast) { showSessionPicker.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 11, weight: .semibold))
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
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                        .fill(Color.Aurora.glassOverlay.opacity(0.06))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Pop-out button
            Button(action: onPopOut) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Pop out to floating window")
        }
        .padding(.horizontal, AuroraSpacing.space4)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            // Session picker overlay
            if showSessionPicker {
                DrawerSessionPicker(
                    sessions: sessions,
                    showSessionPicker: $showSessionPicker,
                    onLoadSessions: loadSessions
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    // MARK: - Input Bar

    private var chatInputBar: some View {
        DrawerChatInput(
            inputText: $inputText,
            isInputFocused: $isInputFocused,
            onSubmit: handleSubmit,
            onTextChange: { _ in }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AuroraSpacing.space4) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Color.Aurora.microAccent)
            Text(L10n.Drawer.startConversation)
                .font(.Aurora.headline)
                .foregroundColor(Color.Aurora.textPrimary)
            Text(L10n.Drawer.startHint)
                .font(.Aurora.bodySmall)
                .foregroundColor(Color.Aurora.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(AuroraSpacing.space6)
    }

    // MARK: - Helpers

    private var currentSessionTitle: String {
        if let session = appState.currentSessionRef {
            return session.intent.isEmpty ? "New Chat" : session.intent
        }
        return "New Chat"
    }

    private func loadSessions() {
        let all = appState.getAllSessions()
        sessions = all.sorted { s1, s2 in
            let r1 = s1.sessionStatus == .running
            let r2 = s2.sessionStatus == .running
            if r1 != r2 { return r1 }
            return s1.createdAt > s2.createdAt
        }
    }

    private func handleSubmit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        if appState.messages.isEmpty {
            appState.submitIntent(text)
        } else {
            appState.sendFollowUp(text)
        }
    }
}

//
//  DrawerView.swift
//  Motive
//
//  Aurora Design System - Drawer (Conversation Panel)
//  Session management via dropdown menu in header
//

import SwiftUI

struct DrawerView: View {
    private enum Layout {
        static let width: CGFloat = 400
        static let height: CGFloat = 600
        static let fileCompletionWidth: CGFloat = 360
        static let inputAreaReservedHeight: CGFloat = 84
    }

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configManager: ConfigManager
    @StateObject private var permissionManager = PermissionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showContent = false
    @State private var inputText = ""
    @State private var showSessionPicker = false
    @State private var sessions: [Session] = []
    @FocusState private var isInputFocused: Bool

    // @ file completion state
    @StateObject private var fileCompletion = FileCompletionManager()
    @State private var showFileCompletion: Bool = false
    @State private var selectedFileIndex: Int = 0
    @State private var atQueryRange: Range<String.Index>? = nil
    @State private var streamingScrollTask: Task<Void, Never>?
    @State private var editingUserMessageId: UUID?

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            // Premium glass background
            drawerBackground

            VStack(spacing: 0) {
                // Header with session dropdown
                DrawerHeader(showSessionPicker: $showSessionPicker, onLoadSessions: loadSessions)
                    .padding(.horizontal, AuroraSpacing.space4)
                    .padding(.top, AuroraSpacing.space4)
                    .padding(.bottom, AuroraSpacing.space3)

                // Subtle glass separator
                Rectangle()
                    .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.12))
                    .frame(height: 0.5)

                // Content
                if appState.messages.isEmpty {
                    emptyState
                } else if !appState.messages.isEmpty {
                    DrawerConversationContent(
                        showContent: showContent,
                        streamingScrollTask: $streamingScrollTask,
                        onEditLastUserMessage: beginEditingLastUserMessage,
                        enablesUserMessageEditing: true
                    )
                } else {
                    Spacer()
                }

                // Input area (always visible)
                DrawerChatInput(
                    inputText: $inputText,
                    isInputFocused: $isInputFocused,
                    onSubmit: handleInputSubmit,
                    onTextChange: checkForAtCompletion
                )
            }

            // Session picker overlay
            if showSessionPicker {
                DrawerSessionPicker(
                    sessions: sessions,
                    showSessionPicker: $showSessionPicker,
                    onLoadSessions: loadSessions
                )
            }

            // File completion overlay
            if showFileCompletion, !fileCompletion.items.isEmpty {
                fileCompletionView
            }

            // Permission request overlay
            if permissionManager.isShowingRequest, let request = permissionManager.currentRequest {
                PermissionRequestView(request: request) { response in
                    permissionManager.respond(with: response)
                }
                .transition(.opacity)
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.xl, style: .continuous)
                .strokeBorder(Color.Aurora.glassOverlay.opacity(isDark ? 0.10 : 0.15), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.auroraSpring.delay(0.1)) {
                showContent = true
            }
            loadSessions()
        }
        .onChange(of: appState.sessionListRefreshTrigger) {
            loadSessions()
        }
        .onKeyPress(.upArrow) {
            if showFileCompletion, !fileCompletion.items.isEmpty {
                if selectedFileIndex > 0 {
                    selectedFileIndex -= 1
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if showFileCompletion, !fileCompletion.items.isEmpty {
                if selectedFileIndex < fileCompletion.items.count - 1 {
                    selectedFileIndex += 1
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.tab) {
            if showFileCompletion, !fileCompletion.items.isEmpty {
                if selectedFileIndex < fileCompletion.items.count {
                    selectFileCompletion(fileCompletion.items[selectedFileIndex])
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showFileCompletion {
                hideFileCompletion()
                return .handled
            }
            return .ignored
        }
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

    // MARK: - Background

    private var drawerBackground: some View {
        LiquidGlassBackgroundAuto(cornerRadius: AuroraRadius.xl, showBorder: true)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AuroraSpacing.space5) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.Aurora.display.weight(.light))
                    .foregroundColor(Color.Aurora.microAccent)
            }

            VStack(spacing: AuroraSpacing.space2) {
                Text(L10n.Drawer.startConversation)
                    .font(.Aurora.headline)
                    .foregroundColor(Color.Aurora.textPrimary)

                Text(L10n.Drawer.startHint)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Hint about session dropdown
            Text(L10n.Drawer.tip)
                .font(.Aurora.caption)
                .foregroundColor(Color.Aurora.textMuted)

            Spacer()
        }
        .padding(AuroraSpacing.space6)
    }

    // MARK: - File Completion Overlay

    private var fileCompletionView: some View {
        ZStack(alignment: .bottom) {
            // Dismiss area
            Color.black.opacity(0.01)
                .accessibilityHidden(true)
                .onTapGesture {
                    hideFileCompletion()
                }

            // File completion popup
            VStack(spacing: 0) {
                FileCompletionView(
                    items: fileCompletion.items,
                    selectedIndex: selectedFileIndex,
                    currentPath: fileCompletion.currentPath,
                    onSelect: selectFileCompletion,
                    maxHeight: 240
                )
                .id("fileCompletion-\(fileCompletion.currentPath)-\(fileCompletion.items.count)")
            }
            .frame(width: Layout.fileCompletionWidth)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .fill(Color.Aurora.surface)
                    .shadow(color: Color.black.opacity(0.15), radius: 16, y: -6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .strokeBorder(Color.Aurora.border.opacity(0.4), lineWidth: 0.5)
            )
            .padding(.bottom, Layout.inputAreaReservedHeight) // Position above input area
        }
        .transition(.opacity)
    }

    // MARK: - Input Handling

    private func handleInputSubmit() {
        // File completion: select item on Enter
        if showFileCompletion, !fileCompletion.items.isEmpty {
            if selectedFileIndex < fileCompletion.items.count {
                selectFileCompletion(fileCompletion.items[selectedFileIndex])
            }
            return
        }

        sendMessage()
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        hideFileCompletion()

        if appState.messages.isEmpty {
            editingUserMessageId = nil
            appState.submitIntent(text)
        } else {
            if let editingUserMessageId {
                appState.resumeSessionReplacingLastUserMessage(
                    id: editingUserMessageId,
                    with: text
                )
                self.editingUserMessageId = nil
            } else {
                appState.resumeSession(with: text)
            }
        }
    }

    private func beginEditingLastUserMessage(_ message: ConversationMessage) {
        guard appState.sessionStatus != .running else { return }
        editingUserMessageId = message.id
        inputText = message.content
        hideFileCompletion()
        isInputFocused = true
    }

    // MARK: - @ File Completion

    private func checkForAtCompletion(_ text: String) {
        guard let token = DrawerFileCompletion.currentAtToken(in: text) else {
            hideFileCompletion()
            return
        }

        let query = token.query
        let newRange = token.range

        // Skip if range and query haven't changed (avoid re-loading after manual selection)
        if showFileCompletion, let oldRange = atQueryRange, oldRange == newRange {
            return
        }

        atQueryRange = newRange

        let baseDir = fileCompletion.getBaseDirectory(for: configManager)
        fileCompletion.loadItems(query: query, baseDir: baseDir)

        showFileCompletion = true
        selectedFileIndex = 0
    }

    private func hideFileCompletion() {
        showFileCompletion = false
        atQueryRange = nil
        fileCompletion.clear()
    }

    private func selectFileCompletion(_ item: FileCompletionItem) {
        guard let range = atQueryRange else { return }

        let replacement = if item.isDirectory {
            "@\(item.path)/"
        } else {
            "@\(item.path) "
        }

        // Calculate the new @ range after replacement
        let startIndex = range.lowerBound
        inputText.replaceSubrange(range, with: replacement)

        // Reset selection index
        selectedFileIndex = 0

        // If it's a directory, reload completions for the new path
        if item.isDirectory {
            // Update atQueryRange to point to the new @ token
            if let newEndIndex = inputText.index(startIndex, offsetBy: replacement.count, limitedBy: inputText.endIndex) {
                atQueryRange = startIndex ..< newEndIndex

                // Directly load items for the new directory
                let baseDir = fileCompletion.getBaseDirectory(for: configManager)
                fileCompletion.loadItems(query: replacement, baseDir: baseDir)

                // Keep completion visible
                showFileCompletion = true
            } else {
                hideFileCompletion()
            }
        } else {
            // File selected - hide completion (space already added)
            hideFileCompletion()
        }
    }
}

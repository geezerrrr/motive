//
//  DrawerView.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

struct DrawerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var configManager: ConfigManager
    @StateObject private var permissionManager = PermissionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showContent = false
    @State private var inputText = ""
    @State private var showSessionPicker = false
    @FocusState private var isInputFocused: Bool
    
    private var isDark: Bool { colorScheme == .dark }
    
    // Adaptive colors
    private var buttonBackground: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }
    private var buttonBorder: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    var body: some View {
        ZStack {
            // Adaptive glass background
            DarkGlassBackground(cornerRadius: 16)
            
            VStack(spacing: 0) {
                // Header with session picker
                conversationHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                
                // Divider
                Rectangle()
                    .fill(Color.Velvet.border)
                    .frame(height: 1)
                
                // Error banner (if any)
                if let error = appState.lastErrorMessage {
                    errorBanner(error)
                }
                
                // Content
                if appState.messages.isEmpty && appState.lastErrorMessage == nil {
                    emptyState
                } else if !appState.messages.isEmpty {
                    conversationContent
                } else {
                    Spacer()
                }
                
                // Input area (always visible)
                chatInputArea
            }
            
            // Session picker overlay
            if showSessionPicker {
                sessionPickerOverlay
            }
            
            // Permission request overlay
            if permissionManager.isShowingRequest, let request = permissionManager.currentRequest {
                PermissionRequestView(request: request) { response in
                    permissionManager.respond(with: response)
                }
                .transition(.opacity)
            }
        }
        .frame(width: 380, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.15), radius: 40, y: 15)
        .onAppear {
            withAnimation(.velvetSpring.delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Header
    
    private var conversationHeader: some View {
        HStack(spacing: 10) {
            // Session selector button
            Button(action: { showSessionPicker.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.Velvet.textSecondary)
                    
                    Text(currentSessionTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.Velvet.textPrimary)
                        .lineLimit(1)
                    
                    Image(systemName: showSessionPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.Velvet.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(buttonBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Status badge
            SessionStatusBadge(status: appState.sessionStatus, currentTool: appState.currentToolName)
            
            // New chat button
            Button(action: { appState.startNewEmptySession() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.Velvet.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(buttonBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            
            // Close button
            Button(action: { appState.hideDrawer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.Velvet.textMuted)
                    .frame(width: 26, height: 26)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(buttonBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.Drawer.close)
        }
    }
    
    private var currentSessionTitle: String {
        if appState.messages.isEmpty {
            return L10n.Drawer.newChat
        }
        // Use first user message as title
        if let firstUser = appState.messages.first(where: { $0.type == .user }) {
            let text = firstUser.content
            return String(text.prefix(24)) + (text.count > 24 ? "…" : "")
        }
        return L10n.Drawer.conversation
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.Velvet.textPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Velvet.textPrimary)
                
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Color.Velvet.textSecondary)
                    .lineLimit(3)
            }
            
            Spacer()
            
            Button {
                appState.lastErrorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.Velvet.textMuted)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Color.Velvet.textSecondary)
            }
            
            VStack(spacing: 6) {
                Text(L10n.Drawer.startConversation)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.Velvet.textPrimary)
                
                Text(L10n.Drawer.startHint)
                    .font(.system(size: 12))
                    .foregroundColor(Color.Velvet.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Conversation Content
    
    private var conversationContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(appState.messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 8)
                            .animation(
                                .velvetSpring.delay(Double(index) * 0.015),
                                value: showContent
                            )
                    }
                    
                    // Thinking indicator
                    if appState.sessionStatus == .running {
                        ThinkingIndicator(toolName: appState.currentToolName)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .onChange(of: appState.messages.count) { _, _ in
                if let last = appState.messages.last {
                    withAnimation(.velvetSpring) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Chat Input Area
    
    // Adaptive colors for input area
    private var inputFieldBackground: Color {
        isDark ? Color.white.opacity(0.04) : Color.white
    }
    private var inputFieldBorder: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }
    private var inputAreaBackground: Color {
        isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.03)
    }
    private var sendButtonDisabledBg: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    
    private var chatInputArea: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color.Velvet.border)
                .frame(height: 1)
            
            HStack(spacing: 10) {
                if appState.sessionStatus == .running {
                    // Running state with shimmer effect
                    HStack(spacing: 8) {
                        ShimmerText(text: L10n.Drawer.processing, isDark: isDark)
                    }
                    
                    Spacer()
                    
                    Button(action: { appState.interruptSession() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // Input field with styled background
                    HStack(spacing: 8) {
                        TextField(L10n.Drawer.messagePlaceholder, text: $inputText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(Color.Velvet.textPrimary)
                            .focused($isInputFocused)
                            .onSubmit(sendMessage)
                        
                        // Send button
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(inputText.isEmpty ? Color.Velvet.textMuted : (isDark ? .black : .white))
                                .frame(width: 24, height: 24)
                                .background(
                                    inputText.isEmpty
                                        ? sendButtonDisabledBg
                                        : (isDark ? Color.white : Color.black)
                                )
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(inputFieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(inputFieldBorder, lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(inputAreaBackground)
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        
        if appState.messages.isEmpty {
            // Start new session
            appState.submitIntent(text)
        } else {
            // Continue existing session
            appState.resumeSession(with: text)
        }
    }
    
    // MARK: - Session Picker Overlay
    
    private var sessionPickerOverlay: some View {
        ZStack {
            // Dismiss background
            Color.black.opacity(isDark ? 0.4 : 0.2)
                .ignoresSafeArea()
                .onTapGesture { showSessionPicker = false }
            
            // Session list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(L10n.Drawer.history)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.Velvet.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { showSessionPicker = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.Velvet.textMuted)
                            .frame(width: 20, height: 20)
                            .background(buttonBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                
                Rectangle()
                    .fill(Color.Velvet.border)
                    .frame(height: 1)
                
                // Session list
                let sessions = appState.getAllSessions()
                if sessions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(Color.Velvet.textMuted)
                        Text(L10n.Drawer.noHistory)
                            .font(.system(size: 12))
                            .foregroundColor(Color.Velvet.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(sessions.prefix(15), id: \.id) { session in
                                SessionListItem(session: session, isDark: isDark) {
                                    appState.switchToSession(session)
                                    showSessionPicker = false
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 280)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDark ? Color(hex: "1A1A1C") : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(isDark ? 0.4 : 0.15), radius: 30, y: 10)
            .frame(width: 320)
            .padding(.top, 50)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
}

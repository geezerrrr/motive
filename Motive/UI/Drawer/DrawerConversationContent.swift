//
//  DrawerConversationContent.swift
//  Motive
//
//  Aurora Design System - Drawer conversation content area
//

import SwiftUI

struct DrawerConversationContent: View {
    @EnvironmentObject private var appState: AppState
    let showContent: Bool
    @Binding var streamingScrollTask: Task<Void, Never>?
    let onEditLastUserMessage: (ConversationMessage) -> Void
    let enablesUserMessageEditing: Bool

    private struct DisplayEntry: Identifiable {
        let id: UUID
        let message: ConversationMessage
    }

    private var displayEntries: [DisplayEntry] {
        let allMessages = appState.messages
        return allMessages.enumerated().compactMap { index, message in
            if shouldDemoteAssistantToProcessThought(index: index, in: allMessages) {
                return nil
            }
            return DisplayEntry(id: message.id, message: message)
        }
    }

    private var editableLastUserMessageId: UUID? {
        guard enablesUserMessageEditing else { return nil }
        return appState.sessionStatus == .running
            ? nil
            : appState.messages.last(where: { $0.type == .user })?.id
    }

    /// True when this assistant bubble is the final assistant output of its turn.
    /// A turn boundary is the next user message (or end of session).
    private func isTurnFinalAssistant(at index: Int) -> Bool {
        guard displayEntries[index].message.type == .assistant else { return false }
        guard index + 1 < displayEntries.count else { return true }
        for next in displayEntries[(index + 1)...] {
            if next.message.type == .assistant {
                return false
            }
            if next.message.type == .user {
                return true
            }
        }
        return true
    }

    private func shouldDemoteAssistantToProcessThought(index: Int, in messages: [ConversationMessage]) -> Bool {
        guard messages[index].type == .assistant else { return false }
        var cursor = index + 1
        var hasToolBetween = false
        while cursor < messages.count {
            let next = messages[cursor]
            if next.type == .tool {
                hasToolBetween = true
                cursor += 1
                continue
            }
            if next.type == .assistant {
                return hasToolBetween
            }
            return false
        }
        return false
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AuroraSpacing.space3) {
                    ForEach(Array(displayEntries.enumerated()), id: \.element.id) { index, entry in
                        MessageBubble(
                            message: entry.message,
                            isFinalAssistantResult: isTurnFinalAssistant(at: index),
                            isEditableLastUserMessage: entry.id == editableLastUserMessageId,
                            onEditLastUserMessage: onEditLastUserMessage
                        )
                        .id(entry.id)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 8)
                        .animation(
                            .auroraSpring.delay(Double(index) * 0.02),
                            value: showContent
                        )
                    }

                    // Transient reasoning bubble — shows live thinking process,
                    // disappears when thinking ends (tool call / assistant text / finish).
                    if let reasoningText = appState.currentReasoningText {
                        TransientReasoningBubble(text: reasoningText)
                            .id("transient-reasoning")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    // Thinking indicator — only show when genuinely waiting for OpenCode
                    // with no active output (not during assistant text streaming).
                    else if appState.sessionStatus == .running,
                            appState.currentToolName == nil,
                            appState.menuBarState != .responding
                    {
                        ThinkingIndicator()
                            .id("thinking-indicator")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Invisible anchor at bottom for reliable scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                }
                .padding(.horizontal, AuroraSpacing.space4)
                .padding(.vertical, AuroraSpacing.space4)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: appState.messages.count) { _, _ in
                // During active runs, avoid repeated animated jumps that can look like drifting.
                if appState.sessionStatus == .running {
                    scheduleStreamingScroll(proxy: proxy)
                } else {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: appState.messages.last?.content) { _, _ in
                // Scroll when message content updates (streaming)
                // Throttled to avoid animation conflicts from rapid delta updates
                scheduleStreamingScroll(proxy: proxy)
            }
            .onChange(of: appState.currentReasoningText) { _, _ in
                // Scroll when reasoning text streams in
                scheduleStreamingScroll(proxy: proxy)
            }
            .onChange(of: appState.sessionStatus) { _, newStatus in
                // Scroll when status changes (e.g., starts running)
                if newStatus == .running {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }

    /// Throttle streaming scroll to avoid rapid-fire animation conflicts
    private func scheduleStreamingScroll(proxy: ScrollViewProxy) {
        // Cancel any pending scroll to avoid stacking animations
        streamingScrollTask?.cancel()
        streamingScrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            // Keep streaming follow stable: no animation to prevent visual "floating".
            scrollToBottom(proxy: proxy, animated: false)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            // Use a non-bouncing animation to prevent the "scroll back up" effect
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
        }
    }
}

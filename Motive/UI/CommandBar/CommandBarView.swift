//
//  CommandBarView.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import SwiftUI

struct CommandBarRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @State private var didAttachContext = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                guard !didAttachContext else { return }
                didAttachContext = true
                appState.attachModelContext(modelContext)
            }
    }
}

struct CommandBarView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme

    @State private var inputText: String = ""
    @State private var isHovering: Bool = false
    @FocusState private var isFocused: Bool
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main input area
            inputArea
            
            // Footer with subtle background difference
            footerArea
        }
        .frame(width: 640)
        .background(commandBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Metallic border effect
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: isDark ? Color.white.opacity(0.35) : Color.white.opacity(0.9), location: 0),
                            .init(color: isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.3), location: 0.5),
                            .init(color: isDark ? Color.white.opacity(0.15) : Color.white.opacity(0.5), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Outer shadow for depth
        .shadow(color: .black.opacity(isDark ? 0.5 : 0.12), radius: 40, y: 20)
        .shadow(color: .black.opacity(isDark ? 0.3 : 0.08), radius: 16, y: 8)
        .onExitCommand {
            appState.hideCommandBar()
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        HStack(spacing: 14) {
            // Logo icon
            ZStack {
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.Velvet.primary, Color.Velvet.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 28)
            
            // Input field
            TextField("", text: $inputText, prompt: Text("What should I do?")
                .foregroundColor(isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.35)))
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Color.Velvet.textPrimary)
                .focused($isFocused)
                .onSubmit(submit)
            
            // Action button
            actionButton
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        if !configManager.hasAPIKey {
            ActionPill(
                icon: "gear",
                label: "Setup",
                style: .warning,
                isDark: isDark
            ) {
                openSettings()
            }
        } else if let error = appState.lastErrorMessage {
            ActionPill(
                icon: "exclamationmark.triangle.fill",
                label: "Error",
                style: .error,
                isDark: isDark
            ) {
                openSettings()
            }
            .help(error)
        } else if !inputText.isEmpty {
            ActionPill(
                icon: "arrow.right",
                label: "Run",
                style: .primary,
                isDark: isDark
            ) {
                submit()
            }
        } else {
            Color.clear
                .frame(width: 70, height: 32)
        }
    }
    
    // MARK: - Footer Area
    
    private var footerArea: some View {
        HStack(spacing: 0) {
            // Status indicator
            if appState.menuBarState != .idle {
                HStack(spacing: 8) {
                    PulsingDot(color: appState.menuBarState == .reasoning ? .purple : .green)
                    
                    Text(appState.menuBarState.displayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                .padding(.leading, 4)
            }
            
            Spacer()
            
            // Keyboard shortcuts
            HStack(spacing: 16) {
                ShortcutBadge(keys: ["↵"], label: "Run", isDark: isDark)
                ShortcutBadge(keys: ["esc"], label: "Close", isDark: isDark)
                ShortcutBadge(keys: ["⌘", ","], label: "Settings", isDark: isDark)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 20)
        .background(
            // Subtle darker background for footer
            isDark
                ? Color.black.opacity(0.25)
                : Color.black.opacity(0.03)
        )
    }
    
    // MARK: - Background
    
    private var commandBarBackground: some View {
        ZStack {
            // Blur effect
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            
            // Clean base color
            if isDark {
                Color(hex: "1A1A1C").opacity(0.95)
            } else {
                Color.white.opacity(0.95)
            }
        }
    }
    
    private func submit() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        inputText = ""
        appState.submitIntent(text)
    }
}

// MARK: - Action Pill

private struct ActionPill: View {
    let icon: String
    let label: String
    let style: Style
    var isDark: Bool = true
    let action: () -> Void
    
    enum Style {
        case primary, warning, error
        
        var backgroundColor: Color {
            switch self {
            case .primary: return Color.Velvet.primary
            case .warning: return Color.orange
            case .error: return Color.red
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                ZStack {
                    style.backgroundColor
                    
                    // Subtle top highlight
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(Capsule())
            .shadow(color: style.backgroundColor.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shortcut Badge

private struct ShortcutBadge: View {
    let keys: [String]
    let label: String
    var isDark: Bool = true
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.45))
                    .frame(minWidth: 16)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1),
                                lineWidth: 0.5
                            )
                    )
            }
            
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.35))
        }
    }
}

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.5 : 1)
                .opacity(isPulsing ? 0 : 0.5)
            
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Menu Bar State Display Text

extension AppState.MenuBarState {
    var displayText: String {
        switch self {
        case .idle: return "Ready"
        case .reasoning: return "Thinking…"
        case .executing: return "Running…"
        }
    }
}

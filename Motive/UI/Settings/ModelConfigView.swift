//
//  ModelConfigView.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

struct ModelConfigView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSavedFeedback = false
    @FocusState private var focusedField: Field?
    
    private var isDark: Bool { colorScheme == .dark }
    
    enum Field: Hashable {
        case baseURL, apiKey, modelName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Provider Selection
            SettingsCard(title: "Provider", icon: "cpu") {
                providerPicker
                    .padding(16)
            }
            
            // Configuration
            SettingsCard(title: "Configuration", icon: "slider.horizontal.3") {
                VStack(spacing: 0) {
                    // API Key (not for Ollama)
                    if configManager.provider != .ollama {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("API Key")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.Velvet.textPrimary)
                                
                                Spacer()
                                
                                if configManager.hasAPIKey {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color.Velvet.success)
                                        Text("Configured")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(Color.Velvet.success)
                                    }
                                }
                            }
                            
                            SecureField(apiKeyPlaceholder, text: Binding(
                                get: { configManager.apiKey },
                                set: { configManager.apiKey = $0 }
                            ))
                            .textFieldStyle(ModernTextFieldStyle())
                            .focused($focusedField, equals: .apiKey)
                        }
                        .padding(16)
                        
                        Divider()
                            .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                            .padding(.leading, 16)
                    }
                    
                    // Base URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text(configManager.provider == .ollama ? "Ollama Host" : "Base URL")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Velvet.textPrimary)
                        
                        TextField(baseURLPlaceholder, text: $configManager.baseURL)
                            .textFieldStyle(ModernTextFieldStyle())
                            .focused($focusedField, equals: .baseURL)
                        
                        Text("Leave empty to use default endpoint")
                            .font(.system(size: 11))
                            .foregroundColor(Color.Velvet.textMuted)
                    }
                    .padding(16)
                    
                    Divider()
                        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.leading, 16)
                    
                    // Model Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Velvet.textPrimary)
                        
                        TextField(modelPlaceholder, text: $configManager.modelName)
                            .textFieldStyle(ModernTextFieldStyle())
                            .focused($focusedField, equals: .modelName)
                    }
                    .padding(16)
                }
            }
            
            // Warning Banner
            if let error = configManager.providerConfigurationError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.Velvet.warning)
                    
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(Color.Velvet.warning)
                    
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.Velvet.warning.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.Velvet.warning.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Action Bar
            HStack {
                Spacer()
                
                if showSavedFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.Velvet.success)
                        Text("Agent restarted")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.Velvet.textSecondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Button(action: saveAndRestart) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Save & Restart")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.Velvet.primary)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSavedFeedback)
    }
    
    // MARK: - Provider Picker
    
    private var providerPicker: some View {
        HStack(spacing: 12) {
            ForEach(ConfigManager.Provider.allCases) { provider in
                ProviderCard(
                    provider: provider,
                    isSelected: configManager.provider == provider,
                    isDark: isDark
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        configManager.provider = provider
                    }
                }
            }
        }
    }
    
    private var modelPlaceholder: String {
        switch configManager.provider {
        case .claude: return "claude-sonnet-4-5-20250929"
        case .openai: return "gpt-5.1-codex"
        case .gemini: return "gemini-3-pro-preview"
        case .ollama: return "llama3"
        }
    }
    
    private var apiKeyPlaceholder: String {
        switch configManager.provider {
        case .claude: return "sk-ant-..."
        case .openai: return "sk-..."
        case .gemini: return "AIza..."
        case .ollama: return ""
        }
    }
    
    private var baseURLPlaceholder: String {
        switch configManager.provider {
        case .claude: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com"
        case .gemini: return "https://generativelanguage.googleapis.com"
        case .ollama: return "http://localhost:11434"
        }
    }
    
    private func saveAndRestart() {
        appState.restartAgent()
        showSavedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedFeedback = false
            }
        }
    }
}

// MARK: - Provider Card

struct ProviderCard: View {
    let provider: ConfigManager.Provider
    let isSelected: Bool
    var isDark: Bool = true
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(provider.iconAsset)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? Color.Velvet.primary : Color.Velvet.textSecondary)
                
                Text(provider.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? Color.Velvet.textPrimary : Color.Velvet.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? (isDark ? Color.white.opacity(0.1) : Color.Velvet.primary.opacity(0.1))
                            : (isHovering ? (isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.Velvet.primary.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Modern Text Field Style

struct ModernTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Provider Extension

extension ConfigManager.Provider {
    /// Asset Catalog icon name
    var iconAsset: String {
        switch self {
        case .claude: return "anthropic"
        case .openai: return "open-ai"
        case .gemini: return "gemini-ai"
        case .ollama: return "ollama"
        }
    }
}

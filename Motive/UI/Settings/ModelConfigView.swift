//
//  ModelConfigView.swift
//  Motive
//
//  Aurora Design System - Model Configuration
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
        VStack(alignment: .leading, spacing: AuroraSpacing.space6) {
            // Provider Selection
            VStack(alignment: .leading, spacing: AuroraSpacing.space4) {
                // Header with warning badge
                HStack(spacing: AuroraSpacing.space2) {
                    Image(systemName: "cpu")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Aurora.auroraGradient)
                    
                    Text(L10n.Settings.provider)
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    // Warning badge
                    if let error = configManager.providerConfigurationError {
                        HStack(spacing: AuroraSpacing.space2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.Aurora.warning)
                            
                            Text(error)
                                .font(.Aurora.micro.weight(.medium))
                                .foregroundColor(Color.Aurora.warning)
                        }
                        .padding(.horizontal, AuroraSpacing.space3)
                        .padding(.vertical, AuroraSpacing.space2)
                        .background(
                            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                                .fill(Color.Aurora.warning.opacity(0.12))
                        )
                    }
                }
                
                // Provider cards
                VStack(spacing: 0) {
                    providerPicker
                        .padding(AuroraSpacing.space4)
                }
                .background(
                    RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                        .fill(Color.Aurora.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                        .stroke(Color.Aurora.border, lineWidth: 1)
                )
            }
            
            // Configuration
            SettingsCard(title: L10n.Settings.configuration, icon: "slider.horizontal.3") {
                VStack(spacing: 0) {
                    // API Key (not for Ollama)
                    if configManager.provider != .ollama {
                        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                            HStack {
                                Text(L10n.Settings.apiKey)
                                    .font(.Aurora.body.weight(.medium))
                                    .foregroundColor(Color.Aurora.textPrimary)
                                
                                Spacer()
                                
                                if configManager.hasAPIKey {
                                    HStack(spacing: AuroraSpacing.space1) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.Aurora.success)
                                        Text(L10n.Settings.apiKeyConfigured)
                                            .font(.Aurora.micro.weight(.medium))
                                            .foregroundColor(Color.Aurora.success)
                                    }
                                }
                            }
                            
                            SettingsSecureField(
                                placeholder: apiKeyPlaceholder,
                                text: Binding(
                                    get: { configManager.apiKey },
                                    set: { configManager.apiKey = $0 }
                                ),
                                isFocused: focusedField == .apiKey
                            )
                            .focused($focusedField, equals: .apiKey)
                        }
                        .padding(AuroraSpacing.space4)
                        
                        Rectangle()
                            .fill(Color.Aurora.border)
                            .frame(height: 1)
                            .padding(.leading, AuroraSpacing.space4)
                    }
                    
                    // Base URL
                    VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                        Text(configManager.provider == .ollama ? L10n.Settings.ollamaHost : L10n.Settings.baseURL)
                            .font(.Aurora.body.weight(.medium))
                            .foregroundColor(Color.Aurora.textPrimary)
                        
                        SettingsTextField(
                            placeholder: baseURLPlaceholder,
                            text: $configManager.baseURL,
                            isFocused: focusedField == .baseURL
                        )
                        .focused($focusedField, equals: .baseURL)
                        
                        Text(L10n.Settings.defaultEndpoint)
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                    .padding(AuroraSpacing.space4)
                    
                    Rectangle()
                        .fill(Color.Aurora.border)
                        .frame(height: 1)
                        .padding(.leading, AuroraSpacing.space4)
                    
                    // Model Name
                    VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                        Text(L10n.Settings.model)
                            .font(.Aurora.body.weight(.medium))
                            .foregroundColor(Color.Aurora.textPrimary)
                        
                        SettingsTextField(
                            placeholder: modelPlaceholder,
                            text: $configManager.modelName,
                            isFocused: focusedField == .modelName
                        )
                        .focused($focusedField, equals: .modelName)
                    }
                    .padding(AuroraSpacing.space4)
                }
            }
            
            // Action Bar
            HStack {
                Spacer()
                
                if showSavedFeedback {
                    HStack(spacing: AuroraSpacing.space2) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.Aurora.success)
                        Text(L10n.Settings.agentRestarted)
                            .font(.Aurora.bodySmall.weight(.medium))
                            .foregroundColor(Color.Aurora.textSecondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Button(action: saveAndRestart) {
                    HStack(spacing: AuroraSpacing.space2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.Settings.saveRestart)
                            .font(.Aurora.bodySmall.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AuroraSpacing.space4)
                    .padding(.vertical, AuroraSpacing.space3)
                    .background(
                        LinearGradient(
                            colors: Color.Aurora.auroraGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
                    .shadow(color: Color.Aurora.accentMid.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.auroraSpring, value: showSavedFeedback)
    }
    
    // MARK: - Provider Picker
    
    private var providerPicker: some View {
        HStack(spacing: AuroraSpacing.space3) {
            ForEach(ConfigManager.Provider.allCases) { provider in
                AuroraProviderCard(
                    provider: provider,
                    isSelected: configManager.provider == provider
                ) {
                    withAnimation(.auroraSpring) {
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

// MARK: - Aurora Provider Card

struct AuroraProviderCard: View {
    let provider: ConfigManager.Provider
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AuroraSpacing.space3) {
                // Provider icon
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: Color.Aurora.auroraGradientColors.map { $0.opacity(0.15) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                    }
                    
                    Image(provider.iconAsset)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(isSelected ? Color.Aurora.accent : Color.Aurora.textSecondary)
                }
                
                Text(provider.displayName)
                    .font(.Aurora.bodySmall.weight(.medium))
                    .foregroundColor(isSelected ? Color.Aurora.textPrimary : Color.Aurora.textSecondary)
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.Aurora.auroraGradient)
                } else {
                    Circle()
                        .stroke(Color.Aurora.border, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AuroraSpacing.space4)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.Aurora.accent.opacity(isDark ? 0.1 : 0.08)
                            : (isHovering ? Color.Aurora.surfaceElevated : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: Color.Aurora.auroraGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering && !isSelected ? 1.02 : 1.0)
        .animation(.auroraFast, value: isHovering)
    }
}

// Legacy ProviderCard for compatibility
struct ProviderCard: View {
    let provider: ConfigManager.Provider
    let isSelected: Bool
    var isDark: Bool = true
    let action: () -> Void
    
    var body: some View {
        AuroraProviderCard(provider: provider, isSelected: isSelected, action: action)
    }
}

// MARK: - Settings Text Field (View-based, not TextFieldStyle)

struct SettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var backgroundColor: Color {
        isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) 
               : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0)
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.Aurora.body)
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, AuroraSpacing.space3)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(
                        isFocused ? Color.Aurora.borderFocus : Color.Aurora.border,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.auroraFast, value: isFocused)
    }
}

// MARK: - Settings Secure Field (View-based)

struct SettingsSecureField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var backgroundColor: Color {
        isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) 
               : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0)
    }
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.Aurora.body)
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, AuroraSpacing.space3)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(
                        isFocused ? Color.Aurora.borderFocus : Color.Aurora.border,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.auroraFast, value: isFocused)
    }
}

// Legacy compatibility
struct AuroraModernTextFieldStyle: TextFieldStyle {
    var isFocused: Bool = false
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
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

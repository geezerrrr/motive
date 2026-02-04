//
//  ModelConfigView.swift
//  Motive
//
//  Compact Model Configuration
//

import SwiftUI

struct ModelConfigView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSavedFeedback = false
    @State private var showAPIKey = false
    @FocusState private var focusedField: Field?
    
    private var isDark: Bool { colorScheme == .dark }
    
    enum Field: Hashable {
        case baseURL, apiKey, modelName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Provider Selection
            VStack(alignment: .leading, spacing: 10) {
                // Header with warning badge - fixed height to prevent layout shift
                HStack(spacing: 8) {
                    Text(L10n.Settings.provider)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Aurora.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    // Warning badge - always reserve space
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.Aurora.warning)
                        
                        Text(configManager.providerConfigurationError ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.Aurora.warning)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.Aurora.warning.opacity(0.12))
                    )
                    .opacity(configManager.providerConfigurationError != nil ? 1 : 0)
                }
                .frame(height: 28)
                .padding(.leading, 4)
                
                // Compact provider picker
                providerPicker
            }
            
            // Configuration
            SettingSection(L10n.Settings.configuration) {
                // API Key (only for providers that require it)
                if configManager.provider.requiresAPIKey {
                    SettingRow(L10n.Settings.apiKey) {
                        // API Key field with visibility toggle
                        ZStack(alignment: .trailing) {
                            HStack(spacing: 8) {
                                // Checkmark on the left when key is configured
                                if configManager.hasAPIKey {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.Aurora.success)
                                }
                                
                                Group {
                                    if showAPIKey {
                                        TextField(apiKeyPlaceholder, text: Binding(
                                            get: { configManager.apiKey },
                                            set: { configManager.apiKey = $0 }
                                        ))
                                    } else {
                                        SecureField(apiKeyPlaceholder, text: Binding(
                                            get: { configManager.apiKey },
                                            set: { configManager.apiKey = $0 }
                                        ))
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                            }
                            .padding(.leading, 12)
                            .padding(.trailing, 32)
                            .padding(.vertical, 8)
                            
                            // Eye toggle button
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.Aurora.textMuted)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 10)
                        }
                        .frame(width: 220)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(configManager.hasAPIKey ? Color.Aurora.success.opacity(0.5) : Color.Aurora.border, lineWidth: 1)
                        )
                    }
                }
                
                // Base URL
                SettingRow(configManager.provider == .ollama ? L10n.Settings.ollamaHost : L10n.Settings.baseURL) {
                    TextField(baseURLPlaceholder, text: $configManager.baseURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 220)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.Aurora.border, lineWidth: 1)
                        )
                }
                
                // Model Name
                SettingRow(L10n.Settings.model, showDivider: false) {
                    TextField(modelPlaceholder, text: $configManager.modelName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 220)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.Aurora.border, lineWidth: 1)
                        )
                }
            }
            
            // Action Bar (no Spacer - keep content compact)
            HStack {
                Spacer()
                
                if showSavedFeedback {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.Aurora.success)
                        Text(L10n.Settings.agentRestarted)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.Aurora.textSecondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Button(action: saveAndRestart) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.Settings.saveRestart)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.Aurora.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.auroraFast, value: showSavedFeedback)
    }
    
    // MARK: - Provider Picker
    
    private var providerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ConfigManager.Provider.allCases) { provider in
                    CompactProviderCard(
                        provider: provider,
                        isSelected: configManager.provider == provider
                    ) {
                        withAnimation(.auroraFast) {
                            configManager.provider = provider
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.Aurora.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 1)
        )
    }
    
    private var modelPlaceholder: String {
        configManager.provider.defaultModel
    }
    
    private var apiKeyPlaceholder: String {
        configManager.provider.apiKeyPlaceholder
    }
    
    private var baseURLPlaceholder: String {
        configManager.provider.baseURLPlaceholder
    }
    
    private func saveAndRestart() {
        appState.restartAgent()
        showSavedFeedback = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showSavedFeedback = false
            }
        }
    }
}

// MARK: - Compact Provider Card

private struct CompactProviderCard: View {
    let provider: ConfigManager.Provider
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Provider icon (custom asset or SF Symbol)
                providerIcon
                    .frame(width: 22, height: 22)
                    .foregroundColor(isSelected ? Color.Aurora.primary : Color.Aurora.textSecondary)
                
                Text(provider.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.Aurora.textPrimary : Color.Aurora.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.Aurora.primary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    @ViewBuilder
    private var providerIcon: some View {
        if provider.usesCustomIcon {
            Image(provider.iconAsset)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: provider.sfSymbol)
                .font(.system(size: 18, weight: .medium))
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.Aurora.primary.opacity(isDark ? 0.12 : 0.08)
        } else if isHovering {
            return isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
        }
        return Color.clear
    }
}

// MARK: - Legacy Components (kept for compatibility)

struct AuroraProviderCard: View {
    let provider: ConfigManager.Provider
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        CompactProviderCard(provider: provider, isSelected: isSelected, action: action)
    }
}

struct ProviderCard: View {
    let provider: ConfigManager.Provider
    let isSelected: Bool
    var isDark: Bool = true
    let action: () -> Void
    
    var body: some View {
        CompactProviderCard(provider: provider, isSelected: isSelected, action: action)
    }
}

struct SettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isFocused ? Color.Aurora.primary : Color.Aurora.border, lineWidth: 1)
            )
    }
}

struct SettingsSecureField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isFocused ? Color.Aurora.primary : Color.Aurora.border, lineWidth: 1)
            )
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
    /// Asset Catalog icon name (SF Symbol for providers without custom icon)
    var iconAsset: String {
        switch self {
        // Primary providers with custom icons
        case .claude: return "anthropic"
        case .openai: return "open-ai"
        case .gemini: return "gemini-ai"
        case .ollama: return "ollama"
        // Cloud providers (use SF Symbols)
        case .openrouter, .mistral, .groq, .xai, .cohere, .deepinfra, .togetherai, .perplexity, .cerebras:
            return ""  // Will use SF Symbol
        // Enterprise / Cloud (use SF Symbols)
        case .azure, .bedrock, .googleVertex:
            return ""  // Will use SF Symbol
        // OpenAI-compatible
        case .openaiCompatible:
            return ""  // Will use SF Symbol
        }
    }
    
    /// SF Symbol name for providers without custom icons
    var sfSymbol: String {
        switch self {
        case .claude, .openai, .gemini, .ollama: return ""  // Use custom icon
        case .openrouter: return "arrow.triangle.branch"
        case .mistral: return "wind"
        case .groq: return "bolt.fill"
        case .xai: return "x.circle.fill"
        case .cohere: return "circle.hexagongrid.fill"
        case .deepinfra: return "server.rack"
        case .togetherai: return "person.2.fill"
        case .perplexity: return "sparkle.magnifyingglass"
        case .cerebras: return "brain.head.profile"
        case .azure: return "cloud.fill"
        case .bedrock: return "square.3.layers.3d.down.right"
        case .googleVertex: return "triangle.fill"
        case .openaiCompatible: return "network"
        }
    }
    
    /// Whether this provider uses a custom asset or SF Symbol
    var usesCustomIcon: Bool {
        !iconAsset.isEmpty
    }
    
    /// API key placeholder text
    var apiKeyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .openai, .openaiCompatible: return "sk-..."
        case .gemini: return "AIza..."
        case .ollama: return ""
        case .openrouter: return "sk-or-..."
        case .mistral: return "..."
        case .groq: return "gsk_..."
        case .xai: return "xai-..."
        case .cohere: return "..."
        case .deepinfra: return "..."
        case .togetherai: return "..."
        case .perplexity: return "pplx-..."
        case .cerebras: return "csk-..."
        case .azure: return "..."
        case .bedrock: return "AKIA..."
        case .googleVertex: return "project-id"
        }
    }
    
    /// Base URL placeholder text
    var baseURLPlaceholder: String {
        switch self {
        case .claude: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com"
        case .gemini: return "https://generativelanguage.googleapis.com"
        case .ollama: return "http://localhost:11434"
        case .openrouter: return "https://openrouter.ai/api"
        case .mistral: return "https://api.mistral.ai"
        case .groq: return "https://api.groq.com"
        case .xai: return "https://api.x.ai"
        case .cohere: return "https://api.cohere.ai"
        case .deepinfra: return "https://api.deepinfra.com"
        case .togetherai: return "https://api.together.xyz"
        case .perplexity: return "https://api.perplexity.ai"
        case .cerebras: return "https://api.cerebras.ai"
        case .azure: return "https://<resource>.openai.azure.com"
        case .bedrock: return "https://bedrock-runtime.<region>.amazonaws.com"
        case .googleVertex: return "https://<region>-aiplatform.googleapis.com"
        case .openaiCompatible: return "https://your-api.example.com"
        }
    }
}

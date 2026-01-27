//
//  OnboardingView.swift
//  Motive
//
//  Aurora Design System - Onboarding Flow
//

import SwiftUI

// MARK: - Aurora Input Field Style

private enum AuroraInputFieldStyle {
    static let height: CGFloat = 36
    static let horizontalPadding: CGFloat = AuroraSpacing.space3
    static let cornerRadius: CGFloat = AuroraRadius.sm
}

// MARK: - Aurora Styled Text Field

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    // Use explicit color values to ensure correct background
    private var backgroundColor: Color {
        isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) 
               : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0)
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.Aurora.body)
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, AuroraInputFieldStyle.horizontalPadding)
            .frame(height: AuroraInputFieldStyle.height)
            .background(
                RoundedRectangle(cornerRadius: AuroraInputFieldStyle.cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraInputFieldStyle.cornerRadius, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
    }
}

// MARK: - Aurora Secure Input Field

struct SecureInputField: View {
    let placeholder: String
    @Binding var text: String
    @State private var showingText: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    // Use explicit color values to ensure correct background
    private var backgroundColor: Color {
        isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) 
               : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Group {
                if showingText {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.Aurora.body)
            .foregroundColor(Color.Aurora.textPrimary)
            
            Button(action: { showingText.toggle() }) {
                Image(systemName: showingText ? "eye.slash" : "eye")
                    .foregroundColor(Color.Aurora.textMuted)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, AuroraSpacing.space1)
        }
        .padding(.horizontal, AuroraInputFieldStyle.horizontalPadding)
        .frame(height: AuroraInputFieldStyle.height)
        .background(
            RoundedRectangle(cornerRadius: AuroraInputFieldStyle.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraInputFieldStyle.cornerRadius, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 1)
        )
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentStep: OnboardingStep = .welcome
    
    private var isDark: Bool { colorScheme == .dark }
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case aiProvider
        case accessibility
        case browserAutomation
        case complete
        
        var next: OnboardingStep? {
            OnboardingStep(rawValue: rawValue + 1)
        }
        
        var previous: OnboardingStep? {
            OnboardingStep(rawValue: rawValue - 1)
        }
    }
    
    var body: some View {
        ZStack {
            // Aurora background
            Color.Aurora.backgroundDeep
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            if isDark {
                LinearGradient(
                    colors: [
                        Color.Aurora.accentMid.opacity(0.05),
                        Color.clear,
                        Color.Aurora.accentStart.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Progress indicator
                if currentStep != .welcome && currentStep != .complete {
                    AuroraOnboardingProgress(currentStep: currentStep)
                        .padding(.top, AuroraSpacing.space5)
                        .padding(.bottom, AuroraSpacing.space3)
                }
                
                // Content
                Group {
                    switch currentStep {
                    case .welcome:
                        AuroraWelcomeStep(onContinue: { goToNext() })
                    case .aiProvider:
                        AuroraAIProviderStep(
                            onContinue: { goToNext() },
                            onSkip: { goToNext() }
                        )
                    case .accessibility:
                        AuroraAccessibilityStep(
                            onContinue: { goToNext() },
                            onSkip: { goToNext() }
                        )
                    case .browserAutomation:
                        AuroraBrowserStep(
                            onContinue: { goToNext() },
                            onSkip: { goToNext() }
                        )
                    case .complete:
                        AuroraCompleteStep(onFinish: { completeOnboarding() })
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.auroraSpring, value: currentStep)
            }
            .frame(width: 520, height: 480)
        }
    }
    
    private func goToNext() {
        withAnimation {
            if let next = currentStep.next {
                currentStep = next
            }
        }
    }
    
    private func completeOnboarding() {
        configManager.hasCompletedOnboarding = true
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

// MARK: - Aurora Onboarding Settings Row

struct OnboardingSettingsRow<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space3)
    }
}

// MARK: - Aurora Progress Indicator

struct AuroraOnboardingProgress: View {
    let currentStep: OnboardingView.OnboardingStep
    
    private let steps: [OnboardingView.OnboardingStep] = [.aiProvider, .accessibility, .browserAutomation]
    
    var body: some View {
        HStack(spacing: AuroraSpacing.space2) {
            ForEach(steps, id: \.rawValue) { step in
                Circle()
                    .fill(
                        step.rawValue <= currentStep.rawValue
                            ? AnyShapeStyle(Color.Aurora.auroraGradient)
                            : AnyShapeStyle(Color.Aurora.textMuted.opacity(0.3))
                    )
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// Legacy alias
struct OnboardingProgressView: View {
    let currentStep: OnboardingView.OnboardingStep
    
    var body: some View {
        AuroraOnboardingProgress(currentStep: currentStep)
    }
}

// MARK: - Aurora Welcome Step

struct AuroraWelcomeStep: View {
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: AuroraSpacing.space6) {
            Spacer()
            
            // App icon with glow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: Color.Aurora.auroraGradientColors.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.Aurora.accentMid.opacity(0.3), radius: 20, y: 8)
            }
            
            VStack(spacing: AuroraSpacing.space3) {
                Text(L10n.Onboarding.welcomeTitle)
                    .font(.Aurora.display)
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(L10n.Onboarding.welcomeSubtitle)
                    .font(.Aurora.body)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AuroraSpacing.space10)
            }
            
            Spacer()
            
            Button(action: onContinue) {
                HStack(spacing: AuroraSpacing.space2) {
                    Text(L10n.Onboarding.getStarted)
                        .font(.Aurora.body.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuroraSpacing.space4)
                .background(Color.Aurora.auroraGradient)
                .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
                .shadow(color: Color.Aurora.accentMid.opacity(0.4), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AuroraSpacing.space12)
            .padding(.bottom, AuroraSpacing.space10)
        }
    }
}

// Legacy alias
struct WelcomeStepView: View {
    let onContinue: () -> Void
    var body: some View { AuroraWelcomeStep(onContinue: onContinue) }
}

// MARK: - Aurora AI Provider Step

struct AuroraAIProviderStep: View {
    @EnvironmentObject var configManager: ConfigManager
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: AuroraSpacing.space4) {
            // Header
            VStack(spacing: AuroraSpacing.space2) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.Aurora.auroraGradient)
                
                Text(L10n.Onboarding.aiProviderTitle)
                    .font(.Aurora.title2)
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(L10n.Onboarding.aiProviderSubtitle)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, AuroraSpacing.space4)
            
            // Configuration card
            VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
                Text(L10n.Settings.selectProvider)
                    .font(.Aurora.bodySmall.weight(.medium))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Picker("", selection: $configManager.providerRawValue) {
                    ForEach(ConfigManager.Provider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: configManager.providerRawValue) { _, _ in
                    apiKey = ""
                    baseURL = ""
                }
                
                // API Key input
                if configManager.provider != .ollama {
                    VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                        Text(L10n.Settings.apiKey)
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textSecondary)
                        
                        SecureInputField(placeholder: apiKeyPlaceholder, text: $apiKey)
                    }
                }
                
                // Base URL
                VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                    Text(configManager.provider == .ollama ? L10n.Settings.ollamaHost : L10n.Settings.baseURL)
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textSecondary)
                    
                    StyledTextField(placeholder: baseURLPlaceholder, text: $baseURL)
                    
                    Text(L10n.Settings.defaultEndpoint)
                        .font(.Aurora.micro)
                        .foregroundColor(Color.Aurora.textMuted)
                }
            }
            .padding(AuroraSpacing.space4)
            .background(Color.Aurora.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
            .padding(.horizontal, AuroraSpacing.space10)
            
            Spacer()
            
            // Buttons
            HStack(spacing: AuroraSpacing.space3) {
                Button(action: onSkip) {
                    Text(L10n.Onboarding.skip)
                        .font(.Aurora.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                }
                .buttonStyle(AuroraOnboardingButtonStyle(style: .secondary))
                
                Button(action: {
                    saveSettings()
                    onContinue()
                }) {
                    Text(L10n.Onboarding.continueButton)
                        .font(.Aurora.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                }
                .buttonStyle(AuroraOnboardingButtonStyle(style: .primary))
                .disabled(configManager.provider != .ollama && apiKey.isEmpty)
            }
            .padding(.horizontal, AuroraSpacing.space10)
            .padding(.bottom, AuroraSpacing.space8)
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
    
    private func saveSettings() {
        if !apiKey.isEmpty { configManager.apiKey = apiKey }
        if !baseURL.isEmpty { configManager.baseURL = baseURL }
    }
}

// Legacy alias
struct AIProviderStepView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onContinue: () -> Void
    let onSkip: () -> Void
    var body: some View { AuroraAIProviderStep(onContinue: onContinue, onSkip: onSkip) }
}

// MARK: - Aurora Accessibility Step

struct AuroraAccessibilityStep: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var hasPermission: Bool = false
    @State private var checkTimer: Timer?
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: AuroraSpacing.space5) {
            // Header
            VStack(spacing: AuroraSpacing.space2) {
                Image(systemName: hasPermission ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(hasPermission ? AnyShapeStyle(Color.Aurora.success) : AnyShapeStyle(Color.Aurora.auroraGradient))
                
                Text(L10n.Onboarding.accessibilityTitle)
                    .font(.Aurora.title2)
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(L10n.Onboarding.accessibilitySubtitle)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AuroraSpacing.space5)
            }
            .padding(.top, AuroraSpacing.space5)
            
            // Status Card
            VStack(spacing: AuroraSpacing.space4) {
                HStack(spacing: AuroraSpacing.space3) {
                    // Status icon with background
                    ZStack {
                        Circle()
                            .fill(hasPermission ? Color.Aurora.success.opacity(0.15) : Color.Aurora.warning.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(hasPermission ? Color.Aurora.success : Color.Aurora.warning)
                    }
                    
                    VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                        Text(hasPermission ? L10n.Onboarding.accessibilityGranted : L10n.Onboarding.accessibilityRequired)
                            .font(.Aurora.body.weight(.medium))
                            .foregroundColor(Color.Aurora.textPrimary)
                        
                        Text(hasPermission ? "Hotkey is ready to use" : "Required for global hotkey")
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(AuroraSpacing.space4)
                .background(
                    RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                        .fill(Color.Aurora.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                        .stroke(
                            hasPermission ? Color.Aurora.success.opacity(0.3) : Color.Aurora.warning.opacity(0.3),
                            lineWidth: 1
                        )
                )
                
                if !hasPermission {
                    Button(action: openAccessibilitySettings) {
                        HStack(spacing: AuroraSpacing.space2) {
                            Image(systemName: "gear")
                                .font(.system(size: 14, weight: .medium))
                            Text(L10n.Onboarding.openSystemSettings)
                                .font(.Aurora.body.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                    }
                    .buttonStyle(AuroraOnboardingButtonStyle(style: .secondary))
                }
            }
            .padding(.horizontal, AuroraSpacing.space10)
            
            if !hasPermission {
                Text(L10n.Onboarding.accessibilityInstructions)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textMuted)
                    .padding(.horizontal, AuroraSpacing.space10)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: AuroraSpacing.space3) {
                Button(action: onSkip) {
                    Text(L10n.Onboarding.skip)
                        .font(.Aurora.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                }
                .buttonStyle(AuroraOnboardingButtonStyle(style: .secondary))
                
                Button(action: onContinue) {
                    Text(L10n.Onboarding.continueButton)
                        .font(.Aurora.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                }
                .buttonStyle(AuroraOnboardingButtonStyle(style: .primary))
            }
            .padding(.horizontal, AuroraSpacing.space10)
            .padding(.bottom, AuroraSpacing.space8)
        }
        .onAppear {
            checkPermission()
            startPermissionCheck()
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }
    
    private func checkPermission() {
        hasPermission = AccessibilityHelper.hasPermission
    }
    
    private func startPermissionCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in checkPermission() }
        }
    }
    
    private func openAccessibilitySettings() {
        AccessibilityHelper.openAccessibilitySettings()
    }
}

// Legacy alias
struct AccessibilityStepView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    var body: some View { AuroraAccessibilityStep(onContinue: onContinue, onSkip: onSkip) }
}

// MARK: - Aurora Browser Step

struct AuroraBrowserStep: View {
    @EnvironmentObject var configManager: ConfigManager
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var browserAgentAPIKey: String = ""
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: AuroraSpacing.space4) {
            // Header
            VStack(spacing: AuroraSpacing.space2) {
                Image(systemName: "globe")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.Aurora.auroraGradient)
                
                Text(L10n.Onboarding.browserTitle)
                    .font(.Aurora.title2)
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(L10n.Onboarding.browserSubtitle)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AuroraSpacing.space5)
            }
            .padding(.top, AuroraSpacing.space4)
            
            // Configuration card
            VStack(spacing: 0) {
                // Enable toggle
                OnboardingSettingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                            Text(L10n.Settings.browserEnable)
                                .font(.Aurora.bodySmall.weight(.medium))
                                .foregroundColor(Color.Aurora.textPrimary)
                            Text(L10n.Onboarding.browserEnableDesc)
                                .font(.Aurora.caption)
                                .foregroundColor(Color.Aurora.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $configManager.browserUseEnabled)
                            .toggleStyle(.switch)
                            .tint(Color.Aurora.accent)
                            .labelsHidden()
                    }
                }
                
                if configManager.browserUseEnabled {
                    Rectangle().fill(Color.Aurora.border).frame(height: 1).padding(.leading, AuroraSpacing.space4)
                    
                    OnboardingSettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                                Text(L10n.Settings.browserShowWindow)
                                    .font(.Aurora.bodySmall.weight(.medium))
                                    .foregroundColor(Color.Aurora.textPrimary)
                                Text(L10n.Settings.browserShowWindowDesc)
                                    .font(.Aurora.caption)
                                    .foregroundColor(Color.Aurora.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $configManager.browserUseHeadedMode)
                                .toggleStyle(.switch)
                                .tint(Color.Aurora.accent)
                                .labelsHidden()
                        }
                    }
                    
                    Rectangle().fill(Color.Aurora.border).frame(height: 1).padding(.leading, AuroraSpacing.space4)
                    
                    OnboardingSettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                                Text(L10n.Settings.browserAgentProvider)
                                    .font(.Aurora.bodySmall.weight(.medium))
                                    .foregroundColor(Color.Aurora.textPrimary)
                                Text(L10n.Settings.browserAgentProviderDesc)
                                    .font(.Aurora.caption)
                                    .foregroundColor(Color.Aurora.textSecondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { configManager.browserAgentProvider },
                                set: { newValue in
                                    configManager.browserAgentProvider = newValue
                                    configManager.clearBrowserAgentAPIKeyCache()
                                    browserAgentAPIKey = ""
                                }
                            )) {
                                ForEach(ConfigManager.BrowserAgentProvider.allCases, id: \.self) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                    }
                    
                    Rectangle().fill(Color.Aurora.border).frame(height: 1).padding(.leading, AuroraSpacing.space4)
                    
                    OnboardingSettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                                Text(configManager.browserAgentProvider.envKeyName)
                                    .font(.Aurora.bodySmall.weight(.medium))
                                    .foregroundColor(Color.Aurora.textPrimary)
                                Text(L10n.Settings.browserApiKeyDesc)
                                    .font(.Aurora.caption)
                                    .foregroundColor(Color.Aurora.textSecondary)
                            }
                            Spacer()
                            SecureInputField(placeholder: "sk-...", text: $browserAgentAPIKey)
                                .frame(width: 160)
                        }
                    }
                }
            }
            .background(Color.Aurora.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
            .padding(.horizontal, AuroraSpacing.space10)
            
            HStack(spacing: AuroraSpacing.space2) {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.Aurora.textMuted)
                Text(L10n.Onboarding.browserInfo)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textMuted)
            }
            .padding(.horizontal, AuroraSpacing.space10)
            
            Spacer()
            
            // Buttons
            HStack(spacing: AuroraSpacing.space3) {
                Button(action: onSkip) {
                    Text(L10n.Onboarding.skip)
                        .font(.Aurora.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                }
                .buttonStyle(AuroraOnboardingButtonStyle(style: .secondary))
                
                Button(action: {
                    saveSettings()
                    onContinue()
                }) {
                    Text(L10n.Onboarding.continueButton)
                        .font(.Aurora.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuroraSpacing.space3)
                }
                .buttonStyle(AuroraOnboardingButtonStyle(style: .primary))
            }
            .padding(.horizontal, AuroraSpacing.space10)
            .padding(.bottom, AuroraSpacing.space8)
        }
    }
    
    private func saveSettings() {
        if configManager.browserUseEnabled && !browserAgentAPIKey.isEmpty {
            configManager.browserAgentAPIKey = browserAgentAPIKey
        }
        SkillManager.shared.reloadSkills()
    }
}

// Legacy alias
struct BrowserAutomationStepView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onContinue: () -> Void
    let onSkip: () -> Void
    var body: some View { AuroraBrowserStep(onContinue: onContinue, onSkip: onSkip) }
}

// MARK: - Aurora Complete Step

struct AuroraCompleteStep: View {
    @EnvironmentObject var configManager: ConfigManager
    let onFinish: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: AuroraSpacing.space6) {
            Spacer()
            
            // Success icon with gradient
            ZStack {
                Circle()
                    .fill(Color.Aurora.success.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.Aurora.success)
            }
            
            VStack(spacing: AuroraSpacing.space3) {
                Text(L10n.Onboarding.completeTitle)
                    .font(.Aurora.title1)
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(L10n.Onboarding.completeSubtitle)
                    .font(.Aurora.body)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AuroraSpacing.space10)
            }
            
            // Hotkey display
            VStack(spacing: AuroraSpacing.space2) {
                Text(L10n.Onboarding.hotkeyLabel)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textSecondary)
                
                Text(configManager.hotkey)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(Color.Aurora.textPrimary)
                    .padding(.horizontal, AuroraSpacing.space6)
                    .padding(.vertical, AuroraSpacing.space3)
                    .background(
                        RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                            .fill(Color.Aurora.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                                    .stroke(Color.Aurora.auroraGradient, lineWidth: 1.5)
                            )
                    )
            }
            .padding(.top, AuroraSpacing.space3)
            
            Text(L10n.Onboarding.hotkeyHint)
                .font(.Aurora.caption)
                .foregroundColor(Color.Aurora.textMuted)
            
            Spacer()
            
            Button(action: onFinish) {
                HStack(spacing: AuroraSpacing.space2) {
                    Text(L10n.Onboarding.startUsing)
                        .font(.Aurora.body.weight(.semibold))
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuroraSpacing.space4)
                .background(Color.Aurora.auroraGradient)
                .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
                .shadow(color: Color.Aurora.accentMid.opacity(0.4), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AuroraSpacing.space12)
            .padding(.bottom, AuroraSpacing.space10)
        }
    }
}

// Legacy alias
struct CompleteStepView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onFinish: () -> Void
    var body: some View { AuroraCompleteStep(onFinish: onFinish) }
}

// MARK: - Aurora Onboarding Button Style

private struct AuroraOnboardingButtonStyle: ButtonStyle {
    enum Style { case primary, secondary }
    let style: Style
    
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(background(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
            .overlay(overlay)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.auroraSpringStiff, value: configuration.isPressed)
    }
    
    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: Color.Aurora.auroraGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(isPressed ? 0.8 : 1.0)
        case .secondary:
            Color.Aurora.surface
                .opacity(isPressed ? 0.8 : 1.0)
        }
    }
    
    private var foregroundColor: Color {
        style == .primary ? .white : Color.Aurora.textPrimary
    }
    
    @ViewBuilder
    private var overlay: some View {
        if style == .secondary {
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 1)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(ConfigManager())
        .environmentObject(AppState(configManager: ConfigManager()))
}

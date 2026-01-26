//
//  OnboardingView.swift
//  Motive
//
//  Onboarding flow for first-time users.
//

import SwiftUI

// MARK: - Onboarding Input Field Style Constants
private enum InputFieldStyle {
    static let height: CGFloat = 32
    static let horizontalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 6
}

// MARK: - Styled Text Field (consistent height with SecureInputField)
struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, InputFieldStyle.horizontalPadding)
            .frame(height: InputFieldStyle.height)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(InputFieldStyle.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: InputFieldStyle.cornerRadius)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Secure Input Field with inline eye toggle
struct SecureInputField: View {
    let placeholder: String
    @Binding var text: String
    @State private var showingText: Bool = false
    
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
            
            Button(action: { showingText.toggle() }) {
                Image(systemName: showingText ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.horizontal, InputFieldStyle.horizontalPadding)
        .frame(height: InputFieldStyle.height)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(InputFieldStyle.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: InputFieldStyle.cornerRadius)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

struct OnboardingView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var appState: AppState
    @State private var currentStep: OnboardingStep = .welcome
    
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
            // Background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                if currentStep != .welcome && currentStep != .complete {
                    OnboardingProgressView(currentStep: currentStep)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                }
                
                // Content
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeStepView(onContinue: { goToNext() })
                    case .aiProvider:
                        AIProviderStepView(
                            onContinue: { goToNext() },
                            onSkip: { goToNext() }
                        )
                    case .accessibility:
                        AccessibilityStepView(
                            onContinue: { goToNext() },
                            onSkip: { goToNext() }
                        )
                    case .browserAutomation:
                        BrowserAutomationStepView(
                            onContinue: { goToNext() },
                            onSkip: { goToNext() }
                        )
                    case .complete:
                        CompleteStepView(onFinish: { completeOnboarding() })
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
            .frame(width: 500, height: 450)
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

// MARK: - Onboarding Settings Row

/// A consistent row container for onboarding settings
struct OnboardingSettingsRow<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

// MARK: - Progress Indicator

struct OnboardingProgressView: View {
    let currentStep: OnboardingView.OnboardingStep
    
    private let steps: [OnboardingView.OnboardingStep] = [.aiProvider, .accessibility, .browserAutomation]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
            VStack(spacing: 12) {
                Text(L10n.Onboarding.welcomeTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(L10n.Onboarding.welcomeSubtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: onContinue) {
                Text(L10n.Onboarding.getStarted)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - AI Provider Step

struct AIProviderStepView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                Text(L10n.Onboarding.aiProviderTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(L10n.Onboarding.aiProviderSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            
            // Configuration card
            VStack(alignment: .leading, spacing: 12) {
                // Provider picker
                Text(L10n.Settings.selectProvider)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $configManager.providerRawValue) {
                    ForEach(ConfigManager.Provider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: configManager.providerRawValue) { _, _ in
                    // Reset fields when provider changes
                    apiKey = ""
                    baseURL = ""
                }
                
                // API Key input (not for Ollama)
                if configManager.provider != .ollama {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.Settings.apiKey)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureInputField(placeholder: apiKeyPlaceholder, text: $apiKey)
                    }
                }
                
                // Base URL input
                VStack(alignment: .leading, spacing: 6) {
                    Text(configManager.provider == .ollama ? L10n.Settings.ollamaHost : L10n.Settings.baseURL)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    StyledTextField(placeholder: baseURLPlaceholder, text: $baseURL)
                    
                    Text(L10n.Settings.defaultEndpoint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text(L10n.Onboarding.skip)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    saveSettings()
                    onContinue()
                }) {
                    Text(L10n.Onboarding.continueButton)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(configManager.provider != .ollama && apiKey.isEmpty)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
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
        // Save API key
        if !apiKey.isEmpty {
            configManager.apiKey = apiKey
        }
        // Save Base URL
        if !baseURL.isEmpty {
            configManager.baseURL = baseURL
        }
    }
}

// MARK: - Accessibility Step

struct AccessibilityStepView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var hasPermission: Bool = false
    @State private var checkTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: hasPermission ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.system(size: 40))
                    .foregroundColor(hasPermission ? .green : .accentColor)
                
                Text(L10n.Onboarding.accessibilityTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(L10n.Onboarding.accessibilitySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            // Status
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasPermission ? .green : .orange)
                    Text(hasPermission ? L10n.Onboarding.accessibilityGranted : L10n.Onboarding.accessibilityRequired)
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                if !hasPermission {
                    Button(action: openAccessibilitySettings) {
                        Label(L10n.Onboarding.openSystemSettings, systemImage: "gear")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 40)
            
            // Instructions
            if !hasPermission {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Onboarding.accessibilityInstructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text(L10n.Onboarding.skip)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: onContinue) {
                    Text(L10n.Onboarding.continueButton)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
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
            Task { @MainActor in
                checkPermission()
            }
        }
    }
    
    private func openAccessibilitySettings() {
        AccessibilityHelper.openAccessibilitySettings()
    }
}

// MARK: - Browser Automation Step

struct BrowserAutomationStepView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var browserAgentAPIKey: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                Text(L10n.Onboarding.browserTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(L10n.Onboarding.browserSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            
            // Configuration card
            VStack(spacing: 0) {
                // Enable toggle row
                OnboardingSettingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Settings.browserEnable)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(L10n.Onboarding.browserEnableDesc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $configManager.browserUseEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
                
                if configManager.browserUseEnabled {
                    Divider().padding(.leading, 16)
                    
                    // Headed mode toggle row
                    OnboardingSettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.Settings.browserShowWindow)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(L10n.Settings.browserShowWindowDesc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $configManager.browserUseHeadedMode)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // Agent Provider picker row
                    OnboardingSettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.Settings.browserAgentProvider)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(L10n.Settings.browserAgentProviderDesc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                            .frame(width: 160)
                        }
                    }
                    
                    Divider().padding(.leading, 16)
                    
                    // API Key input row
                    OnboardingSettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(configManager.browserAgentProvider.envKeyName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(L10n.Settings.browserApiKeyDesc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            SecureInputField(placeholder: "sk-...", text: $browserAgentAPIKey)
                                .frame(width: 180)
                        }
                    }
                }
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 40)
            
            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text(L10n.Onboarding.browserInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text(L10n.Onboarding.skip)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    saveSettings()
                    onContinue()
                }) {
                    Text(L10n.Onboarding.continueButton)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }
    
    private func saveSettings() {
        // Save browser agent API key if provided
        if configManager.browserUseEnabled && !browserAgentAPIKey.isEmpty {
            configManager.browserAgentAPIKey = browserAgentAPIKey
        }
        // Reload skills to apply changes
        SkillManager.shared.reloadSkills()
    }
}

// MARK: - Complete Step

struct CompleteStepView: View {
    @EnvironmentObject var configManager: ConfigManager
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text(L10n.Onboarding.completeTitle)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(L10n.Onboarding.completeSubtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Hotkey display
            VStack(spacing: 8) {
                Text(L10n.Onboarding.hotkeyLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(configManager.hotkey)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(12)
            }
            .padding(.top, 10)
            
            Text(L10n.Onboarding.hotkeyHint)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onFinish) {
                Text(L10n.Onboarding.startUsing)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(ConfigManager())
        .environmentObject(AppState(configManager: ConfigManager()))
}

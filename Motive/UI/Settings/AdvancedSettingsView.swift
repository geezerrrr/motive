//
//  AdvancedSettingsView.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var browserAgentAPIKeyInput: String = ""
    @State private var showBrowserAgentAPIKey: Bool = false
    @State private var browserAgentBaseUrlInput: String = ""
    
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Binary Section
            SettingsCard(title: L10n.Settings.openCodeBinary, icon: "terminal") {
                VStack(spacing: 0) {
                    // Status Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Settings.binaryStatus)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.Aurora.textPrimary)
                            
                            binaryStatusText
                        }
                        
                        Spacer()
                        
                        binaryStatusIcon
                    }
                    .padding(16)
                    
                    Divider()
                        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        .padding(.leading, 16)
                    
                    // Source Path (if set)
                    if !configManager.openCodeBinarySourcePath.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.Settings.sourcePath)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.Aurora.textPrimary)
                                
                                Text(configManager.openCodeBinarySourcePath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.Aurora.textMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        
                        Divider()
                            .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                            .padding(.leading, 16)
                    }
                    
                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            showFileImporter = true
                        } label: {
                            HStack(spacing: 6) {
                                if isImporting {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                }
                                Text(isImporting ? L10n.Settings.importing : L10n.Settings.selectBinary)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color.Aurora.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isImporting)
                        
                        Button {
                            autoDetectAndImport()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                                Text(L10n.Settings.autoDetect)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color.Aurora.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isImporting)
                        
                        Spacer()
                    }
                    .padding(16)
                }
            }
            
            // Import Error
            if let error = importError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.Aurora.error)
                    
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(Color.Aurora.error)
                    
                    Spacer()
                    
                    Button {
                        importError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.Aurora.error.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.Aurora.error.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.Aurora.error.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Browser Automation Section
            SettingsCard(title: L10n.Settings.browserTitle, icon: "globe") {
                VStack(spacing: 0) {
                    // Enable toggle
                    SettingsRow(label: L10n.Settings.browserEnable, description: L10n.Settings.browserEnableDesc) {
                        Toggle("", isOn: $configManager.browserUseEnabled)
                            .toggleStyle(.switch)
                            .tint(Color.Aurora.accent)
                            .onChange(of: configManager.browserUseEnabled) { _, newValue in
                                // Reload skills when toggled
                                SkillManager.shared.reloadSkills()
                                appState.restartAgent()
                            }
                    }
                    
                    if configManager.browserUseEnabled {
                        // Headed mode toggle
                        SettingsRow(label: L10n.Settings.browserShowWindow, description: L10n.Settings.browserShowWindowDesc) {
                            Toggle("", isOn: $configManager.browserUseHeadedMode)
                                .toggleStyle(.switch)
                                .tint(Color.Aurora.accent)
                                .onChange(of: configManager.browserUseHeadedMode) { _, _ in
                                    SkillManager.shared.reloadSkills()
                                    appState.restartAgent()
                                }
                        }
                        
                        // Agent Mode Section Header
                        HStack {
                            Text(L10n.Settings.browserAgentMode)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.Aurora.textMuted)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        
                        // Agent Provider Selection
                        SettingsRow(label: L10n.Settings.browserAgentProvider, description: L10n.Settings.browserAgentProviderDesc) {
                            Picker("", selection: Binding(
                                get: { configManager.browserAgentProvider },
                                set: { newValue in
                                    configManager.browserAgentProvider = newValue
                                    configManager.clearBrowserAgentAPIKeyCache()
                                    browserAgentAPIKeyInput = configManager.browserAgentAPIKey
                                    browserAgentBaseUrlInput = configManager.browserAgentBaseUrl
                                    syncBrowserAgentConfig()
                                    appState.restartAgent()
                                }
                            )) {
                                ForEach(ConfigManager.BrowserAgentProvider.allCases, id: \.self) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }
                        
                        // API Key Input
                        browserAgentAPIKeyRow
                        
                        // Base URL Input (only for providers that support it)
                        if configManager.browserAgentProvider.supportsBaseUrl {
                            browserAgentBaseUrlRow
                        }
                        
                        // Status row
                        browserUseStatusRow
                    }
                }
            }
            
            // Debug Section
            SettingsCard(title: L10n.Settings.diagnostics, icon: "ant") {
                SettingsRow(label: L10n.Settings.debugMode, description: L10n.Settings.debugModeDesc, showDivider: false) {
                    Toggle("", isOn: $configManager.debugMode)
                        .toggleStyle(.switch)
                        .tint(Color.Aurora.accent)
                }
            }
            
            // About Section
            SettingsCard(title: L10n.Settings.about, icon: "info.circle") {
                VStack(spacing: 0) {
                    aboutRow(L10n.Settings.version, value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                    aboutRow(L10n.Settings.build, value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1", showDivider: false)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.unixExecutable, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                importBinary(from: url)
            }
        }
        .onAppear {
            _ = configManager.resolveBinary()
            browserAgentAPIKeyInput = configManager.browserAgentAPIKey
            browserAgentBaseUrlInput = configManager.browserAgentBaseUrl
            syncBrowserAgentConfig()
        }
    }
    
    // MARK: - Binary Status
    
    private var binaryStatusText: some View {
        Group {
            switch configManager.binaryStatus {
            case .notConfigured:
                Text(L10n.Settings.notConfigured)
                    .font(.system(size: 11))
                    .foregroundColor(Color.Aurora.warning)
            case .ready(let path):
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .error(let error):
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Color.Aurora.error)
            }
        }
    }
    
    private var binaryStatusIcon: some View {
        Group {
            switch configManager.binaryStatus {
            case .notConfigured:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.Aurora.warning)
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.Aurora.success)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.Aurora.error)
            }
        }
    }
    
    // MARK: - About Row
    
    private func aboutRow(_ label: String, value: String, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.Aurora.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.Aurora.textMuted)
            }
            .padding(16)
            
            if showDivider {
                Divider()
                    .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                    .padding(.leading, 16)
            }
        }
    }
    
    // MARK: - Browser Automation Status
    
    @ViewBuilder
    private var browserAgentAPIKeyRow: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(configManager.browserAgentProvider.envKeyName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    Text(L10n.Settings.browserApiKeyDesc)
                        .font(.system(size: 11))
                        .foregroundColor(Color.Aurora.textMuted)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if showBrowserAgentAPIKey {
                        TextField("sk-...", text: $browserAgentAPIKeyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.Aurora.textPrimary)
                            .frame(width: 180)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.Aurora.border, lineWidth: 1)
                            )
                            .onChange(of: browserAgentAPIKeyInput) { _, newValue in
                                configManager.browserAgentAPIKey = newValue
                                syncBrowserAgentConfig()
                                appState.restartAgent()
                            }
                    } else {
                        Text(configManager.hasBrowserAgentAPIKey ? "••••••••" : L10n.Settings.browserNotSet)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(configManager.hasBrowserAgentAPIKey ? Color.Aurora.textMuted : Color.Aurora.warning)
                            .frame(width: 180, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    
                    Button {
                        showBrowserAgentAPIKey.toggle()
                        if showBrowserAgentAPIKey {
                            browserAgentAPIKeyInput = configManager.browserAgentAPIKey
                        }
                    } label: {
                        Image(systemName: showBrowserAgentAPIKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(Color.Aurora.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            
            Divider()
                .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                .padding(.leading, 16)
        }
    }
    
    @ViewBuilder
    private var browserAgentBaseUrlRow: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Settings.browserBaseUrl)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    Text(L10n.Settings.browserBaseUrlDesc)
                        .font(.system(size: 11))
                        .foregroundColor(Color.Aurora.textMuted)
                }
                
                Spacer()
                
                TextField("https://api.example.com", text: $browserAgentBaseUrlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.Aurora.textPrimary)
                    .frame(width: 200)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.Aurora.border, lineWidth: 1)
                    )
                    .onChange(of: browserAgentBaseUrlInput) { _, newValue in
                        configManager.browserAgentBaseUrl = newValue
                        syncBrowserAgentConfig()
                        appState.restartAgent()
                    }
            }
            .padding(16)
            
            Divider()
                .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                .padding(.leading, 16)
        }
    }
    
    @ViewBuilder
    private var browserUseStatusRow: some View {
        let status = configManager.browserUseStatus
        
        SettingsRow(label: L10n.Settings.browserStatus, description: browserUseStatusDescription(status), showDivider: false) {
            browserUseStatusIcon(status)
        }
    }
    
    private func browserUseStatusDescription(_ status: ConfigManager.BrowserUseStatus) -> String {
        switch status {
        case .ready:
            return L10n.Settings.browserStatusReady
        case .binaryNotFound:
            return L10n.Settings.browserStatusNotFound
        case .disabled:
            return L10n.Settings.browserStatusDisabled
        }
    }
    
    @ViewBuilder
    private func browserUseStatusIcon(_ status: ConfigManager.BrowserUseStatus) -> some View {
        switch status {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.Aurora.success)
        case .binaryNotFound:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.Aurora.warning)
        case .disabled:
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.Aurora.textMuted)
        }
    }
    
    // MARK: - Actions
    
    private func importBinary(from url: URL) {
        isImporting = true
        importError = nil
        
        Task {
            do {
                try await configManager.importBinary(from: url)
                appState.restartAgent()
            } catch {
                importError = error.localizedDescription
            }
            isImporting = false
        }
    }
    
    private func autoDetectAndImport() {
        isImporting = true
        importError = nil
        
        Task {
            let result = await configManager.getSignedBinaryURL()
            if let error = result.error {
                importError = error
            } else {
                appState.restartAgent()
            }
            isImporting = false
        }
    }
    
    /// Sync browser agent API configuration to BrowserUseBridge
    private func syncBrowserAgentConfig() {
        BrowserUseBridge.shared.configureAgentAPIKey(
            envName: configManager.browserAgentProvider.envKeyName,
            apiKey: configManager.browserAgentAPIKey,
            baseUrlEnvName: configManager.browserAgentProvider.baseUrlEnvName,
            baseUrl: configManager.browserAgentBaseUrl
        )
    }
}

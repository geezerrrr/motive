//
//  AdvancedSettingsView.swift
//  Motive
//
//  Compact advanced settings with collapsible sections
//

import SwiftUI
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var appState: AppState
    
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var browserAgentAPIKeyInput: String = ""
    @State private var showBrowserAgentAPIKey: Bool = false
    @State private var browserAgentBaseUrlInput: String = ""
    

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // OpenCode Binary Section
                CollapsibleSection(L10n.Settings.openCodeBinary, icon: "terminal.fill") {
                    SettingRow(L10n.Settings.binaryStatus) {
                        HStack(spacing: 10) {
                            binaryStatusIcon
                            binaryStatusText
                        }
                    }
                    
                    if !configManager.openCodeBinarySourcePath.isEmpty {
                        SettingRow(L10n.Settings.sourcePath) {
                            Text(configManager.openCodeBinarySourcePath)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.Aurora.textMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 200, alignment: .trailing)
                        }
                    }
                    
                    SettingRow("Actions", showDivider: false) {
                        HStack(spacing: 10) {
                            Button {
                                showFileImporter = true
                            } label: {
                                HStack(spacing: 6) {
                                    if isImporting {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "folder")
                                            .font(.system(size: 11))
                                    }
                                    Text(isImporting ? L10n.Settings.importing : L10n.Settings.selectBinary)
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.Aurora.primary)
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
                            }
                            .buttonStyle(.bordered)
                            .disabled(isImporting)
                        }
                    }
                }
                
                // Import Error
                if let error = importError {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
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
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.Aurora.error.opacity(0.1))
                    )
                }
                
                // Browser Automation Section
                CollapsibleSection(L10n.Settings.browserTitle, icon: "globe") {
                    SettingRow(L10n.Settings.browserEnable, description: L10n.Settings.browserEnableDesc) {
                        Toggle("", isOn: $configManager.browserUseEnabled)
                            .toggleStyle(.switch)
                            .tint(Color.Aurora.primary)
                            .controlSize(.small)
                            .onChange(of: configManager.browserUseEnabled) { _, _ in
                                SkillManager.shared.reloadSkills()
                                appState.restartAgent()
                            }
                    }
                    
                    if configManager.browserUseEnabled {
                        SettingRow(L10n.Settings.browserShowWindow, description: L10n.Settings.browserShowWindowDesc) {
                            Toggle("", isOn: $configManager.browserUseHeadedMode)
                                .toggleStyle(.switch)
                                .tint(Color.Aurora.primary)
                                .controlSize(.small)
                                .onChange(of: configManager.browserUseHeadedMode) { _, _ in
                                    SkillManager.shared.reloadSkills()
                                    appState.restartAgent()
                                }
                        }
                        
                        SettingRow(L10n.Settings.browserAgentProvider, description: L10n.Settings.browserAgentProviderDesc) {
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
                            .frame(width: 180)
                            .controlSize(.small)
                        }
                        
                        SettingRow(configManager.browserAgentProvider.envKeyName, description: L10n.Settings.browserApiKeyDesc) {
                            // API Key field with eye toggle inside
                            ZStack(alignment: .trailing) {
                                Group {
                                    if showBrowserAgentAPIKey {
                                        TextField("sk-...", text: $browserAgentAPIKeyInput)
                                    } else {
                                        SecureField("sk-...", text: $browserAgentAPIKeyInput)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.leading, 10)
                                .padding(.trailing, 32)
                                .padding(.vertical, 6)
                                .controlSize(.small)
                                .onChange(of: browserAgentAPIKeyInput) { _, newValue in
                                    configManager.browserAgentAPIKey = newValue
                                    syncBrowserAgentConfig()
                                    appState.restartAgent()
                                }

                                Button {
                                    showBrowserAgentAPIKey.toggle()
                                    if showBrowserAgentAPIKey {
                                        browserAgentAPIKeyInput = configManager.browserAgentAPIKey
                                    }
                                } label: {
                                    Image(systemName: showBrowserAgentAPIKey ? "eye.slash" : "eye")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.Aurora.textMuted)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                            }
                            .frame(width: 180)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.Aurora.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.Aurora.border, lineWidth: 1)
                            )
                        }
                        
                        if configManager.browserAgentProvider.supportsBaseUrl {
                            SettingRow(L10n.Settings.browserBaseUrl, description: L10n.Settings.browserBaseUrlDesc) {
                                TextField("https://api.example.com", text: $browserAgentBaseUrlInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 160)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .controlSize(.small)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.Aurora.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.Aurora.border, lineWidth: 1)
                                    )
                                    .onChange(of: browserAgentBaseUrlInput) { _, newValue in
                                        configManager.browserAgentBaseUrl = newValue
                                        syncBrowserAgentConfig()
                                        appState.restartAgent()
                                    }
                            }
                        }
                        
                        SettingRow(L10n.Settings.browserStatus, showDivider: false) {
                            HStack(spacing: 8) {
                                browserUseStatusIcon(configManager.browserUseStatus)
                                Text(browserUseStatusDescription(configManager.browserUseStatus))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.Aurora.textSecondary)
                            }
                        }
                    }
                }
                
                // Debug Section
                CollapsibleSection(L10n.Settings.diagnostics, icon: "ladybug.fill") {
                    SettingRow(L10n.Settings.debugMode, description: L10n.Settings.debugModeDesc, showDivider: false) {
                        Toggle("", isOn: $configManager.debugMode)
                            .toggleStyle(.switch)
                            .tint(Color.Aurora.primary)
                            .controlSize(.small)
                    }
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
                    .font(.system(size: 12))
                    .foregroundColor(Color.Aurora.warning)
            case .ready(let path):
                Text(path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .error(let error):
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(Color.Aurora.error)
            }
        }
    }
    
    private var binaryStatusIcon: some View {
        Group {
            switch configManager.binaryStatus {
            case .notConfigured:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.Aurora.warning)
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.Aurora.success)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.Aurora.error)
            }
        }
    }
    
    // MARK: - Browser Automation Status
    
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
                .font(.system(size: 12))
                .foregroundColor(Color.Aurora.success)
        case .binaryNotFound:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.Aurora.warning)
        case .disabled:
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 12))
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

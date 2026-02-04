//
//  SkillsSettingsView.swift
//  Motive
//
//  Compact skills management with split-pane layout
//

import SwiftUI
import Foundation
import MarkdownUI

struct SkillsSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SkillsSettingsViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText: String = ""
    @State private var selectedSkillId: String?
    @State private var markdownContent: String = ""
    @State private var markdownError: String? = nil
    @State private var isMarkdownLoading: Bool = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    /// Filtered skills based on search
    private var filteredSkills: [SkillStatusEntry] {
        if searchText.isEmpty {
            return viewModel.statusEntries
        }
        let lowercasedSearch = searchText.lowercased()
        return viewModel.statusEntries.filter { status in
            status.entry.name.lowercased().contains(lowercasedSearch) ||
            status.entry.description.lowercased().contains(lowercasedSearch)
        }
    }

    /// The currently selected skill status
    private var selectedSkill: SkillStatusEntry? {
        guard let id = selectedSkillId else { return nil }
        return viewModel.statusEntries.first { $0.entry.name == id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Controls bar
            controlsBar
            
            // Main content: List + Detail
            HStack(alignment: .top, spacing: 0) {
                // Skills list (left)
                skillsList
                    .frame(width: 240)
                
                // Divider
                Rectangle()
                    .fill(Color.Aurora.border)
                    .frame(width: 1)
                
                // Detail panel (right)
                detailPanel
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.Aurora.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
        }
        .onAppear {
            viewModel.setConfigManager(configManager)
            if selectedSkillId == nil, let first = viewModel.statusEntries.first {
                selectedSkillId = first.entry.name
                loadMarkdown(for: first.entry)
            }
        }
        .onChange(of: viewModel.statusEntries) { _, newValue in
            if let id = selectedSkillId, newValue.contains(where: { $0.entry.name == id }) {
                return
            }
            if let first = newValue.first {
                selectedSkillId = first.entry.name
                loadMarkdown(for: first.entry)
            }
        }
        .onChange(of: selectedSkillId) { _, newValue in
            guard let id = newValue,
                  let entry = viewModel.statusEntries.first(where: { $0.entry.name == id })?.entry else {
                return
            }
            loadMarkdown(for: entry)
        }
        // Auto-restart agent when skill config changes
        .onChange(of: viewModel.needsRestart) { _, needsRestart in
            if needsRestart {
                // Small delay to let UI update first
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    appState.restartAgent()
                    viewModel.clearRestartNeeded()
                }
            }
        }
    }
    
    // MARK: - Controls Bar
    
    private var controlsBar: some View {
        HStack(spacing: 12) {
            // Enable toggle
            HStack(spacing: 8) {
                Toggle("", isOn: $configManager.skillsSystemEnabled)
                    .toggleStyle(.switch)
                    .tint(Color.Aurora.primary)
                    .scaleEffect(0.85)
                    .onChange(of: configManager.skillsSystemEnabled) { _, _ in
                        viewModel.refresh()
                    }
                
                Text(L10n.Settings.skillsEnable)
                    .font(.system(size: 13))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            
            Spacer()
            
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(Color.Aurora.textMuted)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(width: 120)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
            
            // Refresh button
            Button {
                viewModel.refresh()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                }
                .foregroundColor(Color.Aurora.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Skills List
    
    private var skillsList: some View {
        Group {
            if viewModel.isLoading && viewModel.statusEntries.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.Aurora.textMuted)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredSkills.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(Color.Aurora.textMuted)
                    Text(searchText.isEmpty ? "No skills" : "No matches")
                        .font(.system(size: 12))
                        .foregroundColor(Color.Aurora.textMuted)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSkills) { status in
                            SkillListItem(
                                status: status,
                                isSelected: selectedSkillId == status.entry.name,
                                onSelect: {
                                    selectedSkillId = status.entry.name
                                },
                                onToggle: { enabled in
                                    viewModel.toggleSkill(status.entry.name, enabled: enabled)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Detail Panel
    
    private var detailPanel: some View {
        Group {
            if let skill = selectedSkill {
                SkillDetail(
                    status: skill,
                    markdownContent: markdownContent,
                    markdownError: markdownError,
                    isMarkdownLoading: isMarkdownLoading,
                    isBusy: viewModel.installingSkillKey == skill.entry.name,
                    installMessage: viewModel.installMessages[skill.entry.name],
                    currentApiKey: viewModel.getApiKey(for: skill.entry.name),
                    onToggle: { enabled in
                        viewModel.toggleSkill(skill.entry.name, enabled: enabled)
                    },
                    onInstall: { option in
                        Task {
                            await viewModel.install(skill.entry, option: option)
                        }
                    },
                    onSaveApiKey: { key in
                        viewModel.saveApiKey(for: skill.entry.name, key: key)
                    }
                )
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(Color.Aurora.textMuted)
                    Text("Select a skill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.Aurora.textMuted)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func loadMarkdown(for entry: SkillEntry) {
        let path = entry.filePath
        isMarkdownLoading = true
        markdownError = nil
        markdownContent = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            let content = try? String(contentsOfFile: path, encoding: .utf8)
            let sanitized = content.map(stripFrontmatter(from:)) ?? ""
            DispatchQueue.main.async {
                isMarkdownLoading = false
                if !sanitized.isEmpty {
                    markdownContent = sanitized
                } else {
                    markdownError = "Unable to load SKILL.md"
                }
            }
        }
    }
    
    private func stripFrontmatter(from content: String) -> String {
        guard content.hasPrefix("---") else { return content }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 2 else { return content }
        var endIndex: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                endIndex = i
                break
            }
        }
        guard let endIndex else { return content }
        let remaining = lines[(endIndex + 1)...].joined(separator: "\n")
        return remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Skill Status Type
// Two dimensions:
// 1. Dependency: Ready (deps satisfied) vs Blocked (missing deps)
// 2. Enabled: Enabled vs Disabled (only meaningful when Ready)

private enum SkillListStatus {
    case blockedDisabled   // Missing deps + disabled
    case blockedEnabled    // Missing deps + enabled (shouldn't happen but handle it)
    case readyDisabled     // Deps OK but disabled
    case readyEnabled      // Deps OK and enabled - fully active
    
    var color: Color {
        switch self {
        case .blockedDisabled, .blockedEnabled:
            return Color.Aurora.warning  // Orange for blocked
        case .readyDisabled:
            return Color.Aurora.textMuted  // Gray for disabled
        case .readyEnabled:
            return Color.Aurora.success  // Green for active
        }
    }
    
    var icon: String {
        switch self {
        case .blockedDisabled, .blockedEnabled:
            return "exclamationmark.circle.fill"  // Warning for blocked
        case .readyDisabled:
            return "minus.circle.fill"  // Minus for disabled
        case .readyEnabled:
            return "checkmark.circle.fill"  // Check for active
        }
    }
}

// MARK: - Skill List Item

private struct SkillListItem: View {
    let status: SkillStatusEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: (Bool) -> Void
    
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    /// Determine the display status based on dependency and enabled state
    private var listStatus: SkillListStatus {
        let isBlocked = !status.missing.isEmpty
        let isDisabled = status.disabled
        
        if isBlocked {
            return isDisabled ? .blockedDisabled : .blockedEnabled
        } else {
            return isDisabled ? .readyDisabled : .readyEnabled
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Emoji or icon
                Group {
                    if let emoji = status.entry.metadata?.emoji {
                        Text(emoji)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                }
                .frame(width: 24)
                
                // Name only (description in detail panel)
                Text(status.entry.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(status.disabled ? Color.Aurora.textMuted : Color.Aurora.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Status indicator with icon
                Image(systemName: listStatus.icon)
                    .font(.system(size: 10))
                    .foregroundColor(listStatus.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        } else if isHovering {
            return isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
        }
        return Color.clear
    }
}

// MARK: - Skill Detail

private struct SkillDetail: View {
    let status: SkillStatusEntry
    let markdownContent: String
    let markdownError: String?
    let isMarkdownLoading: Bool
    let isBusy: Bool
    let installMessage: SkillsSettingsViewModel.SkillInstallMessage?
    let currentApiKey: String
    let onToggle: (Bool) -> Void
    let onInstall: (SkillInstallOption) -> Void
    let onSaveApiKey: (String) -> Void
    
    @State private var apiKeyInput: String = ""
    @State private var isEditingKey: Bool = false
    @State private var showApiKey: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var primaryEnvName: String? {
        status.entry.metadata?.primaryEnv
    }
    
    private var hasApiKey: Bool {
        !currentApiKey.isEmpty
    }
    
    /// Dependency status: Blocked (missing deps) or Ready (deps satisfied)
    private var isReady: Bool {
        status.missing.isEmpty
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        // Show dependency status: Blocked or Ready
        let text = isReady ? "Ready" : "Blocked"
        let color = isReady ? Color.Aurora.success : Color.Aurora.warning
        
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
            )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                // Missing deps warning
                if !status.missing.isEmpty {
                    missingSection
                }
                
                // API Key input
                if let envName = primaryEnvName {
                    apiKeySection(envName: envName)
                }
                
                // Install options
                if !status.installOptions.isEmpty && !status.missing.bins.isEmpty {
                    installSection
                }
                
                // Markdown content
                markdownSection
            }
            .padding(20)
        }
        .onAppear {
            apiKeyInput = currentApiKey
        }
        .onChange(of: currentApiKey) { _, newValue in
            if !isEditingKey {
                apiKeyInput = newValue
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: emoji, name, badges
            HStack(spacing: 12) {
                // Emoji/icon
                Group {
                    if let emoji = status.entry.metadata?.emoji {
                        Text(emoji)
                            .font(.system(size: 32))
                    } else {
                        Image(systemName: "sparkle")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.Aurora.auroraGradient)
                    }
                }
                
                // Name and badges
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(status.entry.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.Aurora.textPrimary)
                        
                        // Status badge - distinguish between Disabled, Blocked, and Ready
                        statusBadge
                        
                        // Source badge
                        Text(status.entry.source.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.Aurora.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                            )
                    }
                }
                
                Spacer()
            }
            
            // Description - full width
            Text(status.entry.description)
                .font(.system(size: 13))
                .foregroundColor(Color.Aurora.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Missing Requirements")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.Aurora.warning)
            
            if !status.missing.bins.isEmpty {
                Text("binaries: \(status.missing.bins.joined(separator: ", "))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            
            let otherMissingEnv = status.missing.env.filter { $0 != primaryEnvName }
            if !otherMissingEnv.isEmpty {
                Text("env: \(otherMissingEnv.joined(separator: ", "))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            
            if !status.missing.config.isEmpty {
                Text("config: \(status.missing.config.joined(separator: ", "))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.Aurora.warning.opacity(0.08))
        )
    }
    
    @ViewBuilder
    private func apiKeySection(envName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(envName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.Aurora.textMuted)
                
                if hasApiKey && !isEditingKey {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.Aurora.success)
                }
            }
            
            if isEditingKey || !hasApiKey {
                HStack(spacing: 8) {
                    // API Key field with eye toggle inside
                    ZStack(alignment: .trailing) {
                        Group {
                            if showApiKey {
                                TextField("Enter API key...", text: $apiKeyInput)
                            } else {
                                SecureField("Enter API key...", text: $apiKeyInput)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.leading, 10)
                        .padding(.trailing, 30)
                        .padding(.vertical, 6)
                        .onSubmit { saveApiKey() }
                        
                        Button {
                            showApiKey.toggle()
                        } label: {
                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                                .font(.system(size: 10))
                                .foregroundColor(Color.Aurora.textMuted)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.Aurora.border, lineWidth: 1)
                    )
                    
                    Button {
                        saveApiKey()
                    } label: {
                        Text("Save")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.Aurora.primary)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(apiKeyInput.isEmpty)
                    
                    if isEditingKey {
                        Button {
                            apiKeyInput = currentApiKey
                            isEditingKey = false
                            showApiKey = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.Aurora.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack {
                    Text(maskedKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.Aurora.textMuted)
                    
                    Spacer()
                    
                    Button {
                        isEditingKey = true
                        apiKeyInput = ""
                    } label: {
                        Text("Edit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.Aurora.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.02) : Color.black.opacity(0.01))
        )
    }
    
    private var installSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.Aurora.textMuted)
            
            HStack(spacing: 8) {
                ForEach(status.installOptions, id: \.id) { option in
                    Button {
                        onInstall(option)
                    } label: {
                        HStack(spacing: 4) {
                            if isBusy {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: iconName(for: option.kind))
                                    .font(.system(size: 10))
                            }
                            
                            Text(option.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(option.available ? Color.Aurora.textPrimary : Color.Aurora.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.available || isBusy)
                }
            }
            
            if let installMessage {
                HStack(spacing: 4) {
                    Image(systemName: installMessage.kind == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(installMessage.message)
                        .font(.system(size: 10))
                }
                .foregroundColor(installMessage.kind == .success ? Color.Aurora.success : Color.Aurora.error)
            }
        }
    }
    
    private var markdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with Toggle
            HStack {
                Text("Skill Guide")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.Aurora.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                // Toggle moved here - disabled when skill is blocked
                HStack(spacing: 8) {
                    if !isReady {
                        Text("Blocked")
                            .font(.system(size: 11))
                            .foregroundColor(Color.Aurora.warning)
                    } else {
                        Text(status.disabled ? "Disabled" : "Enabled")
                            .font(.system(size: 11))
                            .foregroundColor(status.disabled ? Color.Aurora.textMuted : Color.Aurora.success)
                    }
                    
                    Toggle("", isOn: Binding(
                        get: { !status.disabled },
                        set: { onToggle($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(Color.Aurora.primary)
                    .disabled(!isReady)  // Can't enable blocked skills
                }
            }
            
            Group {
                if isMarkdownLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading...")
                            .font(.system(size: 11))
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                    .padding(.vertical, 16)
                } else if let markdownError {
                    Text(markdownError)
                        .font(.system(size: 11))
                        .foregroundColor(Color.Aurora.error)
                        .padding(.vertical, 8)
                } else {
                    Markdown(markdownContent)
                        .markdownTextStyle {
                            FontSize(13)
                            ForegroundColor(Color.Aurora.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.02) : Color.black.opacity(0.01))
            )
        }
    }
    
    private var maskedKey: String {
        guard currentApiKey.count > 8 else {
            return String(repeating: "•", count: max(currentApiKey.count, 4))
        }
        let prefix = String(currentApiKey.prefix(4))
        let suffix = String(currentApiKey.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
    
    private func saveApiKey() {
        guard !apiKeyInput.isEmpty else { return }
        onSaveApiKey(apiKeyInput)
        isEditingKey = false
    }
    
    private func iconName(for kind: InstallKind) -> String {
        switch kind {
        case .brew: return "cup.and.saucer.fill"
        case .node: return "shippingbox.fill"
        case .go: return "chevron.left.forwardslash.chevron.right"
        case .uv: return "puzzlepiece.fill"
        case .apt: return "square.and.arrow.down.fill"
        case .download: return "arrow.down.circle.fill"
        }
    }
}

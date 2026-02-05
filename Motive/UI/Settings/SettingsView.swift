//
//  SettingsView.swift
//  Motive
//
//  Settings Window
//  Premium macOS-native layout with sidebar navigation
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    var initialTab: SettingsTab = .general
    @State private var selectedTab: SettingsTab? = .general
    init(initialTab: SettingsTab = .general) {
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }
    
    private var activeTab: SettingsTab {
        selectedTab ?? .general
    }
    
    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
        } detail: {
            SettingsDetailView(tab: activeTab)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: activeTab.windowSize.width, height: activeTab.windowSize.height)
        .background(Color.Aurora.background)
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case persona
    case model
    case skills
    case permissions
    case advanced
    case about
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return L10n.Settings.general
        case .persona: return L10n.Settings.persona
        case .model: return L10n.Settings.aiProvider
        case .skills: return L10n.Settings.skills
        case .permissions: return L10n.Settings.permissions
        case .advanced: return L10n.Settings.advanced
        case .about: return L10n.Settings.about
        }
    }

    var subtitle: String {
        switch self {
        case .general: return L10n.Settings.generalSubtitle
        case .persona: return L10n.Settings.personaSubtitle
        case .model: return L10n.Settings.aiProviderSubtitle
        case .skills: return L10n.Settings.skillsSubtitle
        case .permissions: return L10n.Settings.permissionsSubtitle
        case .advanced: return L10n.Settings.advancedSubtitle
        case .about: return L10n.Settings.aboutSubtitle
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .persona: return "person.fill"
        case .model: return "cpu.fill"
        case .skills: return "sparkles"
        case .permissions: return "lock.shield.fill"
        case .advanced: return "wrench.and.screwdriver.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    /// Fixed window size for all tabs
    var windowSize: CGSize {
        CGSize(width: 920, height: 640)
    }
    
    @ViewBuilder
    var contentView: some View {
        switch self {
        case .general:
            GeneralSettingsView()
        case .persona:
            PersonaSettingsView()
        case .model:
            ModelConfigView()
        case .skills:
            SkillsSettingsView()
        case .permissions:
            PermissionPolicyView()
        case .advanced:
            AdvancedSettingsView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - Settings Detail

private struct SettingsDetailView: View {
    let tab: SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.Aurora.primary)
                Text(tab.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.Aurora.textPrimary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Text(tab.subtitle)
                .font(.system(size: 13))
                .foregroundColor(Color.Aurora.textSecondary)
                .padding(.horizontal, 28)

            Divider()
                .padding(.horizontal, 28)

            Group {
                if tab == .skills || tab == .advanced {
                    tab.contentView
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                } else {
                    ScrollView {
                        tab.contentView
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.Aurora.background)
    }
}

// MARK: - New Setting Section Component

struct SettingSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.Aurora.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
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
    }
}

// MARK: - New Setting Row Component

struct SettingRow<Content: View>: View {
    let label: String
    var description: String? = nil
    let content: Content
    var showDivider: Bool = true
    
    init(_ label: String, description: String? = nil, showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.label = label
        self.description = description
        self.showDivider = showDivider
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Label
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    if let description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(Color.Aurora.textMuted)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Control
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Divider
            if showDivider {
                Rectangle()
                    .fill(Color.Aurora.border)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Collapsible Section (for Advanced)

struct CollapsibleSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    let content: Content
    
    @State private var isExpanded: Bool = true
    
    init(_ title: String, icon: String? = nil, expanded: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self._isExpanded = State(initialValue: expanded)
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (clickable)
            Button {
                withAnimation(.auroraFast) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.Aurora.primary)
                    }
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Aurora.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.Aurora.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                VStack(spacing: 0) {
                    content
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Aurora.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.Aurora.border, lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}


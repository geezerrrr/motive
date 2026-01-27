//
//  SettingsView.swift
//  Motive
//
//  Aurora Design System - Settings Window
//

import SwiftUI

struct SettingsView: View {
    var initialTab: SettingsTab = .general
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    init(initialTab: SettingsTab = .general) {
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
            
            // Divider (extend to full height including titlebar)
            Rectangle()
                .fill(Color.Aurora.border)
                .frame(width: 1)
                .ignoresSafeArea()
            
            // Content
            contentArea
        }
        .frame(width: 760, height: 560)
        .background(Color.Aurora.background.ignoresSafeArea())
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding
            HStack(spacing: AuroraSpacing.space3) {
                // Logo with aurora glow
                ZStack {
                    if let logoImage = NSImage(named: isDark ? "logo-light" : "logo-dark") {
                        Image(nsImage: logoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                            .fill(Color.Aurora.auroraGradient)
                            .frame(width: 48, height: 48)
                    }
                }
                .shadow(color: Color.Aurora.accentMid.opacity(0.2), radius: 8, y: 2)
                
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    Text(L10n.appName)
                        .font(.Aurora.headline)
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                        .font(.Aurora.micro)
                        .foregroundColor(Color.Aurora.textMuted)
                }
            }
            .padding(.horizontal, AuroraSpacing.space5)
            .padding(.top, AuroraSpacing.space6)
            .padding(.bottom, AuroraSpacing.space8)
            
            // Navigation
            VStack(spacing: AuroraSpacing.space1) {
                ForEach(SettingsTab.allCases) { tab in
                    AuroraSettingsNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.auroraSpring) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, AuroraSpacing.space3)
            
            Spacer()
            
            // Footer
            VStack(spacing: AuroraSpacing.space3) {
                Rectangle()
                    .fill(Color.Aurora.border)
                    .frame(height: 1)
                
                Link(destination: URL(string: "https://github.com/geezerrrr/motive")!) {
                    HStack(spacing: AuroraSpacing.space2) {
                        Image(systemName: "star")
                            .font(.system(size: 13))
                        Text(L10n.Settings.starOnGitHub)
                            .font(.Aurora.bodySmall.weight(.medium))
                    }
                    .foregroundColor(Color.Aurora.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AuroraSpacing.space3)
                    .background(
                        RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                            .fill(Color.Aurora.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                            .stroke(Color.Aurora.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AuroraSpacing.space3)
            }
            .padding(.bottom, AuroraSpacing.space4)
        }
        .frame(width: 220)
        .background(Color.Aurora.backgroundDeep.ignoresSafeArea())
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                    Text(selectedTab.title)
                        .font(.Aurora.title1)
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    Text(selectedTab.subtitle)
                        .font(.Aurora.body)
                        .foregroundColor(Color.Aurora.textSecondary)
                }
                .padding(.top, AuroraSpacing.space8)
                .padding(.bottom, AuroraSpacing.space6)
                .padding(.horizontal, AuroraSpacing.space8)
                
                // Content
                selectedTab.contentView
                    .padding(.horizontal, AuroraSpacing.space8)
                    .padding(.bottom, AuroraSpacing.space8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case model
    case permissions
    case advanced
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return L10n.Settings.general
        case .model: return L10n.Settings.aiProvider
        case .permissions: return L10n.Settings.permissions
        case .advanced: return L10n.Settings.advanced
        }
    }
    
    var subtitle: String {
        switch self {
        case .general: return L10n.Settings.generalSubtitle
        case .model: return L10n.Settings.aiProviderSubtitle
        case .permissions: return L10n.Settings.permissionsSubtitle
        case .advanced: return L10n.Settings.advancedSubtitle
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .model: return "cpu.fill"
        case .permissions: return "lock.shield.fill"
        case .advanced: return "wrench.and.screwdriver.fill"
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch self {
        case .general:
            GeneralSettingsView()
        case .model:
            ModelConfigView()
        case .permissions:
            PermissionPolicyView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - Aurora Settings Navigation Item

private struct AuroraSettingsNavItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AuroraSpacing.space3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? Color.Aurora.accent : Color.Aurora.textSecondary)
                    .frame(width: 22)
                
                Text(tab.title)
                    .font(.Aurora.body.weight(isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.Aurora.textPrimary : Color.Aurora.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                // Gradient left border for selected
                HStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.Aurora.auroraGradient)
                            .frame(width: 3)
                    }
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.Aurora.accent.opacity(isDark ? 0.15 : 0.12)
        } else if isHovering {
            return Color.Aurora.surfaceElevated
        }
        return Color.clear
    }
}

// MARK: - Aurora Settings Card

struct SettingsCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space4) {
            // Header
            HStack(spacing: AuroraSpacing.space2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Aurora.auroraGradient)
                }
                
                Text(title)
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            // Content card
            VStack(spacing: 0) {
                content
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
    }
}

// MARK: - Aurora Settings Row

struct SettingsRow<Content: View>: View {
    let label: String
    var description: String? = nil
    let content: Content
    var showDivider: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    init(label: String, description: String? = nil, showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.label = label
        self.description = description
        self.showDivider = showDivider
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    Text(label)
                        .font(.Aurora.body.weight(.medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    if let description {
                        Text(description)
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                }
                
                Spacer()
                
                content
            }
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space4)
            
            if showDivider {
                Rectangle()
                    .fill(Color.Aurora.border)
                    .frame(height: 1)
                    .padding(.leading, AuroraSpacing.space4)
            }
        }
    }
}

// MARK: - Legacy Support

struct SettingsSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    let content: Content
    
    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        SettingsCard(title: title, icon: icon) {
            content
        }
    }
}

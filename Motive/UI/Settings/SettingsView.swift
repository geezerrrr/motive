//
//  SettingsView.swift
//  Motive
//
//  Redesigned Settings Window
//  Compact tab bar + unified layout system
//

import SwiftUI

// MARK: - Settings View

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
        VStack(spacing: 0) {
            // Compact Tab Bar
            CompactTabBar(selectedTab: $selectedTab)
            
            // Content area - centered with max width
            Group {
                if selectedTab == .skills {
                    // Skills uses full width
                    selectedTab.contentView
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                } else if selectedTab == .advanced || selectedTab == .permissions || selectedTab == .persona {
                    // Advanced, Permissions and Persona need scroll
                    ScrollView {
                        VStack {
                            selectedTab.contentView
                                .frame(maxWidth: 520)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 24)
                    }
                } else {
                    // Other tabs: no scroll, vertically centered
                    VStack {
                        selectedTab.contentView
                            .frame(maxWidth: 520)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Aurora.background)
        }
        .frame(width: selectedTab.windowSize.width, height: selectedTab.windowSize.height)
        .background(Color.Aurora.backgroundDeep)
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
        // Use consistent size for all tabs
        CGSize(width: 720, height: 560)
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

// MARK: - Compact Tab Bar

struct CompactTabBar: View {
    @Binding var selectedTab: SettingsTab
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                CompactTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.Aurora.backgroundDeep)
    }
}

// MARK: - Compact Tab Button

private struct CompactTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
            }
            .frame(width: 64, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    private var iconColor: Color {
        if isSelected {
            return Color.Aurora.primary
        }
        return isHovering ? Color.Aurora.textPrimary : Color.Aurora.textSecondary
    }
    
    private var textColor: Color {
        if isSelected {
            return Color.Aurora.textPrimary
        }
        return Color.Aurora.textSecondary
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.Aurora.primary.opacity(isDark ? 0.15 : 0.12)
        } else if isHovering {
            return isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
        }
        return Color.clear
    }
}

// MARK: - New Setting Section Component

struct SettingSection<Content: View>: View {
    let title: String
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section title
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.Aurora.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)
            
            // Content card with rows
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
    
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    
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
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    
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
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.Aurora.auroraGradient)
                    }
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Aurora.textMuted)
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


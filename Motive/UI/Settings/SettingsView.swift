//
//  SettingsView.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
            
            // Divider
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                .frame(width: 1)
            
            // Content
            contentArea
        }
        .frame(width: 720, height: 520)
        .background(
            isDark
                ? Color(hex: "1C1C1E")
                : Color(hex: "F5F5F7")
        )
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.Velvet.primary, Color.Velvet.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Motive")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Velvet.textPrimary)
                    
                    Text("v0.1.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.Velvet.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
            
            // Navigation
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isDark: isDark
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Divider()
                    .background(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                
                Link(destination: URL(string: "https://github.com/geezerrrr/motive")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "star")
                            .font(.system(size: 12))
                        Text("Star on GitHub")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color.Velvet.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 200)
        .background(
            isDark
                ? Color(hex: "141416")
                : Color.white
        )
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTab.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.Velvet.textPrimary)
                    
                    Text(selectedTab.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color.Velvet.textSecondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 24)
                .padding(.horizontal, 32)
                
                // Content
                selectedTab.contentView
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case model
    case advanced
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .model: return "AI Provider"
        case .advanced: return "Advanced"
        }
    }
    
    var subtitle: String {
        switch self {
        case .general: return "Startup, appearance, and keyboard shortcuts"
        case .model: return "Configure your AI provider and API credentials"
        case .advanced: return "Binary paths and debug options"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .model: return "cpu.fill"
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
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - Navigation Item

private struct SettingsNavItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let isDark: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? Color.Velvet.primary : Color.Velvet.textSecondary)
                    .frame(width: 20)
                
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.Velvet.textPrimary : Color.Velvet.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? (isDark ? Color.white.opacity(0.1) : Color.Velvet.primary.opacity(0.12))
                            : (isHovering ? (isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Settings Card

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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.Velvet.primary)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Velvet.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            // Content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.05) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Settings Row

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
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.Velvet.textPrimary)
                    
                    if let description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(Color.Velvet.textMuted)
                    }
                }
                
                Spacer()
                
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if showDivider {
                Divider()
                    .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Legacy Support (SettingsSection wraps SettingsCard for compatibility)

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

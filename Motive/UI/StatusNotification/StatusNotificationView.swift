//
//  StatusNotificationView.swift
//  Motive
//
//  Aurora Design System - Status Notification Popup
//

import SwiftUI

enum StatusNotificationType {
    case success
    case error
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return Color.Aurora.success
        case .error: return Color.Aurora.error
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .success: return [Color.Aurora.success, Color(hex: "059669")]
        case .error: return [Color.Aurora.error, Color(hex: "DC2626")]
        }
    }
    
    var title: String {
        switch self {
        case .success: return L10n.Drawer.completed
        case .error: return L10n.Drawer.failed
        }
    }
}

struct StatusNotificationView: View {
    let type: StatusNotificationType
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showContent = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        HStack(spacing: AuroraSpacing.space3) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: type.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(0.15)
                    )
                    .frame(width: 28, height: 28)
                
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: type.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(type.title)
                .font(.Aurora.bodySmall.weight(.medium))
                .foregroundColor(Color.Aurora.textPrimary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, AuroraSpacing.space4)
        .padding(.vertical, AuroraSpacing.space3)
        .fixedSize()
        .background(
            ZStack {
                // Blur effect
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                
                // Base color
                Color.Aurora.background.opacity(0.95)
                
                // Subtle gradient tint
                if isDark {
                    LinearGradient(
                        colors: type.gradientColors.map { $0.opacity(0.03) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.md, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 0.5)
        )
        .shadow(color: type.color.opacity(isDark ? 0.15 : 0.1), radius: 16, y: 8)
        .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.1), radius: 12, x: 0, y: 6)
        .scaleEffect(showContent ? 1.0 : 0.9)
        .opacity(showContent ? 1.0 : 0)
        .onAppear {
            withAnimation(.auroraSpring) {
                showContent = true
            }
        }
        .onTapGesture { onDismiss() }
    }
}

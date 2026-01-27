//
//  CommandBarHistoriesView.swift
//  Motive
//
//  Aurora Design System - Histories Command View
//  Raycast-style session list with keyboard navigation
//

import SwiftUI

struct CommandBarHistoriesView: View {
    let sessions: [Session]  // Passed from parent
    @Binding var selectedIndex: Int
    let onSelect: (Session) -> Void
    let onRequestDelete: (Int) -> Void  // Request delete confirmation (don't delete directly)
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: 0) {
            if sessions.isEmpty {
                emptyStateView
            } else {
                sessionListView
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Session List
    
    private var sessionListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        HistoryListItem(
                            session: session,
                            isSelected: index == selectedIndex,
                            onSelect: { onSelect(session) },
                            onRequestDelete: { onRequestDelete(index) }
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, AuroraSpacing.space2)
                .padding(.horizontal, AuroraSpacing.space3)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.auroraFast) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: AuroraSpacing.space4) {
            Image(systemName: "clock")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.Aurora.auroraGradient)
            
            VStack(spacing: AuroraSpacing.space2) {
                Text("No sessions yet")
                    .font(.Aurora.bodySmall.weight(.medium))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text("Your conversation history will appear here")
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History List Item

private struct HistoryListItem: View {
    let session: Session
    let isSelected: Bool
    let onSelect: () -> Void
    let onRequestDelete: () -> Void  // Just request, don't show dialog here
    
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AuroraSpacing.space3) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Content
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    Text(session.intent)
                        .font(.Aurora.bodySmall.weight(.medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: AuroraSpacing.space2) {
                        Text(timeAgo)
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textMuted)
                        
                        if session.logs.count > 0 {
                            Text("•")
                                .font(.Aurora.caption)
                                .foregroundColor(Color.Aurora.textMuted)
                            
                            Text("\(session.logs.count) events")
                                .font(.Aurora.caption)
                                .foregroundColor(Color.Aurora.textMuted)
                        }
                    }
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: AuroraSpacing.space2) {
                    if isHovering || isSelected {
                        // Delete button - just triggers callback, parent handles confirmation
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.Aurora.textMuted)
                            .frame(width: 24, height: 24)
                            .background(Color.Aurora.surface)
                            .clipShape(Circle())
                            .onTapGesture {
                                onRequestDelete()
                            }
                            .transition(.opacity)
                    }
                    
                    if isSelected {
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                }
            }
            .padding(.horizontal, AuroraSpacing.space3)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(isSelected ? Color.Aurora.accent.opacity(0.1) : (isHovering ? Color.Aurora.surfaceElevated : Color.clear))
            )
            .overlay(
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
        .animation(.auroraFast, value: isHovering)
    }
    
    private var statusColor: Color {
        switch session.status {
        case "running":
            return Color.Aurora.accent
        case "completed":
            return Color.Aurora.accent  // Use accent for completed (monochrome theme)
        case "failed":
            return Color.Aurora.error
        default:
            return Color.Aurora.textMuted
        }
    }
    
    private var timeAgo: String {
        let now = Date()
        let diff = now.timeIntervalSince(session.createdAt)
        
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 604800 { return "\(Int(diff / 86400))d ago" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: session.createdAt)
    }
}

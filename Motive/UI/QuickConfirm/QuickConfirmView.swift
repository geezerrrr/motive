//
//  QuickConfirmView.swift
//  Motive
//
//  Aurora Design System - Quick Confirm Popup
//

import SwiftUI

struct QuickConfirmView: View {
    let request: PermissionRequest
    let onResponse: (String) -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedOptions: Set<String> = []
    @State private var textInput: String = ""
    @State private var isHovering: Bool = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
            // Header
            headerView
            
            // Content based on request type
            contentView
            
            // Actions
            actionButtons
        }
        .padding(AuroraSpacing.space4)
        .frame(width: 340)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 0.5)
        )
        .shadow(color: Color.Aurora.accentMid.opacity(isDark ? 0.1 : 0.05), radius: 20, y: 8)
        .shadow(color: Color.black.opacity(isDark ? 0.3 : 0.12), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: AuroraSpacing.space3) {
            // Icon with gradient
            ZStack {
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(0.15)
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: AuroraSpacing.space0_5) {
                Text(headerTitle)
                    .font(.Aurora.bodySmall.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                if let subtitle = headerSubtitle {
                    Text(subtitle)
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Close button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.Aurora.textMuted)
                    .frame(width: 22, height: 22)
                    .background(Color.Aurora.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        switch request.type {
        case .question:
            questionContent
        case .file:
            filePermissionContent
        case .tool:
            toolPermissionContent
        }
    }
    
    private var questionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
            // Question text
            if let question = request.question {
                Text(question)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Options or text input
            if let options = request.options, !options.isEmpty {
                optionsView(options: options)
            } else {
                // Free text input
                TextField("Type your answer...", text: $textInput)
                    .textFieldStyle(.plain)
                    .font(.Aurora.bodySmall)
                    .padding(AuroraSpacing.space3)
                    .background(Color.Aurora.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                            .stroke(Color.Aurora.border, lineWidth: 0.5)
                    )
            }
        }
    }
    
    private func optionsView(options: [PermissionRequest.QuestionOption]) -> some View {
        VStack(spacing: AuroraSpacing.space2) {
            ForEach(options, id: \.effectiveValue) { option in
                optionButton(option: option)
            }
        }
    }
    
    private func optionButton(option: PermissionRequest.QuestionOption) -> some View {
        let optionValue = option.effectiveValue
        let isSelected = selectedOptions.contains(optionValue)
        let isMultiSelect = request.multiSelect == true
        
        return Button {
            if isMultiSelect {
                if isSelected {
                    selectedOptions.remove(optionValue)
                } else {
                    selectedOptions.insert(optionValue)
                }
            } else {
                onResponse(optionValue)
            }
        } label: {
            HStack(spacing: AuroraSpacing.space3) {
                if isMultiSelect {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? AnyShapeStyle(Color.Aurora.auroraGradient) : AnyShapeStyle(Color.Aurora.textSecondary))
                }
                
                Text(option.label)
                    .font(.Aurora.bodySmall.weight(isSelected ? .medium : .regular))
                    .foregroundColor(Color.Aurora.textPrimary)
                  
                Spacer()
                
                if !isMultiSelect {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.Aurora.textMuted)
                }
            }
            .padding(.horizontal, AuroraSpacing.space3)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(isSelected ? Color.Aurora.accent.opacity(0.08) : Color.Aurora.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(isSelected ? Color.Aurora.accent.opacity(0.2) : Color.Aurora.border, lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var filePermissionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            // Operation description
            HStack(spacing: AuroraSpacing.space2) {
                Text(operationVerb)
                    .font(.Aurora.bodySmall.weight(.medium))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                if let path = request.filePath {
                    Text(shortenPath(path))
                        .font(.Aurora.monoSmall)
                        .foregroundColor(Color.Aurora.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            // Preview if available
            if let preview = request.contentPreview, !preview.isEmpty {
                ScrollView {
                    Text(preview)
                        .font(.Aurora.monoSmall)
                        .foregroundColor(Color.Aurora.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
                .padding(AuroraSpacing.space2)
                .background(Color.Aurora.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous))
            }
        }
    }
    
    private var toolPermissionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            if let toolName = request.toolName {
                HStack(spacing: AuroraSpacing.space2) {
                    Text("Tool:")
                        .font(.Aurora.bodySmall)
                        .foregroundColor(Color.Aurora.textSecondary)
                    
                    Text(toolName.simplifiedToolName)
                        .font(.Aurora.mono.weight(.medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        switch request.type {
        case .question:
            if request.multiSelect == true || request.options == nil {
                HStack(spacing: AuroraSpacing.space2) {
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(AuroraQuickConfirmButtonStyle(style: .secondary))
                    
                    Button("Confirm") {
                        if request.options != nil {
                            onResponse(selectedOptions.joined(separator: ","))
                        } else {
                            onResponse(textInput)
                        }
                    }
                    .buttonStyle(AuroraQuickConfirmButtonStyle(style: .primary))
                    .disabled(request.options != nil ? selectedOptions.isEmpty : textInput.isEmpty)
                }
            }
            
        case .file, .tool:
            HStack(spacing: AuroraSpacing.space2) {
                Spacer()
                
                Button(L10n.deny) {
                    onResponse("denied")
                }
                .buttonStyle(AuroraQuickConfirmButtonStyle(style: .secondary))
                
                Button(L10n.allow) {
                    onResponse("approved")
                }
                .buttonStyle(AuroraQuickConfirmButtonStyle(style: .primary))
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Blur effect
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            
            // Base overlay
            Color.Aurora.background.opacity(0.95)
            
            // Subtle gradient
            if isDark {
                LinearGradient(
                    colors: [
                        Color.Aurora.accentMid.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private var iconName: String {
        switch request.type {
        case .question: return "hand.raised"
        case .file: return "doc.badge.gearshape"
        case .tool: return "hand.raised"
        }
    }
    
    private var iconGradientColors: [Color] {
        switch request.type {
        case .question: return Color.Aurora.auroraGradientColors
        case .file: return [Color.Aurora.warning, Color(hex: "F97316")]
        case .tool: return [Color.Aurora.accentMid, Color.Aurora.accentEnd]
        }
    }
    
    private var headerTitle: String {
        switch request.type {
        case .question:
            return request.header ?? "Question"
        case .file:
            return "File Permission"
        case .tool:
            return "Tool Permission"
        }
    }
    
    private var headerSubtitle: String? {
        switch request.type {
        case .question:
            return nil
        case .file:
            return request.fileOperation?.rawValue.capitalized
        case .tool:
            return request.toolName?.simplifiedToolName
        }
    }
    
    private var operationVerb: String {
        guard let op = request.fileOperation else { return "Access" }
        switch op {
        case .create: return "Create"
        case .delete: return "Delete"
        case .rename: return "Rename"
        case .move: return "Move"
        case .modify: return "Modify"
        case .overwrite: return "Overwrite"
        case .readBinary: return "Read"
        case .execute: return "Execute"
        }
    }
    
    private func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 3 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

// MARK: - Aurora Quick Confirm Button Style

private struct AuroraQuickConfirmButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }
    
    let style: Style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.Aurora.bodySmall.weight(.medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space2)
            .background(background(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
            .overlay(overlay)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.auroraSpringStiff, value: configuration.isPressed)
    }
    
    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: Color.Aurora.auroraGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(isPressed ? 0.8 : 1.0)
        case .secondary:
            Color.Aurora.surface
                .opacity(isPressed ? 0.8 : 1.0)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.Aurora.textPrimary
        }
    }
    
    @ViewBuilder
    private var overlay: some View {
        if style == .secondary {
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 1)
        }
    }
}

// MARK: - Visual Effect (Legacy compatibility)

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Legacy Button Style (compatibility)

struct QuickConfirmButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.Aurora.bodySmall.weight(.medium))
            .foregroundColor(isPrimary ? .white : Color.Aurora.textPrimary)
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space2)
            .background(
                isPrimary
                    ? AnyShapeStyle(Color.Aurora.auroraGradient)
                    : AnyShapeStyle(Color.Aurora.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
            .overlay(
                !isPrimary
                    ? RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                        .stroke(Color.Aurora.border, lineWidth: 1)
                    : nil
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

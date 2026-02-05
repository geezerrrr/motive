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
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView
            Divider()
            contentView
            Divider()
            actionButtons
        }
        .padding(20)
        .frame(width: 360)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.12), radius: 18, y: 10)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.Aurora.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                if let subtitle = headerSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.cancel)
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
                    .font(.system(size: 13))
                    .foregroundColor(Color.Aurora.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Options or text input
            if let options = request.options, !options.isEmpty {
                optionsView(options: options)
            } else {
                // Free text input
                AuroraStyledTextField(
                    placeholder: "Type your answer...",
                    text: $textInput
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
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? Color.Aurora.primary : Color.Aurora.textSecondary)
                }
                
                Text(option.label)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
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
                    .fill(isSelected ? Color.Aurora.primary.opacity(0.1) : Color.Aurora.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(isSelected ? Color.Aurora.primary.opacity(0.3) : Color.Aurora.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var filePermissionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            // Operation description
            HStack(spacing: AuroraSpacing.space2) {
                Text(operationVerb)
                    .font(.system(size: 13, weight: .medium))
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
                        .font(.system(size: 12))
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
                    
                    Button(L10n.cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(L10n.submit) {
                        if request.options != nil {
                            onResponse(selectedOptions.joined(separator: ","))
                        } else {
                            onResponse(textInput)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Aurora.primary)
                    .controlSize(.small)
                    .disabled(request.options != nil ? selectedOptions.isEmpty : textInput.isEmpty)
                }
            }
            
        case .file, .tool:
            HStack(spacing: AuroraSpacing.space2) {
                Spacer()
                
                Button(L10n.deny) {
                    onResponse("denied")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(L10n.allow) {
                    onResponse("approved")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Aurora.primary)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
            Color.Aurora.background.opacity(0.92)
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

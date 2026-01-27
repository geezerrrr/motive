//
//  PermissionRequestView.swift
//  Motive
//
//  Aurora Design System - Permission Request Modal
//

import SwiftUI

struct PermissionRequestView: View {
    let request: PermissionRequest
    let onRespond: (PermissionResponse) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedOptions: Set<String> = []
    @State private var customResponse: String = ""
    @State private var showCustomInput: Bool = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(spacing: 0) {
            // Backdrop
            Color.black.opacity(isDark ? 0.5 : 0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    respond(allowed: false)
                }
            
            // Modal Card
            VStack(alignment: .leading, spacing: AuroraSpacing.space4) {
                // Header
                HStack(alignment: .top, spacing: AuroraSpacing.space3) {
                    // Icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: iconGradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ).opacity(0.15)
                            )
                            .frame(width: 44, height: 44)
                        
                        iconImage
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: iconGradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                        Text(headerTitle)
                            .font(.Aurora.headline)
                            .foregroundColor(Color.Aurora.textPrimary)
                        
                        requestContent
                    }
                }
                
                // Action Buttons
                HStack(spacing: AuroraSpacing.space3) {
                    Button(action: { respond(allowed: false) }) {
                        Text(denyButtonText)
                            .font(.Aurora.bodySmall.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AuroraSpacing.space3)
                    }
                    .buttonStyle(AuroraPermissionButtonStyle(style: .secondary))
                    
                    Button(action: { respond(allowed: true) }) {
                        Text(allowButtonText)
                            .font(.Aurora.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AuroraSpacing.space3)
                    }
                    .buttonStyle(AuroraPermissionButtonStyle(style: request.isDeleteOperation ? .danger : .primary))
                    .disabled(isAllowDisabled)
                }
            }
            .padding(AuroraSpacing.space5)
            .background(Color.Aurora.background)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
            .shadow(color: Color.Aurora.accentMid.opacity(isDark ? 0.1 : 0.05), radius: 30, y: 10)
            .shadow(color: Color.black.opacity(isDark ? 0.3 : 0.15), radius: 20, y: 10)
            .padding(AuroraSpacing.space8)
        }
        .onAppear {
            if request.type == .question,
               (request.options?.isEmpty ?? true) {
                showCustomInput = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var headerTitle: String {
        if request.isDeleteOperation {
            return "File Deletion Warning"
        }
        
        switch request.type {
        case .file:
            return "File Permission Required"
        case .question:
            return request.header ?? "Question"
        case .tool:
            return "Permission Required"
        }
    }
    
    private var iconGradientColors: [Color] {
        if request.isDeleteOperation {
            return [Color.Aurora.error, Color.Aurora.warning]
        }
        
        switch request.type {
        case .file:
            return [Color.Aurora.warning, Color(hex: "F97316")]
        case .question:
            return Color.Aurora.auroraGradientColors
        case .tool:
            return [Color.Aurora.accentMid, Color.Aurora.accentEnd]
        }
    }
    
    private var iconImage: Image {
        if request.isDeleteOperation {
            return Image(systemName: "exclamationmark.triangle.fill")
        }
        
        switch request.type {
        case .file:
            return Image(systemName: "doc.fill")
        case .question:
            return Image(systemName: "hand.raised.fill")
        case .tool:
            return Image(systemName: "hand.raised.fill")
        }
    }
    
    private var denyButtonText: String {
        request.type == .question ? "Cancel" : "Deny"
    }
    
    private var allowButtonText: String {
        if request.isDeleteOperation {
            return request.displayFilePaths.count > 1 ? "Delete All" : "Delete"
        }
        return request.type == .question ? "Submit" : "Allow"
    }
    
    private var isAllowDisabled: Bool {
        if request.type == .question,
           !showCustomInput,
           let options = request.options,
           !options.isEmpty {
            return selectedOptions.isEmpty
        }
        return false
    }
    
    // MARK: - Request Content
    
    @ViewBuilder
    private var requestContent: some View {
        switch request.type {
        case .file:
            filePermissionContent
        case .question:
            questionContent
        case .tool:
            toolContent
        }
    }
    
    @ViewBuilder
    private var filePermissionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
            // Delete warning banner
            if request.isDeleteOperation {
                HStack {
                    Text(request.displayFilePaths.count > 1
                         ? "\(request.displayFilePaths.count) files will be permanently deleted:"
                         : "This file will be permanently deleted:")
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.error)
                }
                .padding(AuroraSpacing.space2)
                .background(Color.Aurora.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous))
            } else if let operation = request.fileOperation {
                Text(operation.rawValue.uppercased())
                    .font(.Aurora.micro.weight(.bold))
                    .foregroundColor(Color.Aurora.accent)
                    .padding(.horizontal, AuroraSpacing.space2)
                    .padding(.vertical, AuroraSpacing.space1)
                    .background(Color.Aurora.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous))
            }
            
            // File paths
            VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                ForEach(request.displayFilePaths, id: \.self) { path in
                    Text(request.displayFilePaths.count > 1 ? "• \(path)" : path)
                        .font(.Aurora.monoSmall)
                        .foregroundColor(Color.Aurora.textPrimary)
                }
                
                if let targetPath = request.targetPath {
                    Text("→ \(targetPath)")
                        .font(.Aurora.monoSmall)
                        .foregroundColor(Color.Aurora.textSecondary)
                }
            }
            .padding(AuroraSpacing.space3)
            .background(Color.Aurora.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 0.5)
            )
            
            if request.isDeleteOperation {
                Text("This action cannot be undone.")
                    .font(.Aurora.caption)
                    .foregroundColor(Color.Aurora.textMuted)
            }
            
            // Content preview
            if let preview = request.contentPreview {
                DisclosureGroup("Preview content") {
                    ScrollView {
                        Text(preview)
                            .font(.Aurora.monoSmall)
                            .foregroundColor(Color.Aurora.textSecondary)
                    }
                    .frame(maxHeight: 100)
                }
                .font(.Aurora.caption)
                .foregroundColor(Color.Aurora.textSecondary)
            }
        }
    }
    
    @ViewBuilder
    private var questionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
            if let question = request.question {
                Text(question)
                    .font(.Aurora.body)
                    .foregroundColor(Color.Aurora.textPrimary)
            }
            
            if showCustomInput {
                VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                    TextField("Type your response...", text: $customResponse)
                        .textFieldStyle(AuroraModernTextFieldStyle())
                        .onSubmit {
                            if !customResponse.trimmingCharacters(in: .whitespaces).isEmpty {
                                respond(allowed: true)
                            }
                        }
                    
                    if request.options != nil && !request.options!.isEmpty {
                        Button("← Back to options") {
                            showCustomInput = false
                            customResponse = ""
                        }
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textSecondary)
                    }
                }
            } else if let options = request.options, !options.isEmpty {
                VStack(spacing: AuroraSpacing.space2) {
                    ForEach(options, id: \.label) { option in
                        AuroraOptionButton(
                            option: option,
                            isSelected: selectedOptions.contains(option.label),
                            isMultiSelect: request.multiSelect == true
                        ) {
                            if option.label.lowercased() == "other" {
                                showCustomInput = true
                                selectedOptions.removeAll()
                            } else if request.multiSelect == true {
                                if selectedOptions.contains(option.label) {
                                    selectedOptions.remove(option.label)
                                } else {
                                    selectedOptions.insert(option.label)
                                }
                            } else {
                                selectedOptions = [option.label]
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var toolContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            if let toolName = request.toolName {
                Text("Allow \(toolName.simplifiedToolName)?")
                    .font(.Aurora.body)
                    .foregroundColor(Color.Aurora.textSecondary)
                
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    Text("Tool: \(toolName.simplifiedToolName)")
                        .font(.Aurora.caption)
                        .foregroundColor(Color.Aurora.textSecondary)
                    
                    if let input = request.toolInput {
                        ScrollView {
                            Text(formatToolInput(input))
                                .font(.Aurora.monoSmall)
                                .foregroundColor(Color.Aurora.textPrimary)
                        }
                        .frame(maxHeight: 100)
                    }
                }
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
    
    // MARK: - Helpers
    
    private func formatToolInput(_ input: [String: Any]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: input, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: input)
    }
    
    private func respond(allowed: Bool) {
        var response = PermissionResponse(
            requestId: request.id,
            taskId: request.taskId,
            decision: allowed ? .allow : .deny
        )
        
        if request.type == .question {
            if showCustomInput && !customResponse.trimmingCharacters(in: .whitespaces).isEmpty {
                response.customText = customResponse.trimmingCharacters(in: .whitespaces)
            } else if !selectedOptions.isEmpty {
                response.selectedOptions = Array(selectedOptions)
            }
        }
        
        onRespond(response)
    }
}

// MARK: - Aurora Option Button

private struct AuroraOptionButton: View {
    let option: PermissionRequest.QuestionOption
    let isSelected: Bool
    let isMultiSelect: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: AuroraSpacing.space1) {
                    Text(option.label)
                        .font(.Aurora.body.weight(.medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                    
                    if let desc = option.description {
                        Text(desc)
                            .font(.Aurora.caption)
                            .foregroundColor(Color.Aurora.textSecondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.Aurora.auroraGradient)
                }
            }
            .padding(AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(isSelected ? Color.Aurora.accent.opacity(0.1) : (isHovering ? Color.Aurora.surfaceElevated : Color.Aurora.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.Aurora.accent.opacity(0.3)
                            : Color.Aurora.border,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Aurora Permission Button Style

private struct AuroraPermissionButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary, danger
    }
    
    let style: Style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(background(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
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
        case .danger:
            LinearGradient(
                colors: [Color.Aurora.error, Color(hex: "DC2626")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(isPressed ? 0.8 : 1.0)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .danger: return .white
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

// MARK: - Preview

#Preview {
    PermissionRequestView(
        request: PermissionRequest(
            id: "test",
            taskId: "task_1",
            type: .file,
            fileOperation: .delete,
            filePath: "/Users/test/Documents/important.txt"
        ),
        onRespond: { _ in }
    )
    .frame(width: 500, height: 400)
}

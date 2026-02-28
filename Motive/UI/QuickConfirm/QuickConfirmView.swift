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
    let onPreviewPlan: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedOptions: Set<String> = []
    @State private var textInput: String = ""
    @State private var showCustomInput: Bool = false
    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space3 + 2) {
            headerView
            Rectangle()
                .fill(AuroraPromptStyle.dividerColor)
                .frame(height: AuroraPromptStyle.subtleBorderWidth)
            contentView
            Rectangle()
                .fill(AuroraPromptStyle.dividerColor)
                .frame(height: AuroraPromptStyle.subtleBorderWidth)
            actionButtons
        }
        .padding(AuroraSpacing.space5)
        .frame(minWidth: 360, idealWidth: 400, maxWidth: 520)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous)
                .strokeBorder(AuroraPromptStyle.borderColor, lineWidth: AuroraPromptStyle.borderWidth)
        )
        .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.12), radius: 18, y: 10)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.Aurora.body.weight(.semibold))
                .foregroundColor(request.isPlanExitConfirmation ? Color.Aurora.success : Color.Aurora.microAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.Aurora.bodySmall.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)

                if let subtitle = headerSubtitle {
                    Text(subtitle)
                        .font(.Aurora.caption.weight(.regular))
                        .foregroundColor(Color.Aurora.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Close button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.Aurora.micro.weight(.medium))
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
        case .permission:
            permissionContent
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
                if request.isPlanExitConfirmation, let onPreviewPlan {
                    Button(action: onPreviewPlan) {
                        HStack(spacing: AuroraSpacing.space2) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.Aurora.micro.weight(.bold))
                            Text("drawer.preview_plan".localized)
                                .font(.Aurora.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.Aurora.micro.weight(.medium))
                        }
                        .foregroundColor(Color.Aurora.textSecondary)
                        .padding(.horizontal, AuroraSpacing.space3)
                        .padding(.vertical, AuroraSpacing.space2)
                        .background(
                            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                                .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                                .stroke(AuroraPromptStyle.subtleBorderColor, lineWidth: AuroraPromptStyle.subtleBorderWidth)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("drawer.preview_plan".localized)
                    .accessibilityHint("drawer.preview_plan_hint".localized)
                }

                optionsView(options: options)

                if showCustomInput {
                    AuroraStyledTextField(
                        placeholder: L10n.Permission.typeAnswer,
                        text: $textInput
                    )
                    .onSubmit {
                        let trimmed = textInput.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { onResponse(trimmed) }
                    }
                }
            } else {
                // Free text input (no options at all)
                AuroraStyledTextField(
                    placeholder: L10n.Permission.typeAnswer,
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

    // swiftlint:disable function_body_length
    private func optionButton(option: PermissionRequest.QuestionOption) -> some View {
        let optionValue = option.effectiveValue
        let isSelected = selectedOptions.contains(optionValue)
        let isMultiSelect = request.multiSelect == true

        // Plan exit: "Execute Plan" gets prominent green styling
        let isPlanExecute = request.isPlanExitConfirmation && option.label == "Execute Plan"
        let accentColor = isPlanExecute ? Color.Aurora.success : Color.Aurora.microAccent

        return Button {
            if option.label.lowercased() == "other" {
                showCustomInput.toggle()
            } else if isMultiSelect {
                if isSelected {
                    selectedOptions.remove(optionValue)
                } else {
                    selectedOptions.insert(optionValue)
                }
                showCustomInput = false
            } else {
                onResponse(optionValue)
            }
        } label: {
            HStack(spacing: AuroraSpacing.space3) {
                if isMultiSelect {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.Aurora.bodySmall)
                        .foregroundColor(isSelected ? accentColor : Color.Aurora.textSecondary)
                }

                if isPlanExecute {
                    Image(systemName: "play.fill")
                        .font(.Aurora.micro.weight(.bold))
                        .foregroundColor(Color.Aurora.success)
                }

                Text(option.label)
                    .font(.Aurora.bodySmall.weight(isPlanExecute || isSelected ? .semibold : .regular))
                    .foregroundColor(isPlanExecute ? Color.Aurora.success : Color.Aurora.textPrimary)

                Spacer()

                if !isMultiSelect {
                    Image(systemName: isPlanExecute ? "arrow.right" : "chevron.right")
                        .font(.Aurora.micro.weight(.medium))
                        .foregroundColor(isPlanExecute ? Color.Aurora.success : Color.Aurora.textMuted)
                }
            }
            .padding(.horizontal, AuroraSpacing.space3)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(
                        isPlanExecute
                            ? Color.Aurora.success.opacity(0.1)
                            : (isSelected ? accentColor.opacity(0.1) : Color.Aurora.glassOverlay.opacity(0.06))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(
                        isPlanExecute
                            ? Color.Aurora.success.opacity(0.4)
                            : (isSelected ? accentColor.opacity(0.3) : AuroraPromptStyle.subtleBorderColor),
                        lineWidth: isPlanExecute ? AuroraPromptStyle.emphasisBorderWidth : AuroraPromptStyle.subtleBorderWidth
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityHint(isMultiSelect ? "Toggle option selection" : "Select and submit this option")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    // swiftlint:enable function_body_length

    private var permissionContent: some View {
        VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
            // Permission type (e.g., "edit", "bash")
            if let permType = request.permissionType {
                HStack(spacing: AuroraSpacing.space2) {
                    Text(L10n.Permission.permissionLabel)
                        .font(.Aurora.caption.weight(.regular))
                        .foregroundColor(Color.Aurora.textSecondary)

                    Text(permType.capitalized)
                        .font(.Aurora.mono.weight(.medium))
                        .foregroundColor(Color.Aurora.textPrimary)
                }
            }

            // File paths / patterns
            if let patterns = request.patterns, !patterns.isEmpty {
                HStack(spacing: AuroraSpacing.space2) {
                    Text(patterns.count == 1 ? L10n.Permission.pathLabel : L10n.Permission.pathsLabel)
                        .font(.Aurora.caption.weight(.regular))
                        .foregroundColor(Color.Aurora.textSecondary)

                    Text(patterns.map { shortenPath($0) }.joined(separator: ", "))
                        .font(.Aurora.monoSmall)
                        .foregroundColor(Color.Aurora.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            // Diff preview if available
            if let diff = request.diff, !diff.isEmpty {
                DiffView(diff: diff)
                    .frame(maxHeight: 160)
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch request.type {
        case .question:
            if request.multiSelect == true || request.options == nil || showCustomInput {
                HStack(spacing: AuroraSpacing.space2) {
                    Spacer()

                    Button(L10n.cancel) {
                        if showCustomInput, request.multiSelect != true {
                            showCustomInput = false
                            textInput = ""
                        } else {
                            onCancel()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(L10n.submit) {
                        if showCustomInput, !textInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            onResponse(textInput.trimmingCharacters(in: .whitespaces))
                        } else if request.options != nil {
                            onResponse(selectedOptions.joined(separator: ","))
                        } else {
                            onResponse(textInput)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Aurora.microAccent)
                    .controlSize(.small)
                    .disabled(submitDisabled)
                    .accessibilityHint("Submit the current answer")
                }
            }

        case .permission:
            HStack(spacing: AuroraSpacing.space2) {
                Spacer()

                Button(L10n.reject) {
                    onResponse("Reject")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(L10n.allowOnce) {
                    onResponse("Allow Once")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Aurora.microAccent)
                .controlSize(.small)
                .accessibilityHint("Allow this action once")

                Button(L10n.alwaysAllow) {
                    onResponse("Always Allow")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Aurora.success)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow, state: .active)
            Color.Aurora.background.opacity(isDark ? 0.6 : 0.7)
        }
    }

    // MARK: - Helpers

    private var iconName: String {
        if request.isPlanExitConfirmation {
            return "doc.badge.gearshape"
        }
        switch request.type {
        case .question: return "hand.raised"
        case .permission: return "lock.shield"
        }
    }

    private var headerTitle: String {
        switch request.type {
        case .question:
            request.header ?? L10n.Permission.question
        case .permission:
            L10n.Permission.permissionRequired
        }
    }

    private var headerSubtitle: String? {
        if let intent = request.sessionIntent, !intent.isEmpty {
            let truncated = intent.count > 40 ? String(intent.prefix(40)) + "…" : intent
            return "From: \(truncated)"
        }
        switch request.type {
        case .question:
            return nil
        case .permission:
            return request.permissionType?.capitalized
        }
    }

    private var submitDisabled: Bool {
        if showCustomInput {
            textInput.trimmingCharacters(in: .whitespaces).isEmpty
        } else if request.options != nil {
            selectedOptions.isEmpty
        } else {
            textInput.isEmpty
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
        case .primary: .white
        case .secondary: Color.Aurora.textPrimary
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if style == .secondary {
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .stroke(AuroraPromptStyle.borderColor, lineWidth: AuroraPromptStyle.borderWidth)
        }
    }
}

// MARK: - Diff View

/// Renders a unified diff with red/green colored lines like GitHub/Cursor.
struct DiffView: View {
    let diff: String
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var parsedLines: [DiffLine] {
        DiffParser.parse(diff)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                    diffLineView(line)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous)
                .fill(Color.Aurora.surfaceElevated.opacity(isDark ? 0.6 : 0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous)
                .stroke(AuroraPromptStyle.subtleBorderColor, lineWidth: AuroraPromptStyle.subtleBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.xs, style: .continuous))
    }

    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Line number gutter
            HStack(spacing: 2) {
                Text(line.oldLineNumber ?? "")
                    .frame(width: 28, alignment: .trailing)
                Text(line.newLineNumber ?? "")
                    .frame(width: 28, alignment: .trailing)
            }
            .font(.Aurora.micro.weight(.regular))
            .foregroundColor(Color.Aurora.textMuted.opacity(0.6))
            .padding(.trailing, 4)

            // Prefix character (+, -, space)
            Text(line.prefix)
                .font(.Aurora.micro.weight(.medium))
                .foregroundColor(line.prefixColor(isDark: isDark))
                .frame(width: 12)

            // Content
            Text(line.content)
                .font(.Aurora.monoSmall)
                .foregroundColor(line.textColor(isDark: isDark))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(line.backgroundColor(isDark: isDark))
    }
}

// MARK: - Diff Parser

enum DiffLineType: Sendable {
    case addition
    case deletion
    case context
    case header // @@ ... @@ or diff --git lines
    case meta // --- or +++ lines
}

struct DiffLine: Sendable {
    let type: DiffLineType
    let content: String
    let prefix: String
    let oldLineNumber: String?
    let newLineNumber: String?

    func backgroundColor(isDark: Bool) -> Color {
        switch type {
        case .addition:
            if isDark {
                Color(red: 0.1, green: 0.3, blue: 0.1).opacity(0.5)
            } else {
                Color(red: 0.85, green: 1.0, blue: 0.85)
            }
        case .deletion:
            if isDark {
                Color(red: 0.35, green: 0.1, blue: 0.1).opacity(0.5)
            } else {
                Color(red: 1.0, green: 0.9, blue: 0.9)
            }
        case .header, .meta:
            if isDark {
                Color(red: 0.15, green: 0.2, blue: 0.35).opacity(0.4)
            } else {
                Color(red: 0.92, green: 0.95, blue: 1.0)
            }
        case .context:
            .clear
        }
    }

    func textColor(isDark: Bool) -> Color {
        switch type {
        case .addition:
            if isDark {
                Color(red: 0.5, green: 0.9, blue: 0.5)
            } else {
                Color(red: 0.1, green: 0.5, blue: 0.1)
            }
        case .deletion:
            if isDark {
                Color(red: 0.95, green: 0.5, blue: 0.5)
            } else {
                Color(red: 0.6, green: 0.1, blue: 0.1)
            }
        case .header, .meta:
            if isDark {
                Color(red: 0.5, green: 0.7, blue: 1.0)
            } else {
                Color(red: 0.2, green: 0.3, blue: 0.6)
            }
        case .context:
            if isDark {
                Color(white: 0.7)
            } else {
                Color(white: 0.3)
            }
        }
    }

    func prefixColor(isDark: Bool) -> Color {
        switch type {
        case .addition:
            if isDark {
                Color(red: 0.3, green: 0.9, blue: 0.3)
            } else {
                Color(red: 0.1, green: 0.6, blue: 0.1)
            }
        case .deletion:
            if isDark {
                Color(red: 0.95, green: 0.35, blue: 0.35)
            } else {
                Color(red: 0.7, green: 0.1, blue: 0.1)
            }
        default:
            .clear
        }
    }
}

enum DiffParser {
    /// Parse a unified diff string into typed lines with line numbers.
    static func parse(_ diff: String) -> [DiffLine] {
        let rawLines = diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        for raw in rawLines {
            if raw.hasPrefix("@@") {
                // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
                let numbers = parseHunkHeader(raw)
                oldLine = numbers.oldStart
                newLine = numbers.newStart
                result.append(DiffLine(type: .header, content: raw, prefix: "", oldLineNumber: nil, newLineNumber: nil))
            } else if raw.hasPrefix("diff ") || raw.hasPrefix("index ") {
                result.append(DiffLine(type: .header, content: raw, prefix: "", oldLineNumber: nil, newLineNumber: nil))
            } else if raw.hasPrefix("---") || raw.hasPrefix("+++") {
                result.append(DiffLine(type: .meta, content: raw, prefix: "", oldLineNumber: nil, newLineNumber: nil))
            } else if raw.hasPrefix("+") {
                let content = String(raw.dropFirst())
                result.append(DiffLine(type: .addition, content: content, prefix: "+", oldLineNumber: nil, newLineNumber: "\(newLine)"))
                newLine += 1
            } else if raw.hasPrefix("-") {
                let content = String(raw.dropFirst())
                result.append(DiffLine(type: .deletion, content: content, prefix: "-", oldLineNumber: "\(oldLine)", newLineNumber: nil))
                oldLine += 1
            } else {
                // Context line (starts with space or is empty)
                let content = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
                result.append(DiffLine(type: .context, content: content, prefix: " ", oldLineNumber: "\(oldLine)", newLineNumber: "\(newLine)"))
                oldLine += 1
                newLine += 1
            }
        }

        return result
    }

    /// Parse @@ -start,count +start,count @@ into start values.
    private static func parseHunkHeader(_ header: String) -> (oldStart: Int, newStart: Int) {
        // Matches: @@ -10,5 +10,8 @@
        let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header))
        else {
            return (1, 1)
        }
        let oldStart = Int(header[Range(match.range(at: 1), in: header)!]) ?? 1
        let newStart = Int(header[Range(match.range(at: 2), in: header)!]) ?? 1
        return (oldStart, newStart)
    }
}

//
//  PlanPreviewView.swift
//  Motive
//

import MarkdownUI
import SwiftUI

struct PlanPreviewView: View {
    let planFilePath: String
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var markdownContent = ""
    @State private var loadError: String?

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.Aurora.border)
            content
            Divider().background(Color.Aurora.border)
            footer
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear(perform: loadContent)
    }

    private var header: some View {
        HStack(spacing: AuroraSpacing.space3) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.Aurora.body.weight(.semibold))
                .foregroundColor(Color.Aurora.microAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Drawer.planPreview)
                    .font(.Aurora.bodySmall.weight(.semibold))
                    .foregroundColor(Color.Aurora.textPrimary)
                Text(planFilePath)
                    .font(.Aurora.monoSmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.Aurora.micro.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.Aurora.textMuted)
            .accessibilityLabel(L10n.Drawer.close)
        }
        .padding(AuroraSpacing.space4)
        .background(Color.Aurora.background.opacity(isDark ? 0.4 : 0.7))
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuroraSpacing.space3) {
                if let loadError {
                    Text(loadError)
                        .font(.Aurora.bodySmall)
                        .foregroundColor(Color.Aurora.error)
                        .textSelection(.enabled)
                } else {
                    Markdown(markdownContent)
                        .markdownTextStyle {
                            FontSize(13)
                            ForegroundColor(Color.Aurora.textPrimary)
                        }
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AuroraSpacing.space4)
        }
        .background(Color.Aurora.background.opacity(isDark ? 0.25 : 0.45))
    }

    private var footer: some View {
        HStack {
            Button(L10n.Drawer.reloadPlanPreview) {
                loadContent()
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.Aurora.textSecondary)

            Spacer()

            Button(L10n.done) {
                onClose()
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.Aurora.microAccent)
        }
        .padding(AuroraSpacing.space4)
        .background(Color.Aurora.background.opacity(isDark ? 0.35 : 0.6))
    }

    private func loadContent() {
        do {
            markdownContent = try String(contentsOfFile: planFilePath, encoding: .utf8)
            loadError = nil
        } catch {
            loadError = String(format: L10n.Drawer.planPreviewLoadFailed, error.localizedDescription)
        }
    }
}

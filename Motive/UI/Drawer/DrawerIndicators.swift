//
//  DrawerIndicators.swift
//  Motive
//
//  Aurora Design System - Drawer Components
//

import SwiftUI

// MARK: - Tool Running Indicator (small spinner for tool bubble)

struct ToolRunningIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "arrow.trianglehead.2.counterclockwise")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.Aurora.primary)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        // Metallic shimmer text — matches menu bar animation style.
        ShimmerText(
            text: L10n.Drawer.thinking,
            font: .Aurora.caption.weight(.medium)
        )
        .padding(.horizontal, AuroraSpacing.space3)
        .padding(.vertical, AuroraSpacing.space2)
        .background(
            RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                .fill(Color.Aurora.glassOverlay.opacity(isDark ? 0.06 : 0.08))
        )
    }
}

// MARK: - Aurora Loading Dots

struct AuroraLoadingDots: View {
    @State private var animationPhase: Int = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0 ..< 3) { index in
                Circle()
                    .fill(Color.Aurora.primary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animationPhase == index ? 1.3 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.4)
            }
        }
        .onAppear {
            animationTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animationPhase = (animationPhase + 1) % 3
                    }
                }
            }
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }
}

// MARK: - Shimmer Text (thin wrapper over AuroraShimmer)

struct ShimmerText: View {
    let text: String
    var font: Font = .Aurora.micro.weight(.semibold)
    var baseColor: Color = .Aurora.textSecondary

    var body: some View {
        MetallicShimmerText(
            text: text,
            font: font,
            baseColor: baseColor,
            isActive: true
        )
    }
}

// MARK: - Transient Reasoning Bubble

/// A standalone bubble that shows live reasoning text during the thinking phase.
/// This is NOT a message — it appears transiently and disappears when thinking ends.
struct TransientReasoningBubble: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var previewScrollTask: Task<Void, Never>?

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let lineCount = lines.count

        HStack {
            VStack(alignment: .leading, spacing: AuroraSpacing.space2) {
                HStack(spacing: AuroraSpacing.space2) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.Aurora.textSecondary)
                    Text(L10n.Drawer.thinking)
                        .font(.Aurora.micro.weight(.semibold))
                        .foregroundColor(Color.Aurora.textSecondary)
                        .auroraShimmer(isDark: isDark)
                    if lineCount > 0 {
                        Text("\(lineCount) lines")
                            .font(.Aurora.micro)
                            .foregroundColor(Color.Aurora.textMuted)
                    }
                    Spacer()
                }

                if !trimmed.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(trimmed)
                                .font(.Aurora.caption)
                                .foregroundColor(Color.Aurora.textSecondary.opacity(isDark ? 0.78 : 0.72))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("reasoning-preview-anchor")
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 80) // ~4-5 lines preview window
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.74),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .onAppear {
                            scrollPreviewToBottom(proxy: proxy, animated: false)
                        }
                        .onChange(of: text) { _, _ in
                            schedulePreviewScroll(proxy: proxy)
                        }
                    }
                }
            }
            .padding(AuroraSpacing.space3)
            .background(Color.Aurora.glassOverlay.opacity(isDark ? 0.04 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.lg, style: .continuous)
                    .strokeBorder(Color.Aurora.glassOverlay.opacity(isDark ? 0.04 : 0.06), lineWidth: 0.5)
            )

            Spacer(minLength: 40)
        }
    }

    private func schedulePreviewScroll(proxy: ScrollViewProxy) {
        previewScrollTask?.cancel()
        previewScrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            scrollPreviewToBottom(proxy: proxy)
        }
    }

    private func scrollPreviewToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo("reasoning-preview-anchor", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("reasoning-preview-anchor", anchor: .bottom)
        }
    }
}

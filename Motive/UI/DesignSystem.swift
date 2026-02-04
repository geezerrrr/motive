//
//  DesignSystem.swift
//  Motive
//
//  Aurora Design System - A sophisticated, gradient-infused dark-first experience
//

import AppKit
import SwiftUI

// MARK: - Aurora Color Palette

extension Color {
    enum Aurora {
        // MARK: - Background Colors (Notion Style - 温暖优雅)
        
        /// Base canvas - deepest background (#191919)
        static var backgroundDeep: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "191919") : NSColor(hex: "FAFAFA")
            })
        }
        
        /// Main background (#202020)
        static var background: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "202020") : NSColor(hex: "F5F5F5")
            })
        }
        
        /// Cards, inputs (#2B2B2B)
        static var surface: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "2B2B2B") : NSColor(hex: "FFFFFF")
            })
        }
        
        /// Hover states (#363636)
        static var surfaceElevated: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "363636") : NSColor(hex: "F0F0F0")
            })
        }
        
        // MARK: - Accent Colors (Notion Style - 柔和灰)
        
        /// Accent start - Light Gray (#ABABAB)
        static let accentStart = Color(hex: "ABABAB")
        
        /// Accent middle - Medium Gray (#8B8B8B)
        static let accentMid = Color(hex: "8B8B8B")
        
        /// Accent end - Dark Gray (#6B6B6B)
        static let accentEnd = Color(hex: "6B6B6B")
        
        /// Primary accent color (Medium Gray)
        static let accent = Color(hex: "8B8B8B")
        
        // MARK: - Primary Colors (Amber 琥珀金 - 主题亮色)
        
        /// Primary color - Amber (#F59E0B)
        static let primary = Color(hex: "F59E0B")
        
        /// Primary light - for hover (#FBBF24)
        static let primaryLight = Color(hex: "FBBF24")
        
        /// Primary dark - for pressed (#D97706)
        static let primaryDark = Color(hex: "D97706")
        
        // MARK: - Semantic Colors
        
        /// Success - Emerald (#10B981)
        static let success = Color(hex: "10B981")
        
        /// Warning - Amber (#F59E0B)
        static let warning = Color(hex: "F59E0B")
        
        /// Error - Red (#EF4444)
        static let error = Color(hex: "EF4444")
        
        /// Info - Blue (#3B82F6)
        static let info = Color(hex: "3B82F6")
        
        // MARK: - Text Colors (Notion Style)
        
        /// Primary text - soft white (#EBEBEB / #1A1A1A)
        static var textPrimary: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "EBEBEB") : NSColor(hex: "1A1A1A")
            })
        }
        
        /// Secondary text (#9B9B9B / #5A5A5A)
        static var textSecondary: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "9B9B9B") : NSColor(hex: "5A5A5A")
            })
        }
        
        /// Muted text (#6B6B6B / #8A8A8A)
        static var textMuted: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "6B6B6B") : NSColor(hex: "8A8A8A")
            })
        }
        
        /// Disabled text (#4A4A4A / #BABABA)
        static var textDisabled: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark ? NSColor(hex: "4A4A4A") : NSColor(hex: "BABABA")
            })
        }
        
        // MARK: - Border Colors (Notion Style)
        
        /// Default border - subtle
        static var border: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark
                    ? NSColor.white.withAlphaComponent(0.06)
                    : NSColor.black.withAlphaComponent(0.06)
            })
        }
        
        /// Hover border
        static var borderHover: Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark
                    ? NSColor.white.withAlphaComponent(0.10)
                    : NSColor.black.withAlphaComponent(0.10)
            })
        }
        
        /// Focus border (Amber accent for visibility)
        static let borderFocus = Color(hex: "F59E0B").opacity(0.6)
        
        // MARK: - Gradient Helpers
        
        /// Aurora gradient colors array
        static var auroraGradientColors: [Color] {
            [accentStart, accentMid, accentEnd]
        }
        
        /// Aurora gradient
        static var auroraGradient: LinearGradient {
            LinearGradient(
                colors: auroraGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        /// Horizontal aurora gradient
        static var auroraGradientHorizontal: LinearGradient {
            LinearGradient(
                colors: auroraGradientColors,
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        
        // MARK: - Status Colors
        
        static var idle: Color { textMuted }
        static var reasoning: Color { primary }
        static var executing: Color { primary }
    }
}

// MARK: - NSColor Helpers

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Aurora Typography

extension Font {
    enum Aurora {
        // Display - for large titles (32pt / Bold / -0.02em)
        static let display = Font.system(size: 32, weight: .bold, design: .default)
        
        // Title 1 (24pt / Semibold / -0.01em)
        static let title1 = Font.system(size: 24, weight: .semibold, design: .default)
        
        // Title 2 (20pt / Semibold / -0.01em)
        static let title2 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // Headline (17pt / Semibold)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        
        // Body (15pt / Regular / 1.5 line-height)
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        
        // Body Small (14pt / Regular)
        static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
        
        // Caption (12pt / Medium)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        
        // Micro (11pt / Medium / 0.02em)
        static let micro = Font.system(size: 11, weight: .medium, design: .default)
        
        // Monospace for code/technical
        static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
        static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    }
}

// MARK: - Aurora Spacing (Base Unit: 4px)

enum AuroraSpacing {
    static let space0_5: CGFloat = 2    // micro gaps
    static let space1: CGFloat = 4      // tight
    static let space2: CGFloat = 8      // compact
    static let space3: CGFloat = 12     // default gap
    static let space4: CGFloat = 16     // standard
    static let space5: CGFloat = 20     // comfortable
    static let space6: CGFloat = 24     // sections
    static let space8: CGFloat = 32     // large sections
    static let space10: CGFloat = 40    // page padding
    static let space12: CGFloat = 48    // hero spacing
}

// Legacy Spacing namespace
enum Spacing {
    static let xxs: CGFloat = AuroraSpacing.space0_5
    static let xs: CGFloat = AuroraSpacing.space1
    static let sm: CGFloat = AuroraSpacing.space2
    static let md: CGFloat = AuroraSpacing.space3
    static let lg: CGFloat = AuroraSpacing.space4
    static let xl: CGFloat = AuroraSpacing.space6
    static let xxl: CGFloat = AuroraSpacing.space8
}

// MARK: - Aurora Corner Radius

enum AuroraRadius {
    static let xs: CGFloat = 4      // badges, tags
    static let sm: CGFloat = 6      // buttons, inputs
    static let md: CGFloat = 10     // cards
    static let lg: CGFloat = 14     // modals, panels
    static let xl: CGFloat = 20     // main containers
    static let full: CGFloat = 9999 // pills, avatars
}

// Legacy CornerRadius namespace
enum CornerRadius {
    static let small: CGFloat = AuroraRadius.sm
    static let medium: CGFloat = AuroraRadius.md
    static let large: CGFloat = AuroraRadius.lg
    static let xlarge: CGFloat = AuroraRadius.xl
}

// MARK: - Aurora Animations

extension Animation {
    // Spring animations - preferred for natural motion
    static let auroraSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let auroraSpringBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let auroraSpringStiff = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let auroraSpringSnappy = Animation.spring(response: 0.15, dampingFraction: 0.9)
    
    // Spring-based replacements for timing animations (preferred)
    static let auroraInstant = Animation.spring(response: 0.1, dampingFraction: 0.9)
    static let auroraFast = Animation.spring(response: 0.15, dampingFraction: 0.85)
    static let auroraNormal = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let auroraSlow = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    // Legacy compatibility
    static let velvetSpring = auroraSpring
    static let quickSpring = auroraSpringStiff
}

// MARK: - Aurora Shadow System

extension View {
    /// Large ambient glow shadow
    func auroraShadowLarge() -> some View {
        self.shadow(color: Color.Aurora.accentStart.opacity(0.15), radius: 40, x: 0, y: 20)
    }
    
    /// Medium shadow for cards
    func auroraShadowMedium() -> some View {
        self.shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
    }
    
    /// Small shadow for buttons
    func auroraShadowSmall() -> some View {
        self.shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    /// Glow effect with aurora colors
    func auroraGlow(intensity: Double = 0.3) -> some View {
        self.shadow(color: Color.Aurora.accentMid.opacity(intensity), radius: 20, x: 0, y: 0)
    }
    
    // Legacy shadows
    func velvetShadow(opacity: Double = 0.15, radius: CGFloat = 20, y: CGFloat = 8) -> some View {
        self.shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: y)
    }
    
    func subtleShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Aurora Gradient Border

struct AuroraGradientBorder: View {
    var cornerRadius: CGFloat = AuroraRadius.lg
    var lineWidth: CGFloat = 1.5
    var opacity: Double = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.Aurora.accent, lineWidth: lineWidth)
            .opacity(opacity)
    }
}

// MARK: - Aurora Background

struct AuroraBackground: View {
    var cornerRadius: CGFloat = AuroraRadius.lg
    var showGradientBorder: Bool = true
    var borderOpacity: Double = 0.6
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        ZStack {
            // Solid background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.Aurora.background)
            
            // Subtle gradient overlay for depth
            if isDark {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.Aurora.accentMid.opacity(0.03),
                                Color.clear,
                                Color.Aurora.accentStart.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Gradient border
            if showGradientBorder {
                AuroraGradientBorder(cornerRadius: cornerRadius, opacity: borderOpacity)
            }
        }
    }
}

// MARK: - Aurora Surface (for cards/elevated content)

struct AuroraSurface: View {
    var cornerRadius: CGFloat = AuroraRadius.md
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.Aurora.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.Aurora.border, lineWidth: 1)
            )
    }
}

// MARK: - Legacy Glass Backgrounds (for compatibility)

struct GlassBackground: View {
    var cornerRadius: CGFloat = CornerRadius.large
    var opacity: Double = 0.85
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow, state: .active)
            
            if colorScheme == .dark {
                Color.Aurora.background.opacity(opacity)
            } else {
                Color.white.opacity(0.9)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 0.5)
        )
    }
}

struct DarkGlassBackground: View {
    var cornerRadius: CGFloat = CornerRadius.large
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            VisualEffectView(
                material: colorScheme == .dark ? .sidebar : .popover,
                blendingMode: .behindWindow,
                state: .active
            )
            
            Color.Aurora.backgroundDeep.opacity(0.95)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.Aurora.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Aurora Status Indicator

struct AuroraStatusIndicator: View {
    let state: AppState.MenuBarState
    @State private var isPulsing = false
    @State private var gradientRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer glow for active states
            if state != .idle {
                Circle()
                    .fill(stateColor.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
            }
            
            // Main indicator
            Circle()
                .fill(
                    state == .idle
                        ? AnyShapeStyle(stateColor)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: Color.Aurora.auroraGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .frame(width: 8, height: 8)
        }
        .onAppear {
            if state != .idle {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: state) { _, newState in
            isPulsing = false
            if newState != .idle {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .idle: return Color.Aurora.textMuted
        case .reasoning: return Color.Aurora.accentMid
        case .executing: return Color.Aurora.accentStart
        }
    }
}

// Legacy StatusIndicator for compatibility
struct StatusIndicator: View {
    let state: AppState.MenuBarState
    
    var body: some View {
        AuroraStatusIndicator(state: state)
    }
}

// MARK: - Aurora Button Style

struct AuroraButtonStyle: ButtonStyle {
    enum Style {
        case primary    // Gradient fill
        case secondary  // Outline
        case ghost      // No background
    }
    
    var style: Style = .primary
    var size: Size = .medium
    
    enum Size {
        case small, medium, large
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return AuroraSpacing.space3
            case .medium: return AuroraSpacing.space4
            case .large: return AuroraSpacing.space5
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return AuroraSpacing.space2
            case .medium: return AuroraSpacing.space3
            case .large: return AuroraSpacing.space4
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .Aurora.caption
            case .medium: return .Aurora.bodySmall
            case .large: return .Aurora.body
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font.weight(.semibold))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(background(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous))
            .overlay(overlay)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
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
        case .ghost:
            Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary, .ghost: return Color.Aurora.textPrimary
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


// MARK: - Aurora Text Field Style

// MARK: - Aurora Styled TextField (View-based component)
// NOTE: TextFieldStyle cannot use .textFieldStyle(.plain) inside _body
// Use this View component directly instead of TextFieldStyle

struct AuroraStyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var backgroundColor: Color {
        isDark ? Color(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0) 
               : Color(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0)
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.Aurora.body)
            .foregroundColor(Color.Aurora.textPrimary)
            .padding(.horizontal, AuroraSpacing.space4)
            .padding(.vertical, AuroraSpacing.space3)
            .background(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuroraRadius.sm, style: .continuous)
                    .stroke(
                        isFocused ? Color.Aurora.borderFocus : Color.Aurora.border,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.auroraFast, value: isFocused)
    }
}

// Legacy TextFieldStyle (kept for compatibility, does nothing special)
struct AuroraTextFieldStyle: TextFieldStyle {
    var isFocused: Bool = false
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
    }
}


// MARK: - Aurora Card Component

struct AuroraCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = AuroraSpacing.space4
    
    init(padding: CGFloat = AuroraSpacing.space4, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AuroraSurface())
    }
}


// MARK: - Aurora Section Header

struct AuroraSectionHeader: View {
    let title: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: AuroraSpacing.space2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.Aurora.accent)
            }
            Text(title)
                .font(.Aurora.caption)
                .foregroundColor(Color.Aurora.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// Legacy SectionHeader
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    
    var body: some View {
        AuroraSectionHeader(title: title, icon: icon)
    }
}

// MARK: - Aurora Empty State

struct AuroraEmptyState: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: AuroraSpacing.space4) {
            ZStack {
                Circle()
                    .fill(Color.Aurora.accent.opacity(0.1))
                    .frame(width: 72, height: 72)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.Aurora.auroraGradient)
            }
            
            VStack(spacing: AuroraSpacing.space2) {
                Text(title)
                    .font(.Aurora.headline)
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Text(message)
                    .font(.Aurora.bodySmall)
                    .foregroundColor(Color.Aurora.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Legacy EmptyStateView
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        AuroraEmptyState(icon: icon, title: title, message: message)
    }
}

// MARK: - Aurora Shimmer Effect

struct AuroraShimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    var isDark: Bool = true
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: shimmerColor.opacity(0.4), location: 0.4),
                            .init(color: shimmerColor.opacity(0.6), location: 0.5),
                            .init(color: shimmerColor.opacity(0.4), location: 0.6),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
    
    private var shimmerColor: Color {
        isDark ? Color.Aurora.accentMid : Color.Aurora.accentStart
    }
}

extension View {
    func auroraShimmer(isDark: Bool = true) -> some View {
        modifier(AuroraShimmer(isDark: isDark))
    }
}

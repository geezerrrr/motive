//
//  StatusBarController.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import SwiftUI

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarDidRequestToggleDrawer()
    func statusBarDidRequestSettings()
    func statusBarDidRequestQuit()
    func statusBarDidRequestCommandBar()
    /// Build menu for right-click (includes dynamic Running tasks when count > 0)
    func statusBarMenu() -> NSMenu
}

/// Extended status for status bar display
enum StatusBarDisplayState {
    case idle
    case thinking
    case executing(tool: String?)
    case waitingForInput(type: String) // "Permission", "Question", etc.
    case completed
    case error

    var icon: String {
        switch self {
        case .idle: "sparkle"
        case .thinking: "brain.head.profile"
        case .executing: "bolt.fill"
        case .waitingForInput: "hand.raised.fill"
        case .completed: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var text: String {
        switch self {
        case .idle: ""
        case .thinking: "Thinking…"
        case let .executing(tool): tool ?? "Running…"
        case let .waitingForInput(type): type
        case .completed: "Done"
        case .error: "Error"
        }
    }

    var showText: Bool {
        switch self {
        case .idle: false
        default: true
        }
    }
}

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private weak var delegate: StatusBarControllerDelegate?
    private var animationTask: Task<Void, Never>?
    private var animationDots = 0
    private var notificationPanel: NSPanel?
    private var notificationDismissTask: Task<Void, Never>?
    private var commandMenuItem: NSMenuItem?
    private var configManager: ConfigManager?

    init(delegate: StatusBarControllerDelegate) {
        self.delegate = delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        configureStatusButton()
        configureMenu()
        updateDisplay(state: .idle)
    }

    /// Configure with ConfigManager to display hotkey in menu
    func configure(configManager: ConfigManager) {
        self.configManager = configManager
        updateCommandBarMenuItem()
    }

    /// Update the Command Bar menu item with current hotkey
    func updateCommandBarMenuItem() {
        guard let item = commandMenuItem, let configManager else { return }
        let parsed = HotkeyParser.parseToMenuShortcut(configManager.hotkey)
        item.keyEquivalent = parsed.keyEquivalent
        item.keyEquivalentModifierMask = parsed.modifiers
    }

    /// Get the frame of the status bar button in screen coordinates
    var buttonFrame: NSRect? {
        guard let button = statusItem.button,
              let window = button.window else { return nil }
        let buttonRect = button.convert(button.bounds, to: nil)
        return window.convertToScreen(buttonRect)
    }

    func update(state: AppState.MenuBarState, toolName: String? = nil, isWaitingForInput: Bool = false, inputType: String? = nil) {
        let displayState: StatusBarDisplayState = if isWaitingForInput {
            .waitingForInput(type: inputType ?? "Input Required")
        } else {
            switch state {
            case .idle:
                .idle
            case .reasoning:
                .thinking
            case .executing:
                .executing(tool: toolName)
            case .responding:
                .executing(tool: toolName)
            }
        }

        updateDisplay(state: displayState)
    }

    func showCompleted() {
        updateDisplay(state: .completed)
        showNotification(type: .success)
        // Auto-revert to idle after 2 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.updateDisplay(state: .idle)
        }
    }

    func showError() {
        updateDisplay(state: .error)
        showNotification(type: .error)
        // Auto-revert to idle after 3 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.updateDisplay(state: .idle)
        }
    }

    // MARK: - Notification Popup

    private func showNotification(type: StatusNotificationType) {
        // Dismiss existing
        dismissNotification()

        let glassMode = configManager?.liquidGlassMode ?? .clear
        let view = StatusNotificationView(type: type, onDismiss: { [weak self] in
            self?.dismissNotification()
        }, glassMode: glassMode)

        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = .intrinsicContentSize
        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        let size = hostingView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView

        // Positioning strategy:
        // When the menu bar is auto-hidden, statusItem.button?.window still exists
        // and buttonFrame still returns valid coordinates at the top of the screen.
        // However, visibleFrame *excludes* the hidden menu bar region. So we check
        // whether the button actually sits within the visible area.
        // Positioning strategy:
        // When the menu bar is auto-hidden, statusItem.button?.window still exists
        // and buttonFrame still returns valid coordinates at the top of the screen.
        // However, visibleFrame *excludes* the hidden menu bar region. So we check
        // whether the button actually sits within the visible area.
        let targetScreen = statusItem.button?.window?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let visibleFrame = targetScreen.visibleFrame // excludes dock + hidden menu bar

        if let anchor = buttonFrame, visibleFrame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) {
            // Menu bar is visible — position notification directly below the button
            let x = anchor.midX - size.width / 2
            let y = anchor.minY - size.height - 8
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            // Menu bar is hidden — bottom-center above the dock
            let x = visibleFrame.midX - size.width / 2
            let y = visibleFrame.minY + 24
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        notificationPanel = panel

        // Auto dismiss after 2.5 seconds
        notificationDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.dismissNotification()
        }
    }

    private func dismissNotification() {
        notificationDismissTask?.cancel()
        notificationDismissTask = nil

        guard let panel = notificationPanel else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
        notificationPanel = nil
    }

    private func updateDisplay(state: StatusBarDisplayState) {
        guard let button = statusItem.button else { return }

        // Stop any existing animation
        animationTask?.cancel()
        animationTask = nil

        // Configure icon based on state
        switch state {
        case .idle:
            // Use custom logo for idle state
            if let logoImage = NSImage(named: "status-bar-icon") {
                let icon = logoImage.copy() as! NSImage
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                let image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Motive")
                let configured = image?.withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
                configured?.isTemplate = true
                button.image = configured
            }
        default:
            // Use state-specific system icon for other states
            let image = NSImage(systemSymbolName: state.icon, accessibilityDescription: "Motive")
            let configured = image?.withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
            configured?.isTemplate = true
            button.image = configured
        }

        button.imagePosition = state.showText ? .imageLeading : .imageOnly
        button.contentTintColor = nil // Let system handle color
        button.toolTip = state.showText ? "Motive: \(state.text)" : "Motive"
        button.setAccessibilityLabel(state.showText ? "Motive \(state.text)" : "Motive")

        // Configure text (always use variableLength — the system auto-sizes
        // to the image alone when there is no title text).
        if state.showText {
            let baseText = state.text

            // Start animation for active states
            switch state {
            case .thinking, .executing, .waitingForInput:
                startTextAnimation(baseText: baseText, button: button)
            default:
                setButtonTitle(baseText, button: button)
            }
        } else {
            button.title = ""
        }

        statusItem.length = NSStatusItem.variableLength
        statusItem.isVisible = true
    }

    private func startTextAnimation(baseText: String, button: NSStatusBarButton) {
        // Remove ... from text
        let cleanText = baseText.replacingOccurrences(of: "…", with: "")
        animationDots = 0

        // Start shimmer animation using Task-based loop
        animationTask = Task { @MainActor [weak self, weak button] in
            while !Task.isCancelled {
                guard let self, let button else { break }

                // Increment phase
                self.animationDots = (self.animationDots + 1) % MetallicShimmerStyle.cycleFrames
                self.updateShimmerTitle(cleanText, button: button, phase: self.animationDots)

                try? await Task.sleep(for: .milliseconds(MetallicShimmerStyle.frameIntervalMS))
            }
        }
    }

    /// Resolve the correct text color for the menu bar based on the
    /// status button's effective appearance. The menu bar switches between
    /// vibrant-dark (light text) and vibrant-light (dark text) depending
    /// on the desktop wallpaper behind it.
    private func menuBarTextColor(for button: NSStatusBarButton) -> NSColor {
        let isDark = button.effectiveAppearance
            .bestMatch(from: [.vibrantDark, .vibrantLight]) == .vibrantDark
        return isDark ? .white : .black
    }

    private func updateShimmerTitle(_ text: String, button: NSStatusBarButton, phase: Int) {
        let attributedString = NSMutableAttributedString(string: " \(text)")
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let baseColor = menuBarTextColor(for: button)

        // Apply gradient effect per character
        for i in 0 ..< attributedString.length {
            let charProgress = CGFloat(i) / CGFloat(max(1, attributedString.length - 1))
            let alpha = MetallicShimmerStyle.alpha(charProgress: charProgress, phase: phase)

            let color = baseColor.withAlphaComponent(alpha)
            attributedString.addAttributes([
                .font: font,
                .foregroundColor: color
            ], range: NSRange(location: i, length: 1))
        }

        button.attributedTitle = attributedString
    }

    private func setButtonTitle(_ title: String, button: NSStatusBarButton, alpha: CGFloat = 1.0) {
        let color = menuBarTextColor(for: button).withAlphaComponent(alpha)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color
        ]
        button.attributedTitle = NSAttributedString(string: " \(title)", attributes: attributes)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusButton)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        let commandItem = NSMenuItem(title: L10n.StatusBar.commandBar, action: #selector(openCommandBar), keyEquivalent: "")
        commandItem.target = self
        commandItem.image = NSImage(systemSymbolName: "command", accessibilityDescription: nil)
        self.commandMenuItem = commandItem // Save reference for later update

        let settingsItem = NSMenuItem(title: L10n.StatusBar.settings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)

        let quitItem = NSMenuItem(title: L10n.StatusBar.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = .command
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)

        menu.addItem(commandItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    @objc private func handleStatusButton() {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            statusItem.menu = delegate?.statusBarMenu() ?? menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            delegate?.statusBarDidRequestToggleDrawer()
        }
    }

    @objc private func openSettings() {
        delegate?.statusBarDidRequestSettings()
    }

    @objc private func quitApp() {
        delegate?.statusBarDidRequestQuit()
    }

    @objc private func openCommandBar() {
        delegate?.statusBarDidRequestCommandBar()
    }
}

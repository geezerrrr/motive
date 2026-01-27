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
}

/// Extended status for status bar display
enum StatusBarDisplayState {
    case idle
    case thinking
    case executing(tool: String?)
    case waitingForInput(type: String)  // "Permission", "Question", etc.
    case completed
    case error
    
    var icon: String {
        switch self {
        case .idle: return "sparkle"
        case .thinking: return "brain.head.profile"
        case .executing: return "bolt.fill"
        case .waitingForInput: return "hand.raised.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var text: String {
        switch self {
        case .idle: return ""
        case .thinking: return "Thinking…"
        case .executing(let tool): return tool ?? "Running…"
        case .waitingForInput(let type): return type
        case .completed: return "Done"
        case .error: return "Error"
        }
    }
    
    var showText: Bool {
        switch self {
        case .idle: return false
        default: return true
        }
    }
}

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private weak var delegate: StatusBarControllerDelegate?
    private var animationTimer: Timer?
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
        // Initial state
        updateDisplay(state: .idle)
    }
    
    /// Configure with ConfigManager to display hotkey in menu
    func configure(configManager: ConfigManager) {
        self.configManager = configManager
        updateCommandBarMenuItem()
    }
    
    /// Update the Command Bar menu item with current hotkey
    func updateCommandBarMenuItem() {
        guard let item = commandMenuItem, let configManager = configManager else { return }
        let (keyEquivalent, modifiers) = parseHotkeyForMenu(configManager.hotkey)
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = modifiers
    }
    
    /// Parse hotkey string like "⌥Space" into (keyEquivalent, modifierMask) for NSMenuItem
    private func parseHotkeyForMenu(_ hotkey: String) -> (String, NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = []
        var remaining = hotkey
        
        // Parse modifiers
        while !remaining.isEmpty {
            if remaining.hasPrefix("⌘") || remaining.hasPrefix("Cmd") {
                modifiers.insert(.command)
                remaining = remaining.hasPrefix("⌘") ? String(remaining.dropFirst()) : String(remaining.dropFirst(3))
            } else if remaining.hasPrefix("⌥") || remaining.hasPrefix("Alt") || remaining.hasPrefix("Option") {
                modifiers.insert(.option)
                remaining = remaining.hasPrefix("⌥") ? String(remaining.dropFirst()) : (remaining.hasPrefix("Alt") ? String(remaining.dropFirst(3)) : String(remaining.dropFirst(6)))
            } else if remaining.hasPrefix("⇧") || remaining.hasPrefix("Shift") {
                modifiers.insert(.shift)
                remaining = remaining.hasPrefix("⇧") ? String(remaining.dropFirst()) : String(remaining.dropFirst(5))
            } else if remaining.hasPrefix("⌃") || remaining.hasPrefix("Ctrl") || remaining.hasPrefix("Control") {
                modifiers.insert(.control)
                remaining = remaining.hasPrefix("⌃") ? String(remaining.dropFirst()) : (remaining.hasPrefix("Ctrl") ? String(remaining.dropFirst(4)) : String(remaining.dropFirst(7)))
            } else {
                break
            }
        }
        
        // Parse key
        let keyEquivalent: String
        switch remaining.lowercased() {
        case "space", " ":
            keyEquivalent = " "
        case "return", "enter":
            keyEquivalent = "\r"
        case "tab":
            keyEquivalent = "\t"
        case "escape", "esc":
            keyEquivalent = "\u{1B}"
        default:
            keyEquivalent = remaining.lowercased()
        }
        
        return (keyEquivalent, modifiers)
    }
    
    /// Get the frame of the status bar button in screen coordinates
    var buttonFrame: NSRect? {
        guard let button = statusItem.button,
              let window = button.window else { return nil }
        let buttonRect = button.convert(button.bounds, to: nil)
        return window.convertToScreen(buttonRect)
    }

    func update(state: AppState.MenuBarState, toolName: String? = nil, isWaitingForInput: Bool = false, inputType: String? = nil) {
        let displayState: StatusBarDisplayState
        
        if isWaitingForInput {
            displayState = .waitingForInput(type: inputType ?? "Input Required")
        } else {
            switch state {
            case .idle:
                displayState = .idle
            case .reasoning:
                displayState = .thinking
            case .executing:
                displayState = .executing(tool: toolName)
            }
        }
        
        updateDisplay(state: displayState)
    }
    
    func showCompleted() {
        updateDisplay(state: .completed)
        showNotification(type: .success)
        // Auto-revert to idle after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.updateDisplay(state: .idle)
        }
    }
    
    func showError() {
        updateDisplay(state: .error)
        showNotification(type: .error)
        // Auto-revert to idle after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.updateDisplay(state: .idle)
        }
    }
    
    // MARK: - Notification Popup
    
    private func showNotification(type: StatusNotificationType) {
        // Dismiss existing
        dismissNotification()
        
        let view = StatusNotificationView(type: type) { [weak self] in
            self?.dismissNotification()
        }
        
        let hostingView = NSHostingView(rootView: view)
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
        
        // Position below status bar button
        if let anchor = buttonFrame {
            let x = anchor.midX - size.width / 2
            let y = anchor.minY - size.height - 8
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
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        notificationPanel = nil
    }
    
    private func updateDisplay(state: StatusBarDisplayState) {
        guard let button = statusItem.button else { return }
        
        // Stop any existing animation
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Configure icon based on state
        switch state {
        case .idle:
            // Use custom logo for idle state
            if let logoImage = NSImage(named: "status-bar-icon") {
                logoImage.isTemplate = true
                let resizedLogo = logoImage.copy() as! NSImage
                resizedLogo.size = NSSize(width: 18, height: 18)
                button.image = resizedLogo
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
        button.contentTintColor = nil  // Let system handle color
        
        // Configure text
        if state.showText {
            let baseText = state.text
            
            // Start animation for active states
            switch state {
            case .thinking, .executing, .waitingForInput:
                startTextAnimation(baseText: baseText, button: button)
            default:
                setButtonTitle(baseText, button: button)
            }
            
            // Variable width for text
            statusItem.length = NSStatusItem.variableLength
        } else {
            button.title = ""
            statusItem.length = NSStatusItem.squareLength
        }
        
        statusItem.isVisible = true
    }
    
    private func startTextAnimation(baseText: String, button: NSStatusBarButton) {
        // Remove ... from text
        let cleanText = baseText.replacingOccurrences(of: "…", with: "")
        animationDots = 0
        
        // Start shimmer animation using attributed string
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self, weak button] _ in
            guard let self, let button else { return }
            
            // Increment phase
            self.animationDots = (self.animationDots + 1) % 40  // 40 frames, ~1.2s per cycle
            
            Task { @MainActor in
                self.updateShimmerTitle(cleanText, button: button, phase: self.animationDots)
            }
        }
    }
    
    private func updateShimmerTitle(_ text: String, button: NSStatusBarButton, phase: Int) {
        let baseAlpha: CGFloat = 0.4
        let highlightAlpha: CGFloat = 1.0
        
        // Calculate highlight position (0 to 1)
        let progress = CGFloat(phase) / 40.0
        let highlightCenter = progress * 1.4 - 0.2  // -0.2 to 1.2 range for smooth entry/exit
        
        let attributedString = NSMutableAttributedString(string: " \(text)")
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        
        // Apply gradient effect per character
        for i in 0..<attributedString.length {
            let charProgress = CGFloat(i) / CGFloat(max(1, attributedString.length - 1))
            let distance = abs(charProgress - highlightCenter)
            let alpha = max(baseAlpha, highlightAlpha - distance * 2.5)
            
            let color = NSColor.controlTextColor.withAlphaComponent(alpha)
            attributedString.addAttributes([
                .font: font,
                .foregroundColor: color
            ], range: NSRange(location: i, length: 1))
        }
        
        button.attributedTitle = attributedString
    }
    
    private func setButtonTitle(_ title: String, button: NSStatusBarButton, alpha: CGFloat = 1.0) {
        // Use controlTextColor which adapts to system appearance automatically
        let color = NSColor.controlTextColor.withAlphaComponent(alpha)
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
        self.commandMenuItem = commandItem  // Save reference for later update
        
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
            statusItem.menu = menu
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

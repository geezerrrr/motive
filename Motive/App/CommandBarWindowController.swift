//
//  CommandBarWindowController.swift
//  Motive
//
//  Dynamic height CommandBar window - auto-sizes based on SwiftUI content
//

import AppKit
import SwiftUI

@MainActor
final class CommandBarWindowController {
    private let window: KeyablePanel
    private let hostingView: NSHostingView<AnyView>
    private let containerView: NSView
    private var resignKeyObserver: Any?
    private var resignActiveObserver: Any?
    private var currentHeight: CGFloat = CommandBarWindowController.heights["idle"] ?? 100
    
    /// Whether the window has been shown at least once (for lazy initialization)
    private var hasBeenShown = false
    
    /// When true, the window will not hide on resign key (used during delete confirmation)
    var suppressAutoHide: Bool = false
    
    /// Whether the window is currently visible
    var isVisible: Bool { window.isVisible }
    
    // Height constants matching CommandBarMode
    static let heights: [String: CGFloat] = [
        "idle": 100,
        "input": 100,
        "command": 450,
        "history": 450,
        "projects": 450,
        "fileCompletion": 450,
        "running": 160,
        "completed": 160,
        "error": 160
    ]

    init<Content: View>(rootView: Content) {
        hostingView = NSHostingView(rootView: AnyView(rootView))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = false
        
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: currentHeight))
        containerView.wantsLayer = true
        
        // Initialize window off-screen to prevent first-frame flash at (0,0)
        let panel = KeyablePanel(
            contentRect: NSRect(x: -10000, y: -10000, width: 600, height: 100),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true  // Defer creation until needed
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.contentView = containerView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = AuroraRadius.xl
        panel.contentView?.layer?.masksToBounds = true
        
        // Start hidden with 0 alpha
        panel.alphaValue = 0
        
        window = panel
        
        containerView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Hide when window loses key status (unless suppressed)
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.suppressAutoHide {
                self.hide()
            }
        }
        
        // Also hide when app loses active status
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.suppressAutoHide && self.window.isKeyWindow {
                self.hide()
            }
        }
    }
    
    deinit {
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func show() {
        // 1. Position window BEFORE showing (invisible)
        positionWindowAtCenter()
        
        // 2. Activate app
        NSApp.activate(ignoringOtherApps: true)
        
        // 3. Show window with fade-in animation
        window.orderFrontRegardless()
        window.makeKey()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        
        // 4. Focus input field after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.focusFirstResponder()
        }
        
        hasBeenShown = true
    }

    func hide() {
        // Skip if already hidden
        guard window.isVisible else { return }
        
        // Resign first responder immediately
        window.makeFirstResponder(nil)
        
        // Fade out then order out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window.orderOut(nil)
        })
    }
    
    /// Update window height with smooth animation
    /// Window expands DOWNWARD - top edge (input position) stays fixed
    func updateHeight(to newHeight: CGFloat, animated: Bool = true) {
        guard newHeight != currentHeight else { return }
        
        let currentFrame = window.frame
        let heightDelta = newHeight - currentFrame.height
        
        var newFrame = currentFrame
        newFrame.size.height = newHeight
        // Keep TOP edge fixed, expand downward
        newFrame.origin.y -= heightDelta
        
        if animated && window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: window.isVisible)
        }
        
        currentHeight = newHeight
    }
    
    /// Update height based on mode name
    func updateHeightForMode(_ modeName: String, animated: Bool = true) {
        if let height = Self.heights[modeName] {
            updateHeight(to: height, animated: animated)
        }
    }

    func focusFirstResponder() {
        if let textField = window.contentView?.findFirstTextField() {
            window.makeFirstResponder(textField)
        }
    }

    func getWindow() -> NSWindow {
        window
    }
    
    /// Reposition window to center of current screen (for multi-monitor support)
    func recenter() {
        positionWindowAtCenter()
    }

    private func positionWindowAtCenter() {
        guard let screen = screenForMouse() ?? window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.frame
        
        let height = max(96, currentHeight)
        let windowSize = NSSize(width: 600, height: height)
        let x = screenFrame.midX - windowSize.width / 2
        
        // Position input at ~55% from bottom of screen
        let topEdgeY = screenFrame.minY + screenFrame.height * 0.55 + 100
        let y = topEdgeY - height
        
        // Set frame without display (we're not visible yet or already positioned)
        window.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: false)
    }

    private func screenForMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        var displayID: CGDirectDisplayID = 0
        var count: UInt32 = 0
        if CGGetDisplaysWithPoint(mouseLocation, 1, &displayID, &count) == .success, count > 0 {
            return NSScreen.screens.first(where: { screen in
                (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
            })
        }
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

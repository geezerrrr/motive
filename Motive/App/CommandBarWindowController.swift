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
    private var frameObserver: NSObjectProtocol?
    private var currentHeight: CGFloat = CommandBarWindowController.heights["idle"] ?? 100
    
    /// When true, the window will not hide on resign key (used during delete confirmation)
    var suppressAutoHide: Bool = false
    
    // Height constants matching CommandBarMode
    // Layout: [status bar ~50] + input(52) + [list] + footer(40) + padding
    // Note: command/histories heights are for session mode (max height);
    // non-session mode is 50px less (no status bar)
    static let heights: [String: CGFloat] = [
        "idle": 100,      // input + footer + padding
        "input": 100,
        "command": 450,   // Same as histories for consistency
        "histories": 450, // status(50) + input + footer + list(280) + padding (max case)
        "running": 160,   // status + input + footer + padding
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
        
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 100),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true  // Use native window shadow
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.contentView = containerView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = AuroraRadius.xl
        panel.contentView?.layer?.masksToBounds = true
        window = panel
        
        containerView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Hide when window loses key status (unless suppressed)
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.suppressAutoHide {
                self.hide()
            }
        }
        
        // Also hide when app loses active status (e.g., clicking menu bar, switching apps)
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.suppressAutoHide {
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
        if let observer = frameObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        // Always re-center with current height
        centerWindow()
        window.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.async { [weak self] in
            self?.focusFirstResponder()
        }
    }

    func hide() {
        window.orderOut(nil)
    }
    
    /// Update window height with smooth animation
    /// Window expands DOWNWARD - top edge (input position) stays fixed
    func updateHeight(to newHeight: CGFloat, animated: Bool = true) {
        let currentFrame = window.frame
        let heightDelta = newHeight - currentFrame.height
        
        var newFrame = currentFrame
        newFrame.size.height = newHeight
        // Keep TOP edge fixed (input stays in place), expand downward
        // In macOS coordinates, origin is bottom-left, so we subtract heightDelta from y
        newFrame.origin.y -= heightDelta
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
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

    private func centerWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let height = max(96, currentHeight)
        let windowSize = NSSize(width: 600, height: height)
        let x = screenFrame.midX - windowSize.width / 2
        
        // Calculate TOP edge position (fixed point where input appears)
        // Input should appear at ~55% from bottom of screen
        let topEdgeY = screenFrame.minY + screenFrame.height * 0.55 + 100  // 100 = idle height
        
        // Window origin is bottom-left, so: originY = topEdgeY - height
        let y = topEdgeY - height
        
        window.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true)
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}


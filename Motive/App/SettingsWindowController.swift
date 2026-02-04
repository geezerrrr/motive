//
//  SettingsWindowController.swift
//  Motive
//
//  Manages the settings window directly.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var configManager: ConfigManager?
    private var appState: AppState?
    
    /// The tab to show when opening settings
    private var initialTab: SettingsTab = .general
    
    private override init() {
        super.init()
    }
    
    func configure(configManager: ConfigManager, appState: AppState) {
        self.configManager = configManager
        self.appState = appState
    }
    
    func show(tab: SettingsTab = .general) {
        let previousTab = initialTab
        initialTab = tab
        
        // Hide command bar first to avoid layer conflicts
        appState?.hideCommandBar()
        
        // If window exists, just bring it to front (don't recreate)
        if let existingWindow = window,
           let configManager = configManager,
           let appState = appState {
            // Update content view if tab changed or window was hidden
            if previousTab != tab || !existingWindow.isVisible {
                let settingsView = SettingsView(initialTab: tab)
                    .environmentObject(configManager)
                    .environmentObject(appState)
                existingWindow.contentView = NSHostingView(rootView: settingsView)
            }
            
            // Ensure window is visible and focused
            NSApp.setActivationPolicy(.regular)
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // Double-check focus after a short delay
            Task { @MainActor [weak existingWindow] in
                try? await Task.sleep(for: .milliseconds(50))
                existingWindow?.makeKeyAndOrderFront(nil)
            }
            return
        }
        
        guard let configManager = configManager, let appState = appState else {
            Log.error("SettingsWindowController not configured")
            return
        }
        
        // Set activation policy FIRST before creating window
        NSApp.setActivationPolicy(.regular)
        
        // Create settings view with initial tab
        let settingsView = SettingsView(initialTab: tab)
            .environmentObject(configManager)
            .environmentObject(appState)
        
        // Create window with unified titlebar appearance
        // Use dynamic size based on initial tab
        let initialSize = tab.windowSize
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Motive Settings"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        newWindow.toolbarStyle = .unified
        newWindow.isMovableByWindowBackground = true
        
        // Match Aurora.backgroundDeep (#191919 dark / #FAFAFA light) for sidebar area
        newWindow.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0, alpha: 1.0)
                : NSColor(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0, alpha: 1.0)
        }
        
        newWindow.contentView = NSHostingView(rootView: settingsView)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        // Use normal window level (not floating) - this prevents layer conflicts
        newWindow.level = .normal
        
        // Store reference BEFORE showing
        self.window = newWindow
        
        // Show window and activate app
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure focus is maintained after activation settles
        Task { @MainActor [weak newWindow] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let window = newWindow, window.isVisible else { return }
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func close() {
        window?.close()
    }
    
    // MARK: - NSWindowDelegate
    
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Restore accessory mode (hide dock icon)
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

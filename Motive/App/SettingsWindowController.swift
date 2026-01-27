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
        initialTab = tab
        
        // Hide command bar first to avoid layer conflicts
        appState?.hideCommandBar()
        
        // If window exists and visible but requesting different tab, recreate it
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.close()
            window = nil
        }
        
        guard let configManager = configManager, let appState = appState else {
            Log.error("SettingsWindowController not configured")
            return
        }
        
        // Create settings view with initial tab
        let settingsView = SettingsView(initialTab: tab)
            .environmentObject(configManager)
            .environmentObject(appState)
        
        // Create window with unified titlebar appearance
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        
        // Match Aurora.backgroundDeep (#191919 dark / #FAFAFA light) for sidebar area
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x19/255.0, green: 0x19/255.0, blue: 0x19/255.0, alpha: 1.0)
                : NSColor(red: 0xFA/255.0, green: 0xFA/255.0, blue: 0xFA/255.0, alpha: 1.0)
        }
        
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        self.window = window
        
        // Show window and bring to front
        NSApp.setActivationPolicy(.regular)
        window.level = .floating  // Ensure window is above others initially
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Reset to normal level after activation so it behaves normally
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.level = .normal
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

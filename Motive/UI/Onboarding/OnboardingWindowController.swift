//
//  OnboardingWindowController.swift
//  Motive
//
//  Window controller for the onboarding flow.
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    
    func show(configManager: ConfigManager, appState: AppState) {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        let onboardingView = OnboardingView()
            .environmentObject(configManager)
            .environmentObject(appState)
        
        let hostingView = NSHostingView(rootView: AnyView(onboardingView))
        self.hostingView = hostingView
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("OnboardingWindow")
        window.isReleasedWhenClosed = false
        
        // Prevent closing during onboarding
        window.delegate = WindowDelegate.shared
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func close() {
        window?.close()
        window = nil
        hostingView = nil
    }
}

// Simple delegate to handle window behavior
private class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow closing - user can skip onboarding
        return true
    }
}

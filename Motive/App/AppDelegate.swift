//
//  AppDelegate.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var permissionCheckTimer: Timer?
    private var hotkeyObserver: NSObjectProtocol?
    private var onboardingController: OnboardingWindowController?
    
    /// Parsed hotkey components from ConfigManager
    private var expectedModifiers: NSEvent.ModifierFlags = .option
    private var expectedKeyCode: UInt16 = 49  // Space key

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're a menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Clean up any stale browser-sidecar processes from previous runs
        cleanupBrowserSidecar()
        
        // Apply saved appearance mode
        appState?.configManagerRef.applyAppearance()
        
        // Check if onboarding is needed
        if let configManager = appState?.configManagerRef, !configManager.hasCompletedOnboarding {
            showOnboarding()
            return
        }
        
        // Normal startup - Start the app state (creates status bar, etc.)
        startNormalFlow()
    }
    
    /// Show onboarding window for first-time users
    private func showOnboarding() {
        guard let appState = appState else { return }
        
        // Show dock icon during onboarding for better UX
        NSApp.setActivationPolicy(.regular)
        
        onboardingController = OnboardingWindowController()
        onboardingController?.show(configManager: appState.configManagerRef, appState: appState)
        
        // Observe when onboarding completes
        NotificationCenter.default.addObserver(
            forName: .onboardingCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onboardingDidComplete()
        }
    }
    
    /// Called when onboarding is completed
    private func onboardingDidComplete() {
        onboardingController?.close()
        onboardingController = nil
        
        // Switch back to accessory app (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        // Start normal flow
        startNormalFlow()
    }
    
    /// Start the normal app flow (after onboarding or on subsequent launches)
    private func startNormalFlow() {
        appState?.start()
        
        // Retry status bar creation after launch (safety)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.appState?.ensureStatusBar()
        }
        
        // Observe hotkey changes from settings
        observeHotkeyChanges()
        
        // Request accessibility permission
        requestAccessibilityAndRegisterHotkey()
        
        // Hide command bar initially - user can invoke via hotkey
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.appState?.hideCommandBar()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotkey()
        permissionCheckTimer?.invalidate()
        if let observer = hotkeyObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Clean up browser-use-sidecar processes
        cleanupBrowserSidecar()
    }
    
    /// Kill any browser-use-sidecar processes when app terminates
    private func cleanupBrowserSidecar() {
        // Method 1: Try to send close command via CLI
        // Supports both --onedir and --onefile builds
        if let dirURL = Bundle.main.url(forResource: "browser-use-sidecar", withExtension: nil) {
            var sidecarPath = dirURL.appendingPathComponent("browser-use-sidecar").path
            // Fallback to --onefile structure
            if !FileManager.default.isExecutableFile(atPath: sidecarPath) {
                sidecarPath = dirURL.path
            }
            if FileManager.default.isExecutableFile(atPath: sidecarPath) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: sidecarPath)
                process.arguments = ["close"]
                process.standardOutput = nil
                process.standardError = nil
                try? process.run()
                // Don't wait - just fire and forget
            }
        }
        
        // Method 2: Kill by PID file (backup)
        let pidPath = FileManager.default.temporaryDirectory.appendingPathComponent("browser-use-sidecar.pid")
        if let pidString = try? String(contentsOf: pidPath, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
        }
        
        // Clean up files
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("browser-use-sidecar.sock"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("browser-use-sidecar.pid"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("browser-use-sidecar.lock"))
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Skip during onboarding
        guard onboardingController == nil else { return }
        
        // Check if permission was granted while app was in background
        if globalMonitor == nil && AccessibilityHelper.hasPermission {
            registerHotkey()
        }
        appState?.ensureStatusBar()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Skip during onboarding
        guard onboardingController == nil else { return true }
        
        appState?.showCommandBar()
        return true
    }
    
    // MARK: - Accessibility Permission
    
    private func requestAccessibilityAndRegisterHotkey() {
        if AccessibilityHelper.hasPermission {
            // Already have permission
            registerHotkey()
            return
        }
        
        // Try to trigger system prompt (only works first time)
        let prompted = AccessibilityHelper.requestPermission()
        
        if !prompted {
            // System didn't show prompt (already asked before), show our own guide
            showAccessibilityGuide()
        }
        
        // Start polling for permission grant
        startPermissionCheckTimer()
    }
    
    private func showAccessibilityGuide() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let hotkeyStr = self?.appState?.configManagerRef.hotkey ?? "⌥Space"
            let alert = NSAlert()
            alert.messageText = "Enable Accessibility for Hotkey"
            alert.informativeText = """
            To use the \(hotkeyStr) hotkey, please enable Motive in:
            
            System Settings → Privacy & Security → Accessibility
            
            Find "Motive" in the list and turn it ON.
            
            (If Motive is not in the list, you may need to click '+' and add it manually from Applications folder)
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "I'll do it later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                AccessibilityHelper.openAccessibilitySettings()
            }
        }
    }
    
    private func startPermissionCheckTimer() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if AccessibilityHelper.hasPermission {
                    self?.permissionCheckTimer?.invalidate()
                    self?.permissionCheckTimer = nil
                    self?.registerHotkey()
                }
            }
        }
    }
    
    // MARK: - Global Hotkey
    
    private func observeHotkeyChanges() {
        // Observe UserDefaults changes for hotkey
        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reregisterHotkey()
            }
        }
    }
    
    private func reregisterHotkey() {
        // Only re-parse if the hotkey string changed
        guard let configManager = appState?.configManagerRef else { return }
        let newHotkey = configManager.hotkey
        
        // Parse and update
        let (modifiers, keyCode) = parseHotkey(newHotkey)
        if modifiers != expectedModifiers || keyCode != expectedKeyCode {
            expectedModifiers = modifiers
            expectedKeyCode = keyCode
            Log.debug("Hotkey updated to: \(newHotkey) (keyCode: \(keyCode))")
        }
    }
    
    private func registerHotkey() {
        guard globalMonitor == nil else { return }  // Already registered
        
        // Parse the hotkey from settings
        if let configManager = appState?.configManagerRef {
            let (modifiers, keyCode) = parseHotkey(configManager.hotkey)
            expectedModifiers = modifiers
            expectedKeyCode = keyCode
        }
        
        // Global monitor for when app is not active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor for when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil  // Consume the event
            }
            return event
        }
        
        let hotkeyStr = appState?.configManagerRef.hotkey ?? "⌥Space"
        Log.debug("Hotkey \(hotkeyStr) registered successfully (keyCode: \(expectedKeyCode))")
    }
    
    private func unregisterHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    /// Parse hotkey string like "⌥Space", "⌘⇧K" into modifiers and key code
    private func parseHotkey(_ hotkey: String) -> (NSEvent.ModifierFlags, UInt16) {
        var modifiers: NSEvent.ModifierFlags = []
        var remaining = hotkey
        
        // Parse modifier symbols
        if remaining.contains("⌃") {
            modifiers.insert(.control)
            remaining = remaining.replacingOccurrences(of: "⌃", with: "")
        }
        if remaining.contains("⌥") {
            modifiers.insert(.option)
            remaining = remaining.replacingOccurrences(of: "⌥", with: "")
        }
        if remaining.contains("⇧") {
            modifiers.insert(.shift)
            remaining = remaining.replacingOccurrences(of: "⇧", with: "")
        }
        if remaining.contains("⌘") {
            modifiers.insert(.command)
            remaining = remaining.replacingOccurrences(of: "⌘", with: "")
        }
        
        // Parse key name
        let keyName = remaining.trimmingCharacters(in: .whitespaces)
        let keyCode = keyCodeForName(keyName)
        
        return (modifiers, keyCode)
    }
    
    /// Convert key name to key code
    private func keyCodeForName(_ name: String) -> UInt16 {
        switch name.lowercased() {
        case "space": return 49
        case "return", "enter", "↵": return 36
        case "tab": return 48
        case "delete", "backspace": return 51
        case "escape", "esc": return 53
        case "←", "left": return 123
        case "→", "right": return 124
        case "↓", "down": return 125
        case "↑", "up": return 126
        case "f1": return 122
        case "f2": return 120
        case "f3": return 99
        case "f4": return 118
        case "f5": return 96
        case "f6": return 97
        case "f7": return 98
        case "f8": return 100
        case "f9": return 101
        case "f10": return 109
        case "f11": return 103
        case "f12": return 111
        // Letters
        case "a": return 0
        case "b": return 11
        case "c": return 8
        case "d": return 2
        case "e": return 14
        case "f": return 3
        case "g": return 5
        case "h": return 4
        case "i": return 34
        case "j": return 38
        case "k": return 40
        case "l": return 37
        case "m": return 46
        case "n": return 45
        case "o": return 31
        case "p": return 35
        case "q": return 12
        case "r": return 15
        case "s": return 1
        case "t": return 17
        case "u": return 32
        case "v": return 9
        case "w": return 13
        case "x": return 7
        case "y": return 16
        case "z": return 6
        // Numbers
        case "0": return 29
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25
        default:
            // For single character, try to get keyCode from character
            if name.count == 1 {
                return keyCodeForCharacter(name.uppercased())
            }
            return 49  // Default to Space
        }
    }
    
    private func keyCodeForCharacter(_ char: String) -> UInt16 {
        // Map single characters to key codes
        guard let scalar = char.unicodeScalars.first else { return 49 }
        let code = scalar.value
        
        // A-Z
        if code >= 65 && code <= 90 {
            let letterKeyCodes: [UInt16] = [0, 11, 8, 2, 14, 3, 5, 4, 34, 38, 40, 37, 46, 45, 31, 35, 12, 15, 1, 17, 32, 9, 13, 7, 16, 6]
            return letterKeyCodes[Int(code - 65)]
        }
        
        return 49  // Default to Space
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if the pressed key matches our expected hotkey
        let pressedModifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        
        if pressedModifiers == expectedModifiers && event.keyCode == expectedKeyCode {
            Task { @MainActor [weak self] in
                self?.toggleCommandBar()
            }
            return true
        }
        return false
    }
    
    private func toggleCommandBar() {
        guard let appState else { return }
        
        if let window = appState.commandBarWindowRef, window.isVisible {
            appState.hideCommandBar()
        } else {
            appState.showCommandBar()
        }
    }
}

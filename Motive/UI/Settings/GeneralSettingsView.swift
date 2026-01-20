//
//  GeneralSettingsView.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Startup
            SettingsCard(title: "Startup", icon: "power") {
                SettingsRow(label: "Launch at Login", description: "Start Motive when you log in", showDivider: false) {
                    Toggle("", isOn: $configManager.launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(Color.Velvet.primary)
                }
            }
            
            // Keyboard
            SettingsCard(title: "Keyboard", icon: "keyboard") {
                SettingsRow(label: "Global Hotkey", description: "Summon the Command Bar", showDivider: false) {
                    HotkeyRecorderView(hotkey: $configManager.hotkey)
                        .frame(width: 120, height: 28)
                }
            }

            // Appearance
            SettingsCard(title: "Appearance", icon: "circle.lefthalf.filled") {
                SettingsRow(label: "Theme", description: "Choose light, dark, or follow system", showDivider: false) {
                    Picker("", selection: Binding(
                        get: { configManager.appearanceMode },
                        set: { configManager.appearanceMode = $0 }
                    )) {
                        ForEach(ConfigManager.AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
        }
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: String

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let button = HotkeyRecorderButton()
        button.onHotkeyChange = { hotkey = $0 }
        button.currentHotkey = hotkey
        return button
    }

    func updateNSView(_ nsView: HotkeyRecorderButton, context: Context) {
        nsView.currentHotkey = hotkey
    }
}

final class HotkeyRecorderButton: NSButton {
    var onHotkeyChange: ((String) -> Void)?
    var currentHotkey: String = "" {
        didSet {
            updateTitle()
        }
    }
    private var isRecording = false
    private var localMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    private func setupAppearance() {
        bezelStyle = .rounded
        isBordered = true
        font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        wantsLayer = true
        target = self
        action = #selector(buttonClicked)
        updateTitle()
    }
    
    private func updateTitle() {
        if isRecording {
            title = "Press keys..."
        } else if currentHotkey.isEmpty {
            title = "Click to record"
        } else {
            title = currentHotkey
        }
    }
    
    @objc private func buttonClicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        updateTitle()
        
        // Listen for key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            if event.type == .keyDown {
                let symbols = self.modifierSymbols(for: event.modifierFlags)
                let key = self.keyName(for: event)
                
                // Only record if there's a modifier or it's a special key
                if !symbols.isEmpty || self.isSpecialKey(event.keyCode) {
                    let value = symbols + key
                    self.currentHotkey = value
                    self.onHotkeyChange?(value)
                    self.stopRecording()
                    return nil // Consume the event
                }
            }
            return event
        }
        
        // Stop recording when clicking elsewhere
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.stopRecording()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        updateTitle()
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func isSpecialKey(_ keyCode: UInt16) -> Bool {
        // Function keys, arrows, etc.
        return [49, 36, 48, 51, 53, 123, 124, 125, 126].contains(keyCode) ||
               (keyCode >= 122 && keyCode <= 126) // F keys start around here
    }

    private func modifierSymbols(for flags: NSEvent.ModifierFlags) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        return symbols
    }
    
    private func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? ""
        }
    }
    
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

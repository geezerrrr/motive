//
//  GeneralSettingsView.swift
//  Motive
//
//  Compact unified settings layout
//

import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showRestartAlert = false
    
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Startup Section
            SettingSection(L10n.Settings.startup) {
                SettingRow(L10n.Settings.launchAtLogin, showDivider: false) {
                    Toggle("", isOn: $configManager.launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(Color.Aurora.primary)
                }
            }
            
            // Appearance Section
            SettingSection(L10n.Settings.appearance) {
                SettingRow(L10n.Settings.theme) {
                    menuPicker(
                        selection: Binding(
                            get: { configManager.appearanceMode },
                            set: { configManager.appearanceMode = $0 }
                        ),
                        options: ConfigManager.AppearanceMode.allCases,
                        label: { $0.localizedName }
                    )
                }
                
                SettingRow(L10n.Settings.language, showDivider: false) {
                    menuPicker(
                        selection: Binding(
                            get: { configManager.language },
                            set: { newValue in
                                let oldValue = configManager.language
                                configManager.language = newValue
                                if oldValue != newValue {
                                    showRestartAlert = true
                                }
                            }
                        ),
                        options: ConfigManager.Language.allCases,
                        label: { $0.displayName }
                    )
                }
            }
            
            // Keyboard Section
            SettingSection(L10n.Settings.keyboard) {
                SettingRow(L10n.Settings.globalHotkey, showDivider: false) {
                    HotkeyRecorderView(hotkey: $configManager.hotkey)
                        .frame(width: 140, height: 32)
                }
            }
            
            Spacer()
        }
        .alert(L10n.Settings.language, isPresented: $showRestartAlert) {
            Button(L10n.cancel) { }
            Button(L10n.Settings.restartNow) {
                restartApp()
            }
        } message: {
            Text(L10n.Settings.languageRestartRequired)
        }
    }
    
    private func restartApp() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        
        let script = """
        sleep 0.5
        open "\(bundlePath)"
        """
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]
        
        do {
            try task.run()
        } catch {
            Log.error("Failed to restart: \(error)")
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - Custom Menu Picker
    
    /// Creates a consistent-width menu picker
    private func menuPicker<T: Hashable>(
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(label(option)) {
                    selection.wrappedValue = option
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(label(selection.wrappedValue))
                    .font(.system(size: 13))
                    .foregroundColor(Color.Aurora.textPrimary)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.Aurora.textSecondary)
            }
            .frame(width: 140, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
            title = L10n.Settings.pressKeys
        } else if currentHotkey.isEmpty {
            title = L10n.Settings.clickToRecord
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
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            if event.type == .keyDown {
                let symbols = self.modifierSymbols(for: event.modifierFlags)
                let key = self.keyName(for: event)
                
                if !symbols.isEmpty || self.isSpecialKey(event.keyCode) {
                    let value = symbols + key
                    self.currentHotkey = value
                    self.onHotkeyChange?(value)
                    self.stopRecording()
                    return nil
                }
            }
            return event
        }
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
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
        let specialKeys: Set<UInt16> = [49, 36, 48, 51, 53, 123, 124, 125, 126]
        let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        return specialKeys.contains(keyCode) || functionKeys.contains(keyCode)
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
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
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

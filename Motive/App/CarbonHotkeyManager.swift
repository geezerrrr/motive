//
//  CarbonHotkeyManager.swift
//  Motive
//
//  Created by antigravity on 2026/2/22.
//

import AppKit
import Carbon

/// A wrapper around the Carbon HotKey API for reliable, non-leaking global shortcuts.
final class CarbonHotkeyManager {
    private static let signature: OSType = 0x4D54_5645 // "MTVE" (Motive)

    private let hotKeyIdentifier: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// - Parameter id: Unique ID per manager so multiple hotkeys can coexist.
    init(id: UInt32 = 1) {
        hotKeyIdentifier = id
    }

    /// Triggered when the registered hotkey is pressed.
    var onKeyDown: (() -> Void)?

    /// Register a new global hotkey.
    /// Returns true if successful. Replaces any previous registration.
    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        unregister()

        // Map NSEvent modifiers to Carbon-style modifiers
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        // Unique ID for this hotkey
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: hotKeyIdentifier)

        // Define the event type to listen for
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Global handler function (C-compatible)
        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<CarbonHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            // Every installed handler sees every hotkey press; only handle our own
            var pressedID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedID
            )
            guard status == noErr,
                  pressedID.signature == CarbonHotkeyManager.signature,
                  pressedID.id == manager.hotKeyIdentifier
            else { return OSStatus(eventNotHandledErr) }

            // Execute callback on main actor
            DispatchQueue.main.async {
                manager.onKeyDown?()
            }

            return noErr
        }

        // Install the handler
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard result == noErr else {
            Log.error("Failed to install Carbon event handler (OSStatus: \(result))")
            return false
        }

        // Register the actual hotkey
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            Log.error("Failed to register Carbon HotKey (OSStatus: \(status))")
            return false
        }

        return true
    }

    /// Remove existing hotkey registration and handlers.
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}

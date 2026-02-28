//
//  CommandBarTextField.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import SwiftUI

struct CommandBarTextField: View {
    @Binding var text: String
    var placeholder: String
    var isDisabled: Bool
    var onSubmit: () -> Void
    var onCmdDelete: () -> Void
    var onCmdN: (() -> Void)?
    var onCmdReturn: (() -> Void)?
    var onEscape: (() -> Void)?
    @Binding var inputHeight: CGFloat

    private static let maxLines = 6

    var body: some View {
        GrowingTextView(
            text: $text,
            placeholder: placeholder,
            font: .systemFont(ofSize: 17, weight: .regular),
            textColor: NSColor(Color.Aurora.textPrimary),
            placeholderColor: commandBarPlaceholderColor,
            maxLines: Self.maxLines,
            isDisabled: isDisabled,
            onSubmit: onSubmit,
            onEscape: onEscape,
            height: $inputHeight
        )
        .frame(height: inputHeight)
        .background(KeyboardShortcutMonitor(
            onCmdDelete: onCmdDelete,
            onCmdN: onCmdN,
            onCmdReturn: onCmdReturn,
            onEscape: onEscape
        ))
    }

    private var commandBarPlaceholderColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor(white: 1.0, alpha: 0.25)
                : NSColor(hex: "757575")
        }
    }
}

// MARK: - Keyboard Shortcut Monitor (Cmd+Delete, Cmd+N, Cmd+Return, ESC)

/// Installs a local NSEvent monitor for command-level keyboard shortcuts.
/// These shortcuts work regardless of which responder has focus within the window.
private struct KeyboardShortcutMonitor: NSViewRepresentable {
    var onCmdDelete: (() -> Void)?
    var onCmdN: (() -> Void)?
    var onCmdReturn: (() -> Void)?
    var onEscape: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.setupMonitor()
        return view
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.onCmdDelete = onCmdDelete
        context.coordinator.onCmdN = onCmdN
        context.coordinator.onCmdReturn = onCmdReturn
        context.coordinator.onEscape = onEscape
    }

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var onCmdDelete: (() -> Void)?
        var onCmdN: (() -> Void)?
        var onCmdReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        init(_ parent: KeyboardShortcutMonitor) {
            onCmdDelete = parent.onCmdDelete
            onCmdN = parent.onCmdN
            onCmdReturn = parent.onCmdReturn
            onEscape = parent.onEscape
        }

        func setupMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                if event.keyCode == 53 {
                    self.onEscape?()
                    return nil
                }

                guard event.modifierFlags.contains(.command) else { return event }

                if event.keyCode == 51 {
                    self.onCmdDelete?()
                    return nil
                }
                if event.keyCode == 45 {
                    self.onCmdN?()
                    return nil
                }
                if event.keyCode == 36 {
                    self.onCmdReturn?()
                    return nil
                }

                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

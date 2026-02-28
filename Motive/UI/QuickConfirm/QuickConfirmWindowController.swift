//
//  QuickConfirmWindowController.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import SwiftUI

/// A lightweight panel that appears below the status bar for quick confirmations
@MainActor
final class QuickConfirmWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    /// Show the quick confirm panel below the status bar
    func show(
        request: PermissionRequest,
        anchorFrame: NSRect?,
        onResponse: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onPreviewPlan: (() -> Void)? = nil
    ) {
        // Dismiss any existing panel
        dismiss()

        // Create the SwiftUI view
        let view = QuickConfirmView(
            request: request,
            onResponse: { [weak self] response in
                onResponse(response)
                self?.dismiss()
            },
            onCancel: { [weak self] in
                onCancel()
                self?.dismiss()
            },
            onPreviewPlan: onPreviewPlan
        )

        // Create hosting view
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.sizingOptions = .intrinsicContentSize
        hosting.setFrameSize(hosting.fittingSize)
        hostingView = hosting

        // Create panel — use KeyablePanel so text fields can receive input
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // SwiftUI handles shadow
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = hosting

        self.panel = panel

        // Position below status bar
        positionPanel(anchorFrame: anchorFrame, panelSize: hosting.fittingSize)

        // Show with animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.hostingView = nil
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private func positionPanel(anchorFrame: NSRect?, panelSize: NSSize) {
        guard let panel else { return }
        let screen = screenForAnchor(anchorFrame: anchorFrame) ?? panel.screen ?? NSScreen.main
        guard let screen else { return }

        let screenFrame = screen.visibleFrame
        var origin = if let anchor = anchorFrame {
            // Position below the status bar button, centered
            NSPoint(
                x: anchor.midX - panelSize.width / 2,
                y: anchor.minY - panelSize.height - 8
            )
        } else {
            // Fallback: top-right corner
            NSPoint(
                x: screenFrame.maxX - panelSize.width - 20,
                y: screenFrame.maxY - panelSize.height - 30
            )
        }

        // Keep within screen bounds
        origin.x = max(screenFrame.minX + 10, min(origin.x, screenFrame.maxX - panelSize.width - 10))
        origin.y = max(screenFrame.minY + 10, origin.y)

        panel.setFrameOrigin(origin)
    }

    private func screenForAnchor(anchorFrame: NSRect?) -> NSScreen? {
        guard let anchorFrame else {
            return KeyablePanel.screenForMouse()
        }
        let anchorPoint = NSPoint(x: anchorFrame.midX, y: anchorFrame.midY)
        return NSScreen.screens.first { $0.frame.contains(anchorPoint) } ?? KeyablePanel.screenForMouse()
    }
}

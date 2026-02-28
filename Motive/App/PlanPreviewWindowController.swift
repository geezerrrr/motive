//
//  PlanPreviewWindowController.swift
//  Motive
//

import AppKit
import SwiftUI

@MainActor
final class PlanPreviewWindowController {
    private var window: NSWindow?

    func show(planFilePath: String) {
        let content = PlanPreviewView(planFilePath: planFilePath) { [weak self] in
            self?.close()
        }
        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.sizingOptions = .intrinsicContentSize

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = min(max(screen.width * 0.62, 680), 980)
        let height = min(max(screen.height * 0.68, 520), 860)
        let origin = NSPoint(
            x: screen.midX - width / 2,
            y: screen.midY - height / 2
        )

        if let window {
            window.contentView = hosting
            window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true, animate: true)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.Drawer.planPreview
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func close() {
        window?.orderOut(nil)
    }
}

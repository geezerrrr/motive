//
//  AppState+CommandBar.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI

extension AppState {
    /// Whether the command bar is currently visible
    var isCommandBarVisible: Bool {
        commandBarController?.isVisible ?? false
    }
    
    func showCommandBar() {
        guard let commandBarController else {
            Log.debug("commandBarController is nil!")
            return
        }
        
        // Only trigger reset if CommandBar is currently hidden
        // This prevents unnecessary re-renders when already visible
        if !commandBarController.isVisible {
            commandBarResetTrigger += 1
        }
        
        commandBarController.show()
    }

    func hideCommandBar() {
        commandBarController?.hide()
    }

    func updateCommandBarHeight(for modeName: String) {
        commandBarController?.updateHeightForMode(modeName, animated: false)
    }

    func updateCommandBarHeight(to height: CGFloat) {
        commandBarController?.updateHeight(to: height, animated: false)
    }

    /// Suppress or allow auto-hide when command bar loses focus
    func setCommandBarAutoHideSuppressed(_ suppressed: Bool) {
        commandBarController?.suppressAutoHide = suppressed
    }

    /// Refocus the command bar input field
    func refocusCommandBar() {
        commandBarController?.focusFirstResponder()
    }
}

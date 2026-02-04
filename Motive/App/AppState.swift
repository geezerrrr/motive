//
//  AppState.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum MenuBarState: String, Sendable {
        case idle
        case reasoning
        case executing
    }

    enum SessionStatus: String, Sendable {
        case idle
        case running
        case completed
        case failed
        case interrupted
    }

    @Published var menuBarState: MenuBarState = .idle
    @Published var messages: [ConversationMessage] = []
    @Published var sessionStatus: SessionStatus = .idle
    @Published var lastErrorMessage: String?
    @Published var currentToolName: String?
    @Published var currentToolInput: String?  // Current tool's input (e.g., command, file path)
    @Published var commandBarResetTrigger: Int = 0  // Increment to trigger reset
    @Published var sessionListRefreshTrigger: Int = 0  // Increment to refresh session list

    let configManager: ConfigManager
    lazy var bridge: OpenCodeBridge = {
        OpenCodeBridge { [weak self] event in
            await MainActor.run { self?.handle(event: event) }
        }
    }()
    var modelContext: ModelContext?
    var currentSession: Session?
    var commandBarController: CommandBarWindowController?
    var statusBarController: StatusBarController?
    var drawerWindowController: DrawerWindowController?
    var quickConfirmController: QuickConfirmWindowController?
    var hasStarted = false

    // CloudKit for remote commands from iOS
    lazy var cloudKitManager: CloudKitManager = CloudKitManager()
    var currentRemoteCommandId: String?
    
    var cancellables = Set<AnyCancellable>()

    var configManagerRef: ConfigManager { configManager }
    var commandBarWindowRef: NSWindow? { commandBarController?.getWindow() }
    var currentSessionRef: Session? { currentSession }

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }
}

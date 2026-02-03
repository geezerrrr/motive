//
//  AppState+Lifecycle.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

extension AppState {
    func attachModelContext(_ context: ModelContext) {
        modelContext = context
        createCommandBarIfNeeded()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // Ensure workspace exists (creates bootstrap files for fresh install)
        Task { @MainActor in
            do {
                try await WorkspaceManager.shared.ensureWorkspace()
            } catch {
                Log.config("Failed to ensure workspace: \(error)")
            }
        }
        
        // Ensure default project directory exists
        configManager.ensureDefaultProjectDirectory()
        configManager.ensureCurrentProjectInRecents()

        // Preload API keys early to trigger Keychain prompts at startup
        // This avoids scattered prompts during usage
        configManager.preloadAPIKeys()

        // Initialize SkillManager with ConfigManager to enable browser automation skill
        SkillManager.shared.setConfigManager(configManager)
        SkillRegistry.shared.setConfigManager(configManager)

        PermissionManager.shared.startServers()
        observePermissionRequests()
        observeMenuBarState()
        Task {
            await configureBridge()
            await bridge.startIfNeeded()
        }
        ensureStatusBar()
        drawerWindowController = DrawerWindowController(
            rootView: DrawerView()
                .environmentObject(self)
                .environmentObject(configManager)
        )
        // Configure settings window controller
        SettingsWindowController.shared.configure(configManager: configManager, appState: self)
        updateStatusBar()

        // Start CloudKit listener for remote commands from iOS
        startCloudKitListener()
    }

    /// Start listening for remote commands from iOS via CloudKit
    private func startCloudKitListener() {
        cloudKitManager.onCommandReceived = { [weak self] command in
            guard let self else { return }
            self.handleRemoteCommand(command)
        }
        cloudKitManager.startListening(appState: self)
        Log.debug("CloudKit listener started for remote commands")
    }

    /// Handle a remote command received from iOS
    private func handleRemoteCommand(_ command: RemoteCommand) {
        Log.debug("Received remote command: \(command.instruction)")

        // Store the remote command ID for status updates
        currentRemoteCommandId = command.id

        // Use the configured project directory as working directory
        let cwd = configManager.currentProjectURL.path

        // Submit the intent just like local commands
        submitIntent(command.instruction, workingDirectory: cwd)
    }

    func ensureStatusBar() {
        if statusBarController == nil {
            statusBarController = StatusBarController(delegate: self)
            statusBarController?.configure(configManager: configManager)
        }
        updateStatusBar()
    }

    func updateStatusBar() {
        let isWaiting = PermissionManager.shared.isShowingRequest
        let inputType = PermissionManager.shared.currentRequest?.type == .question ? "Question" : "Permission"
        statusBarController?.update(
            state: menuBarState,
            toolName: currentToolName,
            isWaitingForInput: isWaiting,
            inputType: inputType
        )
    }

    private func observeMenuBarState() {
        // Debounce menu bar state updates to avoid "multiple times per frame" warning
        $menuBarState
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main) // ~1 frame at 60fps
            .sink { [weak self] state in
                guard let self else { return }
                let isWaiting = PermissionManager.shared.isShowingRequest
                let inputType = PermissionManager.shared.currentRequest?.type == .question ? "Question" : "Permission"
                self.statusBarController?.update(
                    state: state,
                    toolName: self.currentToolName,
                    isWaitingForInput: isWaiting,
                    inputType: inputType
                )
            }
            .store(in: &cancellables)
    }

    private func observePermissionRequests() {
        PermissionManager.shared.$currentRequest
            .receive(on: RunLoop.main)
            .sink { [weak self] request in
                guard let self else { return }

                if let request = request {
                    // If this is a remote command, send question to iOS via CloudKit
                    if let commandId = self.currentRemoteCommandId {
                        self.sendQuestionToiOS(request: request, commandId: commandId)
                    } else if self.drawerWindowController?.isVisible == true {
                        // Drawer will handle it via its own UI
                    } else {
                        self.showQuickConfirm(for: request)
                    }
                } else {
                    // Dismiss quick confirm if request is cleared
                    self.quickConfirmController?.dismiss()
                }

                // Update status bar to show waiting state
                self.updateStatusBar()
            }
            .store(in: &cancellables)
    }

    /// Send a permission/question request to iOS via CloudKit for remote commands
    private func sendQuestionToiOS(request: PermissionRequest, commandId: String) {
        Log.debug("Sending question to iOS via CloudKit for remote command: \(commandId)")
        
        let optionLabels = request.options?.map { $0.label } ?? ["Yes", "No"]
        let header = request.header ?? ""
        let question = request.question ?? "Question from Mac"
        let questionText = header.isEmpty ? question : "\(header): \(question)"
        
        Task {
            let response = await cloudKitManager.sendPermissionRequest(
                commandId: commandId,
                question: questionText,
                options: optionLabels
            )
            
            // Build response and send to PermissionManager
            let permResponse: PermissionResponse
            if let response = response {
                Log.debug("Got response from iOS: \(response)")
                if request.type == .question {
                    permResponse = PermissionResponse(
                        requestId: request.id,
                        taskId: request.taskId,
                        decision: .allow,
                        selectedOptions: [response],
                        customText: response
                    )
                } else {
                    let approved = response.lowercased() == "yes" || response.lowercased() == "allow" || response.lowercased() == "approved"
                    permResponse = PermissionResponse(
                        requestId: request.id,
                        taskId: request.taskId,
                        decision: approved ? .allow : .deny
                    )
                }
            } else {
                Log.debug("No response from iOS, denying request")
                permResponse = PermissionResponse(
                    requestId: request.id,
                    taskId: request.taskId,
                    decision: .deny
                )
            }
            
            PermissionManager.shared.respond(with: permResponse)
            updateStatusBar()
        }
    }

    private func showQuickConfirm(for request: PermissionRequest) {
        if quickConfirmController == nil {
            quickConfirmController = QuickConfirmWindowController()
        }

        // Get status bar button frame for positioning
        let anchorFrame = statusBarController?.buttonFrame

        quickConfirmController?.show(
            request: request,
            anchorFrame: anchorFrame,
            onResponse: { [weak self] response in
                // Handle the response
                let permResponse: PermissionResponse
                if request.type == .question {
                    permResponse = PermissionResponse(
                        requestId: request.id,
                        taskId: request.taskId,
                        decision: .allow,
                        selectedOptions: [response],
                        customText: response
                    )
                } else {
                    let approved = response == "approved"
                    permResponse = PermissionResponse(
                        requestId: request.id,
                        taskId: request.taskId,
                        decision: approved ? .allow : .deny
                    )
                }
                PermissionManager.shared.respond(with: permResponse)
                self?.updateStatusBar()
            },
            onCancel: { [weak self] in
                // Cancel/deny the request
                let permResponse = PermissionResponse(
                    requestId: request.id,
                    taskId: request.taskId,
                    decision: .deny
                )
                PermissionManager.shared.respond(with: permResponse)
                self?.updateStatusBar()
            }
        )
    }

    private func createCommandBarIfNeeded() {
        guard commandBarController == nil, let modelContext else { return }
        let rootView = CommandBarView()
            .environmentObject(self)
            .environmentObject(configManager)
            .environment(\.modelContext, modelContext)
        commandBarController = CommandBarWindowController(rootView: rootView)
        // No pre-warm needed - window uses defer:true and alpha:0
        // First show will be slightly slower but avoids visual glitches
    }
}

//
//  CloudKitManager.swift
//  Motive
//
//  CloudKit manager for receiving remote commands from iOS
//

import CloudKit
import Foundation

/// Manages CloudKit communication for remote commands from iOS
@MainActor
final class CloudKitManager {
    
    /// Callback when a new command is received
    var onCommandReceived: ((RemoteCommand) -> Void)?
    
    /// Callback when a permission request response is received
    var onPermissionResponse: ((String, String) -> Void)?  // (requestId, response)
    
    private var subscriptionId: String?
    private var pollTask: Task<Void, Never>?
    private weak var appState: AppState?
    
    /// Whether CloudKit is enabled (checked at startup)
    private var isEnabled = false
    
    // MARK: - Public Methods
    
    /// Start listening for remote commands from iOS
    func startListening(appState: AppState) {
        self.appState = appState
        
        // Check if CloudKit entitlement is present before attempting any CloudKit operations
        guard hasCloudKitEntitlement else {
            Log.debug("CloudKitManager: CloudKit not available (missing entitlement or not signed in). iOS Remote disabled.")
            return
        }
        
        isEnabled = true
        
        Task {
            // Setup CloudKit subscription for real-time updates
            await setupSubscription()
            
            // Initial poll for any pending commands
            await pollForPendingCommands()
            
            // Start periodic polling as backup
            startPolling()
        }
        
        Log.debug("CloudKitManager: Started listening for remote commands")
    }
    
    /// Stop listening for remote commands
    func stopListening() {
        pollTask?.cancel()
        pollTask = nil
        Log.debug("CloudKitManager: Stopped listening")
    }
    
    // MARK: - Command Status Updates
    
    /// Update command status to running
    func startCommand(commandId: String, toolName: String? = nil) {
        guard isEnabled else { return }
        Task {
            await updateCommandStatus(
                commandId: commandId,
                status: .running,
                toolName: toolName
            )
        }
    }
    
    /// Update command with current tool name
    func updateProgress(commandId: String, toolName: String?, progress: Double? = nil) {
        guard isEnabled else { return }
        Task {
            await updateCommandStatus(
                commandId: commandId,
                status: .running,
                toolName: toolName,
                progress: progress
            )
        }
    }
    
    /// Mark command as completed
    func completeCommand(commandId: String, result: String?) {
        guard isEnabled else { return }
        Task {
            await updateCommandStatus(
                commandId: commandId,
                status: .completed,
                result: result
            )
        }
    }
    
    /// Mark command as failed
    func failCommand(commandId: String, error: String) {
        guard isEnabled else { return }
        Task {
            await updateCommandStatus(
                commandId: commandId,
                status: .failed,
                errorMessage: error
            )
        }
    }
    
    // MARK: - Permission Requests
    
    /// Send a permission request to iOS for user confirmation
    func sendPermissionRequest(commandId: String, question: String, options: [String]) async -> String? {
        guard isEnabled else { return nil }
        Log.debug("CloudKitManager: Creating permission request for command \(commandId)")
        Log.debug("CloudKitManager: Question: \(question)")
        Log.debug("CloudKitManager: Options: \(options)")
        
        let record = RemotePermissionRequest.createRecord(
            commandId: commandId,
            question: question,
            options: options
        )
        
        do {
            Log.debug("CloudKitManager: Saving permission request to CloudKit...")
            let savedRecord = try await motivePrivateDatabase.save(record)
            let requestId = savedRecord.recordID.recordName
            Log.debug("CloudKitManager: Sent permission request \(requestId)")
            
            // Wait for response (poll every 2 seconds, timeout after 5 minutes)
            return await waitForPermissionResponse(requestId: requestId, timeout: 300)
        } catch {
            Log.debug("CloudKitManager: Failed to send permission request: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscription() async {
        let predicate = NSPredicate(format: "status == %@", RemoteCommand.CommandStatus.pending.rawValue)
        let subscription = CKQuerySubscription(
            recordType: RemoteCommand.recordType,
            predicate: predicate,
            options: [.firesOnRecordCreation]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        do {
            let savedSubscription = try await motivePrivateDatabase.save(subscription)
            subscriptionId = savedSubscription.subscriptionID
            Log.debug("CloudKitManager: Subscription created: \(savedSubscription.subscriptionID)")
        } catch {
            Log.debug("CloudKitManager: Failed to create subscription: \(error)")
        }
    }
    
    private func startPolling() {
        // Poll every 5 seconds as backup for push notifications
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await self?.pollForPendingCommands()
            }
        }
    }
    
    private func pollForPendingCommands() async {
        let predicate = NSPredicate(format: "status == %@", RemoteCommand.CommandStatus.pending.rawValue)
        let query = CKQuery(recordType: RemoteCommand.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            let (matchResults, _) = try await motivePrivateDatabase.records(matching: query)
            
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    let command = RemoteCommand(record: record)
                    
                    // Check if this command is for this device (or no specific target)
                    let myDeviceId = getDeviceIdentifier()
                    if command.targetDeviceId == nil || command.targetDeviceId == myDeviceId {
                        Log.debug("CloudKitManager: Found pending command: \(command.instruction)")
                        
                        // Mark as running immediately to prevent duplicate processing
                        await updateCommandStatus(commandId: command.id, status: .running)
                        
                        // Notify handler
                        onCommandReceived?(command)
                    }
                }
            }
        } catch {
            Log.debug("CloudKitManager: Poll error: \(error)")
        }
    }
    
    private func updateCommandStatus(
        commandId: String,
        status: RemoteCommand.CommandStatus,
        toolName: String? = nil,
        progress: Double? = nil,
        result: String? = nil,
        errorMessage: String? = nil
    ) async {
        let recordID = CKRecord.ID(recordName: commandId)
        
        // Retry up to 3 times on conflict
        for attempt in 1...3 {
            do {
                let record = try await motivePrivateDatabase.record(for: recordID)
                record[RemoteCommand.FieldKey.status.rawValue] = status.rawValue
                record[RemoteCommand.FieldKey.updatedAt.rawValue] = Date()
                
                if let toolName = toolName {
                    record[RemoteCommand.FieldKey.toolName.rawValue] = toolName
                }
                if let progress = progress {
                    record[RemoteCommand.FieldKey.progress.rawValue] = progress
                }
                if let result = result {
                    record[RemoteCommand.FieldKey.result.rawValue] = result
                }
                if let errorMessage = errorMessage {
                    record[RemoteCommand.FieldKey.errorMessage.rawValue] = errorMessage
                }
                
                try await motivePrivateDatabase.save(record)
                Log.debug("CloudKitManager: Updated command \(commandId) to \(status.rawValue)")
                return  // Success, exit retry loop
            } catch let error as CKError where error.code == .serverRecordChanged {
                // Conflict - retry with fresh record
                if attempt < 3 {
                    Log.debug("CloudKitManager: Conflict on attempt \(attempt), retrying...")
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s delay
                    continue
                }
                Log.debug("CloudKitManager: Conflict after 3 attempts, giving up")
            } catch {
                Log.debug("CloudKitManager: Failed to update command status: \(error)")
                return
            }
        }
    }
    
    private func waitForPermissionResponse(requestId: String, timeout: TimeInterval) async -> String? {
        let startTime = Date()
        let recordID = CKRecord.ID(recordName: requestId)
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let record = try await motivePrivateDatabase.record(for: recordID)
                if let response = record[RemotePermissionRequest.FieldKey.response.rawValue] as? String {
                    Log.debug("CloudKitManager: Got permission response: \(response)")
                    return response
                }
            } catch {
                Log.debug("CloudKitManager: Error fetching permission request: \(error)")
            }
            
            // Wait 2 seconds before next poll
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        Log.debug("CloudKitManager: Permission request timed out")
        return nil
    }
}

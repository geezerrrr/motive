//
//  MotiveApp.swift
//  Motive
//
//  Created by geezerrrr on 2026/1/19.
//

import SwiftUI
import SwiftData

@main
struct MotiveApp: App {
    @StateObject private var configManager: ConfigManager
    @StateObject private var appState: AppState
    private let modelContainer: ModelContainer
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let configManager = ConfigManager()
        let container: ModelContainer
        
        // Use local-only storage in Application Support/Motive/
        // Our CloudKit usage is separate (CKRecord for remote commands)
        let schema = Schema([Session.self, LogEntry.self])
        let storeURL = Self.storeURL()
        
        // Ensure the Motive directory exists
        let motiveDir = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: motiveDir, withIntermediateDirectories: true)
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none  // Explicitly disable CloudKit sync
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema mismatch or corrupted database - delete and retry
            print("[Motive] ModelContainer failed: \(error). Recreating database...")
            Self.deleteCorruptedDatabase()
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
        
        // Create AppState with modelContext directly (no need for SwiftUI environment)
        let appState = AppState(configManager: configManager)
        appState.attachModelContext(container.mainContext)
        
        _configManager = StateObject(wrappedValue: configManager)
        _appState = StateObject(wrappedValue: appState)
        modelContainer = container
        appDelegate.appState = appState
        // Note: appState.start() is called in AppDelegate.applicationDidFinishLaunching
        // to ensure GUI connection is fully established before creating NSStatusItem
    }
    
    /// Get the SwiftData store URL in Application Support/Motive/
    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Motive/motive.store")
    }
    
    /// Delete corrupted SwiftData database files to allow recreation
    private static func deleteCorruptedDatabase() {
        let storeURL = Self.storeURL()
        let filesToDelete = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        for url in filesToDelete {
            try? FileManager.default.removeItem(at: url)
        }
        print("[Motive] Deleted corrupted database files at \(storeURL.path)")
    }
 
    var body: some Scene {
        // Use Settings scene instead of WindowGroup to avoid creating a visible window
        // This is a menu bar only app - all UI is managed via AppKit windows
        Settings {
            EmptyView()
        }
        .commands {
            // Disable default File menu commands that conflict with our shortcuts
            CommandGroup(replacing: .newItem) {
                // Custom "New Session" command that delegates to AppState
                Button("New Session") {
                    appState.startNewEmptySession()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // Custom Settings command using our window controller
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

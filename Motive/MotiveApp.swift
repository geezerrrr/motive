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
        do {
            container = try ModelContainer(for: Session.self, LogEntry.self)
        } catch {
            // Schema mismatch or corrupted database - delete and retry
            print("[Motive] ModelContainer failed: \(error). Recreating database...")
            Self.deleteCorruptedDatabase()
            do {
                container = try ModelContainer(for: Session.self, LogEntry.self)
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
    
    /// Delete corrupted SwiftData database files to allow recreation
    private static func deleteCorruptedDatabase() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        // SwiftData stores in Application Support/default.store
        let defaultStoreURL = appSupport.appendingPathComponent("default.store")
        let filesToDelete = [
            defaultStoreURL,
            defaultStoreURL.appendingPathExtension("shm"),
            defaultStoreURL.appendingPathExtension("wal")
        ]
        for url in filesToDelete {
            try? FileManager.default.removeItem(at: url)
        }
        print("[Motive] Deleted corrupted database files")
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

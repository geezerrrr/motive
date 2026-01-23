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
        let appState = AppState(configManager: configManager)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Session.self, LogEntry.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        } 
        _configManager = StateObject(wrappedValue: configManager)
        _appState = StateObject(wrappedValue: appState)
        modelContainer = container
        appDelegate.appState = appState
        // Note: appState.start() is called in AppDelegate.applicationDidFinishLaunching
        // to ensure GUI connection is fully established before creating NSStatusItem
    }
 
    var body: some Scene {
        WindowGroup {
            CommandBarRootView()
                .environmentObject(configManager)
                .environmentObject(appState)
                .applyColorScheme(configManager.appearanceMode.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
                .environmentObject(configManager)
                .environmentObject(appState)
                .applyColorScheme(configManager.appearanceMode.colorScheme)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyColorScheme(_ scheme: ColorScheme?) -> some View {
        if let scheme {
            self.environment(\.colorScheme, scheme)
        } else {
            self
        }
    }
}

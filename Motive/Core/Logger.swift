//
//  Logger.swift
//  Motive
//
//  Debug logging utility. Outputs in DEBUG builds or when Debug Mode is enabled.
//

import Foundation
import os.log

/// Logger that outputs in DEBUG builds or when user enables Debug Mode in Settings
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.velvet.motive"
    
    private static let appLogger = os.Logger(subsystem: subsystem, category: "App")
    private static let bridgeLogger = os.Logger(subsystem: subsystem, category: "Bridge")
    private static let permissionLogger = os.Logger(subsystem: subsystem, category: "Permission")
    private static let configLogger = os.Logger(subsystem: subsystem, category: "Config")
    
    /// Check if debug logging is enabled (DEBUG build or user setting)
    private static var isDebugEnabled: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "debugMode")
        #endif
    }
    
    /// Log general app messages
    static func debug(_ message: String, file: String = #file, function: String = #function) {
        guard isDebugEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        appLogger.debug("[\(filename):\(function)] \(message)")
    }
    
    /// Log OpenCode bridge messages
    static func bridge(_ message: String) {
        guard isDebugEnabled else { return }
        bridgeLogger.debug("\(message)")
    }
    
    /// Log permission-related messages
    static func permission(_ message: String) {
        guard isDebugEnabled else { return }
        permissionLogger.debug("\(message)")
    }
    
    /// Log configuration messages
    static func config(_ message: String) {
        guard isDebugEnabled else { return }
        configLogger.debug("\(message)")
    }
    
    /// Log errors (always logged, even in release)
    static func error(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        appLogger.error("[\(filename):\(function)] \(message)")
    }
    
    /// Log warnings (always logged)
    static func warning(_ message: String) {
        appLogger.warning("\(message)")
    }
}

//
//  Logger.swift
//  Motive
//
//  Structured logging with OSLog and privacy annotations.
//  
//  Privacy Levels:
//  - .public: Safe to log (file names, error types, status messages)
//  - .private: PII or sensitive (user input, API keys, paths with user data)
//  - .sensitive: Hashed in logs (session IDs, request IDs)
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
    private static let skillsLogger = os.Logger(subsystem: subsystem, category: "Skills")
    private static let sessionLogger = os.Logger(subsystem: subsystem, category: "Session")
    
    /// Check if debug logging is enabled (DEBUG build or user setting)
    private static var isDebugEnabled: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "debugMode")
        #endif
    }
    
    // MARK: - General Logging
    
    /// Log general app messages (public by default)
    /// Note: Uses .info level because .debug is not persisted in Release builds
    static func debug(_ message: String, file: String = #file, function: String = #function) {
        guard isDebugEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        appLogger.info("[\(filename, privacy: .public):\(function, privacy: .public)] \(message, privacy: .public)")
    }
    
    /// Log sensitive debug messages (private - not visible in Console.app without debugging)
    static func debugPrivate(_ message: String, file: String = #file, function: String = #function) {
        guard isDebugEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        appLogger.info("[\(filename, privacy: .public):\(function, privacy: .public)] \(message, privacy: .private)")
    }
    
    /// Log sensitive debug messages with hash (hashed in logs)
    static func debugSensitive(_ message: String, file: String = #file, function: String = #function) {
        guard isDebugEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        appLogger.info("[\(filename, privacy: .public):\(function, privacy: .public)] \(message, privacy: .sensitive)")
    }
    
    // MARK: - Bridge Logging
    
    /// Log OpenCode bridge messages (public by default)
    static func bridge(_ message: String) {
        guard isDebugEnabled else { return }
        bridgeLogger.info("\(message, privacy: .public)")
    }
    
    /// Log OpenCode bridge messages with private content
    static func bridgePrivate(_ message: String) {
        guard isDebugEnabled else { return }
        bridgeLogger.info("\(message, privacy: .private)")
    }
    
    // MARK: - Permission Logging
    
    /// Log permission-related messages (public by default)
    static func permission(_ message: String) {
        guard isDebugEnabled else { return }
        permissionLogger.info("\(message, privacy: .public)")
    }
    
    /// Log permission-related messages with private content
    static func permissionPrivate(_ message: String) {
        guard isDebugEnabled else { return }
        permissionLogger.info("\(message, privacy: .private)")
    }
    
    // MARK: - Config Logging
    
    /// Log configuration messages (public by default)
    static func config(_ message: String) {
        guard isDebugEnabled else { return }
        configLogger.info("\(message, privacy: .public)")
    }
    
    /// Log configuration messages with private content
    static func configPrivate(_ message: String) {
        guard isDebugEnabled else { return }
        configLogger.info("\(message, privacy: .private)")
    }
    
    // MARK: - Skills Logging
    
    /// Log skills-related messages
    static func skills(_ message: String) {
        guard isDebugEnabled else { return }
        skillsLogger.info("\(message, privacy: .public)")
    }
    
    // MARK: - Session Logging
    
    /// Log session-related messages
    static func session(_ message: String) {
        guard isDebugEnabled else { return }
        sessionLogger.info("\(message, privacy: .public)")
    }
    
    /// Log session ID (hashed for privacy)
    static func sessionId(_ sessionId: String, context: String) {
        guard isDebugEnabled else { return }
        sessionLogger.info("\(context, privacy: .public): \(sessionId, privacy: .sensitive)")
    }
    
    // MARK: - Error and Warning (Always Logged)
    
    /// Log errors (always logged, even in release)
    static func error(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        appLogger.error("[\(filename, privacy: .public):\(function, privacy: .public)] \(message, privacy: .public)")
    }
    
    /// Log warnings (always logged)
    static func warning(_ message: String) {
        appLogger.warning("\(message, privacy: .public)")
    }
    
    /// Log a fault (critical error, triggers Instruments mark)
    static func fault(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        appLogger.fault("[\(filename, privacy: .public):\(function, privacy: .public)] \(message, privacy: .public)")
    }
}

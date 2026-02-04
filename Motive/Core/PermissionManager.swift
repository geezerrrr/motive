import Foundation
import Combine
import Network

// MARK: - Permission Request Types

// Note: FileOperation is defined in FileOperationPolicy.swift with additional types:
// create, delete, rename, move, modify, overwrite, readBinary, execute

/// Permission request type
enum PermissionRequestType: String, Codable, Sendable {
    case file
    case question
    case tool
}

/// Permission request from OpenCode CLI or MCP server
/// Note: @unchecked Sendable because toolInput is [String: Any] which isn't Sendable
struct PermissionRequest: Identifiable, Codable, @unchecked Sendable {
    let id: String
    let taskId: String
    let type: PermissionRequestType
    let createdAt: String
    
    // File permission fields
    var fileOperation: FileOperation?
    var filePath: String?
    var filePaths: [String]?
    var targetPath: String?
    var contentPreview: String?
    
    // Question fields
    var question: String?
    var header: String?
    var options: [QuestionOption]?
    var multiSelect: Bool?
    
    // Tool fields
    var toolName: String?
    var toolInput: [String: Any]?
    
    struct QuestionOption: Codable, Sendable {
        let label: String
        var value: String?
        var description: String?
        
        /// Returns value if available, otherwise label
        var effectiveValue: String {
            value ?? label
        }
    }
    
    // Custom encoding/decoding for toolInput
    enum CodingKeys: String, CodingKey {
        case id, taskId, type, createdAt
        case fileOperation, filePath, filePaths, targetPath, contentPreview
        case question, header, options, multiSelect
        case toolName, toolInput
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        taskId = try container.decode(String.self, forKey: .taskId)
        type = try container.decode(PermissionRequestType.self, forKey: .type)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        fileOperation = try container.decodeIfPresent(FileOperation.self, forKey: .fileOperation)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths)
        targetPath = try container.decodeIfPresent(String.self, forKey: .targetPath)
        contentPreview = try container.decodeIfPresent(String.self, forKey: .contentPreview)
        
        question = try container.decodeIfPresent(String.self, forKey: .question)
        header = try container.decodeIfPresent(String.self, forKey: .header)
        options = try container.decodeIfPresent([QuestionOption].self, forKey: .options)
        multiSelect = try container.decodeIfPresent(Bool.self, forKey: .multiSelect)
        
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = nil // JSON parsing handled separately
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(type, forKey: .type)
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encodeIfPresent(fileOperation, forKey: .fileOperation)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(filePaths, forKey: .filePaths)
        try container.encodeIfPresent(targetPath, forKey: .targetPath)
        try container.encodeIfPresent(contentPreview, forKey: .contentPreview)
        
        try container.encodeIfPresent(question, forKey: .question)
        try container.encodeIfPresent(header, forKey: .header)
        try container.encodeIfPresent(options, forKey: .options)
        try container.encodeIfPresent(multiSelect, forKey: .multiSelect)
        
        try container.encodeIfPresent(toolName, forKey: .toolName)
    }
    
    init(
        id: String,
        taskId: String,
        type: PermissionRequestType,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        fileOperation: FileOperation? = nil,
        filePath: String? = nil,
        filePaths: [String]? = nil,
        targetPath: String? = nil,
        contentPreview: String? = nil,
        question: String? = nil,
        header: String? = nil,
        options: [QuestionOption]? = nil,
        multiSelect: Bool? = nil,
        toolName: String? = nil,
        toolInput: [String: Any]? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.type = type
        self.createdAt = createdAt
        self.fileOperation = fileOperation
        self.filePath = filePath
        self.filePaths = filePaths
        self.targetPath = targetPath
        self.contentPreview = contentPreview
        self.question = question
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
        self.toolName = toolName
        self.toolInput = toolInput
    }
    
    /// Check if this is a delete operation
    var isDeleteOperation: Bool {
        type == .file && fileOperation == .delete
    }
    
    /// Get all file paths (single or multiple)
    var displayFilePaths: [String] {
        if let paths = filePaths, !paths.isEmpty {
            return paths
        }
        if let path = filePath {
            return [path]
        }
        return []
    }
}

/// Permission response
struct PermissionResponse: Sendable {
    let requestId: String
    let taskId: String
    let decision: Decision
    var selectedOptions: [String]?
    var customText: String?
    var message: String?
    
    enum Decision: String, Sendable {
        case allow
        case deny
    }
}

// MARK: - Permission Manager

/// Manages permission requests and responses
@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var currentRequest: PermissionRequest?
    @Published var isShowingRequest = false
    
    private var pendingRequests: [String: (Bool) -> Void] = [:]
    private var pendingQuestions: [String: (PermissionResponse) -> Void] = [:]
    
    private var permissionServer: PermissionAPIServer?
    private var questionServer: QuestionAPIServer?
    
    private init() {}
    
    /// Start the permission API servers
    nonisolated func startServers() {
        // Use callback-based handler to avoid async parameter passing issues
        let permissionHandler: (Data, @escaping (Bool) -> Void) -> Void = { [weak self] data, completion in
            // Copy data BEFORE creating Task
            let dataCopy = Data(data)
            Log.permission(" /permission handler received \(dataCopy.count) bytes")
            // Dispatch to MainActor for UI operations
            Task { @MainActor in
                guard let self else {
                    completion(false)
                    return
                }
                guard let json = try? JSONSerialization.jsonObject(with: dataCopy) as? [String: Any] else {
                    Log.permission(" /permission failed to parse JSON on MainActor")
                    completion(false)
                    return
                }
                let result = await self.handleFilePermissionRequest(json)
                completion(result)
            }
        }
        
        // Use callback-based handler to avoid async parameter passing issues
        let questionHandler: (Data, @escaping (PermissionResponse) -> Void) -> Void = { [weak self] data, completion in
            // Copy data BEFORE creating Task
            let dataCopy = Data(data)
            Log.permission(" /question handler received \(dataCopy.count) bytes")
            // Dispatch to MainActor for UI operations
            Task { @MainActor in
                guard let self else {
                    completion(PermissionResponse(requestId: "", taskId: "", decision: .deny))
                    return
                }
                do {
                    guard let json = try JSONSerialization.jsonObject(with: dataCopy, options: []) as? [String: Any] else {
                        Log.permission(" /question JSON is not a dictionary")
                        completion(PermissionResponse(requestId: "", taskId: "", decision: .deny))
                        return
                    }
                    Log.permission(" /question handling on MainActor, keys: \(json.keys.joined(separator: ", "))")
                    let result = await self.handleQuestionRequest(json)
                    completion(result)
                } catch {
                    let dataStr = String(data: dataCopy, encoding: .utf8) ?? "<binary>"
                    Log.permission(" /question JSON parse error: \(error), data: \(dataStr.prefix(500))")
                    completion(PermissionResponse(requestId: "", taskId: "", decision: .deny))
                }
            }
        }
        
        Task { @MainActor in
            self.permissionServer = PermissionAPIServer(port: 9226, handler: permissionHandler)
            self.permissionServer?.start()
            
            self.questionServer = QuestionAPIServer(port: 9227, handler: questionHandler)
            self.questionServer?.start()
            
            Log.permission(" Permission API servers starting on ports 9226 (/permission) and 9227 (/question)")
        }
    }
    
    /// Stop the permission API servers
    func stopServers() {
        permissionServer?.stop()
        questionServer?.stop()
        Log.permission(" Permission API servers stopped")
    }
    
    /// Show a permission request to the user
    func showRequest(_ request: PermissionRequest) {
        currentRequest = request
        isShowingRequest = true
    }
    
    /// Handle user response to permission request
    func respond(with response: PermissionResponse) {
        let requestId = response.requestId
        Log.permission(" respond() called with requestId: \(requestId), decision: \(response.decision)")
        
        // Check if it's a file permission request
        if requestId.hasPrefix("filereq_") {
            if let callback = pendingRequests[requestId] {
                Log.permission(" Found pending file request callback, calling with: \(response.decision == .allow)")
                callback(response.decision == .allow)
                pendingRequests.removeValue(forKey: requestId)
            } else {
                Log.permission(" No pending file request found for \(requestId)")
            }
        }
        // Check if it's a question request
        else if requestId.hasPrefix("questionreq_") {
            if let callback = pendingQuestions[requestId] {
                Log.permission(" Found pending question callback, calling...")
                callback(response)
                pendingQuestions.removeValue(forKey: requestId)
            } else {
                Log.permission(" No pending question found for \(requestId)")
            }
        }
        
        // Clear current request
        currentRequest = nil
        isShowingRequest = false
    }
    
    /// Cancel current request
    func cancelRequest() {
        if let request = currentRequest {
            respond(with: PermissionResponse(
                requestId: request.id,
                taskId: request.taskId,
                decision: .deny
            ))
        }
    }
    
    /// Clear session-level permission decisions (call on new session)
    func clearSessionDecisions() {
        FileOperationPolicy.shared.clearSessionDecisions()
        Log.permission(" Cleared session permission decisions")
    }
    
    // MARK: - Internal handlers
    
    private func handleFilePermissionRequest(_ rawRequest: [String: Any]) async -> Bool {
        Log.permission(" Received file permission request: \(rawRequest)")
        let requestId = generateRequestId(prefix: "filereq")
        let taskId = rawRequest["taskId"] as? String ?? "unknown"
        
        guard let operationStr = rawRequest["operation"] as? String,
              let operation = FileOperation(rawValue: operationStr) else {
            return false
        }
        
        let filePath = rawRequest["filePath"] as? String
        let filePaths = rawRequest["filePaths"] as? [String]
        
        // Check policy for each path
        let pathsToCheck = filePaths ?? (filePath.map { [$0] } ?? [])
        let policy = FileOperationPolicy.shared
        
        // Evaluate policy for all paths
        var autoDecision: Bool? = nil
        for path in pathsToCheck {
            let (shouldAsk, defaultAllow) = policy.shouldRequestPermission(for: operation, path: path)
            
            if !shouldAsk {
                // Policy has an auto-decision
                if let allow = defaultAllow {
                    if allow == false {
                        // Any denial means deny all
                        Log.permission(" Auto-denied by policy for path: \(path)")
                        return false
                    }
                    autoDecision = true
                }
            } else {
                // At least one path requires asking
                autoDecision = nil
                break
            }
        }
        
        // If policy auto-allows all paths, return immediately
        if let decision = autoDecision, decision == true {
            Log.permission(" Auto-allowed by policy for all paths")
            return true
        }
        
        // Otherwise, show request to user
        let request = PermissionRequest(
            id: requestId,
            taskId: taskId,
            type: .file,
            fileOperation: operation,
            filePath: filePath,
            filePaths: filePaths,
            targetPath: rawRequest["targetPath"] as? String,
            contentPreview: (rawRequest["contentPreview"] as? String)?.prefix(500).description
        )
        
        return await withCheckedContinuation { continuation in
            pendingRequests[requestId] = { allowed in
                // Record decision for askOnce policy
                for path in pathsToCheck {
                    policy.recordDecision(for: operation, path: path, allowed: allowed)
                }
                continuation.resume(returning: allowed)
            }
            
            Task { @MainActor in
                self.showRequest(request)
            }
        }
    }
    
    private func handleQuestionRequest(_ rawRequest: [String: Any]) async -> PermissionResponse {
        Log.permission(" Received question request: \(rawRequest)")
        Log.permission(" Question request keys: \(rawRequest.keys.joined(separator: ", "))")
        if let rawOptions = rawRequest["options"] {
            Log.permission(" Question has options: \(rawOptions)")
        } else {
            Log.permission(" Question has NO options field")
        }
        
        let requestId = generateRequestId(prefix: "questionreq")
        let taskId = rawRequest["taskId"] as? String ?? "unknown"
        
        var options: [PermissionRequest.QuestionOption]?
        if let rawOptions = rawRequest["options"] as? [[String: Any]] {
            options = rawOptions.map { opt in
                PermissionRequest.QuestionOption(
                    label: opt["label"] as? String ?? "",
                    description: opt["description"] as? String
                )
            }
            Log.permission(" Parsed \(options?.count ?? 0) options")
        }
        
        let request = PermissionRequest(
            id: requestId,
            taskId: taskId,
            type: .question,
            question: rawRequest["question"] as? String,
            header: rawRequest["header"] as? String,
            options: options,
            multiSelect: rawRequest["multiSelect"] as? Bool ?? false
        )
        
        return await withCheckedContinuation { continuation in
            pendingQuestions[requestId] = { response in
                continuation.resume(returning: response)
            }
            
            Task { @MainActor in
                self.showRequest(request)
            }
        }
    }
    
    private func generateRequestId(prefix: String) -> String {
        "\(prefix)_\(Int(Date().timeIntervalSince1970 * 1000))_\(String(Int.random(in: 0..<1_000_000_000), radix: 36))"
    }
}

// MARK: - HTTP Server for File Permissions

/// HTTP server for file permission requests (port 9226)
class PermissionAPIServer: @unchecked Sendable {
    private let port: UInt16
    // Use callback-based handler to avoid async parameter passing issues
    private let handler: (Data, @escaping (Bool) -> Void) -> Void
    private var server: DataHTTPServer?
    
    init(port: UInt16, handler: @escaping (Data, @escaping (Bool) -> Void) -> Void) {
        self.port = port
        self.handler = handler
    }
    
    func start() {
        let handlerRef = handler
        server = DataHTTPServer(port: port, path: "/permission") { @Sendable [handlerRef] (data: Data, completion: @escaping (Data) -> Void) in
            Log.permission(" PermissionAPIServer received \(data.count) bytes")
            // Call handler synchronously, passing data directly (no async boundary)
            handlerRef(data) { allowed in
                Log.permission(" PermissionAPIServer got response: allowed=\(allowed)")
                guard let responseData = try? JSONSerialization.data(withJSONObject: ["allowed": allowed]) else {
                    Log.error("Failed to serialize permission response")
                    completion(Data())
                    return
                }
                Log.permission(" PermissionAPIServer sending HTTP response: \(String(data: responseData, encoding: .utf8) ?? "")")
                completion(responseData)
            }
        }
        server?.start()
    }
    
    func stop() {
        server?.stop()
    }
}

// MARK: - HTTP Server for Questions

/// HTTP server for question requests (port 9227)
class QuestionAPIServer: @unchecked Sendable {
    private let port: UInt16
    // Use callback-based handler to avoid async parameter passing issues
    private let handler: (Data, @escaping (PermissionResponse) -> Void) -> Void
    private var server: DataHTTPServer?
    
    init(port: UInt16, handler: @escaping (Data, @escaping (PermissionResponse) -> Void) -> Void) {
        self.port = port
        self.handler = handler
    }
    
    func start() {
        let handlerRef = handler
        server = DataHTTPServer(port: port, path: "/question") { @Sendable [handlerRef] (data: Data, completion: @escaping (Data) -> Void) in
            Log.permission(" QuestionAPIServer received \(data.count) bytes")
            // Call handler synchronously, passing data directly (no async boundary)
            handlerRef(data) { response in
                Log.permission(" QuestionAPIServer got response: decision=\(response.decision)")
                var responseDict: [String: Any] = [
                    "answered": response.decision == .allow
                ]
                if response.decision == .deny {
                    responseDict["denied"] = true
                }
                if let selectedOptions = response.selectedOptions {
                    responseDict["selectedOptions"] = selectedOptions
                }
                if let customText = response.customText {
                    responseDict["customText"] = customText
                }
                guard let responseData = try? JSONSerialization.data(withJSONObject: responseDict) else {
                    Log.error("Failed to serialize question response")
                    completion(Data())
                    return
                }
                Log.permission(" QuestionAPIServer sending HTTP response: \(String(data: responseData, encoding: .utf8) ?? "")")
                completion(responseData)
            }
        }
        server?.start()
    }
    
    func stop() {
        server?.stop()
    }
}

// MARK: - Data HTTP Server (MCP permission bridge)

/// HTTP server that handles POST requests and passes raw Data to handler
/// Uses synchronous handler to avoid Swift Concurrency parameter passing bugs
private final class DataHTTPServer: @unchecked Sendable {
    private let port: UInt16
    private let path: String
    // Synchronous handler that receives Data and a completion callback
    private let handler: @Sendable (Data, @escaping (Data) -> Void) -> Void
    private let queue = DispatchQueue(label: "motive.permission.http", qos: .userInteractive)
    private var listener: NWListener?
    
    init(port: UInt16, path: String, handler: @escaping @Sendable (Data, @escaping (Data) -> Void) -> Void) {
        self.port = port
        self.path = path
        self.handler = handler
    }
    
    func start() {
        do {
            let nwPort = NWEndpoint.Port(rawValue: port) ?? .any
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: nwPort)
            self.listener = listener
            
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }
            
            listener.stateUpdateHandler = { [path, port] state in
                switch state {
                case .failed(let error):
                    Log.permission(" HTTP server :\(port) failed: \(error)")
                case .ready:
                    Log.permission(" HTTP server listening on 127.0.0.1:\(port) for \(path)")
                default:
                    break
                }
            }
            
            listener.start(queue: queue)
        } catch {
            Log.permission(" Failed to start HTTP server on port \(port): \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveAll(on: connection, buffer: Data())
    }
    
    private func receiveAll(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            
            var newBuffer = buffer
            if let data {
                newBuffer.append(data)
            }
            
            if let (method, reqPath, body) = self.parseHTTP(data: newBuffer) {
                self.processRequest(connection: connection, method: method, reqPath: reqPath, body: body)
                return
            }
            
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            
            self.receiveAll(on: connection, buffer: newBuffer)
        }
    }
    
    private func parseHTTP(data: Data) -> (String, String, Data?)? {
        let separator = Data([13, 10, 13, 10])
        guard let headerEnd = data.range(of: separator) else { return nil }
        
        let headerData = data.subdata(in: 0..<headerEnd.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        
        let method = String(parts[0])
        let reqPath = String(parts[1])
        
        var contentLength: Int?
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = Int(value)
            }
        }
        
        let bodyStart = headerEnd.upperBound
        
        if let length = contentLength {
            let bodyEnd = bodyStart + length
            guard data.count >= bodyEnd else { return nil }
            let body = data.subdata(in: bodyStart..<bodyEnd)
            return (method, reqPath, body)
        }
        
        if data.count > bodyStart {
            let body = data.subdata(in: bodyStart..<data.count)
            return (method, reqPath, body)
        }
        
        return (method, reqPath, nil)
    }
    
    private func processRequest(connection: NWConnection, method: String, reqPath: String, body: Data?) {
        // Handle OPTIONS
        if method == "OPTIONS" {
            sendResponse(connection: connection, statusCode: 200, body: Data("{}".utf8))
            return
        }
        
        guard method == "POST", reqPath == path else {
            sendResponse(connection: connection, statusCode: 404, body: Data("{\"error\":\"Not found\"}".utf8))
            return
        }
        
        guard let body, !body.isEmpty else {
            Log.permission(" \(path) empty body")
            sendResponse(connection: connection, statusCode: 400, body: Data("{\"error\":\"Empty body\"}".utf8))
            return
        }
        
        // Make a deep copy of body data immediately
        let bodyCopy = Data(body)
        Log.permission(" \(path) received (\(bodyCopy.count) bytes)")
        
        // Call handler synchronously with completion callback
        // The handler is responsible for calling the completion when done
        handler(bodyCopy) { [weak self] responseData in
            self?.sendResponse(connection: connection, statusCode: 200, body: responseData)
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: Data) {
        let headers = [
            "HTTP/1.1 \(statusCode) OK",
            "Content-Type: application/json",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        
        var data = Data(headers.utf8)
        data.append(body)
        
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}


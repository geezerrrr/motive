//
//  SSEClient.swift
//  Motive
//
//  Connects to OpenCode's SSE endpoint and parses events into typed enums.
//  Supports text delta throttling, auto-reconnect, and sessionID filtering.
//
//  Type definitions: SSEEventTypes.swift
//  Parsing logic:    SSEEventParser.swift
//  URLSession delegate: SSESessionDelegate.swift
//

import Foundation
import os

/// Client for OpenCode's Server-Sent Events stream.
///
/// Connects to `GET /event` and emits typed `SSEEvent` values via `AsyncStream`.
/// Text deltas are throttled to ~30Hz to prevent excessive UI updates.
actor SSEClient {

    // MARK: - Properties

    private var streamTask: Task<Void, Never>?
    private var isConnected = false
    private static let reconnectMaxDelay: TimeInterval = 30
    /// Tracks message part type by partID so `message.part.delta` can be classified correctly.
    /// OpenCode deltas only include `partID` + `field`, not the part `type`.
    var partTypeByPartID: [String: String] = [:]
    /// Tracks last full text snapshot for `message.part.updated` events that carry full text
    /// instead of incremental `delta`.
    var textByPartID: [String: String] = [:]
    /// Message IDs whose role is "user". Text parts for these messages must be skipped
    /// to prevent the user's prompt from being echoed as an assistant bubble.
    var userMessageIDs: Set<String> = []

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.velvet.motive", category: "SSE")

    struct ScopedEvent: Sendable {
        let directory: String?
        let event: SSEEvent
    }

    // MARK: - Public API

    /// Connect to the SSE endpoint and return an async stream of events.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL of the OpenCode server (e.g., `http://127.0.0.1:4096`).
    ///   - directory: The working directory to pass via `x-opencode-directory` header.
    ///     **Critical**: This must match the directory used by `OpenCodeAPIClient` so that
    ///     the SSE stream subscribes to the same OpenCode instance that handles prompts.
    /// - Returns: An `AsyncStream` of typed SSE events.
    func connect(to baseURL: URL, directory: String? = nil) -> AsyncStream<SSEEvent> {
        disconnect()

        let (stream, continuation) = AsyncStream.makeStream(of: SSEEvent.self)

        streamTask = Task { [weak self] in
            guard let self else {
                continuation.finish()
                return
            }

            var reconnectDelay: TimeInterval = 1.0

            while !Task.isCancelled {
                do {
                    await self.logger.info("SSE connecting to \(baseURL.absoluteString)...")
                    try await self.consumeEventStream(
                        baseURL: baseURL,
                        directory: directory,
                        continuation: continuation
                    )
                    if !Task.isCancelled {
                        await self.logger.info("SSE stream ended normally, reconnecting in \(reconnectDelay)s...")
                    }
                } catch {
                    if !Task.isCancelled {
                        await self.logger.error("SSE stream error: \(error.localizedDescription), reconnecting in \(reconnectDelay)s...")
                    }
                }

                guard !Task.isCancelled else { break }

                // Exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
                reconnectDelay = min(reconnectDelay * 2, Self.reconnectMaxDelay)
            }

            continuation.finish()
        }

        return stream
    }

    /// Connect to the global SSE endpoint and return scoped events.
    ///
    /// `/global/event` emits payloads in the form:
    /// `{ "directory": "...", "payload": { "type": "...", "properties": ... } }`.
    func connectGlobal(to baseURL: URL) -> AsyncStream<ScopedEvent> {
        disconnect()

        let (stream, continuation) = AsyncStream.makeStream(of: ScopedEvent.self)

        streamTask = Task { [weak self] in
            guard let self else {
                continuation.finish()
                return
            }

            var reconnectDelay: TimeInterval = 1.0

            while !Task.isCancelled {
                do {
                    await self.logger.info("Global SSE connecting to \(baseURL.absoluteString)...")
                    try await self.consumeGlobalEventStream(
                        baseURL: baseURL,
                        continuation: continuation
                    )
                    if !Task.isCancelled {
                        await self.logger.info("Global SSE stream ended normally, reconnecting in \(reconnectDelay)s...")
                    }
                } catch {
                    if !Task.isCancelled {
                        await self.logger.error("Global SSE stream error: \(error.localizedDescription), reconnecting in \(reconnectDelay)s...")
                    }
                }

                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
                reconnectDelay = min(reconnectDelay * 2, Self.reconnectMaxDelay)
            }

            continuation.finish()
        }

        return stream
    }

    /// Whether the SSE stream is currently connected and receiving events.
    var connected: Bool {
        isConnected
    }

    /// Whether the SSE event loop task is alive (may be in reconnect backoff).
    var hasActiveStream: Bool {
        streamTask != nil && !streamTask!.isCancelled
    }

    /// Disconnect from the SSE stream.
    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        isConnected = false
        partTypeByPartID.removeAll()
        textByPartID.removeAll()
        userMessageIDs.removeAll()
    }

    // MARK: - Stream Consumption

    /// Consume SSE using a delegate-based URLSession for real-time data delivery.
    /// Unlike `URLSession.bytes(for:)` which may buffer, this approach processes
    /// each TCP data chunk as it arrives via `urlSession(_:dataTask:didReceive:)`.
    private func consumeEventStream(
        baseURL: URL,
        directory: String?,
        continuation: AsyncStream<SSEEvent>.Continuation
    ) async throws {
        let eventURL = baseURL.appendingPathComponent("event")
        var request = URLRequest(url: eventURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = .infinity

        if let directory, !directory.isEmpty {
            request.setValue(directory, forHTTPHeaderField: "x-opencode-directory")
        }

        let delegate = SSESessionDelegate()
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        let task = session.dataTask(with: request)
        task.resume()

        let httpResponse = try await delegate.waitForResponse()
        guard httpResponse.statusCode == 200 else {
            throw SSEError.badStatus(httpResponse.statusCode)
        }

        isConnected = true
        logger.info("Connected to SSE endpoint (delegate): \(eventURL.absoluteString)")

        var lineBuffer = ""
        var dataBuffer = ""
        var eventCounter = 0

        for await chunk in delegate.dataStream {
            guard !Task.isCancelled else { break }

            lineBuffer += chunk
            while let newlineRange = lineBuffer.range(of: "\n") {
                let line = String(lineBuffer[lineBuffer.startIndex ..< newlineRange.lowerBound])
                lineBuffer = String(lineBuffer[newlineRange.upperBound...])

                if line.hasPrefix("data: ") {
                    if !dataBuffer.isEmpty {
                        flushEvent(dataBuffer, continuation: continuation)
                        dataBuffer = ""
                    }
                    dataBuffer = String(line.dropFirst(6))
                    eventCounter += 1
                    logger.info("📡 SSE[\(eventCounter)] RAW: \(dataBuffer, privacy: .public)")
                } else if line.isEmpty, !dataBuffer.isEmpty {
                    flushEvent(dataBuffer, continuation: continuation)
                    dataBuffer = ""
                }
            }
        }

        if !dataBuffer.isEmpty {
            flushEvent(dataBuffer, continuation: continuation)
        }

        isConnected = false
    }

    private func consumeGlobalEventStream(
        baseURL: URL,
        continuation: AsyncStream<ScopedEvent>.Continuation
    ) async throws {
        let eventURL = baseURL.appendingPathComponent("global/event")
        var request = URLRequest(url: eventURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = .infinity

        let delegate = SSESessionDelegate()
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        let task = session.dataTask(with: request)
        task.resume()

        let httpResponse = try await delegate.waitForResponse()
        guard httpResponse.statusCode == 200 else {
            throw SSEError.badStatus(httpResponse.statusCode)
        }

        isConnected = true
        logger.info("Connected to global SSE endpoint (delegate): \(eventURL.absoluteString)")

        var lineBuffer = ""
        var dataBuffer = ""
        var eventCounter = 0

        for await chunk in delegate.dataStream {
            guard !Task.isCancelled else { break }

            lineBuffer += chunk
            while let newlineRange = lineBuffer.range(of: "\n") {
                let line = String(lineBuffer[lineBuffer.startIndex ..< newlineRange.lowerBound])
                lineBuffer = String(lineBuffer[newlineRange.upperBound...])

                if line.hasPrefix("data: ") {
                    if !dataBuffer.isEmpty {
                        flushGlobalEvent(dataBuffer, continuation: continuation)
                        dataBuffer = ""
                    }
                    dataBuffer = String(line.dropFirst(6))
                    eventCounter += 1
                    logger.info("📡 GLOBAL-SSE[\(eventCounter)] RAW: \(dataBuffer, privacy: .public)")
                } else if line.isEmpty, !dataBuffer.isEmpty {
                    flushGlobalEvent(dataBuffer, continuation: continuation)
                    dataBuffer = ""
                }
            }
        }

        if !dataBuffer.isEmpty {
            flushGlobalEvent(dataBuffer, continuation: continuation)
        }

        isConnected = false
    }

    // MARK: - Event Flushing

    /// Parse a buffered SSE data string and yield the result to the stream.
    private func flushEvent(
        _ dataBuffer: String,
        continuation: AsyncStream<SSEEvent>.Continuation
    ) {
        guard let event = parseSSEData(dataBuffer) else { return }
        continuation.yield(event)
    }

    private func flushGlobalEvent(
        _ dataBuffer: String,
        continuation: AsyncStream<ScopedEvent>.Continuation
    ) {
        guard let scoped = parseGlobalSSEData(dataBuffer) else { return }
        continuation.yield(scoped)
    }

    // MARK: - Errors

    enum SSEError: Error, LocalizedError {
        case badStatus(Int)
        case noResponse

        var errorDescription: String? {
            switch self {
            case let .badStatus(code):
                "SSE endpoint returned HTTP \(code)"
            case .noResponse:
                "SSE endpoint returned no HTTP response"
            }
        }
    }
}

// MARK: - Protocol Conformance

extension SSEClient: SSEClientProtocol {}

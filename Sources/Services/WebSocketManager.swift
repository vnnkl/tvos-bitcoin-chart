import Foundation
import OSLog

private let logger = Logger(subsystem: "com.bitcointerminal.websocket", category: "WebSocketManager")

/// Manages a single `URLSessionWebSocketTask` connection with automatic reconnection.
///
/// Usage:
/// ```swift
/// let manager = WebSocketManager()
/// let stream = manager.connect(to: url)
/// for try await message in stream {
///     // handle message
/// }
/// ```
///
/// Reconnection uses exponential backoff: `min(2^attempt, 60)` seconds.
/// Call `disconnect()` to permanently stop reconnecting.
@Observable
final class WebSocketManager: @unchecked Sendable {

    // MARK: - Observable properties

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var lastError: Error?
    private(set) var reconnectCount: Int = 0

    // MARK: - Private state

    private var task: URLSessionWebSocketTask?
    private var currentURL: URL?
    private var continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation?
    private var receiveLoop: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var isSuspended = false
    private var isDisconnecting = false

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Connect to `url` and return a stream of raw WebSocket messages.
    /// The stream terminates when `disconnect()` is called or on an unrecoverable error.
    func connect(to url: URL) -> AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> {
        currentURL = url
        isDisconnecting = false

        let stream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.task?.cancel(with: .goingAway, reason: nil)
            }
        }

        openConnection()
        return stream
    }

    /// Permanently close the connection and stop reconnection attempts.
    func disconnect() {
        logger.info("disconnect() called — stopping all reconnection")
        isDisconnecting = true
        isSuspended = false
        cancelAll()
        setConnectionState(.disconnected)
        continuation?.finish()
        continuation = nil
    }

    /// Suspend the connection (e.g. app moved to background). Does not clear `currentURL`.
    func suspend() {
        guard !isSuspended else { return }
        logger.info("Suspending WebSocket connection")
        isSuspended = true
        cancelAll()
        setConnectionState(.disconnected)
    }

    /// Resume a previously suspended connection.
    func resume() {
        guard isSuspended, !isDisconnecting else { return }
        logger.info("Resuming WebSocket connection")
        isSuspended = false
        if let url = currentURL {
            _ = connect(to: url)
        }
    }

    // MARK: - Private: connection lifecycle

    private func openConnection() {
        guard let url = currentURL, !isDisconnecting, !isSuspended else { return }

        logger.info("Connecting to \(url.absoluteString)")
        setConnectionState(.connecting)

        let wsTask = session.webSocketTask(with: url)
        task = wsTask
        wsTask.resume()

        setConnectionState(.connected)
        reconnectCount = 0
        logger.info("WebSocket connected to \(url.absoluteString)")

        startReceiveLoop(task: wsTask)
    }

    private func startReceiveLoop(task: URLSessionWebSocketTask) {
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            guard let self else { return }
            await self.receiveMessages(from: task)
        }
    }

    private func receiveMessages(from task: URLSessionWebSocketTask) async {
        while !Task.isCancelled && !isDisconnecting && !isSuspended {
            do {
                let message = try await task.receive()
                // Handle Binance text-frame pings: {"method":"ping"}
                if case .string(let text) = message,
                   text.contains("\"ping\"") || text == "{\"method\":\"ping\"}" {
                    logger.debug("Received ping frame, sending pong")
                    try? await task.send(.string("{\"method\":\"pong\"}"))
                    continue
                }
                continuation?.yield(message)
            } catch {
                if Task.isCancelled || isDisconnecting || isSuspended { break }
                logger.error("WebSocket receive error: \(error.localizedDescription)")
                lastError = error
                scheduleReconnect()
                break
            }
        }
    }

    private func scheduleReconnect() {
        guard !isDisconnecting, !isSuspended else { return }

        let attempt = reconnectCount
        let delay = min(pow(2.0, Double(attempt)), 60.0)
        reconnectCount += 1

        logger.info("Reconnecting in \(delay)s (attempt \(attempt + 1))")
        setConnectionState(.reconnecting)

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled && !self.isDisconnecting && !self.isSuspended else { return }
            self.openConnection()
        }
    }

    private func cancelAll() {
        receiveLoop?.cancel()
        receiveLoop = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func setConnectionState(_ state: ConnectionState) {
        connectionState = state
        logger.info("ConnectionState → \(state.rawValue)")
    }
}

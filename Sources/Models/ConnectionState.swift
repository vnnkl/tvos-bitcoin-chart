import Foundation

/// The lifecycle state of the exchange WebSocket connection.
/// Transitions are: disconnected → connecting → connected → reconnecting → connecting → …
enum ConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

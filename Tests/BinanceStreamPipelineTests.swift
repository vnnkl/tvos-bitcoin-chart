import Testing
import Foundation
@testable import BitcoinTerminal

/// Drives the shared Binance decoded-stream pipeline with a fake message
/// source — no network. Locks the semantics the three per-stream loops had
/// before consolidation: text frames decode and yield, non-text frames are
/// skipped, a malformed frame finishes the stream with its decode error, and
/// source termination (normal or throwing) propagates.
@Suite("Binance decoded-stream pipeline")
struct BinanceStreamPipelineTests {

    private struct TestEvent: Decodable, Equatable, Sendable {
        let value: Int
    }

    /// A controllable stand-in for `WebSocketManager.connect(to:)`.
    private typealias MessageSource = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>

    private func makeSource(
        _ build: (MessageSource.Continuation) -> Void
    ) -> MessageSource {
        AsyncThrowingStream { continuation in
            build(continuation)
        }
    }

    // MARK: - Decode success

    @Test func decodesTextFramesAndAppliesTransform() async throws {
        let source = makeSource { c in
            c.yield(.string(#"{"value": 1}"#))
            c.yield(.string(#"{"value": 2}"#))
            c.finish()
        }

        let stream = decodeBinanceEvents(from: source, label: "test") {
            (event: TestEvent) in event.value * 10
        }

        var received: [Int] = []
        for try await value in stream {
            received.append(value)
        }
        #expect(received == [10, 20])
    }

    // MARK: - Non-text frames are skipped

    @Test func skipsNonTextFrames() async throws {
        let source = makeSource { c in
            c.yield(.data(Data([0x00, 0x01])))
            c.yield(.string(#"{"value": 7}"#))
            c.finish()
        }

        let stream = decodeBinanceEvents(from: source, label: "test") {
            (event: TestEvent) in event
        }

        var received: [TestEvent] = []
        for try await event in stream {
            received.append(event)
        }
        #expect(received == [TestEvent(value: 7)])
    }

    // MARK: - Malformed frame finishes the stream with an error

    @Test func malformedFrameFinishesStreamWithDecodeError() async {
        let source = makeSource { c in
            c.yield(.string(#"{"value": 1}"#))
            c.yield(.string("not json"))
            c.yield(.string(#"{"value": 3}"#))   // must never arrive
            c.finish()
        }

        let stream = decodeBinanceEvents(from: source, label: "test") {
            (event: TestEvent) in event
        }

        var received: [TestEvent] = []
        await #expect(throws: DecodingError.self) {
            for try await event in stream {
                received.append(event)
            }
        }
        #expect(received == [TestEvent(value: 1)])
    }

    // MARK: - Source termination propagates

    @Test func sourceErrorPropagates() async {
        let source = makeSource { c in
            c.finish(throwing: URLError(.networkConnectionLost))
        }

        let stream = decodeBinanceEvents(from: source, label: "test") {
            (event: TestEvent) in event
        }

        await #expect(throws: URLError.self) {
            for try await _ in stream { }
        }
    }

    @Test func sourceFinishEndsStreamWithoutError() async throws {
        let source = makeSource { c in
            c.finish()
        }

        let stream = decodeBinanceEvents(from: source, label: "test") {
            (event: TestEvent) in event
        }

        var count = 0
        for try await _ in stream {
            count += 1
        }
        #expect(count == 0)
    }
}

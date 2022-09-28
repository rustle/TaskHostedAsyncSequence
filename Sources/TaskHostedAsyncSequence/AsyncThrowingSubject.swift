public struct AsyncThrowingSubject<Element>: AsyncSequence, @unchecked Sendable {
    public typealias Failure = any Error
    public typealias AsyncIterator = AsyncThrowingStream<Element, Failure>.Iterator
    private let stream: AsyncThrowingStream<Element, Failure>
    private let continuation: AsyncThrowingStream<Element, Failure>.Continuation
    public init(_ elementType: Element.Type = Element.self) {
        var continuation: AsyncThrowingStream<Element, Failure>.Continuation!
        stream = AsyncThrowingStream(bufferingPolicy: .unbounded) {
            continuation = $0
        }
        self.continuation = continuation
    }
    public func makeAsyncIterator() -> AsyncThrowingStream<Element, Failure>.Iterator {
        stream.makeAsyncIterator()
    }
    public func send(_ value: Element) {
        switch continuation.yield(value) {
        case .dropped(_):
            preconditionFailure("send() should never drop a value")
        default:
            break
        }
    }
    public func finish(throwing error: (any Error)? = nil) {
        continuation.finish(throwing: error)
    }
}

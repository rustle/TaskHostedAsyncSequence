public struct AsyncSubject<Element>: AsyncSequence, @unchecked Sendable {
    public typealias AsyncIterator = AsyncStream<Element>.Iterator
    private let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation
    public init(_ elementType: Element.Type = Element.self) {
        var continuation: AsyncStream<Element>.Continuation!
        stream = AsyncStream(bufferingPolicy: .unbounded) {
            continuation = $0
        }
        self.continuation = continuation
    }
    public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
        stream.makeAsyncIterator()
    }
    public func send(_ value: Element) {
        switch continuation.yield(value) {
        case .dropped(_):
            preconditionFailure("send(_:) should never drop a value")
        default:
            break
        }
    }
    public func finish() {
        continuation.finish()
    }
}

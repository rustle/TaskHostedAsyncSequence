public struct TaskHostedAsyncSequence<Output>: Sendable {
    private var continuation: AsyncStream<Output>.Continuation!
    private var task: Task<Void, Never>!
    public init(receiveValue: @escaping (Output) async -> Void) async {
        // Setup stream and continuation
        var streamContinuation: AsyncStream<Output>.Continuation?
        let stream = AsyncStream {
            streamContinuation = $0
        }
        precondition(streamContinuation != nil)
        self.continuation = streamContinuation
        // Wait for Task to get going
        await withCheckedContinuation { taskLaunchContinuation in
            self.task = Task {
                taskLaunchContinuation.resume()
                guard !Task.isCancelled else { return }
                for await value in stream {
                    guard !Task.isCancelled else { break }
                    await receiveValue(value)
                }
            }
        }
    }
    public func send(_ value: Output) {
        continuation.yield(value)
    }
    public func finish() async {
        // Wrap up the stream
        continuation.finish()
        // Wait for the Task to exit
        _ = await task.result
    }
}

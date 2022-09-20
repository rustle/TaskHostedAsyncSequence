public struct TaskHostedThrowingAsyncSequence<Output>: Sendable {
    private var continuation: AsyncThrowingStream<Output, any Error>.Continuation!
    private var task: Task<Void, any Error>!
    public init(receiveValue: @escaping (Output) async throws -> Void) async {
        // Setup stream and continuation
        var streamContinuation: AsyncThrowingStream<Output, any Error>.Continuation?
        let stream = AsyncThrowingStream {
            streamContinuation = $0
        }
        precondition(streamContinuation != nil)
        self.continuation = streamContinuation
        // Wait for Task to get going
        await withCheckedContinuation { taskLaunchContinuation in
            self.task = Task {
                taskLaunchContinuation.resume()
                try Task.checkCancellation()
                for try await value in stream {
                    try Task.checkCancellation()
                    try await receiveValue(value)
                }
            }
        }
    }
    public func send(_ value: Output) {
        continuation.yield(value)
    }
    public func finish() async throws {
        // Wrap up the stream
        continuation.finish()
        // Wait for the Task to exit
        switch await task.result {
        case .success(_):
            return
        case .failure(let error):
            throw error
        }
    }
}

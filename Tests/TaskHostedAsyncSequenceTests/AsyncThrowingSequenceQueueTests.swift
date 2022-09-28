import XCTest
@testable import TaskHostedAsyncSequence

final class AsyncThrowingSequenceQueueTests: XCTestCase {
    actor SimpleActor {
        var values: [String] = []
        func receive(value: String) async throws {
            values.append(value)
        }
    }
    func testSend_CompletionHandlerResume_CompletionHandlerFinish() async throws {
        let actor = SimpleActor()
        var queue = AsyncThrowingSequenceQueue(receiveValue: actor.receive(value:))
        let finish = self.expectation(description: "Finish")
        var expected: [String] = []
        expected.reserveCapacity(1_000_000)
        queue.resume {
            for i in 0..<1_000_000 {
                expected.append("\(i)")
                queue.send("\(i)")
            }
            queue.finish(throwing: nil) { error in
                finish.fulfill()
            }
        }
        self.wait(
            for: [finish],
            timeout: 5.0
        )
        let values = await actor.values
        XCTAssertEqual(values, expected)
    }
    func testSend_AsyncResume_AsyncFinish() async throws {
        let actor = SimpleActor()
        var queue = AsyncThrowingSequenceQueue(receiveValue: actor.receive(value:))
        await queue.resume()
        var expected: [String] = []
        expected.reserveCapacity(1_000_000)
        for i in 0..<1_000_000 {
            expected.append("\(i)")
            queue.send("\(i)")
        }
        try await queue.finish()
        let values = await actor.values
        XCTAssertEqual(values, expected)
    }
}

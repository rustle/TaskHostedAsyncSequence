import XCTest
@testable import TaskHostedAsyncSequence

final class AsyncSequenceQueueTests: XCTestCase {
    actor SimpleActor {
        var values: [String] = []
        func receive(value: String) async {
            values.append(value)
        }
    }
    func testSend_CompletionHandlerResume_CompletionHandlerFinish() async throws {
        let actor = SimpleActor()
        var queue = AsyncSequenceQueue { value in
            await actor.receive(value: value)
        }
        let finish = self.expectation(description: "finish")
        var expected: [String] = []
        expected.reserveCapacity(1_000_000)
        queue.resume {
            for i in 0..<1_000_000 {
                expected.append("\(i)")
                queue.send("\(i)")
            }
            queue.finish {
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
        var queue = AsyncSequenceQueue { value in
            await actor.receive(value: value)
        }
        await queue.resume()
        var expected: [String] = []
        expected.reserveCapacity(1_000_000)
        for i in 0..<1_000_000 {
            expected.append("\(i)")
            queue.send("\(i)")
        }
        await queue.finish()
        let values = await actor.values
        XCTAssertEqual(values, expected)
    }
}

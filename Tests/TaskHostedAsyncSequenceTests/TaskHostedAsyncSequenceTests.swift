import XCTest
@testable import TaskHostedAsyncSequence

final class TaskHostedAsyncSequenceTests: XCTestCase {
    actor SimpleActor {
        var values: [String] = []
        func receive(value: String) async {
            values.append(value)
        }
        func receiveThrows(value: String) async throws {
            values.append(value)
        }
    }
    func testSend() async throws {
        let actor = SimpleActor()
        let sequence = await TaskHostedAsyncSequence { value in
            await actor.receive(value: value)
        }
        var expected: [String] = []
        for i in 0..<1_000_000 {
            expected.append("\(i)")
            sequence.send("\(i)")
        }
        await sequence.finish()
        let values = await actor.values
        XCTAssertEqual(values, expected)
    }
    func testThrowingSend() async throws {
        let actor = SimpleActor()
        let sequence = await TaskHostedThrowingAsyncSequence(receiveValue: actor.receiveThrows(value:))
        var expected: [String] = []
        for i in 0..<1_000_000 {
            expected.append("\(i)")
            sequence.send("\(i)")
        }
        try await sequence.finish()
        let values = await actor.values
        XCTAssertEqual(values, expected)
    }
}

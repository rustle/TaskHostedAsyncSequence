import Dispatch
import os.log

public struct AsyncThrowingSequenceQueue<Element>: @unchecked Sendable {
    public typealias Failure = any Error
    private let receiveValue: (Element) async throws -> Void
    private let lock: UnfairLock = .init()
    private let log: OSLog
    private let signpostID: OSSignpostID
    private enum State {
        case waiting
        case running(AsyncThrowingSubject<Element>, Task<Void, Failure>)
        case terminal
    }
    private var state: State = .waiting
    public init(receiveValue: @escaping (Element) async throws -> Void) {
        self.receiveValue = receiveValue
        log = OSLog(subsystem: "", category: "AsyncThrowingSequenceQueue")
        signpostID = OSSignpostID(log: log)
    }
    // MARK: -
    public func send(_ value: Element) {
        lock.lock()
        switch state {
        case .waiting:
            os_log(.info, log: log, "send() called before resume()")
            lock.unlock()
        case .running(let subject, _):
            os_signpost(.begin, log: log, name: "send()", signpostID: signpostID)
            subject.send(value)
            os_signpost(.end, log: log, name: "send()", signpostID: signpostID)
            lock.unlock()
        case .terminal:
            os_log(.info, log: log, "send() called after finish()")
            lock.unlock()
        }
    }
    public mutating func resume(
        priority: TaskPriority? = nil,
        completionHandler: @escaping () -> Void,
        completionHandlerQueue: DispatchQueue = .main
    ) {
        lock.lock()
        switch state {
        case .waiting:
            let subject = AsyncThrowingSubject<Element>()
            let receiveValue = self.receiveValue
            let log = self.log
            let signpostID = self.signpostID
            self.state = .running(
                subject,
                Task(priority: priority) {
                    completionHandlerQueue.async {
                        completionHandler()
                    }
                    try Task.checkCancellation()
                    for try await value in subject {
                        try Task.checkCancellation()
                        os_signpost(.begin, log: log, name: "receiveValue()", signpostID: signpostID)
                        try await receiveValue(value)
                        os_signpost(.end, log: log, name: "receiveValue()", signpostID: signpostID)
                    }
                }
            )
            lock.unlock()
        case .running(_, _):
            os_log(.info, log: log, "resume() called more than once")
            lock.unlock()
        case .terminal:
            os_log(.info, log: log, "resume() called after finish()")
            lock.unlock()
        }
    }
    public mutating func resume(priority: TaskPriority? = nil) async {
        lock.lock()
        switch state {
        case .waiting:
            let subject = AsyncThrowingSubject<Element>()
            let receiveValue = self.receiveValue
            let log = self.log
            let signpostID = self.signpostID
            await withCheckedContinuation { continuation in
                self.state = .running(
                    subject,
                    Task(priority: priority) {
                        continuation.resume()
                        try Task.checkCancellation()
                        for try await value in subject {
                            try Task.checkCancellation()
                            os_signpost(.begin, log: log, name: "receiveValue()", signpostID: signpostID)
                            try await receiveValue(value)
                            os_signpost(.end, log: log, name: "receiveValue()", signpostID: signpostID)
                        }
                    }
                )
                lock.unlock()
            }
        case .running(_, _):
            os_log(.info, log: log, "resume() called more than once")
            lock.unlock()
        case .terminal:
            os_log(.info, log: log, "resume() called after finish()")
            lock.unlock()
        }
    }
    public mutating func finish(
        throwing error: (any Error)? = nil,
        completionHandler: @escaping ((any Error)?) -> Void,
        completionHandlerQueue: DispatchQueue = .main
    ) {
        lock.lock()
        switch state {
        case .waiting:
            self.state = .terminal
            lock.unlock()
            break
        case .running(let subject, let task):
            self.state = .terminal
            os_signpost(.begin, log: log, name: "finish()", signpostID: signpostID)
            subject.finish(throwing: error)
            os_signpost(.end, log: log, name: "finish()", signpostID: signpostID)
            lock.unlock()
            Task {
                switch await task.result {
                case .success(_):
                    completionHandlerQueue.async {
                        completionHandler(nil)
                    }
                case .failure(let error):
                    completionHandlerQueue.async {
                        completionHandler(error)
                    }
                }
            }
        case .terminal:
            lock.unlock()
        }
    }
    public mutating func finish(throwing error: (any Error)? = nil) async throws {
        lock.lock()
        switch state {
        case .waiting:
            state = .terminal
            lock.unlock()
        case .running(let subject, let task):
            state = .terminal
            os_signpost(.begin, log: log, name: "finish()", signpostID: signpostID)
            subject.finish(throwing: error)
            os_signpost(.end, log: log, name: "finish()", signpostID: signpostID)
            lock.unlock()
            switch await task.result {
            case .failure(let error):
                throw error
            case .success(_):
                break
            }
        case .terminal:
            lock.unlock()
        }
    }
}

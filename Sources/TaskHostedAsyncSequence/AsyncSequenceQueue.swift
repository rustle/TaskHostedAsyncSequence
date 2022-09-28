import Dispatch
import os.log

public struct AsyncSequenceQueue<Element>: @unchecked Sendable {
    private let receiveValue: (Element) async -> Void
    private let lock: UnfairLock = .init()
    private let log: OSLog
    private let signpostID: OSSignpostID
    private enum State {
        case waiting
        case running(AsyncSubject<Element>, Task<Void, Never>)
        case terminal
    }
    private var state: State = .waiting
    public init(receiveValue: @escaping (Element) async -> Void) {
        self.receiveValue = receiveValue
        log = OSLog(subsystem: "", category: "AsyncSequenceQueue")
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
            let subject = AsyncSubject<Element>()
            let receiveValue = self.receiveValue
            let log = self.log
            let signpostID = self.signpostID
            self.state = .running(
                subject,
                Task(priority: priority) {
                    completionHandlerQueue.async {
                        completionHandler()
                    }
                    guard !Task.isCancelled else { return }
                    for await value in subject {
                        guard !Task.isCancelled else { break }
                        os_signpost(.begin, log: log, name: "receiveValue()", signpostID: signpostID)
                        await receiveValue(value)
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
            let subject = AsyncSubject<Element>()
            let receiveValue = self.receiveValue
            let log = self.log
            let signpostID = self.signpostID
            await withCheckedContinuation { continuation in
                self.state = .running(
                    subject,
                    Task(priority: priority) {
                        continuation.resume()
                        guard !Task.isCancelled else { return }
                        for await value in subject {
                            guard !Task.isCancelled else { break }
                            os_signpost(.begin, log: log, name: "receiveValue()", signpostID: signpostID)
                            await receiveValue(value)
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
        completionHandler: @escaping () -> Void,
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
            subject.finish()
            os_signpost(.end, log: log, name: "finish()", signpostID: signpostID)
            lock.unlock()
            Task {
                _ = await task.result
                completionHandlerQueue.async {
                    completionHandler()
                }
            }
        case .terminal:
            lock.unlock()
        }
    }
    public mutating func finish() async {
        lock.lock()
        switch state {
        case .waiting:
            state = .terminal
            lock.unlock()
        case .running(let continuation, let task):
            state = .terminal
            os_signpost(.begin, log: log, name: "finish()", signpostID: signpostID)
            continuation.finish()
            os_signpost(.end, log: log, name: "finish()", signpostID: signpostID)
            lock.unlock()
            _ = await task.result
        case .terminal:
            lock.unlock()
        }
    }
}

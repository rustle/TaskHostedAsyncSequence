import os.lock

/**
 * https://forums.swift.org/t/atomic-property-wrapper-for-standard-library/30468/18
 */

final class UnfairLock {
    private var unfair_lock: os_unfair_lock_t
    init() {
        unfair_lock = .allocate(capacity: 1)
        unfair_lock.initialize(to: os_unfair_lock())
    }
    deinit {
        unfair_lock.deinitialize(count: 1)
        unfair_lock.deallocate()
    }
    func lock() {
        os_unfair_lock_lock(unfair_lock)
    }
    func unlock() {
        os_unfair_lock_unlock(unfair_lock)
    }
}

import Foundation

// MARK: - Model

/// A commitment or follow-up promise extracted from a drafted reply.
/// Persisted in App Group UserDefaults so both the main app and the
/// keyboard extension share the same list without CoreData.
struct KChimePromise: Codable, Identifiable, Equatable {
    var id: UUID
    var text: String             // the drafted reply text containing the promise
    var reminderDate: Date       // when to fire the local notification
    var notificationID: String   // matches the UNNotificationRequest identifier
    var createdAt: Date
    var isCompleted: Bool
}

// MARK: - Persistence

final class PromiseStore: @unchecked Sendable {
    nonisolated(unsafe) static let shared = PromiseStore()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let key = "kchime_promises"

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    // MARK: - Read

    var all: [KChimePromise] {
        get {
            lock.withLock {
                guard let data = defaults.data(forKey: key),
                      let list = try? JSONDecoder().decode([KChimePromise].self, from: data)
                else { return [] }
                return list.sorted { $0.reminderDate < $1.reminderDate }
            }
        }
        set {
            lock.withLock {
                if let data = try? JSONEncoder().encode(newValue) {
                    defaults.set(data, forKey: key)
                }
            }
        }
    }

    var upcoming: [KChimePromise] {
        all.filter { !$0.isCompleted && $0.reminderDate >= Date() }
    }

    var past: [KChimePromise] {
        all.filter { $0.isCompleted || $0.reminderDate < Date() }
    }

    // MARK: - Write

    func add(_ promise: KChimePromise) {
        lock.withLock {
            var list = _readAll()
            list.append(promise)
            _writeAll(list)
        }
    }

    func update(_ promise: KChimePromise) {
        lock.withLock {
            var list = _readAll()
            if let idx = list.firstIndex(where: { $0.id == promise.id }) {
                list[idx] = promise
            }
            _writeAll(list)
        }
    }

    func delete(id: UUID) {
        lock.withLock {
            let list = _readAll().filter { $0.id != id }
            _writeAll(list)
        }
    }

    func markCompleted(id: UUID) {
        lock.withLock {
            var list = _readAll()
            if let idx = list.firstIndex(where: { $0.id == id }) {
                list[idx].isCompleted = true
            }
            _writeAll(list)
        }
    }

    // MARK: - Private (caller must hold lock)

    private func _readAll() -> [KChimePromise] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([KChimePromise].self, from: data)
        else { return [] }
        return list.sorted { $0.reminderDate < $1.reminderDate }
    }

    private func _writeAll(_ list: [KChimePromise]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }
}

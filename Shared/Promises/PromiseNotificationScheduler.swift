@preconcurrency import UserNotifications
import Foundation

// MARK: - Scheduler

/// Schedules and cancels local notifications for KChime promises.
///
/// The main app must call `requestPermission()` before any notifications can fire.
/// The keyboard extension can call `schedule()` without prompting — if permission
/// hasn't been granted yet, the request will be silently dropped by the OS.
enum PromiseNotificationScheduler {

    // MARK: - Permission

    /// Requests notification authorization. Call from the main app target only
    /// (keyboard extensions cannot present permission alerts).
    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Returns the current authorization status without prompting.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    // MARK: - Schedule

    /// Schedules a calendar-triggered local notification for the given promise.
    /// Safe to call from the keyboard extension.
    static func schedule(_ promise: KChimePromise) {
        let content = UNMutableNotificationContent()
        content.title = "Promise Reminder"
        content.body = promise.text
        content.sound = .default
        content.userInfo = ["promiseID": promise.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: promise.reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: promise.notificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[PromiseScheduler] Failed to schedule '\(promise.notificationID)': \(error)")
            }
        }
    }

    // MARK: - Cancel / Reschedule

    static func cancel(notificationID: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    /// Cancels the old notification and schedules a new one (used when the user edits the date).
    static func reschedule(_ promise: KChimePromise) {
        cancel(notificationID: promise.notificationID)
        schedule(promise)
    }
}

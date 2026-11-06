import Foundation
import UserNotifications

/// Local notifications so the scorer still gets "1 minute left" and "Time!"
/// when the app is in the background or the watch screen is off.
/// (While the app is on screen the in-app alerts and haptics are used instead.)
enum AlertScheduler {
    private static let ids = ["indoor.warning", "indoor.timeup"]

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(timeUpAt: Date?, warningAt: Date?, halfLabel: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)

        if let warningAt, warningAt.timeIntervalSinceNow > 1 {
            let c = UNMutableNotificationContent()
            c.title = "Nearly time"
            c.body = "\(halfLabel) is nearly over."
            c.sound = .default
            c.interruptionLevel = .timeSensitive
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: warningAt.timeIntervalSinceNow, repeats: false)
            center.add(UNNotificationRequest(identifier: ids[0], content: c, trigger: trigger))
        }
        if let timeUpAt, timeUpAt.timeIntervalSinceNow > 1 {
            let c = UNMutableNotificationContent()
            c.title = "TIME!"
            c.body = "\(halfLabel) is over. Enter any last scores, then start the next half."
            c.sound = .default
            c.interruptionLevel = .timeSensitive
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUpAt.timeIntervalSinceNow, repeats: false)
            center.add(UNNotificationRequest(identifier: ids[1], content: c, trigger: trigger))
        }
    }
}

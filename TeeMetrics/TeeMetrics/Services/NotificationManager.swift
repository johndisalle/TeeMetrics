// MARK: - Notification Manager
// Push notifications for engagement: inactivity, handicap changes, milestones

import Foundation
import UserNotifications

enum NotificationManager {

    // MARK: - Request Permission
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    // MARK: - Schedule Inactivity Reminder
    static func scheduleInactivityReminder(lastRoundDate: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["inactivity"])

        guard let last = lastRoundDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "Miss the Course?"
        content.body = "You haven't played in a while. Your clubs are getting lonely!"
        content.sound = .default

        // Fire 14 days after last round
        let triggerDate = Calendar.current.date(byAdding: .day, value: 14, to: last) ?? last
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "inactivity", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Handicap Drop Notification
    static func scheduleHandicapDrop(newHandicap: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Handicap Update"
        content.body = String(format: "Your handicap dropped to %.1f! Keep it up.", newHandicap)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "handicap-\(UUID())", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Achievement Notification
    static func notifyAchievement(_ achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked!"
        content.body = "\(achievement.rawValue) — \(achievement.description)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement-\(achievement.rawValue)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly Summary
    static func scheduleWeeklySummary() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Golf Recap"
        content.body = "Check your stats and see how your game is trending!"
        content.sound = .default

        // Every Sunday at 10am
        var components = DateComponents()
        components.weekday = 1
        components.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "weekly", content: content, trigger: trigger)
        center.add(request)
    }
}

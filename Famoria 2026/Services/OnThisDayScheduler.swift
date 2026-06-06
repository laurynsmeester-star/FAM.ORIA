//
//  OnThisDayScheduler.swift
//  Famoria 2026
//
//  Schedules a daily 9am "On this day" notification when there are
//  past-year posts from today's calendar date. Skips silently on days
//  without any memories so we don't spam the user with empty pings.
//
//  Re-runs whenever the family's posts array changes, which keeps the
//  next-day's content fresh as new posts arrive.
//

import Foundation
import os
import UserNotifications

enum OnThisDayScheduler {

    private static let identifier = "famoria.onThisDay.daily"

    /// Inspects `posts` for any items whose month+day matches today's
    /// date in earlier years, and schedules a single local notification
    /// for 9am the next day surfacing the count. Cancels the previous
    /// schedule first so we never fire two at once.
    static func reschedule(posts: [FamilyPost]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Optional opt-out: if the user disabled it from Notification
        // Preferences, skip silently.
        if UserDefaults.standard.bool(forKey: "famoria.notif.onThisDayDisabled") {
            return
        }

        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let comps = cal.dateComponents([.month, .day], from: tomorrow)
        let thisYear = cal.component(.year, from: tomorrow)

        let memories = posts.filter { post in
            let postComps = cal.dateComponents([.year, .month, .day], from: post.timestamp)
            return postComps.month == comps.month
                && postComps.day == comps.day
                && postComps.year != thisYear
        }

        guard !memories.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "On this day"
        content.body = "\(memories.count) family memor\(memories.count == 1 ? "y" : "ies") from past years."
        content.sound = .default
        content.userInfo = ["page": "familyUpdates", "kind": "onThisDay"]

        var trigger = DateComponents()
        trigger.hour = 9
        trigger.minute = 0
        let calTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: calTrigger
        )
        center.add(request) { error in
            if let error {
                Log.notifications.error("on-this-day schedule failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

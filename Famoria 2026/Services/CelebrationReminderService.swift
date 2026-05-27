//
//  CelebrationReminderService.swift
//  Famoria 2026
//
//  Translated from sendCelebrationReminders.ts
//
//  The TypeScript version ran on a server cron and wrote Notification
//  documents to the DB. Here we use UNUserNotificationCenter to deliver
//  the same messages as local push notifications on-device.
//
//  Call `scheduleReminders(familyId:currentMemberName:)` on app launch
//  and on UIApplication.willEnterForegroundNotification so the schedule
//  stays fresh — this mirrors the periodic cron execution in TS.
//
//  Logic preserved exactly:
//    • Reminder days: [7, 3, 1, 0]
//    • Skip if member has already greeted
//    • Skip if current user IS the honoree
//    • Auto-deactivate celebrations more than 1 day past
//    • Message copy matches the TS strings character-for-character
//

import Foundation
import os
import Combine
import UserNotifications

@MainActor
final class CelebrationReminderService: ObservableObject {

    private let celebrationService = FirebaseCelebrationService()
    private let center = UNUserNotificationCenter.current()

    /// Reminder day offsets — direct translation of `const reminderDays = [7, 3, 1, 0]`
    private let reminderDays = [7, 3, 1, 0]

    // MARK: - Notification Permission

    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                Log.celebration.error("Failed to request notification permission: \(error.localizedDescription, privacy: .public)")
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Main Entry Point

    /// Fetch active celebrations and schedule local notifications.
    /// Mirrors the full body of the Deno.serve handler in sendCelebrationReminders.ts.
    func scheduleReminders(familyId: String, currentMemberName: String) async {
        guard await requestPermission() else { return }

        do {
            let celebrations = try await celebrationService.fetchActiveCelebrations(familyId: familyId)

            // Remove existing celebration notifications before rescheduling
            let pending = await center.pendingNotificationRequests()
            let staleIds = pending
                .filter { $0.identifier.hasPrefix("celebration_") }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: staleIds)

            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())

            for celebration in celebrations {
                let daysUntil = celebration.daysUntil

                // Auto-deactivate celebrations more than 1 day past
                // Mirrors: `if (daysUntil < -1) { Celebration.update(id, { is_active: false }) }`
                if daysUntil < -1 {
                    do {
                        try await celebrationService.deactivateCelebration(
                            id: celebration.id,
                            familyId: familyId
                        )
                    } catch {
                        Log.celebration.error("Failed to deactivate celebration: \(error.localizedDescription, privacy: .public)")
                    }
                    continue
                }

                // Only act on the four reminder windows
                guard reminderDays.contains(daysUntil) else { continue }

                // Skip if the current user IS the honoree
                // Mirrors: `m.name !== celebration.member_name && m.username !== celebration.member_name`
                guard celebration.memberName != currentMemberName else { continue }

                // Skip if already greeted
                // Mirrors: `const hasGreeted = celebration.greetings?.some(g => g.from_member === recipientName)`
                guard !celebration.hasGreeted(memberName: currentMemberName) else { continue }

                let message = buildMessage(
                    memberName: celebration.memberName,
                    type: celebration.celebrationType,
                    daysUntil: daysUntil
                )

                let title = "\(celebration.celebrationType.emoji) Upcoming Celebration"

                // Fire at 9 AM on the relevant day
                let fireDate = cal.date(byAdding: .day, value: daysUntil, to: today) ?? today
                await scheduleNotification(
                    id: "celebration_\(celebration.id)_d\(daysUntil)",
                    title: title,
                    body: message,
                    fireDate: fireDate
                )
            }
        } catch {
            Log.celebration.error("Error scheduling reminders: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Message Builder
    // Copy matches the TS strings exactly.

    private func buildMessage(memberName: String, type: CelebrationType, daysUntil: Int) -> String {
        switch daysUntil {
        case 0:
            return "🎉 Today is \(memberName)'s \(type.displayName)! Send your wishes now!"
        case 1:
            return "Tomorrow is \(memberName)'s \(type.displayName)! Don't forget to send your wishes."
        default:
            return "\(memberName)'s \(type.displayName) is in \(daysUntil) days. Consider sending wishes or contributing to the group gift!"
        }
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(
        id: String,
        title: String,
        body: String,
        fireDate: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "celebration"]

        // Schedule at 9:00 AM on the target day
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            Log.celebration.error("Failed to schedule notification: \(error.localizedDescription, privacy: .public)")
        }
    }
}

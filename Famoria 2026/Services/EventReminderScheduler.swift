//
//  EventReminderScheduler.swift
//  Famoria 2026
//
//  Schedules per-event local notifications at the user-selected offsets
//  before the event start, and (optionally) exports the event to Apple
//  Reminders via EventKit.
//
//  Required Info.plist keys:
//    NSRemindersUsageDescription (and NSRemindersFullAccessUsageDescription
//    on iOS 17+) — for the "Add to Apple Reminders" feature.
//

import Foundation
import os
import UserNotifications
import EventKit

@MainActor
enum EventReminderScheduler {

    /// Replaces any previously-scheduled notifications for this event with a
    /// fresh batch matching the supplied offsets. Call after every save so
    /// edits/deletes stay in sync.
    static func schedule(for event: FamilyEventV2) async {
        // 1. Clear any existing scheduled notifications for this event so
        //    edits don't leave stale fire-dates behind.
        let identifiers = ReminderOffset.allCases.map { identifier(eventId: event.id, offset: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

        guard !event.reminderOffsetsRaw.isEmpty else { return }

        // 2. Make sure we have authorization. Returning early is fine —
        //    iOS already shows the prompt on first request.
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
        } catch {
            Log.appState.error("notification auth failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // 3. Compute the event's effective start date (date + startTime if set).
        let cal = Calendar.current
        let eventStart: Date = {
            guard let t = event.startTime else { return event.date }
            let dateComps = cal.dateComponents([.year, .month, .day], from: event.date)
            let timeComps = cal.dateComponents([.hour, .minute], from: t)
            var merged = DateComponents()
            merged.year = dateComps.year
            merged.month = dateComps.month
            merged.day = dateComps.day
            merged.hour = timeComps.hour
            merged.minute = timeComps.minute
            return cal.date(from: merged) ?? event.date
        }()

        // 4. Schedule one notification per offset, but only if the resulting
        //    fire date is still in the future.
        for offset in event.reminderOffsets {
            let fireDate = eventStart.addingTimeInterval(offset.timeInterval)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = body(for: offset)
            content.sound = .default
            content.userInfo = ["type": "event_reminder", "event_id": event.id]

            let components = cal.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(eventId: event.id, offset: offset),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                Log.appState.error("schedule reminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Cancels any pending notifications for an event. Call from event-delete
    /// flows so we don't keep firing notifications for events that no longer
    /// exist on Firestore.
    static func cancelAll(eventId: String) {
        let identifiers = ReminderOffset.allCases.map { identifier(eventId: eventId, offset: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Adds the event to the system Reminders app. Returns true on success
    /// or false if the user denied access / something else went wrong.
    static func addToAppleReminders(_ event: FamilyEventV2) async -> Bool {
        let store = EKEventStore()
        let granted: Bool
        if #available(iOS 17.0, *) {
            do {
                granted = try await store.requestFullAccessToReminders()
            } catch {
                Log.appState.error("reminders access failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        } else {
            granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                store.requestAccess(to: .reminder) { ok, _ in cont.resume(returning: ok) }
            }
        }
        guard granted else { return false }

        let reminder = EKReminder(eventStore: store)
        reminder.title = event.title
        if let notes = event.notes, !notes.isEmpty {
            reminder.notes = notes
        }
        reminder.calendar = store.defaultCalendarForNewReminders()

        let cal = Calendar.current
        if let startTime = event.startTime {
            let dateComps = cal.dateComponents([.year, .month, .day], from: event.date)
            let timeComps = cal.dateComponents([.hour, .minute], from: startTime)
            var merged = DateComponents()
            merged.year = dateComps.year
            merged.month = dateComps.month
            merged.day = dateComps.day
            merged.hour = timeComps.hour
            merged.minute = timeComps.minute
            reminder.dueDateComponents = merged
            if let fireDate = cal.date(from: merged) {
                reminder.addAlarm(EKAlarm(absoluteDate: fireDate))
            }
        } else {
            let comps = cal.dateComponents([.year, .month, .day], from: event.date)
            reminder.dueDateComponents = comps
            if let fireDate = cal.date(from: comps) {
                reminder.addAlarm(EKAlarm(absoluteDate: fireDate))
            }
        }

        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            Log.appState.error("save reminder failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Helpers

    private static func identifier(eventId: String, offset: ReminderOffset) -> String {
        "event_reminder_\(eventId)_\(offset.rawValue)"
    }

    private static func body(for offset: ReminderOffset) -> String {
        switch offset {
        case .atTime:         return "It's happening now."
        case .fifteenMinutes: return "Starts in 15 minutes."
        case .oneHour:        return "Starts in 1 hour."
        case .oneDay:         return "Tomorrow."
        case .oneWeek:        return "In one week."
        }
    }
}

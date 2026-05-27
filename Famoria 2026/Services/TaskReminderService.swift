//
//  TaskReminderService.swift
//  Famoria 2026
//
//  Translated from sendTaskReminders.ts
//
//  The TypeScript version ran server-side, iterated all incomplete EventTasks,
//  and wrote a Notification document for each assigned member whose task was
//  due within the next 24 hours.
//
//  Here we fire the same reminders as local UNUserNotificationCenter
//  notifications. The existing `EventTask` model in EventModels.swift maps
//  directly to the TS entity fields — no new model needed.
//
//  Call `scheduleReminders(tasks:currentMemberName:)` on app launch and
//  app foreground to keep the notification queue fresh.
//
//  Logic preserved exactly:
//    • Only incomplete tasks (`!t.is_completed`)
//    • Only tasks with a due_date and assigned_to members
//    • Only tasks due within the next 24 hours
//    • Only tasks assigned to the current user
//    • Message: `Reminder: "<task_name>" is due tomorrow!`
//

import Foundation
import os
import Combine
import UserNotifications

@MainActor
final class TaskReminderService: ObservableObject {

    private let center = UNUserNotificationCenter.current()

    // MARK: - Main Entry Point

    /// Schedule local notifications for incomplete tasks assigned to the
    /// current member that are due within the next 24 hours.
    ///
    /// Mirrors the full body of the Deno.serve handler in sendTaskReminders.ts.
    func scheduleReminders(tasks: [EventTask], currentMemberName: String) async {
        // Clear stale task notifications before rescheduling
        let pending = await center.pendingNotificationRequests()
        let staleIds = pending
            .filter { $0.identifier.hasPrefix("task_") }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)

        let now = Date()
        // 24-hour window — mirrors: `const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000)`
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)

        // Filter mirrors: `tasks.filter(t => !t.is_completed)`
        let incompleteTasks = tasks.filter { !$0.isCompleted }

        for task in incompleteTasks {
            // Mirrors: `if (!task.due_date || !task.assigned_to || task.assigned_to.length === 0) continue`
            guard let dueDate = task.dueDate,
                  !task.assignedTo.isEmpty else { continue }

            // Only notify the currently signed-in member
            guard task.assignedTo.contains(currentMemberName) else { continue }

            // Mirrors: `if (dueDate >= now && dueDate <= tomorrow)`
            guard dueDate >= now && dueDate <= tomorrow else { continue }

            await scheduleNotification(for: task)
        }
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(for task: EventTask) async {
        let content = UNMutableNotificationContent()
        // Title and body match the TS strings exactly
        content.title = "Task Due Soon"
        content.body = "Reminder: \"\(task.taskName)\" is due tomorrow!"
        content.sound = .default
        content.userInfo = ["type": "task_reminder", "task_id": task.id]

        // Deliver shortly — the TS cron sends the notification as soon as it runs.
        // A 1-second delay lets the UI settle before the banner appears.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_\(task.id)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            Log.tasks.error("Failed to schedule task reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Convenience

    /// Returns the count of pending task-reminder notifications (useful for badges / debugging).
    func pendingReminderCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix("task_") }.count
    }
}

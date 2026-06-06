//
//  FamoriaNotificationCategories.swift
//  Famoria 2026
//
//  Registers our `UNNotificationCategory` set with the system so push
//  notifications and locally-scheduled reminders can render actionable
//  buttons (RSVP Yes/No, Mark task done, inline Reply).
//
//  Senders attach the `categoryIdentifier` to their notification
//  payload; `AppDelegate.userNotificationCenter(_:didReceive:)` handles
//  the tapped action.
//

import Foundation
import UserNotifications

enum FamoriaNotifCategory: String {
    /// Family event invite. Actions: RSVP Yes / Maybe / No.
    case eventInvite      = "famoria.event.invite"
    /// Event task assigned to me. Action: Mark done.
    case taskAssigned     = "famoria.task.assigned"
    /// Direct or group message. Action: inline reply.
    case message          = "famoria.message"
    /// Personal to-do due-soon reminder. Action: Mark done.
    case personalTaskDue  = "famoria.personalTask.due"
}

enum FamoriaNotifAction: String {
    case rsvpYes      = "famoria.action.rsvpYes"
    case rsvpMaybe    = "famoria.action.rsvpMaybe"
    case rsvpNo       = "famoria.action.rsvpNo"
    case markTaskDone = "famoria.action.markTaskDone"
    case reply        = "famoria.action.reply"
}

enum FamoriaNotificationCategories {

    /// Installs every category on `UNUserNotificationCenter`. Idempotent
    /// — calling more than once just replaces the registered set.
    static func register() {
        let rsvpYes = UNNotificationAction(
            identifier: FamoriaNotifAction.rsvpYes.rawValue,
            title: "Going",
            options: [.foreground]
        )
        let rsvpMaybe = UNNotificationAction(
            identifier: FamoriaNotifAction.rsvpMaybe.rawValue,
            title: "Maybe",
            options: []
        )
        let rsvpNo = UNNotificationAction(
            identifier: FamoriaNotifAction.rsvpNo.rawValue,
            title: "Can't make it",
            options: [.destructive]
        )

        let markDone = UNNotificationAction(
            identifier: FamoriaNotifAction.markTaskDone.rawValue,
            title: "Mark done",
            options: []
        )

        let reply = UNTextInputNotificationAction(
            identifier: FamoriaNotifAction.reply.rawValue,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a reply…"
        )

        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(
                identifier: FamoriaNotifCategory.eventInvite.rawValue,
                actions: [rsvpYes, rsvpMaybe, rsvpNo],
                intentIdentifiers: [],
                options: [.customDismissAction]
            ),
            UNNotificationCategory(
                identifier: FamoriaNotifCategory.taskAssigned.rawValue,
                actions: [markDone],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: FamoriaNotifCategory.personalTaskDue.rawValue,
                actions: [markDone],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: FamoriaNotifCategory.message.rawValue,
                actions: [reply],
                intentIdentifiers: []
            )
        ]

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}

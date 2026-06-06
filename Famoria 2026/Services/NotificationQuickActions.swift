//
//  NotificationQuickActions.swift
//  Famoria 2026
//
//  Small Firestore writers invoked from notification-action taps. They
//  intentionally stay outside of AppState because they're often invoked
//  while the app is still launching from a cold start and the family
//  context may not yet be fully populated.
//

import Foundation
import os
import FirebaseFirestore

enum EventPlanningRSVPWriter {
    /// Upserts an RSVP doc under
    /// `families/{familyId}/eventPlanning/{eventId}/rsvps/{memberName}`.
    static func recordRSVP(
        familyId: String,
        eventId: String,
        memberName: String,
        status: String
    ) async {
        let db = Firestore.firestore()
        let docId = memberName.lowercased().replacingOccurrences(of: " ", with: "_")
        let data: [String: Any] = [
            "id": docId,
            "eventId": eventId,
            "memberName": memberName,
            "status": status,
            "guests": 0,
            "notes": "",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("families")
                .document(familyId)
                .collection("eventPlanning")
                .document(eventId)
                .collection("rsvps")
                .document(docId)
                .setData(data, merge: true)
        } catch {
            Log.appState.error("notif RSVP write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum UserTasksQuickActions {
    /// Sets `isDone = true` on a personal user task.
    static func markDone(userId: String, taskId: String) async {
        let db = Firestore.firestore()
        do {
            try await db.collection("famoria_user_tasks")
                .document(userId)
                .collection("tasks")
                .document(taskId)
                .updateData(["isDone": true])
        } catch {
            Log.appState.error("notif markDone failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Sets `isCompleted = true` on an event-planning task assigned to
    /// the signed-in user.
    static func markEventTaskDone(familyId: String, eventId: String, taskId: String) async {
        let db = Firestore.firestore()
        do {
            try await db.collection("families")
                .document(familyId)
                .collection("eventPlanning")
                .document(eventId)
                .collection("tasks")
                .document(taskId)
                .updateData(["isCompleted": true])
        } catch {
            Log.appState.error("notif markEventTaskDone failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

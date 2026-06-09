//
//  MedicationService.swift
//  Famoria 2026
//
//  Family-wide medication tracking. Each entry carries dosage, the
//  member taking it, an optional refill date, and a per-day schedule of
//  reminder times. The scheduler queues a UNCalendarNotificationTrigger
//  for each (medication × reminder time) pair so the user gets a daily
//  ping per dose, plus a one-shot "refill" reminder when the supply
//  runs out.
//

import Foundation
import os
import FirebaseFirestore
import UserNotifications

/// One medication that a family member is taking. Stored under
/// `families/{familyId}/medications/{id}`.
struct FamoriaMedication: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var memberName: String
    var name: String
    var dosage: String
    var instructions: String
    /// HH:mm strings (24h) for each daily dose. Empty array means "no
    /// scheduled doses, ad-hoc only".
    var reminderTimes: [String]
    /// Optional refill date — used both as a UI badge and as the trigger
    /// date for a one-shot "Refill X" notification.
    var refillDate: Date?
    var isActive: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        memberName: String,
        name: String,
        dosage: String = "",
        instructions: String = "",
        reminderTimes: [String] = [],
        refillDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.memberName = memberName
        self.name = name
        self.dosage = dosage
        self.instructions = instructions
        self.reminderTimes = reminderTimes
        self.refillDate = refillDate
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

@MainActor
final class MedicationService {
    private let db = Firestore.firestore()

    private func ref(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("medications")
    }

    func upsert(_ med: FamoriaMedication, familyId: String) async throws {
        try ref(familyId: familyId).document(med.id).setData(from: med)
        MedicationReminderScheduler.reschedule(med)
    }

    func delete(_ medId: String, familyId: String) async throws {
        try await ref(familyId: familyId).document(medId).delete()
        MedicationReminderScheduler.cancelAll(medId: medId)
    }

    func observe(familyId: String, onChange: @escaping ([FamoriaMedication]) -> Void) -> ListenerRegistration {
        ref(familyId: familyId).addSnapshotListener { snapshot, _ in
            let items = snapshot?.documents.compactMap {
                try? $0.data(as: FamoriaMedication.self)
            } ?? []
            onChange(items)
        }
    }
}

// MARK: - Reminder scheduler

@MainActor
enum MedicationReminderScheduler {

    static func reschedule(_ med: FamoriaMedication) {
        cancelAll(medId: med.id)
        guard med.isActive else { return }

        // One repeating daily notification per scheduled time.
        for time in med.reminderTimes {
            scheduleDose(med: med, hhmm: time)
        }

        // Optional one-shot refill reminder at 9am on the refill day.
        if let refill = med.refillDate {
            scheduleRefill(med: med, on: refill)
        }
    }

    static func cancelAll(medId: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("med-\(medId)-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Private

    private static func scheduleDose(med: FamoriaMedication, hhmm: String) {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Medication: \(med.name)"
        var body = "Time for \(med.memberName)'s dose."
        if !med.dosage.isEmpty { body += " (\(med.dosage))" }
        content.body = body
        content.sound = .default
        content.categoryIdentifier = FamoriaNotifCategory.personalTaskDue.rawValue
        content.userInfo = ["page": "health", "medId": med.id]

        var trigger = DateComponents()
        trigger.hour = hour
        trigger.minute = minute
        let calTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)

        let id = "med-\(med.id)-\(hhmm)"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: calTrigger)
        UNUserNotificationCenter.current().add(req)
    }

    private static func scheduleRefill(med: FamoriaMedication, on date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Refill due: \(med.name)"
        content.body = "Pick up \(med.memberName)'s prescription today."
        content.sound = .default
        content.userInfo = ["page": "health", "medId": med.id, "kind": "refill"]

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let id = "med-\(med.id)-refill"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

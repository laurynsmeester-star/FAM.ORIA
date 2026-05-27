//
//  CalendarSyncService.swift
//  Famoria 2026
//
//  Translated from syncToGoogleCalendar.ts
//
//  The TypeScript version called the Google Calendar REST API directly using
//  an OAuth2 access token. On iOS the native EventKit framework is the right
//  replacement: it writes to the system Calendar app which the user can already
//  have linked to Google Calendar, iCloud, Exchange, etc. — no extra OAuth
//  flow required in the app itself.
//
//  All event-construction logic is preserved:
//    • All-day vs timed events (start/end time handling)
//    • end_date fallback to start date
//    • Recurring events → RRULE:FREQ=YEARLY → EKRecurrenceRule(.yearly)
//    • MM-DD recurring date normalisation to current year
//    • Duplicate guard (avoids re-adding the same event title+date)
//
//  Works with both FamilyEvent (legacy) and FamilyEventV2 (enhanced).
//  Events are written to a dedicated "Famoria" calendar so they're easy to
//  identify and don't clutter the user's default calendar.
//
//  SETUP NOTES:
//    Add NSCalendarsUsageDescription (and NSCalendarsWriteOnlyAccessUsageDescription
//    for iOS 17+) to your Info.plist.
//

import Foundation
import os
import Combine
import EventKit
import UIKit

// MARK: - Sync Status

enum CalendarSyncStatus: Equatable {
    case idle
    case syncing
    case success(CalendarSyncResult)
    case failed(String)

    var description: String {
        switch self {
        case .idle:            return "Not synced yet"
        case .syncing:         return "Syncing…"
        case .success(let r):  return "Synced \(r.synced) of \(r.total) events"
        case .failed(let msg): return "Sync failed: \(msg)"
        }
    }
}

struct CalendarSyncResult: Equatable {
    let synced: Int
    let total: Int
    let errors: [String]?
}

// MARK: - Calendar Sync Service

@MainActor
final class CalendarSyncService: ObservableObject {

    @Published var status: CalendarSyncStatus = .idle
    @Published var lastResult: CalendarSyncResult?

    private let store = EKEventStore()
    /// Name of the dedicated Famoria calendar created in the system Calendar app
    private let calendarTitle = "Famoria"

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let current = EKEventStore.authorizationStatus(for: .event)
        switch current {
        case .fullAccess:
            return true
        case .authorized:   // pre-iOS 17
            return true
        case .notDetermined:
            if #available(iOS 17.0, *) {
                do {
                    return try await store.requestFullAccessToEvents()
                } catch {
                    Log.calendar.error("Failed to request calendar full access: \(error.localizedDescription, privacy: .public)")
                    return false
                }
            } else {
                return await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { granted, _ in
                        cont.resume(returning: granted)
                    }
                }
            }
        default:
            return false
        }
    }

    // MARK: - Sync — FamilyEventV2 (enhanced model)

    /// Primary sync method. Mirrors the full handler in syncToGoogleCalendar.ts.
    @discardableResult
    func syncEvents(_ events: [FamilyEventV2]) async -> CalendarSyncResult {
        status = .syncing

        guard await requestPermission() else {
            let msg = "Calendar access denied. Allow access in Settings → Privacy → Calendars."
            status = .failed(msg)
            return CalendarSyncResult(synced: 0, total: events.count, errors: [msg])
        }

        let calendar = getFamoriaCalendar()
        var syncedCount = 0
        var errors: [String] = []

        for event in events {
            do {
                try syncEvent(event, to: calendar)
                syncedCount += 1
            } catch {
                // Mirrors: `errors.push({ event: event.title, error: errorData.error?.message })`
                errors.append("\(event.title): \(error.localizedDescription)")
            }
        }

        do {
            try store.commit()
        } catch {
            status = .failed(error.localizedDescription)
            return CalendarSyncResult(synced: 0, total: events.count, errors: [error.localizedDescription])
        }

        let result = CalendarSyncResult(
            synced: syncedCount,
            total: events.count,
            errors: errors.isEmpty ? nil : errors
        )
        lastResult = result
        status = .success(result)
        return result
    }

    // MARK: - Sync — FamilyEvent (legacy model)

    /// Convenience overload for the legacy FamilyEvent model used in AppState.
    @discardableResult
    func syncEvents(_ events: [FamilyEvent]) async -> CalendarSyncResult {
        let v2 = events.map { e in
            FamilyEventV2(
                id: e.id,
                title: e.title,
                date: e.date,
                endDate: e.endDate,
                createdBy: e.createdBy
            )
        }
        return await syncEvents(v2)
    }

    // MARK: - Single Event Construction
    // Mirrors the `calendarEvent` object built in the TS for-loop.

    private func syncEvent(_ familyEvent: FamilyEventV2, to calendar: EKCalendar) throws {
        // Normalise recurring event dates that were stored as MM-DD
        // Mirrors the TS block: `if (event.is_recurring && event.date.includes('-') && event.date.length === 5)`
        var eventDate = familyEvent.date
        if familyEvent.isRecurring {
            let cal = Calendar.current
            let comps = cal.dateComponents([.month, .day], from: familyEvent.date)
            let currentYear = cal.component(.year, from: Date())
            if let normalised = cal.date(from: DateComponents(
                year: currentYear,
                month: comps.month,
                day: comps.day
            )) {
                eventDate = normalised
            }
        }

        let endDate = familyEvent.endDate ?? eventDate

        // Duplicate check — avoid re-adding the same event
        let windowEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        let predicate = store.predicateForEvents(
            withStart: eventDate,
            end: windowEnd,
            calendars: [calendar]
        )
        let existing = store.events(matching: predicate).first { $0.title == familyEvent.title }

        let ekEvent = existing ?? EKEvent(eventStore: store)
        ekEvent.title = familyEvent.title
        ekEvent.calendar = calendar
        ekEvent.notes = familyEvent.notes
        ekEvent.location = familyEvent.location

        // Date/time logic — mirrors the TS start/end block:
        // `event.start_time ? { dateTime: ... } : { date: eventDate }`
        if let startTime = familyEvent.startTime {
            ekEvent.startDate = combineDateAndTime(date: eventDate, time: startTime)

            if let endTime = familyEvent.endTime {
                ekEvent.endDate = combineDateAndTime(date: endDate, time: endTime)
            } else {
                // TS fallback: use start_time for end too
                ekEvent.endDate = ekEvent.startDate.addingTimeInterval(3_600) // 1 hour default
            }
            ekEvent.isAllDay = false
        } else {
            ekEvent.startDate = Calendar.current.startOfDay(for: eventDate)
            ekEvent.endDate = Calendar.current.startOfDay(for: endDate)
            ekEvent.isAllDay = true
        }

        // Recurrence — mirrors `recurrence: event.is_recurring ? ['RRULE:FREQ=YEARLY'] : undefined`
        if familyEvent.isRecurring {
            let rule = EKRecurrenceRule(
                recurrenceWith: .yearly,
                interval: 1,
                end: nil
            )
            ekEvent.recurrenceRules = [rule]
        }

        try store.save(ekEvent, span: .thisEvent, commit: false)
    }

    // MARK: - Famoria Calendar

    /// Returns the existing "Famoria" calendar or creates it in the store.
    private func getFamoriaCalendar() -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }
        let newCal = EKCalendar(for: .event, eventStore: store)
        newCal.title = calendarTitle
        newCal.cgColor = UIColor.systemPurple.cgColor
        // Use the same source as the default new-event calendar
        if let source = store.defaultCalendarForNewEvents?.source {
            newCal.source = source
        } else if let local = store.sources.first(where: { $0.sourceType == .local }) {
            newCal.source = local
        }
        do {
            try store.saveCalendar(newCal, commit: true)
        } catch {
            Log.calendar.error("Failed to save Famoria calendar: \(error.localizedDescription, privacy: .public)")
        }
        return newCal
    }

    // MARK: - Helpers

    /// Combines a calendar date with a time-of-day date into a single Date.
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        let dateComps = cal.dateComponents([.year, .month, .day], from: date)
        let timeComps = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(from: DateComponents(
            year: dateComps.year,
            month: dateComps.month,
            day: dateComps.day,
            hour: timeComps.hour,
            minute: timeComps.minute
        )) ?? date
    }
}

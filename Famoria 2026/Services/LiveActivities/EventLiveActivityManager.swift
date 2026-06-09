//
//  EventLiveActivityManager.swift
//  Famoria 2026
//
//  Manages the lifecycle of the "next family event" Live Activity. The
//  app calls `startOrUpdate(for:)` whenever `appState.events` changes;
//  the manager picks the next upcoming event and either starts a new
//  Activity or updates the existing one. Calls `.end(...)` when no
//  upcoming event remains.
//
//  Until the Widget Extension target is added (see
//  FamoriaEventActivity.swift header), `Activity.request(...)` returns
//  silently — no crash, just no visible Live Activity.
//

import Foundation
import os
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
enum EventLiveActivityManager {

    #if canImport(ActivityKit)
    /// Replaces or refreshes the currently-running event activity.
    /// Pass the events array straight from AppState.
    static func startOrUpdate(events: [FamilyEvent]) async {
        let upcomingCutoff = Date().addingTimeInterval(-3600) // include events
                                                              // that started up
                                                              // to an hour ago
        guard let next = events
            .filter({ $0.upcomingDate >= upcomingCutoff })
            .sorted(by: { $0.upcomingDate < $1.upcomingDate })
            .first
        else {
            await endAll()
            return
        }

        let state = FamoriaEventActivity.ContentState(
            startDate: effectiveStart(for: next),
            location: next.location ?? "",
            hasStarted: effectiveStart(for: next) <= Date()
        )

        // Update an existing activity if one is already running.
        if let existing = Activity<FamoriaEventActivity>.activities.first {
            await existing.update(
                ActivityContent(state: state, staleDate: state.startDate.addingTimeInterval(3600))
            )
            return
        }

        // Otherwise request a new one.
        let attributes = FamoriaEventActivity(title: next.title, eventId: next.id)
        do {
            _ = try Activity<FamoriaEventActivity>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: state.startDate.addingTimeInterval(3600)),
                pushType: nil
            )
        } catch {
            Log.appState.debug("Live Activity request skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func endAll() async {
        for activity in Activity<FamoriaEventActivity>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }

    private static func effectiveStart(for event: FamilyEvent) -> Date {
        let date = event.upcomingDate
        guard let time = event.startTime else { return date }
        let cal = Calendar.current
        let day = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = day.year; merged.month = day.month; merged.day = day.day
        merged.hour = t.hour; merged.minute = t.minute
        return cal.date(from: merged) ?? date
    }
    #else
    static func startOrUpdate(events: [FamilyEvent]) async { }
    static func endAll() async { }
    #endif
}

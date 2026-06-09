//
//  FamoriaUpcomingWidget.swift
//  Famoria 2026 (Widget Extension target)
//
//  Home-screen widget that surfaces the next family event + a list of
//  upcoming personal tasks. Designed to live in a Widget Extension
//  target — add it via File → New → Target → Widget Extension and drop
//  this file into the new target only.
//
//  Data hand-off: the widget reads a small JSON blob from a shared App
//  Group. The main app writes that blob via `WidgetSnapshotWriter`
//  whenever the upcoming-event set or task list changes; the widget
//  reads it from inside its `TimelineProvider`. App Group identifier:
//  "group.com.famoria.app" — create it in both target capabilities.
//

import WidgetKit
import SwiftUI

/// Plain Codable struct shared via App Group user defaults.
struct FamoriaWidgetSnapshot: Codable {
    var familyName: String
    var nextEventTitle: String?
    var nextEventDate: Date?
    var nextEventLocation: String?
    var upcomingTasks: [String]

    static let empty = FamoriaWidgetSnapshot(
        familyName: "Our Family",
        nextEventTitle: nil,
        nextEventDate: nil,
        nextEventLocation: nil,
        upcomingTasks: []
    )
}

enum FamoriaWidgetSharedStorage {
    static let appGroupID = "group.com.famoria.app"
    static let key = "famoria.widget.snapshot"

    static func read() -> FamoriaWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(FamoriaWidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    /// Called from the main app whenever the relevant state changes.
    static func write(_ snapshot: FamoriaWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: FamoriaUpcomingWidget.kind)
            #endif
        }
    }
}

// MARK: - Timeline Provider

struct FamoriaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FamoriaWidgetSnapshot
}

struct FamoriaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamoriaWidgetEntry {
        FamoriaWidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (FamoriaWidgetEntry) -> Void) {
        completion(FamoriaWidgetEntry(date: Date(),
                                      snapshot: FamoriaWidgetSharedStorage.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FamoriaWidgetEntry>) -> Void) {
        let entry = FamoriaWidgetEntry(date: Date(),
                                       snapshot: FamoriaWidgetSharedStorage.read())
        // Refresh every 30 minutes; the app pushes an immediate reload
        // when state actually changes.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget View

struct FamoriaWidgetView: View {
    let entry: FamoriaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.snapshot.familyName)
                .font(.caption.weight(.semibold))
                .foregroundColor(.purple)

            if let title = entry.snapshot.nextEventTitle, let date = entry.snapshot.nextEventDate {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(date, style: .relative)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            } else {
                Text("No upcoming events.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !entry.snapshot.upcomingTasks.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(entry.snapshot.upcomingTasks.prefix(3), id: \.self) { task in
                    Label(task, systemImage: "checkmark.circle")
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Widget

struct FamoriaUpcomingWidget: Widget {
    static let kind = "FamoriaUpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FamoriaWidgetProvider()) { entry in
            FamoriaWidgetView(entry: entry)
        }
        .configurationDisplayName("Famoria")
        .description("Your next family event and a few tasks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

//
//  WidgetSnapshotWriter.swift
//  Famoria 2026
//
//  Writes the small JSON blob the Home Screen widget reads from a
//  shared App Group. Called whenever events / personal tasks change.
//
//  Required Xcode setup:
//    1. Both the main app and the Widget Extension target need the
//       "App Groups" capability with id `group.com.famoria.app`.
//    2. The mirror types `FamoriaWidgetSnapshot` and
//       `FamoriaWidgetSharedStorage` live in
//       Shared/Widget/FamoriaUpcomingWidget.swift — add them to BOTH
//       target memberships (main app + widget) so the writer (here)
//       and the reader (the widget timeline provider) decode the same
//       struct.
//
//  Until those steps are done this writer is a no-op (UserDefaults
//  with an unknown suite name returns nil and the write silently
//  drops). Safe to call regardless.
//

import Foundation

enum WidgetSnapshotWriter {

    static func refresh(
        familyName: String?,
        events: [FamilyEvent],
        personalTasks: [String]
    ) {
        let cutoff = Calendar.current.startOfDay(for: Date())
        let next = events
            .filter { $0.upcomingDate >= cutoff }
            .sorted { $0.upcomingDate < $1.upcomingDate }
            .first

        let snapshot = FamoriaWidgetSnapshot(
            familyName: familyName ?? "Our Family",
            nextEventTitle: next?.title,
            nextEventDate: next?.upcomingDate,
            nextEventLocation: next?.location,
            upcomingTasks: Array(personalTasks.prefix(5))
        )
        FamoriaWidgetSharedStorage.write(snapshot)
    }
}

// MARK: - Local stand-in types

// Until the Widget Extension target is added (and the shared
// FamoriaUpcomingWidget.swift is added to BOTH target memberships),
// the symbols below let this file compile against the main-app
// target alone. After the extension is wired up, delete these and
// rely on the real definitions from Shared/Widget/.

#if !WIDGET_EXTENSION
struct FamoriaWidgetSnapshot: Codable {
    var familyName: String
    var nextEventTitle: String?
    var nextEventDate: Date?
    var nextEventLocation: String?
    var upcomingTasks: [String]
}

enum FamoriaWidgetSharedStorage {
    static let appGroupID = "group.com.famoria.app"
    static let key = "famoria.widget.snapshot"

    static func write(_ snapshot: FamoriaWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }
}
#endif

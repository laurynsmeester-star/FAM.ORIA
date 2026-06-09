//
//  FamoriaEventActivity.swift
//  Famoria 2026
//
//  Shared `ActivityAttributes` for the "next family event" Live
//  Activity. Lives in the main app so both the host (this target) and
//  the Widget Extension can decode it from the same type.
//
//  IMPORTANT — manual Xcode step required to surface the Live Activity:
//    1. File → New → Target → Widget Extension. Name it
//       "FamoriaWidget". Check "Include Live Activity".
//    2. Add this file (FamoriaEventActivity.swift) to BOTH target
//       memberships (main app + widget). The Widget Extension imports
//       it to declare its `Widget` view.
//    3. Drop in the file at
//       Famoria 2026/Services/LiveActivities/FamoriaEventLiveActivityView.swift
//       (also created by this PR) and add it to the Widget Extension
//       target only.
//    4. In the main target's Info plist build settings, add
//       `INFOPLIST_KEY_NSSupportsLiveActivities = YES`.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
struct FamoriaEventActivity: ActivityAttributes {
    /// Static attributes — set once on `Activity.request(...)`.
    public typealias FamoriaEventActivityState = ContentState

    public struct ContentState: Codable, Hashable {
        /// Distance from "now" to the event's start date. The widget
        /// renders this with `Text(.timer)` for an automatic countdown.
        public var startDate: Date
        /// Pre-computed location string (or empty if none).
        public var location: String
        /// Whether the event has begun — flips the chrome from
        /// "starts in" to "happening now".
        public var hasStarted: Bool
    }

    public var title: String
    public var eventId: String
}
#endif

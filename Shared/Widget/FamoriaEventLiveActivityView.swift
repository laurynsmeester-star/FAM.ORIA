//
//  FamoriaEventLiveActivityView.swift
//  Famoria 2026 (Widget Extension target)
//
//  ActivityKit Widget that renders the upcoming-event Live Activity in
//  the Lock Screen / Dynamic Island. Add this file to the Widget
//  Extension target only — and add the matching
//  Famoria 2026/Services/LiveActivities/FamoriaEventActivity.swift to
//  BOTH target memberships so the types match across the boundary.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct FamoriaEventLiveActivityView: View {
    let context: ActivityViewContext<FamoriaEventActivity>

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .pink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: context.state.hasStarted ? "checkmark.seal.fill" : "calendar")
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                if context.state.hasStarted {
                    Text("Happening now")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text(context.state.startDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !context.state.location.isEmpty {
                    Text(context.state.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
    }
}

struct FamoriaEventLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FamoriaEventActivity.self) { context in
            FamoriaEventLiveActivityView(context: context)
                .activityBackgroundTint(Color.purple.opacity(0.15))
                .activitySystemActionForegroundColor(.purple)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.hasStarted
                          ? "checkmark.seal.fill"
                          : "calendar")
                        .foregroundColor(.purple)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.hasStarted {
                        Text("Now").font(.caption).foregroundColor(.green)
                    } else {
                        Text(context.state.startDate, style: .timer)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.subheadline.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.location.isEmpty {
                        Text(context.state.location).font(.caption2).foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "calendar").foregroundColor(.purple)
            } compactTrailing: {
                if context.state.hasStarted {
                    Text("Now").font(.caption2)
                } else {
                    Text(context.state.startDate, style: .timer)
                        .font(.caption2)
                        .frame(maxWidth: 50)
                }
            } minimal: {
                Image(systemName: "calendar").foregroundColor(.purple)
            }
        }
    }
}

/// The Widget Extension's `@main` entry. Bundles the home-screen widget
/// + the Live Activity into one extension.
@main
struct FamoriaWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamoriaUpcomingWidget()
        FamoriaEventLiveActivity()
    }
}

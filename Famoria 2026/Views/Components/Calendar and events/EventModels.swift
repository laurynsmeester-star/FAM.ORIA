//
//  EventModels.swift
//  Famoria 2026
//
//  Extended event-planning models translated from the web reference.
//  Adds: event metadata (location, type, recurring, time range, end date),
//        RSVPs, tasks, schedule items, polls + votes, and reminders.
//
//  These are additive types — your existing `FamilyEvent` keeps working.
//  When you're ready, replace the old struct with `FamilyEvent` below
//  (or migrate field-by-field).
//

import Foundation
import SwiftUI

// MARK: - Event Type

public enum EventType: String, Codable, CaseIterable, Identifiable {
    case holiday
    case birthday
    case anniversary
    case vacation
    case reunion
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .holiday:     return "Holiday"
        case .birthday:    return "Birthday"
        case .anniversary: return "Anniversary"
        case .vacation:    return "Vacation"
        case .reunion:     return "Reunion"
        case .other:       return "Other"
        }
    }

    /// Color pair (fill, border) — mirrors the React `eventStyleGetter`.
    public var colors: (fill: Color, border: Color) {
        switch self {
        case .holiday:     return (Color(red: 0.94, green: 0.27, blue: 0.27), Color(red: 0.86, green: 0.15, blue: 0.15))
        case .birthday:    return (Color(red: 0.93, green: 0.28, blue: 0.60), Color(red: 0.86, green: 0.15, blue: 0.47))
        case .anniversary: return (Color(red: 0.96, green: 0.25, blue: 0.37), Color(red: 0.88, green: 0.11, blue: 0.28))
        case .vacation:    return (Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.15, green: 0.39, blue: 0.92))
        case .reunion:     return (Color(red: 0.66, green: 0.33, blue: 0.97), Color(red: 0.58, green: 0.20, blue: 0.92))
        case .other:       return (Color(red: 0.39, green: 0.45, blue: 0.55), Color(red: 0.28, green: 0.34, blue: 0.42))
        }
    }

    public var icon: String {
        switch self {
        case .holiday:     return "gift.fill"
        case .birthday:    return "birthday.cake.fill"
        case .anniversary: return "heart.fill"
        case .vacation:    return "airplane"
        case .reunion:     return "person.3.fill"
        case .other:       return "calendar"
        }
    }
}

// MARK: - Family Event (enhanced)

/// Drop-in replacement for the legacy `FamilyEvent`. Keeps `id/title/date/createdBy`
/// at the same names, adds optional planning metadata.
public struct FamilyEventV2: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var date: Date
    public var endDate: Date?
    public var startTime: Date?
    public var endTime: Date?
    public var location: String?
    public var notes: String?
    public var eventType: EventType
    public var isRecurring: Bool
    public var createdBy: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        date: Date,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        eventType: EventType = .other,
        isRecurring: Bool = false,
        createdBy: String
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.notes = notes
        self.eventType = eventType
        self.isRecurring = isRecurring
        self.createdBy = createdBy
    }

    /// For recurring events, returns the next upcoming occurrence
    /// (this year if not yet passed, otherwise next year).
    public var nextOccurrence: Date {
        guard isRecurring else { return date }
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.month, .day], from: date)
        let thisYear = cal.component(.year, from: now)
        var next = cal.date(from: DateComponents(year: thisYear, month: comps.month, day: comps.day)) ?? date
        if next < cal.startOfDay(for: now) {
            next = cal.date(from: DateComponents(year: thisYear + 1, month: comps.month, day: comps.day)) ?? next
        }
        return next
    }
}

// MARK: - RSVP

public enum RSVPStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case attending
    case maybe
    case notAttending = "not_attending"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pending:      return "Pending"
        case .attending:    return "Attending"
        case .maybe:        return "Maybe"
        case .notAttending: return "Not Attending"
        }
    }

    public var color: Color {
        switch self {
        case .pending:      return .blue
        case .attending:    return .green
        case .maybe:        return .orange
        case .notAttending: return .gray
        }
    }
}

public struct EventRSVP: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var eventId: String
    public var memberName: String
    public var status: RSVPStatus
    public var guests: Int
    public var notes: String

    public init(
        id: String = UUID().uuidString,
        eventId: String,
        memberName: String,
        status: RSVPStatus = .pending,
        guests: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.eventId = eventId
        self.memberName = memberName
        self.status = status
        self.guests = guests
        self.notes = notes
    }
}

// MARK: - Task

public struct EventTask: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var eventId: String
    public var taskName: String
    public var description: String
    public var assignedTo: [String]
    public var dueDate: Date?
    public var isCompleted: Bool

    public init(
        id: String = UUID().uuidString,
        eventId: String,
        taskName: String,
        description: String = "",
        assignedTo: [String] = [],
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.eventId = eventId
        self.taskName = taskName
        self.description = description
        self.assignedTo = assignedTo
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
}

// MARK: - Schedule Item

public struct EventScheduleItem: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var eventId: String
    public var time: Date
    public var activity: String
    public var location: String
    public var notes: String
    public var order: Int

    public init(
        id: String = UUID().uuidString,
        eventId: String,
        time: Date,
        activity: String,
        location: String = "",
        notes: String = "",
        order: Int = 0
    ) {
        self.id = id
        self.eventId = eventId
        self.time = time
        self.activity = activity
        self.location = location
        self.notes = notes
        self.order = order
    }
}

// MARK: - Polls

public struct EventPoll: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var eventId: String
    public var question: String
    public var options: [String]
    public var multipleChoice: Bool
    public var isClosed: Bool

    public init(
        id: String = UUID().uuidString,
        eventId: String,
        question: String,
        options: [String],
        multipleChoice: Bool = false,
        isClosed: Bool = false
    ) {
        self.id = id
        self.eventId = eventId
        self.question = question
        self.options = options
        self.multipleChoice = multipleChoice
        self.isClosed = isClosed
    }
}

public struct PollVote: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var pollId: String
    public var voterName: String
    public var selectedOption: String

    public init(
        id: String = UUID().uuidString,
        pollId: String,
        voterName: String,
        selectedOption: String
    ) {
        self.id = id
        self.pollId = pollId
        self.voterName = voterName
        self.selectedOption = selectedOption
    }
}

// MARK: - Reminder

public enum ReminderOffset: String, Codable, CaseIterable, Identifiable {
    case atTime           = "at_time"
    case fifteenMinutes   = "15_min"
    case oneHour          = "1_hour"
    case oneDay           = "1_day"
    case oneWeek          = "1_week"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .atTime:         return "At time of event"
        case .fifteenMinutes: return "15 minutes before"
        case .oneHour:        return "1 hour before"
        case .oneDay:         return "1 day before"
        case .oneWeek:        return "1 week before"
        }
    }

    public var timeInterval: TimeInterval {
        switch self {
        case .atTime:         return 0
        case .fifteenMinutes: return -15 * 60
        case .oneHour:        return -60 * 60
        case .oneDay:         return -24 * 60 * 60
        case .oneWeek:        return -7 * 24 * 60 * 60
        }
    }
}

public struct EventReminder: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var eventId: String
    public var memberName: String
    public var offset: ReminderOffset
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        eventId: String,
        memberName: String,
        offset: ReminderOffset = .oneDay,
        enabled: Bool = true
    ) {
        self.id = id
        self.eventId = eventId
        self.memberName = memberName
        self.offset = offset
        self.enabled = enabled
    }
}

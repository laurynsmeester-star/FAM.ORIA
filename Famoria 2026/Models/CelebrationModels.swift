//
//  CelebrationModels.swift
//  Famoria 2026
//
//  Translated from sendCelebrationReminders.ts
//  Models the Celebration entity and its Greeting sub-type used by
//  CelebrationReminderService and FirebaseCelebrationService.
//

import Foundation
import SwiftUI

// MARK: - Celebration Type

public enum CelebrationType: String, Codable, CaseIterable, Identifiable {
    case birthday
    case anniversary
    case graduation
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .birthday:    return "Birthday"
        case .anniversary: return "Anniversary"
        case .graduation:  return "Graduation"
        case .other:       return "Special Day"
        }
    }

    /// Emoji used in notification titles — mirrors the TS ternary
    /// `celebration_type === 'birthday' ? '🎂' : '💕'`
    public var emoji: String {
        switch self {
        case .birthday:    return "🎂"
        case .anniversary: return "💕"
        case .graduation:  return "🎓"
        case .other:       return "🎉"
        }
    }

    public var icon: String {
        switch self {
        case .birthday:    return "birthday.cake.fill"
        case .anniversary: return "heart.fill"
        case .graduation:  return "graduationcap.fill"
        case .other:       return "star.fill"
        }
    }

    public var color: Color {
        switch self {
        case .birthday:    return .pink
        case .anniversary: return .red
        case .graduation:  return .indigo
        case .other:       return .orange
        }
    }
}

// MARK: - Celebration Greeting
// Represents one entry in the `greetings` array on a Celebration document.
// Matches: { from_member: string } in the TS filter.

public struct CelebrationGreeting: Codable, Equatable, Hashable {
    public var fromMember: String
    public var message: String
    public var timestamp: Date

    public init(fromMember: String, message: String = "", timestamp: Date = Date()) {
        self.fromMember = fromMember
        self.message = message
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case fromMember = "from_member"
        case message
        case timestamp
    }
}

// MARK: - Celebration

/// A birthday, anniversary, or other recurring family milestone.
/// Matches the TypeScript `Celebration` entity used in sendCelebrationReminders.ts.
public struct Celebration: Identifiable, Codable, Equatable {
    public let id: String
    /// Who is being celebrated (maps to `member_name` in TS)
    public var memberName: String
    /// The date of the celebration (day/month, year ignored for recurring)
    public var celebrationDate: Date
    public var celebrationType: CelebrationType
    /// Whether the celebration is still active (auto-set to false when > 1 day past)
    public var isActive: Bool
    /// Which family members have already sent a greeting
    public var greetings: [CelebrationGreeting]
    public var familyId: String
    public var createdBy: String

    public init(
        id: String = UUID().uuidString,
        memberName: String,
        celebrationDate: Date,
        celebrationType: CelebrationType = .birthday,
        isActive: Bool = true,
        greetings: [CelebrationGreeting] = [],
        familyId: String,
        createdBy: String
    ) {
        self.id = id
        self.memberName = memberName
        self.celebrationDate = celebrationDate
        self.celebrationType = celebrationType
        self.isActive = isActive
        self.greetings = greetings
        self.familyId = familyId
        self.createdBy = createdBy
    }

    // MARK: - Computed Helpers

    /// Days from today until the next occurrence of this celebration.
    /// Negative means the date already passed this year.
    /// Mirrors: `Math.floor((celebrationDate - today) / (1000 * 60 * 60 * 24))`
    public var daysUntil: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let comps = cal.dateComponents([.month, .day], from: celebrationDate)
        let thisYear = cal.component(.year, from: today)
        guard let thisYearDate = cal.date(from: DateComponents(year: thisYear, month: comps.month, day: comps.day)) else {
            return 0
        }
        return cal.dateComponents([.day], from: today, to: thisYearDate).day ?? 0
    }

    /// Whether a given family member has already sent a greeting.
    /// Mirrors: `celebration.greetings?.some(g => g.from_member === recipientName)`
    public func hasGreeted(memberName name: String) -> Bool {
        greetings.contains { $0.fromMember == name }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case memberName       = "member_name"
        case celebrationDate  = "celebration_date"
        case celebrationType  = "celebration_type"
        case isActive         = "is_active"
        case greetings
        case familyId         = "family_id"
        case createdBy        = "created_by"
    }
}

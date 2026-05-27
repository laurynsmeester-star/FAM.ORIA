import Foundation
import SwiftUI

public enum MemberRole: String, Codable, Equatable, CaseIterable {
    case owner
    case admin
    case member
}

public struct User: Identifiable, Equatable, Codable {
    // Equatable conformance based on stable identity
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }

    /// The stable identity of the entity associated with this instance.
    public let id: String

    public var name: String

    public var email: String

    public var familyId: String?

    public var role: MemberRole?
    
    public init(id: String, name: String, email: String, familyId: String?, role: MemberRole?) {
        self.id = id
        self.name = name
        self.email = email
        self.familyId = familyId
        self.role = role
    }

    // Explicit CodingKeys to ensure stable Codable synthesis and avoid ambiguity
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case familyId
        case role
    }
}

public struct Family: Identifiable, Equatable, Codable {

    /// The stable identity of the entity associated with this instance.
    public let id: String

    public var name: String

    public var members: [User]
    
    public init(id: String, name: String, members: [User]) {
        self.id = id
        self.name = name
        self.members = members
    }
}

public struct FamilyEvent: Identifiable, Codable, Equatable {

    /// The stable identity of the entity associated with this instance.
    public let id: String

    public var title: String

    public var date: Date

    public var endDate: Date?

    public var createdBy: String

    // MARK: - V2 fields
    //
    // These were previously stored only in a local `FamilyEventV2` value
    // that never made it to Firestore. They're persisted now so an event
    // created on one family member's device shows up complete on every
    // other member's device.

    /// Optional explicit start time (separate from `date`'s day component).
    public var startTime: Date?
    /// Optional explicit end time on the same day.
    public var endTime: Date?
    /// Free-form location string (a venue, address, "Mom's house", etc.).
    public var location: String?
    /// Free-form notes.
    public var notes: String?
    /// One of `EventType.rawValue` (birthday/anniversary/etc.). Optional
    /// because legacy events created before this field existed will be nil.
    public var eventTypeRaw: String?
    /// Whether the event repeats yearly.
    public var isRecurring: Bool?

    public init(
        id: String,
        title: String,
        date: Date,
        endDate: Date? = nil,
        createdBy: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        eventTypeRaw: String? = nil,
        isRecurring: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.createdBy = createdBy
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.notes = notes
        self.eventTypeRaw = eventTypeRaw
        self.isRecurring = isRecurring
    }
}

public struct PostReaction: Codable, Equatable, Hashable {
    public var emoji: String
    public var userNames: [String]

    public init(emoji: String, userNames: [String] = []) {
        self.emoji = emoji
        self.userNames = userNames
    }
}

public struct PostReply: Identifiable, Codable, Equatable {
    public let id: String
    public var authorName: String
    public var content: String
    public var timestamp: Date

    public init(id: String = UUID().uuidString, authorName: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.authorName = authorName
        self.content = content
        self.timestamp = timestamp
    }
}

public struct FamilyPost: Identifiable, Codable, Equatable {

    public let id: String
    public var authorName: String
    public var content: String
    public var timestamp: Date
    public var reactions: [PostReaction]
    public var replies: [PostReply]
    
    public init(id: String, authorName: String, content: String, timestamp: Date, reactions: [PostReaction] = [], replies: [PostReply] = []) {
        self.id = id
        self.authorName = authorName
        self.content = content
        self.timestamp = timestamp
        self.reactions = reactions
        self.replies = replies
    }
}

// MARK: - Notifications

public enum FamoriaNotificationType: String, Codable {
    case message
    case event
    case invite
    case familyUpdate
    case system

    var icon: String {
        switch self {
        case .message:      return "bubble.left.fill"
        case .event:        return "calendar"
        case .invite:       return "person.badge.plus"
        case .familyUpdate: return "house.fill"
        case .system:       return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .message:      return .blue
        case .event:        return .orange
        case .invite:       return .green
        case .familyUpdate: return .purple
        case .system:       return .gray
        }
    }
}

public struct FamoriaNotification: Identifiable, Codable {
    public let id: String
    public var userId: String
    public var title: String
    public var body: String
    public var type: FamoriaNotificationType
    public var isRead: Bool
    public var createdDate: Date
}

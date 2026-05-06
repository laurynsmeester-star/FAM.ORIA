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

    public init(id: String, title: String, date: Date, endDate: Date? = nil, createdBy: String) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.createdBy = createdBy
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
    public var title: String
    public var body: String
    public var type: FamoriaNotificationType
    public var isRead: Bool
    public var createdDate: Date
}

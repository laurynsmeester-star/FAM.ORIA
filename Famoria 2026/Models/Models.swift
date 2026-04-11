import Foundation
import SwiftUI


internal struct User: Identifiable, Equatable, Codable {
    // Equatable conformance based on stable identity
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }

    /// The stable identity of the entity associated with this instance.
    internal let id: String

    internal var name: String

    internal var email: String

    internal var familyId: String?

    internal var role: MemberRole?

    // Explicit CodingKeys to ensure stable Codable synthesis and avoid ambiguity
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case familyId
        case role
    }
}

internal struct Family: Identifiable, Equatable, Codable {

    /// The stable identity of the entity associated with this instance.
    internal let id: String

    internal var name: String

    internal var members: [User]
}

internal struct FamilyEvent: Identifiable, Codable, Equatable {

    /// The stable identity of the entity associated with this instance.
    internal let id: String

    internal var title: String

    internal var date: Date

    internal var createdBy: String
}

internal struct FamilyPost: Identifiable, Codable, Equatable {

    /// The stable identity of the entity associated with this instance.
    internal let id: String

    internal var authorName: String

    internal var content: String

    internal var timestamp: Date
}

//
//  FamilyTreeModels.swift
//  Famoria 2026
//
//  Data models for the family tree feature.
//
//  A family tree consists of two collections per family:
//    1. members        — every person in the tree (real users + "ghost" profiles)
//    2. relationships  — parent/child and spouse links between members
//
//  Ghost profiles (linkedUserId == nil) represent extended relatives who are
//  not yet on Famoria. They can be invited via email to upgrade into a real
//  linked User account.
//

import Foundation
import SwiftUI

// MARK: - Relationship Type

public enum RelationshipType: String, Codable, Equatable, CaseIterable {
    /// `from` is a parent of `to`.
    case parent
    /// `from` and `to` are spouses/partners. Direction is not meaningful.
    case spouse
}

// MARK: - Gender (used only for tree styling/coloring; optional)

public enum TreeGender: String, Codable, Equatable, CaseIterable {
    case male
    case female
    case other
    case unspecified

    public var accentColor: Color {
        switch self {
        case .male:        return Color(red: 0.36, green: 0.55, blue: 0.95)
        case .female:      return Color(red: 0.93, green: 0.45, blue: 0.66)
        case .other:       return Color(red: 0.55, green: 0.45, blue: 0.85)
        case .unspecified: return Color(white: 0.55)
        }
    }
}

// MARK: - Family Tree Member

/// A single person on the family tree.
///
/// `linkedUserId` is the bridge to your existing `User` model:
///   - nil  → "ghost" profile (extended relative, not on Famoria yet)
///   - set  → linked to a real Famoria User account
public struct FamilyTreeMember: Identifiable, Codable, Equatable {

    public let id: String
    public var familyId: String

    /// If this tree node represents a real Famoria user, their User.id goes here.
    public var linkedUserId: String?

    public var displayName: String
    public var photoURL: String?

    public var gender: TreeGender

    public var birthDate: Date?
    public var deathDate: Date?
    public var isDeceased: Bool

    /// Free-form bio / notes (e.g., "Grandma Rose, lived in Boston")
    public var notes: String?

    /// User.id of who originally added this person to the tree
    public var addedBy: String
    public var createdAt: Date
    public var updatedAt: Date

    /// Email used for "Invite to Famoria" on a ghost profile (optional).
    public var inviteEmail: String?

    public init(
        id: String = UUID().uuidString,
        familyId: String,
        linkedUserId: String? = nil,
        displayName: String,
        photoURL: String? = nil,
        gender: TreeGender = .unspecified,
        birthDate: Date? = nil,
        deathDate: Date? = nil,
        isDeceased: Bool = false,
        notes: String? = nil,
        addedBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        inviteEmail: String? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.linkedUserId = linkedUserId
        self.displayName = displayName
        self.photoURL = photoURL
        self.gender = gender
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.isDeceased = isDeceased
        self.notes = notes
        self.addedBy = addedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.inviteEmail = inviteEmail
    }

    // MARK: Convenience

    public var isGhost: Bool { linkedUserId == nil }

    public var initials: String {
        let parts = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        return parts.joined().uppercased()
    }

    /// "1948–2019" or "b. 1985" or nil
    public var lifespanLabel: String? {
        let cal = Calendar.current
        let birthYear = birthDate.map { cal.component(.year, from: $0) }
        let deathYear = deathDate.map { cal.component(.year, from: $0) }

        switch (birthYear, deathYear) {
        case let (b?, d?):
            return "\(b)–\(d)"
        case let (b?, nil) where isDeceased:
            return "\(b)–?"
        case let (b?, nil):
            return "b. \(b)"
        case let (nil, d?):
            return "d. \(d)"
        default:
            return nil
        }
    }
}

// MARK: - Relationship

/// A directed edge between two family tree members.
///
/// For `.parent`, direction matters: `fromMemberId` is the parent of `toMemberId`.
/// For `.spouse`, direction is not meaningful — but we still store both ids.
public struct Relationship: Identifiable, Codable, Equatable {

    public let id: String
    public var familyId: String
    public var fromMemberId: String
    public var toMemberId: String
    public var type: RelationshipType
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        familyId: String,
        fromMemberId: String,
        toMemberId: String,
        type: RelationshipType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.familyId = familyId
        self.fromMemberId = fromMemberId
        self.toMemberId = toMemberId
        self.type = type
        self.createdAt = createdAt
    }
}

// MARK: - Aggregate

/// Convenience container for the whole tree of one family.
public struct FamilyTree: Equatable {
    public var familyId: String
    public var members: [FamilyTreeMember]
    public var relationships: [Relationship]

    public init(familyId: String, members: [FamilyTreeMember] = [], relationships: [Relationship] = []) {
        self.familyId = familyId
        self.members = members
        self.relationships = relationships
    }

    // MARK: Lookups

    public func member(id: String) -> FamilyTreeMember? {
        members.first(where: { $0.id == id })
    }

    public func parents(of memberId: String) -> [FamilyTreeMember] {
        let parentIds = relationships
            .filter { $0.type == .parent && $0.toMemberId == memberId }
            .map(\.fromMemberId)
        return members.filter { parentIds.contains($0.id) }
    }

    public func children(of memberId: String) -> [FamilyTreeMember] {
        let childIds = relationships
            .filter { $0.type == .parent && $0.fromMemberId == memberId }
            .map(\.toMemberId)
        return members.filter { childIds.contains($0.id) }
    }

    public func spouses(of memberId: String) -> [FamilyTreeMember] {
        let ids = relationships
            .filter { $0.type == .spouse && ($0.fromMemberId == memberId || $0.toMemberId == memberId) }
            .map { $0.fromMemberId == memberId ? $0.toMemberId : $0.fromMemberId }
        return members.filter { ids.contains($0.id) }
    }

    public func siblings(of memberId: String) -> [FamilyTreeMember] {
        let myParents = Set(parents(of: memberId).map(\.id))
        guard !myParents.isEmpty else { return [] }
        return members.filter { other in
            guard other.id != memberId else { return false }
            let theirParents = Set(parents(of: other.id).map(\.id))
            return !myParents.isDisjoint(with: theirParents)
        }
    }
}

// MARK: - Relationship-to-current-user (used by AddRelativeSheet)

/// Pre-baked options the user can pick when adding a new relative.
/// The view model knows how to translate these into actual `Relationship` rows.
public enum AddRelativeKind: String, CaseIterable, Identifiable {
    case parent
    case child
    case spouse
    case sibling

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .parent:  return "Parent"
        case .child:   return "Child"
        case .spouse:  return "Spouse / Partner"
        case .sibling: return "Sibling"
        }
    }

    public var systemImage: String {
        switch self {
        case .parent:  return "person.2.fill"
        case .child:   return "figure.and.child.holdinghands"
        case .spouse:  return "heart.fill"
        case .sibling: return "person.line.dotted.person.fill"
        }
    }
}

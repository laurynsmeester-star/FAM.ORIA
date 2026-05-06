//
//  WishlistModels.swift
//  Famoria 2026
//
//  Data models for the family wishlist feature, lived under the Family Journal
//  tab. Each wish belongs to one family, is "for" one recipient (a Famoria
//  family member or a free-text name for someone not in the app yet), and can
//  be claimed by another family member who wants to gift it.
//
//  Surprise mode rules (enforced in WishlistViewModel, not here):
//    - Auto-hide: when viewing items where you ARE the recipient, items that
//      are already claimed or marked fulfilled are hidden.
//    - Manual toggle: opt-in flag that hides claimed/fulfilled items even when
//      browsing other people's lists.
//

import Foundation
import SwiftUI

// MARK: - Priority

public enum WishPriority: String, Codable, Equatable, CaseIterable, Identifiable {
    case dream
    case wouldLove   = "would love"
    case niceToHave  = "nice to have"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dream:      return "Dream gift"
        case .wouldLove:  return "Would love"
        case .niceToHave: return "Nice to have"
        }
    }

    public var shortLabel: String {
        switch self {
        case .dream:      return "Dream"
        case .wouldLove:  return "Would love"
        case .niceToHave: return "Nice to have"
        }
    }

    public var background: Color {
        switch self {
        case .dream:      return Color(red: 1.00, green: 0.92, blue: 0.94)
        case .wouldLove:  return Color(red: 0.94, green: 0.92, blue: 1.00)
        case .niceToHave: return Color(red: 0.94, green: 0.95, blue: 0.97)
        }
    }

    public var foreground: Color {
        switch self {
        case .dream:      return Color(red: 0.78, green: 0.20, blue: 0.36)
        case .wouldLove:  return Color(red: 0.45, green: 0.30, blue: 0.85)
        case .niceToHave: return Color(red: 0.30, green: 0.36, blue: 0.45)
        }
    }
}

// MARK: - Occasion

public enum WishOccasion: String, Codable, Equatable, CaseIterable, Identifiable {
    case birthday
    case christmas
    case anniversary
    case graduation
    case housewarming
    case anyOccasion = "any occasion"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .birthday:     return "Birthday"
        case .christmas:    return "Christmas"
        case .anniversary:  return "Anniversary"
        case .graduation:   return "Graduation"
        case .housewarming: return "Housewarming"
        case .anyOccasion:  return "Any occasion"
        }
    }

    public var systemImage: String {
        switch self {
        case .birthday:     return "birthday.cake.fill"
        case .christmas:    return "gift.fill"
        case .anniversary:  return "heart.fill"
        case .graduation:   return "graduationcap.fill"
        case .housewarming: return "house.fill"
        case .anyOccasion:  return "sparkles"
        }
    }
}

// MARK: - Wishlist Item

public struct WishlistItem: Identifiable, Codable, Equatable {

    public let id: String
    public var familyId: String

    /// The Famoria User.id this wish is for, when known. Optional because the
    /// recipient might be a relative (or kid) not yet on the app.
    public var recipientUserId: String?
    /// Always present — display name of the recipient. Used for grouping/tabs.
    public var recipientName: String

    public var itemName: String
    public var itemDescription: String?
    public var link: String?

    public var priority: WishPriority
    public var occasion: WishOccasion

    /// User.id of who claimed this gift (so the recipient doesn't see it).
    public var claimedByUserId: String?
    /// Display name fallback (kept in sync with claimedByUserId).
    public var claimedByName: String?

    public var isFulfilled: Bool

    public var addedByUserId: String
    public var addedByName: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        familyId: String,
        recipientUserId: String? = nil,
        recipientName: String,
        itemName: String,
        itemDescription: String? = nil,
        link: String? = nil,
        priority: WishPriority = .wouldLove,
        occasion: WishOccasion = .anyOccasion,
        claimedByUserId: String? = nil,
        claimedByName: String? = nil,
        isFulfilled: Bool = false,
        addedByUserId: String,
        addedByName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.familyId = familyId
        self.recipientUserId = recipientUserId
        self.recipientName = recipientName
        self.itemName = itemName
        self.itemDescription = itemDescription
        self.link = link
        self.priority = priority
        self.occasion = occasion
        self.claimedByUserId = claimedByUserId
        self.claimedByName = claimedByName
        self.isFulfilled = isFulfilled
        self.addedByUserId = addedByUserId
        self.addedByName = addedByName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: Convenience

    public var isClaimed: Bool { claimedByUserId != nil }

    public var hasValidLink: URL? {
        guard let link, !link.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: link)
    }
}

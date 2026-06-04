//
//  SubscriptionModels.swift
//  Famoria 2026
//
//  Models for the family subscription / entitlement system. Subscription
//  state lives on the family document — one admin pays, every member of
//  the family inherits premium access.
//

import Foundation

// MARK: - Product IDs

enum FamoriaProduct: String, CaseIterable {
    case monthly = "com.famoria.plus.monthly"
    case annual  = "com.famoria.plus.annual"

    /// Display title shown on the paywall pricing cards.
    var displayTitle: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual:  return "Annual"
        }
    }

    /// "Save 28%" or similar marketing chip on the annual plan.
    var savingsChip: String? {
        switch self {
        case .monthly: return nil
        case .annual:  return "Save 28%"
        }
    }
}

// MARK: - Tier

public enum SubscriptionTier: String, Codable {
    case free
    case plus

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Famoria Plus"
        }
    }
}

// MARK: - Status

/// Mirrors StoreKit's `Product.SubscriptionInfo.RenewalState` plus our
/// own "free" + "unknown" sentinels so the rest of the app doesn't need
/// to import StoreKit just to read state.
public enum SubscriptionStatus: String, Codable {
    /// User hasn't bought anything yet.
    case free
    /// Active paid subscription, will auto-renew on `expiresAt`.
    case active
    /// Active but the user turned off auto-renew. Still entitled until
    /// `expiresAt`.
    case willNotRenew
    /// In grace period — billing failed, Apple is retrying, user still
    /// has access for now.
    case inBillingRetry
    /// Subscription was revoked (refund). Premium access lost immediately.
    case revoked
    /// Subscription expired and was not renewed.
    case expired
    /// Couldn't determine — transient state.
    case unknown

    public var isEntitled: Bool {
        switch self {
        case .active, .willNotRenew, .inBillingRetry:
            return true
        case .free, .revoked, .expired, .unknown:
            return false
        }
    }
}

// MARK: - FamilySubscription

/// Family-level subscription record. Lives at `families/{familyId}` as
/// a flat set of fields (matches the data model in the spec).
public struct FamilySubscription: Codable, Equatable {
    public var tier: SubscriptionTier
    public var status: SubscriptionStatus
    /// Renewal / expiration date — nil for free tier.
    public var expiresAt: Date?
    /// Apple `uid` of the family member who owns the subscription.
    /// Only this user can manage billing.
    public var ownerUserId: String?
    /// `FamoriaProduct.rawValue` of the currently-active plan, or nil
    /// for the free tier.
    public var productId: String?
    /// Whether the user is still in their 7-day intro free trial.
    public var inTrial: Bool

    public init(
        tier: SubscriptionTier = .free,
        status: SubscriptionStatus = .free,
        expiresAt: Date? = nil,
        ownerUserId: String? = nil,
        productId: String? = nil,
        inTrial: Bool = false
    ) {
        self.tier = tier
        self.status = status
        self.expiresAt = expiresAt
        self.ownerUserId = ownerUserId
        self.productId = productId
        self.inTrial = inTrial
    }

    /// The free tier baseline used everywhere a family has no record yet.
    public static let free = FamilySubscription()
}

// MARK: - Storage Limits

enum StorageLimit {
    /// Free tier: 2 GB across all family content.
    static let freeBytes: Int64 = 2 * 1024 * 1024 * 1024
    /// Plus tier: 100 GB.
    static let plusBytes: Int64 = 100 * 1024 * 1024 * 1024

    static func limit(for tier: SubscriptionTier) -> Int64 {
        switch tier {
        case .free: return freeBytes
        case .plus: return plusBytes
        }
    }
}

// MARK: - Privacy

/// Granular privacy levels for documents, health records, and other
/// per-member content. Enforced both client-side via PrivacyAccessManager
/// and server-side via firestore.rules.
enum PrivacyLevel: String, Codable, CaseIterable, Identifiable {
    /// Visible only to the owner.
    case `private`
    /// Visible to the owner + an explicit allowlist of family member uids.
    case sharedWithSelectedMembers
    /// Visible to every member of the family.
    case familyVisible
    /// Visible only to the family owner/admin role.
    case adminOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .private:                   return "Only me"
        case .sharedWithSelectedMembers: return "Selected members"
        case .familyVisible:             return "Whole family"
        case .adminOnly:                 return "Admins only"
        }
    }

    var icon: String {
        switch self {
        case .private:                   return "lock.fill"
        case .sharedWithSelectedMembers: return "person.2.fill"
        case .familyVisible:             return "house.fill"
        case .adminOnly:                 return "shield.fill"
        }
    }
}

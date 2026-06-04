//
//  EntitlementManager.swift
//  Famoria 2026
//
//  Single source of truth for "can this user do X". Pure derivation off
//  the family's subscription record + the signed-in user's role — no
//  StoreKit access here, no Firestore reads. Pass the family's current
//  `FamilySubscription` and the user's role, and ask the questions.
//
//  Why a struct: every view recomputes entitlements on each render, and
//  a value type means there's no `@Published` to babysit. AppState
//  exposes a computed `entitlements` that returns a fresh struct built
//  from the latest currentFamily.subscription.
//

import Foundation

struct EntitlementManager {

    let subscription: FamilySubscription
    let userRole: MemberRole?

    // MARK: - Core flags

    /// True if the family has an active paid (or trialing) subscription.
    /// All other premium feature flags derive from this.
    var isPremium: Bool {
        subscription.tier == .plus && subscription.status.isEntitled
    }

    /// Same as isPremium — exposed under this name to match the spec's
    /// vocabulary (premium inheritance is family-scoped).
    var isFamilyPremium: Bool { isPremium }

    /// Only the family owner sees the "Manage Subscription" controls. We
    /// also treat .admin as billing-capable for solo-admin families.
    var canManageBilling: Bool {
        userRole == .owner || userRole == .admin
    }

    // MARK: - Feature gates

    var canAccessDocumentVault: Bool { isPremium }
    var canAccessHealthCenter: Bool { isPremium }
    var canGenerateReports: Bool { isPremium }
    var canUseAdvancedPrivacyControls: Bool { isPremium }
    var canUseUnlimitedStorage: Bool { isPremium }

    /// Free families are capped at 5 members. Premium families are
    /// unlimited. `currentCount` is the current `family.members.count`.
    func canAddAdditionalFamilyMembers(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < 5
    }

    // MARK: - Storage

    /// Hard byte ceiling for this family. Free: 2 GB. Plus: 100 GB.
    var storageLimitBytes: Int64 {
        StorageLimit.limit(for: subscription.tier)
    }

    /// Returns true if a hypothetical upload of `incoming` bytes would
    /// fit under the family's storage limit.
    func canUploadBytes(_ incoming: Int64, alreadyUsed: Int64) -> Bool {
        // Premium gets a soft cap — we still want to surface "approaching
        // limit" UI, but we don't hard-block until we hit the real ceiling.
        return alreadyUsed + incoming <= storageLimitBytes
    }
}

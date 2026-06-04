//
//  SubscriptionSyncService.swift
//  Famoria 2026
//
//  Bridge between StoreKit (per-device, per-Apple-ID) and Firestore
//  (per-family). When `SubscriptionManager.currentStatus` changes, this
//  service writes the resulting `FamilySubscription` to
//  `families/{familyId}` so every member of the family sees the updated
//  tier on their next snapshot.
//
//  Only the family's owner (and admins) ever write here — non-owner
//  members observe and inherit. firestore.rules enforces this.
//

import Foundation
import os
import FirebaseFirestore

@MainActor
final class SubscriptionSyncService {

    private let db = Firestore.firestore()

    /// Writes the current StoreKit state to the family doc. Called by
    /// AppState whenever `SubscriptionManager.currentStatus` updates and
    /// the signed-in user owns the family billing.
    func syncToFamily(
        familyId: String,
        ownerUserId: String,
        status: SubscriptionStatus,
        expiresAt: Date?,
        activeProductId: String?,
        inTrial: Bool
    ) async {
        let tier: SubscriptionTier = status.isEntitled ? .plus : .free
        var data: [String: Any] = [
            "subscriptionTier": tier.rawValue,
            "subscriptionStatus": status.rawValue,
            "subscriptionOwnerUID": ownerUserId,
            "subscriptionInTrial": inTrial,
            "subscriptionUpdatedAt": FieldValue.serverTimestamp(),
            "storageLimit": StorageLimit.limit(for: tier)
        ]
        if let expiresAt {
            data["subscriptionExpiration"] = Timestamp(date: expiresAt)
        } else {
            data["subscriptionExpiration"] = FieldValue.delete()
        }
        if let activeProductId {
            data["subscriptionProductID"] = activeProductId
        } else {
            data["subscriptionProductID"] = FieldValue.delete()
        }

        do {
            try await db.collection("families")
                .document(familyId)
                .setData(data, merge: true)
        } catch {
            Log.appState.error("syncToFamily failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Decodes the flat subscription fields stored on a family document
    /// into a `FamilySubscription` value. Defaults to `.free` for any
    /// missing fields so legacy family docs without subscription state
    /// still load cleanly.
    static func decodeFamilySubscription(from data: [String: Any]) -> FamilySubscription {
        let tierRaw = data["subscriptionTier"] as? String ?? "free"
        let statusRaw = data["subscriptionStatus"] as? String ?? "free"
        let expiresAt: Date? = {
            if let ts = data["subscriptionExpiration"] as? Timestamp { return ts.dateValue() }
            if let d = data["subscriptionExpiration"] as? Date { return d }
            return nil
        }()
        let owner = data["subscriptionOwnerUID"] as? String
        let productId = data["subscriptionProductID"] as? String
        let inTrial = data["subscriptionInTrial"] as? Bool ?? false

        return FamilySubscription(
            tier: SubscriptionTier(rawValue: tierRaw) ?? .free,
            status: SubscriptionStatus(rawValue: statusRaw) ?? .free,
            expiresAt: expiresAt,
            ownerUserId: owner,
            productId: productId,
            inTrial: inTrial
        )
    }
}

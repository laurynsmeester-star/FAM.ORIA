//
//  StorageQuotaManager.swift
//  Famoria 2026
//
//  Tracks the family's Cloud Storage usage against the tier ceiling and
//  enforces upload limits. The byte counter lives on the family doc
//  (`storageUsedBytes`) and is incremented by the upload flows (album
//  photos, document vault, chat images) via `recordUpload`.
//
//  We keep this independent from SubscriptionManager so the UI can show
//  the progress bar even while StoreKit is offline.
//

import Foundation
import os
import Combine
import FirebaseFirestore

@MainActor
final class StorageQuotaManager: ObservableObject {

    @Published private(set) var usedBytes: Int64 = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var observedFamilyId: String?

    // MARK: - Lifecycle

    func start(familyId: String) {
        guard observedFamilyId != familyId else { return }
        listener?.remove()
        observedFamilyId = familyId

        listener = db.collection("families")
            .document(familyId)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                let bytes = (data["storageUsedBytes"] as? Int64)
                    ?? Int64(data["storageUsedBytes"] as? Int ?? 0)
                Task { @MainActor in self.usedBytes = bytes }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        observedFamilyId = nil
        usedBytes = 0
    }

    // MARK: - Upload tracking

    /// Atomically bumps the family's usage counter when an upload
    /// succeeds. Pass a positive value for new uploads and a negative
    /// value when content is deleted.
    func recordUpload(familyId: String, bytes: Int64) async {
        do {
            try await db.collection("families")
                .document(familyId)
                .setData(
                    ["storageUsedBytes": FieldValue.increment(bytes)],
                    merge: true
                )
        } catch {
            Log.appState.error("storage usage update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers for the UI

    /// 0.0 – 1.0 fraction of the family's quota that is used. Saturates
    /// at 1.0 so progress bars don't overflow.
    func fraction(tier: SubscriptionTier) -> Double {
        let limit = StorageLimit.limit(for: tier)
        guard limit > 0 else { return 0 }
        let raw = Double(usedBytes) / Double(limit)
        return min(max(raw, 0), 1)
    }

    /// Localized "1.2 GB of 100 GB" string used by the progress bar.
    func displayString(tier: SubscriptionTier) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let used = formatter.string(fromByteCount: usedBytes)
        let limit = formatter.string(fromByteCount: StorageLimit.limit(for: tier))
        return "\(used) of \(limit)"
    }

    /// True if we're within 10% of the family's storage ceiling — used
    /// by views to surface "approaching limit" warnings before uploads
    /// start failing outright.
    func isApproachingLimit(tier: SubscriptionTier) -> Bool {
        fraction(tier: tier) >= 0.9
    }
}

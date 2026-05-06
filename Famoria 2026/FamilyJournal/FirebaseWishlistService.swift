//
//  FirebaseWishlistService.swift
//  Famoria 2026
//
//  Firestore CRUD + live listener for the wishlist.
//
//  Schema:
//    families/{familyId}/wishlistItems/{itemId} — WishlistItem docs
//

import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class FirebaseWishlistService {

    private let db = Firestore.firestore()

    private func itemsRef(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("wishlistItems")
    }

    // MARK: - Read

    @discardableResult
    func observeItems(
        familyId: String,
        onChange: @escaping ([WishlistItem]) -> Void
    ) -> ListenerRegistration {
        return itemsRef(familyId: familyId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, _ in
                let items = snap?.documents.compactMap { Self.decode($0.data()) } ?? []
                onChange(items)
            }
    }

    func loadItems(familyId: String) async throws -> [WishlistItem] {
        let snap = try await itemsRef(familyId: familyId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snap.documents.compactMap { Self.decode($0.data()) }
    }

    // MARK: - Write

    func upsert(_ item: WishlistItem) async throws {
        try await itemsRef(familyId: item.familyId)
            .document(item.id)
            .setData(Self.encode(item), merge: true)
    }

    func delete(_ item: WishlistItem) async throws {
        try await itemsRef(familyId: item.familyId)
            .document(item.id)
            .delete()
    }

    func setClaim(itemId: String, familyId: String, userId: String?, userName: String?) async throws {
        var data: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]
        if let userId, let userName {
            data["claimedByUserId"] = userId
            data["claimedByName"]   = userName
        } else {
            data["claimedByUserId"] = FieldValue.delete()
            data["claimedByName"]   = FieldValue.delete()
        }
        try await itemsRef(familyId: familyId).document(itemId).setData(data, merge: true)
    }

    func setFulfilled(itemId: String, familyId: String, fulfilled: Bool) async throws {
        try await itemsRef(familyId: familyId).document(itemId).setData([
            "isFulfilled": fulfilled,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    // MARK: - Codec

    private static func encode(_ i: WishlistItem) -> [String: Any] {
        var d: [String: Any] = [
            "id": i.id,
            "familyId": i.familyId,
            "recipientName": i.recipientName,
            "itemName": i.itemName,
            "priority": i.priority.rawValue,
            "occasion": i.occasion.rawValue,
            "isFulfilled": i.isFulfilled,
            "addedByUserId": i.addedByUserId,
            "addedByName": i.addedByName,
            "createdAt": Timestamp(date: i.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        if let v = i.recipientUserId  { d["recipientUserId"] = v }
        if let v = i.itemDescription  { d["itemDescription"] = v }
        if let v = i.link             { d["link"] = v }
        if let v = i.claimedByUserId  { d["claimedByUserId"] = v }
        if let v = i.claimedByName    { d["claimedByName"] = v }
        return d
    }

    private static func decode(_ d: [String: Any]) -> WishlistItem? {
        guard
            let id            = d["id"] as? String,
            let familyId      = d["familyId"] as? String,
            let recipientName = d["recipientName"] as? String,
            let itemName      = d["itemName"] as? String,
            let priorityRaw   = d["priority"] as? String,
            let priority      = WishPriority(rawValue: priorityRaw),
            let occasionRaw   = d["occasion"] as? String,
            let occasion      = WishOccasion(rawValue: occasionRaw),
            let addedByUserId = d["addedByUserId"] as? String,
            let addedByName   = d["addedByName"] as? String
        else { return nil }

        let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

        return WishlistItem(
            id: id,
            familyId: familyId,
            recipientUserId: d["recipientUserId"] as? String,
            recipientName: recipientName,
            itemName: itemName,
            itemDescription: d["itemDescription"] as? String,
            link: d["link"] as? String,
            priority: priority,
            occasion: occasion,
            claimedByUserId: d["claimedByUserId"] as? String,
            claimedByName: d["claimedByName"] as? String,
            isFulfilled: d["isFulfilled"] as? Bool ?? false,
            addedByUserId: addedByUserId,
            addedByName: addedByName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

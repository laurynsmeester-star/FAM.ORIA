//
//  FirebaseFamilyTreeService.swift
//  Famoria 2026
//
//  Firestore CRUD for the family tree.
//
//  Schema:
//    families/{familyId}/treeMembers/{memberId}        — FamilyTreeMember docs
//    families/{familyId}/relationships/{relationshipId} — Relationship docs
//
//  This isolates the family tree from your existing `families/{id}/members`
//  collection (which holds real Famoria users only).
//

import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class FirebaseFamilyTreeService {

    private let db = Firestore.firestore()

    // MARK: - Collection refs

    private func membersRef(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("treeMembers")
    }

    private func relationshipsRef(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("relationships")
    }

    // MARK: - Fetch

    /// One-shot load of every member + relationship for a family.
    func loadTree(familyId: String) async throws -> FamilyTree {
        async let memberDocs = membersRef(familyId: familyId).getDocuments()
        async let relDocs    = relationshipsRef(familyId: familyId).getDocuments()

        let (mSnap, rSnap) = try await (memberDocs, relDocs)

        let members       = mSnap.documents.compactMap { Self.decodeMember($0.data()) }
        let relationships = rSnap.documents.compactMap { Self.decodeRelationship($0.data()) }

        return FamilyTree(familyId: familyId, members: members, relationships: relationships)
    }

    /// Live listener — calls `onChange` whenever the tree updates.
    /// Returns a `ListenerRegistration` you should `.remove()` on disappear.
    @discardableResult
    func observeTree(
        familyId: String,
        onChange: @escaping (FamilyTree) -> Void
    ) -> [ListenerRegistration] {

        var snapshotMembers: [FamilyTreeMember] = []
        var snapshotRels: [Relationship] = []

        let mListener = membersRef(familyId: familyId).addSnapshotListener { snap, _ in
            snapshotMembers = snap?.documents.compactMap { Self.decodeMember($0.data()) } ?? []
            onChange(FamilyTree(familyId: familyId, members: snapshotMembers, relationships: snapshotRels))
        }

        let rListener = relationshipsRef(familyId: familyId).addSnapshotListener { snap, _ in
            snapshotRels = snap?.documents.compactMap { Self.decodeRelationship($0.data()) } ?? []
            onChange(FamilyTree(familyId: familyId, members: snapshotMembers, relationships: snapshotRels))
        }

        return [mListener, rListener]
    }

    // MARK: - Mutations: Members

    func upsertMember(_ member: FamilyTreeMember) async throws {
        try await membersRef(familyId: member.familyId)
            .document(member.id)
            .setData(Self.encode(member: member), merge: true)
    }

    func deleteMember(_ member: FamilyTreeMember) async throws {
        // Delete the member doc + every relationship that references them.
        let batch = db.batch()
        let memberRef = membersRef(familyId: member.familyId).document(member.id)
        batch.deleteDocument(memberRef)

        let relSnap = try await relationshipsRef(familyId: member.familyId).getDocuments()
        for doc in relSnap.documents {
            let data = doc.data()
            let from = data["fromMemberId"] as? String
            let to   = data["toMemberId"] as? String
            if from == member.id || to == member.id {
                batch.deleteDocument(doc.reference)
            }
        }
        try await batch.commit()
    }

    // MARK: - Mutations: Relationships

    func upsertRelationship(_ rel: Relationship) async throws {
        try await relationshipsRef(familyId: rel.familyId)
            .document(rel.id)
            .setData(Self.encode(relationship: rel), merge: true)
    }

    func deleteRelationship(_ rel: Relationship) async throws {
        try await relationshipsRef(familyId: rel.familyId)
            .document(rel.id)
            .delete()
    }

    // MARK: - Linking real users to tree nodes

    /// Set / change the `linkedUserId` on a tree member.
    /// Use this when a ghost profile accepts an invite and joins Famoria.
    func linkUser(memberId: String, familyId: String, userId: String?) async throws {
        try await membersRef(familyId: familyId).document(memberId).setData([
            "linkedUserId": userId as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Encoding / decoding

    private static func encode(member m: FamilyTreeMember) -> [String: Any] {
        var dict: [String: Any] = [
            "id": m.id,
            "familyId": m.familyId,
            "displayName": m.displayName,
            "gender": m.gender.rawValue,
            "isDeceased": m.isDeceased,
            "addedBy": m.addedBy,
            "createdAt": Timestamp(date: m.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        if let v = m.linkedUserId  { dict["linkedUserId"] = v }
        if let v = m.photoURL      { dict["photoURL"] = v }
        if let v = m.birthDate     { dict["birthDate"] = Timestamp(date: v) }
        if let v = m.deathDate     { dict["deathDate"] = Timestamp(date: v) }
        if let v = m.notes         { dict["notes"] = v }
        if let v = m.inviteEmail   { dict["inviteEmail"] = v }
        return dict
    }

    private static func decodeMember(_ d: [String: Any]) -> FamilyTreeMember? {
        guard
            let id           = d["id"] as? String,
            let familyId     = d["familyId"] as? String,
            let displayName  = d["displayName"] as? String,
            let addedBy      = d["addedBy"] as? String
        else { return nil }

        let gender = (d["gender"] as? String).flatMap(TreeGender.init(rawValue:)) ?? .unspecified
        let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

        return FamilyTreeMember(
            id: id,
            familyId: familyId,
            linkedUserId: d["linkedUserId"] as? String,
            displayName: displayName,
            photoURL: d["photoURL"] as? String,
            gender: gender,
            birthDate: (d["birthDate"] as? Timestamp)?.dateValue(),
            deathDate: (d["deathDate"] as? Timestamp)?.dateValue(),
            isDeceased: d["isDeceased"] as? Bool ?? false,
            notes: d["notes"] as? String,
            addedBy: addedBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            inviteEmail: d["inviteEmail"] as? String
        )
    }

    private static func encode(relationship r: Relationship) -> [String: Any] {
        return [
            "id": r.id,
            "familyId": r.familyId,
            "fromMemberId": r.fromMemberId,
            "toMemberId": r.toMemberId,
            "type": r.type.rawValue,
            "createdAt": Timestamp(date: r.createdAt)
        ]
    }

    private static func decodeRelationship(_ d: [String: Any]) -> Relationship? {
        guard
            let id           = d["id"] as? String,
            let familyId     = d["familyId"] as? String,
            let fromMemberId = d["fromMemberId"] as? String,
            let toMemberId   = d["toMemberId"] as? String,
            let typeRaw      = d["type"] as? String,
            let type         = RelationshipType(rawValue: typeRaw)
        else { return nil }

        let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Relationship(
            id: id,
            familyId: familyId,
            fromMemberId: fromMemberId,
            toMemberId: toMemberId,
            type: type,
            createdAt: createdAt
        )
    }
}

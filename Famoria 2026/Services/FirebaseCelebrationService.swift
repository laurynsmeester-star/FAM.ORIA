//
//  FirebaseCelebrationService.swift
//  Famoria 2026
//
//  Firestore-backed persistence layer for the Celebration entity.
//  Used by CelebrationReminderService to fetch active celebrations
//  and mark past ones inactive — mirroring the Deno service role
//  calls in sendCelebrationReminders.ts.
//

import Foundation
import os
import FirebaseFirestore

final class FirebaseCelebrationService {

    private let db = Firestore.firestore()

    // MARK: - Collection Reference

    private func collection(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("celebrations")
    }

    // MARK: - Create

    func createCelebration(_ celebration: Celebration) async throws {
        try await collection(familyId: celebration.familyId)
            .document(celebration.id)
            .setData(encode(celebration))
    }

    // MARK: - Read

    /// Fetches all active celebrations for a family.
    /// Mirrors: `base44.asServiceRole.entities.Celebration.filter({ is_active: true })`
    func fetchActiveCelebrations(familyId: String) async throws -> [Celebration] {
        let snapshot = try await collection(familyId: familyId)
            .whereField("is_active", isEqualTo: true)
            .getDocuments()
        return snapshot.documents.compactMap { decode(from: $0) }
    }

    func fetchAllCelebrations(familyId: String) async throws -> [Celebration] {
        let snapshot = try await collection(familyId: familyId).getDocuments()
        return snapshot.documents.compactMap { decode(from: $0) }
    }

    // MARK: - Update

    func updateCelebration(_ celebration: Celebration) async throws {
        try await collection(familyId: celebration.familyId)
            .document(celebration.id)
            .setData(encode(celebration), merge: true)
    }

    /// Sets `is_active = false` on a past celebration.
    /// Mirrors: `base44.asServiceRole.entities.Celebration.update(id, { is_active: false })`
    func deactivateCelebration(id: String, familyId: String) async throws {
        try await collection(familyId: familyId)
            .document(id)
            .updateData(["is_active": false])
    }

    // MARK: - Greetings

    /// Appends a greeting from a family member.
    /// Mirrors the Notification.create calls in sendCelebrationReminders.ts —
    /// but stores the greeting on the Celebration document itself so the
    /// `hasGreeted` check (`celebration.greetings?.some(...)`) works correctly.
    func addGreeting(celebrationId: String, familyId: String, greeting: CelebrationGreeting) async throws {
        let data: [String: Any] = [
            "from_member": greeting.fromMember,
            "message": greeting.message,
            "timestamp": Timestamp(date: greeting.timestamp)
        ]
        try await collection(familyId: familyId)
            .document(celebrationId)
            .updateData(["greetings": FieldValue.arrayUnion([data])])
    }

    // MARK: - Delete

    func deleteCelebration(id: String, familyId: String) async throws {
        try await collection(familyId: familyId).document(id).delete()
    }

    // MARK: - Real-time Observation

    func observeActiveCelebrations(
        familyId: String,
        onChange: @escaping ([Celebration]) -> Void
    ) -> ListenerRegistration {
        collection(familyId: familyId)
            .whereField("is_active", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Log.celebration.error("observeActiveCelebrations failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let self else { return }
                let celebrations = snapshot?.documents.compactMap { self.decode(from: $0) } ?? []
                onChange(celebrations)
            }
    }

    // MARK: - Encoding

    private func encode(_ c: Celebration) -> [String: Any] {
        [
            "id": c.id,
            "member_name": c.memberName,
            "celebration_date": Timestamp(date: c.celebrationDate),
            "celebration_type": c.celebrationType.rawValue,
            "is_active": c.isActive,
            "family_id": c.familyId,
            "created_by": c.createdBy,
            "greetings": c.greetings.map { g -> [String: Any] in
                [
                    "from_member": g.fromMember,
                    "message": g.message,
                    "timestamp": Timestamp(date: g.timestamp)
                ]
            }
        ]
    }

    // MARK: - Decoding

    private func decode(from doc: QueryDocumentSnapshot) -> Celebration? {
        let data = doc.data()
        guard
            let memberName = data["member_name"] as? String,
            let typeRaw = data["celebration_type"] as? String,
            let celebrationType = CelebrationType(rawValue: typeRaw),
            let ts = data["celebration_date"] as? Timestamp,
            let familyId = data["family_id"] as? String,
            let createdBy = data["created_by"] as? String
        else { return nil }

        let greetingsRaw = data["greetings"] as? [[String: Any]] ?? []
        let greetings: [CelebrationGreeting] = greetingsRaw.compactMap { g in
            guard let fromMember = g["from_member"] as? String else { return nil }
            return CelebrationGreeting(
                fromMember: fromMember,
                message: g["message"] as? String ?? "",
                timestamp: (g["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        return Celebration(
            id: doc.documentID,
            memberName: memberName,
            celebrationDate: ts.dateValue(),
            celebrationType: celebrationType,
            isActive: data["is_active"] as? Bool ?? true,
            greetings: greetings,
            familyId: familyId,
            createdBy: createdBy
        )
    }
}

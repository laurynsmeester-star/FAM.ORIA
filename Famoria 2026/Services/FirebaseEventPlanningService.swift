//
//  FirebaseEventPlanningService.swift
//  Famoria 2026
//
//  Persists per-event planning data (RSVPs, tasks, schedule, polls, votes,
//  documents) under:
//
//      families/{familyId}/eventPlanning/{eventId}/<kind>/{docId}
//
//  Where `kind` is one of: rsvps, tasks, schedule, polls, votes, documents.
//
//  All models are Codable; we use Firestore's Codable encoder/decoder so
//  Date <-> Timestamp conversion happens automatically.
//

import Foundation
import FirebaseFirestore

final class FirebaseEventPlanningService {
    private let db = Firestore.firestore()

    // MARK: - Collection refs

    private func eventDoc(familyId: String, eventId: String) -> DocumentReference {
        db.collection("families")
            .document(familyId)
            .collection("eventPlanning")
            .document(eventId)
    }

    private func rsvpsRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("rsvps")
    }
    private func tasksRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("tasks")
    }
    private func scheduleRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("schedule")
    }
    private func pollsRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("polls")
    }
    private func votesRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("votes")
    }
    private func documentsRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("documents")
    }
    private func budgetRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("budget")
    }
    private func groceryRef(familyId: String, eventId: String) -> CollectionReference {
        eventDoc(familyId: familyId, eventId: eventId).collection("grocery")
    }

    // MARK: - RSVPs

    func upsert(rsvp: EventRSVP, familyId: String, eventId: String) async throws {
        try rsvpsRef(familyId: familyId, eventId: eventId)
            .document(rsvp.id)
            .setData(from: rsvp)
    }
    func delete(rsvpId: String, familyId: String, eventId: String) async throws {
        try await rsvpsRef(familyId: familyId, eventId: eventId).document(rsvpId).delete()
    }
    func observeRSVPs(familyId: String, eventId: String, onChange: @escaping ([EventRSVP]) -> Void) -> ListenerRegistration {
        rsvpsRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Tasks

    func upsert(task: EventTask, familyId: String, eventId: String) async throws {
        try tasksRef(familyId: familyId, eventId: eventId)
            .document(task.id)
            .setData(from: task)
    }
    func delete(taskId: String, familyId: String, eventId: String) async throws {
        try await tasksRef(familyId: familyId, eventId: eventId).document(taskId).delete()
    }
    func observeTasks(familyId: String, eventId: String, onChange: @escaping ([EventTask]) -> Void) -> ListenerRegistration {
        tasksRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Schedule

    func upsert(scheduleItem: EventScheduleItem, familyId: String, eventId: String) async throws {
        try scheduleRef(familyId: familyId, eventId: eventId)
            .document(scheduleItem.id)
            .setData(from: scheduleItem)
    }
    func delete(scheduleItemId: String, familyId: String, eventId: String) async throws {
        try await scheduleRef(familyId: familyId, eventId: eventId).document(scheduleItemId).delete()
    }
    func observeSchedule(familyId: String, eventId: String, onChange: @escaping ([EventScheduleItem]) -> Void) -> ListenerRegistration {
        scheduleRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Polls

    func upsert(poll: EventPoll, familyId: String, eventId: String) async throws {
        try pollsRef(familyId: familyId, eventId: eventId)
            .document(poll.id)
            .setData(from: poll)
    }
    func delete(pollId: String, familyId: String, eventId: String) async throws {
        try await pollsRef(familyId: familyId, eventId: eventId).document(pollId).delete()
        // Also clean up any votes for the poll.
        let voteDocs = try await votesRef(familyId: familyId, eventId: eventId)
            .whereField("pollId", isEqualTo: pollId)
            .getDocuments()
        for doc in voteDocs.documents {
            try await doc.reference.delete()
        }
    }
    func observePolls(familyId: String, eventId: String, onChange: @escaping ([EventPoll]) -> Void) -> ListenerRegistration {
        pollsRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Votes

    func upsert(vote: PollVote, familyId: String, eventId: String) async throws {
        try votesRef(familyId: familyId, eventId: eventId)
            .document(vote.id)
            .setData(from: vote)
    }
    func delete(voteId: String, familyId: String, eventId: String) async throws {
        try await votesRef(familyId: familyId, eventId: eventId).document(voteId).delete()
    }
    func observeVotes(familyId: String, eventId: String, onChange: @escaping ([PollVote]) -> Void) -> ListenerRegistration {
        votesRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Documents

    func upsert(document: EventDocument, familyId: String, eventId: String) async throws {
        try documentsRef(familyId: familyId, eventId: eventId)
            .document(document.id)
            .setData(from: document)
    }
    func delete(documentId: String, familyId: String, eventId: String) async throws {
        try await documentsRef(familyId: familyId, eventId: eventId).document(documentId).delete()
    }
    func observeDocuments(familyId: String, eventId: String, onChange: @escaping ([EventDocument]) -> Void) -> ListenerRegistration {
        documentsRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Budget

    func upsert(budgetItem: EventBudgetItem, familyId: String, eventId: String) async throws {
        try budgetRef(familyId: familyId, eventId: eventId)
            .document(budgetItem.id)
            .setData(from: budgetItem)
    }
    func delete(budgetItemId: String, familyId: String, eventId: String) async throws {
        try await budgetRef(familyId: familyId, eventId: eventId).document(budgetItemId).delete()
    }
    func observeBudget(familyId: String, eventId: String, onChange: @escaping ([EventBudgetItem]) -> Void) -> ListenerRegistration {
        budgetRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }

    // MARK: - Grocery / Checklist

    func upsert(groceryItem: EventGroceryItem, familyId: String, eventId: String) async throws {
        try groceryRef(familyId: familyId, eventId: eventId)
            .document(groceryItem.id)
            .setData(from: groceryItem)
    }
    func delete(groceryItemId: String, familyId: String, eventId: String) async throws {
        try await groceryRef(familyId: familyId, eventId: eventId).document(groceryItemId).delete()
    }
    func observeGrocery(familyId: String, eventId: String, onChange: @escaping ([EventGroceryItem]) -> Void) -> ListenerRegistration {
        groceryRef(familyId: familyId, eventId: eventId).addSnapshotListener { snapshot, _ in
            onChange(decode(snapshot))
        }
    }
}

// MARK: - EventDocument Codable

extension EventDocument: Codable {
    enum CodingKeys: String, CodingKey {
        case id, eventId, title, note, addedBy, addedDate
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let eventId = try c.decode(String.self, forKey: .eventId)
        let title = try c.decode(String.self, forKey: .title)
        let note = (try? c.decode(String.self, forKey: .note)) ?? ""
        let addedBy = try c.decode(String.self, forKey: .addedBy)
        let addedDate = (try? c.decode(Date.self, forKey: .addedDate)) ?? Date()
        self.init(id: id, eventId: eventId, title: title, note: note, addedBy: addedBy, addedDate: addedDate)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(eventId, forKey: .eventId)
        try c.encode(title, forKey: .title)
        try c.encode(note, forKey: .note)
        try c.encode(addedBy, forKey: .addedBy)
        try c.encode(addedDate, forKey: .addedDate)
    }
}

// MARK: - Helpers

private func decode<T: Decodable>(_ snapshot: QuerySnapshot?) -> [T] {
    guard let documents = snapshot?.documents else { return [] }
    return documents.compactMap { doc -> T? in
        try? doc.data(as: T.self)
    }
}

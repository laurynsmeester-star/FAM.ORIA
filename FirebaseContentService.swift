import Foundation
import os
import FirebaseCore
import FirebaseFirestore

/// Service responsible for managing family posts and events
final class FirebaseContentService {
    private let db = Firestore.firestore()
    
    // MARK: - Collection References
    
    private func postsRef(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("posts")
    }
    
    private func eventsRef(familyId: String) -> CollectionReference {
        db.collection("families").document(familyId).collection("events")
    }
    
    // MARK: - Posts Management
    
    /// Creates a new post in the family feed
    func createPost(familyId: String, authorName: String, authorId: String, content: String) async throws -> FamilyPost {
        let postId = UUID().uuidString
        let timestamp = Date()

        let post = FamilyPost(
            id: postId,
            authorName: authorName,
            content: content,
            timestamp: timestamp
        )

        let postData: [String: Any] = [
            "id": post.id,
            "authorName": authorName,
            "authorId": authorId,
            "content": content,
            "timestamp": Timestamp(date: timestamp),
            "reactions": [],
            "replies": [],
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await postsRef(familyId: familyId).document(postId).setData(postData)

        return post
    }

    // MARK: - Post encoding helpers

    private static func encodeReactions(_ reactions: [PostReaction]) -> [[String: Any]] {
        reactions.map { ["emoji": $0.emoji, "userNames": $0.userNames] }
    }

    private static func decodeReactions(_ raw: [[String: Any]]) -> [PostReaction] {
        raw.compactMap { dict in
            guard let emoji = dict["emoji"] as? String else { return nil }
            let userNames = dict["userNames"] as? [String] ?? []
            return PostReaction(emoji: emoji, userNames: userNames)
        }
    }

    private static func encodeReplies(_ replies: [PostReply]) -> [[String: Any]] {
        replies.map { reply in
            [
                "id": reply.id,
                "authorName": reply.authorName,
                "content": reply.content,
                "timestamp": Timestamp(date: reply.timestamp)
            ]
        }
    }

    private static func decodeReplies(_ raw: [[String: Any]]) -> [PostReply] {
        raw.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let authorName = dict["authorName"] as? String,
                  let content = dict["content"] as? String else { return nil }
            let timestamp: Date
            if let ts = dict["timestamp"] as? Timestamp {
                timestamp = ts.dateValue()
            } else if let d = dict["timestamp"] as? Date {
                timestamp = d
            } else {
                timestamp = Date()
            }
            return PostReply(id: id, authorName: authorName, content: content, timestamp: timestamp)
        }
    }

    private static func parsePost(from data: [String: Any]) -> FamilyPost? {
        guard let id = data["id"] as? String,
              let authorName = data["authorName"] as? String,
              let content = data["content"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }
        let reactionsRaw = data["reactions"] as? [[String: Any]] ?? []
        let repliesRaw = data["replies"] as? [[String: Any]] ?? []
        return FamilyPost(
            id: id,
            authorName: authorName,
            content: content,
            timestamp: timestamp.dateValue(),
            reactions: decodeReactions(reactionsRaw),
            replies: decodeReplies(repliesRaw)
        )
    }
    
    /// Fetches all posts for a family, ordered by timestamp (newest first)
    func fetchPosts(familyId: String, limit: Int = 50) async throws -> [FamilyPost] {
        let snapshot = try await postsRef(familyId: familyId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { Self.parsePost(from: $0.data()) }
    }

    /// Deletes a post
    func deletePost(familyId: String, postId: String) async throws {
        try await postsRef(familyId: familyId).document(postId).delete()
    }

    /// Updates a post's content
    func updatePost(familyId: String, postId: String, newContent: String) async throws {
        try await postsRef(familyId: familyId).document(postId).updateData([
            "content": newContent,
            "editedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Adds a reply to a post (writes the updated replies array atomically).
    func addReply(familyId: String, postId: String, reply: PostReply) async throws {
        let docRef = postsRef(familyId: familyId).document(postId)
        _ = try await db.runTransaction { txn, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try txn.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            var replies = (snapshot.data()?["replies"] as? [[String: Any]]) ?? []
            replies.append([
                "id": reply.id,
                "authorName": reply.authorName,
                "content": reply.content,
                "timestamp": Timestamp(date: reply.timestamp)
            ])
            txn.updateData(["replies": replies], forDocument: docRef)
            return nil
        }
    }

    /// Toggles a user's reaction emoji on a post. Adds the user to the emoji's
    /// userNames list if absent; removes them (and the whole reaction if empty)
    /// if present. Uses a transaction so concurrent reactions don't clobber.
    func toggleReaction(familyId: String, postId: String, emoji: String, userName: String) async throws {
        let docRef = postsRef(familyId: familyId).document(postId)
        _ = try await db.runTransaction { txn, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try txn.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            var reactions = (snapshot.data()?["reactions"] as? [[String: Any]]) ?? []

            if let idx = reactions.firstIndex(where: { ($0["emoji"] as? String) == emoji }) {
                var userNames = reactions[idx]["userNames"] as? [String] ?? []
                if let userIdx = userNames.firstIndex(of: userName) {
                    userNames.remove(at: userIdx)
                } else {
                    userNames.append(userName)
                }
                if userNames.isEmpty {
                    reactions.remove(at: idx)
                } else {
                    reactions[idx]["userNames"] = userNames
                }
            } else {
                reactions.append(["emoji": emoji, "userNames": [userName]])
            }
            txn.updateData(["reactions": reactions], forDocument: docRef)
            return nil
        }
    }

    /// Sets up a real-time listener for posts
    func observePosts(familyId: String, onChange: @escaping ([FamilyPost]) -> Void) -> ListenerRegistration {
        let listener = postsRef(familyId: familyId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Log.content.error("observePosts failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                onChange(documents.compactMap { Self.parsePost(from: $0.data()) })
            }

        return listener
    }
    
    // MARK: - Events Management
    
    /// Creates a new family event. Pass `id` to use a pre-generated document id
    /// (allowing the caller to optimistically insert the same event locally first).
    /// V2 fields (startTime, endTime, location, notes, eventTypeRaw, isRecurring)
    /// are persisted when provided so other family members see the full event.
    func createEvent(
        familyId: String,
        title: String,
        date: Date,
        createdBy: String,
        id: String? = nil,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        eventTypeRaw: String? = nil,
        isRecurring: Bool? = nil
    ) async throws -> FamilyEvent {
        let eventId = id ?? UUID().uuidString

        let event = FamilyEvent(
            id: eventId,
            title: title,
            date: date,
            endDate: endDate,
            createdBy: createdBy,
            startTime: startTime,
            endTime: endTime,
            location: location,
            notes: notes,
            eventTypeRaw: eventTypeRaw,
            isRecurring: isRecurring
        )

        var eventData: [String: Any] = [
            "id": event.id,
            "title": title,
            "date": Timestamp(date: date),
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let endDate { eventData["endDate"] = Timestamp(date: endDate) }
        if let startTime { eventData["startTime"] = Timestamp(date: startTime) }
        if let endTime { eventData["endTime"] = Timestamp(date: endTime) }
        if let location, !location.isEmpty { eventData["location"] = location }
        if let notes, !notes.isEmpty { eventData["notes"] = notes }
        if let eventTypeRaw { eventData["eventType"] = eventTypeRaw }
        if let isRecurring { eventData["isRecurring"] = isRecurring }

        try await eventsRef(familyId: familyId).document(eventId).setData(eventData)

        return event
    }

    /// Decodes a Firestore event document into a `FamilyEvent`, including
    /// the optional V2 fields. Returns nil if any required field is missing.
    private static func parseEvent(from data: [String: Any]) -> FamilyEvent? {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String,
              let dateTs = data["date"] as? Timestamp,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        let startTime = (data["startTime"] as? Timestamp)?.dateValue()
        let endTime = (data["endTime"] as? Timestamp)?.dateValue()
        let location = data["location"] as? String
        let notes = data["notes"] as? String
        let eventTypeRaw = data["eventType"] as? String
        let isRecurring = data["isRecurring"] as? Bool
        return FamilyEvent(
            id: id,
            title: title,
            date: dateTs.dateValue(),
            endDate: endDate,
            createdBy: createdBy,
            startTime: startTime,
            endTime: endTime,
            location: location,
            notes: notes,
            eventTypeRaw: eventTypeRaw,
            isRecurring: isRecurring
        )
    }

    /// Fetches all events for a family, ordered by date
    func fetchEvents(familyId: String, includePast: Bool = false) async throws -> [FamilyEvent] {
        var query = eventsRef(familyId: familyId).order(by: "date", descending: false)

        // Optionally filter out past events
        if !includePast {
            query = query.whereField("date", isGreaterThanOrEqualTo: Timestamp(date: Date()))
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { Self.parseEvent(from: $0.data()) }
    }
    
    /// Deletes an event
    func deleteEvent(familyId: String, eventId: String) async throws {
        try await eventsRef(familyId: familyId).document(eventId).delete()
    }
    
    /// Updates an event. Pass nil for any field to leave it unchanged.
    func updateEvent(
        familyId: String,
        eventId: String,
        title: String? = nil,
        date: Date? = nil,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        eventTypeRaw: String? = nil,
        isRecurring: Bool? = nil
    ) async throws {
        var updates: [String: Any] = [:]
        if let title { updates["title"] = title }
        if let date { updates["date"] = Timestamp(date: date) }
        if let endDate { updates["endDate"] = Timestamp(date: endDate) }
        if let startTime { updates["startTime"] = Timestamp(date: startTime) }
        if let endTime { updates["endTime"] = Timestamp(date: endTime) }
        if let location { updates["location"] = location }
        if let notes { updates["notes"] = notes }
        if let eventTypeRaw { updates["eventType"] = eventTypeRaw }
        if let isRecurring { updates["isRecurring"] = isRecurring }

        if !updates.isEmpty {
            updates["editedAt"] = FieldValue.serverTimestamp()
            try await eventsRef(familyId: familyId).document(eventId).updateData(updates)
        }
    }

    /// Sets up a real-time listener for events
    func observeEvents(familyId: String, includePast: Bool = false, onChange: @escaping ([FamilyEvent]) -> Void) -> ListenerRegistration {
        var query = eventsRef(familyId: familyId).order(by: "date", descending: false)

        if !includePast {
            query = query.whereField("date", isGreaterThanOrEqualTo: Timestamp(date: Date()))
        }

        let listener = query.addSnapshotListener { snapshot, error in
            if let error {
                Log.content.error("observeEvents failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let documents = snapshot?.documents else {
                onChange([])
                return
            }
            onChange(documents.compactMap { Self.parseEvent(from: $0.data()) })
        }

        return listener
    }
    
    // MARK: - Batch Operations
    
    /// Fetches both posts and events in a single operation
    func fetchAllContent(familyId: String) async throws -> (posts: [FamilyPost], events: [FamilyEvent]) {
        async let posts = fetchPosts(familyId: familyId)
        async let events = fetchEvents(familyId: familyId)
        
        return try await (posts, events)
    }
}

// MARK: - Errors

enum ContentServiceError: LocalizedError {
    case unauthorized
    case contentNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "You don't have permission to perform this action."
        case .contentNotFound:
            return "Content not found."
        case .invalidData:
            return "Invalid content data."
        }
    }
}


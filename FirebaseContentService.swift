import Foundation
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
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await postsRef(familyId: familyId).document(postId).setData(postData)
        
        return post
    }
    
    /// Fetches all posts for a family, ordered by timestamp (newest first)
    func fetchPosts(familyId: String, limit: Int = 50) async throws -> [FamilyPost] {
        let snapshot = try await postsRef(familyId: familyId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> FamilyPost? in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let authorName = data["authorName"] as? String,
                  let content = data["content"] as? String,
                  let timestamp = data["timestamp"] as? Timestamp else {
                return nil
            }
            
            return FamilyPost(
                id: id,
                authorName: authorName,
                content: content,
                timestamp: timestamp.dateValue()
            )
        }
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
    
    /// Sets up a real-time listener for posts
    func observePosts(familyId: String, onChange: @escaping ([FamilyPost]) -> Void) -> ListenerRegistration {
        let listener = postsRef(familyId: familyId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                
                let posts = documents.compactMap { doc -> FamilyPost? in
                    let data = doc.data()
                    guard let id = data["id"] as? String,
                          let authorName = data["authorName"] as? String,
                          let content = data["content"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    
                    return FamilyPost(
                        id: id,
                        authorName: authorName,
                        content: content,
                        timestamp: timestamp.dateValue()
                    )
                }
                
                onChange(posts)
            }
        
        return listener
    }
    
    // MARK: - Events Management
    
    /// Creates a new family event
    func createEvent(familyId: String, title: String, date: Date, createdBy: String) async throws -> FamilyEvent {
        let eventId = UUID().uuidString
        
        let event = FamilyEvent(
            id: eventId,
            title: title,
            date: date,
            createdBy: createdBy
        )
        
        let eventData: [String: Any] = [
            "id": event.id,
            "title": title,
            "date": Timestamp(date: date),
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await eventsRef(familyId: familyId).document(eventId).setData(eventData)
        
        return event
    }
    
    /// Fetches all events for a family, ordered by date
    func fetchEvents(familyId: String, includePast: Bool = false) async throws -> [FamilyEvent] {
        var query = eventsRef(familyId: familyId).order(by: "date", descending: false)
        
        // Optionally filter out past events
        if !includePast {
            query = query.whereField("date", isGreaterThanOrEqualTo: Timestamp(date: Date()))
        }
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc -> FamilyEvent? in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let title = data["title"] as? String,
                  let date = data["date"] as? Timestamp,
                  let createdBy = data["createdBy"] as? String else {
                return nil
            }
            
            return FamilyEvent(
                id: id,
                title: title,
                date: date.dateValue(),
                createdBy: createdBy
            )
        }
    }
    
    /// Deletes an event
    func deleteEvent(familyId: String, eventId: String) async throws {
        try await eventsRef(familyId: familyId).document(eventId).delete()
    }
    
    /// Updates an event
    func updateEvent(familyId: String, eventId: String, title: String?, date: Date?) async throws {
        var updates: [String: Any] = [:]
        
        if let title = title {
            updates["title"] = title
        }
        
        if let date = date {
            updates["date"] = Timestamp(date: date)
        }
        
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
            guard let documents = snapshot?.documents else {
                onChange([])
                return
            }
            
            let events = documents.compactMap { doc -> FamilyEvent? in
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let title = data["title"] as? String,
                      let date = data["date"] as? Timestamp,
                      let createdBy = data["createdBy"] as? String else {
                    return nil
                }
                
                return FamilyEvent(
                    id: id,
                    title: title,
                    date: date.dateValue(),
                    createdBy: createdBy
                )
            }
            
            onChange(events)
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


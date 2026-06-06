import Foundation
import os
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseStorage

protocol AuthService {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String, name: String) async throws -> User
    func signOut() async throws
}

// Simple in-memory stub; swap with Firebase/Supabase implementation later.
final class StubAuthService: AuthService {
    func signIn(email: String, password: String) async throws -> User {
        return User(id: UUID().uuidString, name: "User", email: email, familyId: nil, role: nil)
    }
    func signUp(email: String, password: String, name: String) async throws -> User {
        return User(id: UUID().uuidString, name: name, email: email, familyId: nil, role: nil)
    }
    func signOut() async throws {}
}

struct Invite: Identifiable, Equatable {
    let id: String
    let familyId: String
    let familyName: String
    let invitedEmail: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var currentFamily: Family?
    @Published var isAuthenticated: Bool = false
    @Published var pendingInvites: [Invite] = []
    @Published var deepLinkInviteID: String? = nil
    @Published var deepLinkPage: FamoriaPage? = nil
    /// When set alongside `deepLinkPage = .events`, the calendar should jump to and
    /// select this date. Cleared by the calendar after it consumes the value.
    @Published var pendingEventDate: Date? = nil

    @Published var events: [FamilyEvent] = []
    @Published var posts: [FamilyPost] = []
    
    @Published var chats: [Chat] = [] // All DM/group threads
    @Published var messagesByChat: [String: [ChatMessage]] = [:] // Chat ID → messages
    @Published var activeChatId: String? = nil // Currently viewed chat

    // Notifications
    @Published var notifications: [FamoriaNotification] = []
    private var notificationsListener: ListenerRegistration?

    func startListeningToNotifications() {
        guard let userId = currentUser?.id else {
            Log.notifications.debug("cannot start listener: no currentUser")
            return
        }
        Log.notifications.debug("starting listener for userId=\(userId, privacy: .private)")
        notificationsListener?.remove()
        notificationsListener = db.collection("famoria_notifications")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Log.notifications.error("listener error: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let self, let snapshot else { return }
                Log.notifications.debug("snapshot received: \(snapshot.documents.count) docs")
                self.notifications = snapshot.documents.compactMap { doc in
                    Self.decodeNotification(id: doc.documentID, data: doc.data())
                }.sorted { $0.createdDate > $1.createdDate }
            }
    }

    /// Manual decoder that's resilient to Firestore Timestamp/Date variations.
    /// Avoids silent `try?` failures from `Firestore.Decoder()` that previously
    /// caused notifications to be dropped on the floor.
    private static func decodeNotification(id docId: String, data: [String: Any]) -> FamoriaNotification? {
        guard
            let userId = data["userId"] as? String,
            let title  = data["title"]  as? String,
            let body   = data["body"]   as? String,
            let typeRaw = data["type"]  as? String,
            let type   = FamoriaNotificationType(rawValue: typeRaw)
        else {
            Log.notifications.error("decode failed for doc=\(docId, privacy: .public)")
            return nil
        }
        let isRead = data["isRead"] as? Bool ?? false
        let createdDate: Date
        if let ts = data["createdDate"] as? Timestamp {
            createdDate = ts.dateValue()
        } else if let d = data["createdDate"] as? Date {
            createdDate = d
        } else {
            createdDate = Date()
        }
        return FamoriaNotification(
            id: docId,
            userId: userId,
            title: title,
            body: body,
            type: type,
            isRead: isRead,
            createdDate: createdDate
        )
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var unreadMessagesCount: Int {
        chats.reduce(0) { $0 + $1.unreadCount }
    }

    /// Count of unread event-type notifications. Used by the bottom-nav
    /// badge so the user sees when a family member has added or updated
    /// an event they haven't viewed yet. Clears as notifications are
    /// marked read.
    var upcomingEventsBadge: Int {
        notifications.filter { !$0.isRead && $0.type == .event }.count
    }

    func markNotificationRead(_ id: String) {
        db.collection("famoria_notifications").document(id).updateData(["isRead": true]) { err in
            if let err {
                Log.notifications.error("markNotificationRead failed: \(err.localizedDescription, privacy: .public)")
            }
        }
    }

    func markAllNotificationsRead() {
        let batch = db.batch()
        for notif in notifications where !notif.isRead {
            let ref = db.collection("famoria_notifications").document(notif.id)
            batch.updateData(["isRead": true], forDocument: ref)
        }
        batch.commit { err in
            if let err {
                Log.notifications.error("markAllNotificationsRead failed: \(err.localizedDescription, privacy: .public)")
            }
        }
    }

    func removeNotification(_ id: String) {
        db.collection("famoria_notifications").document(id).delete { err in
            if let err {
                Log.notifications.error("removeNotification failed: \(err.localizedDescription, privacy: .public)")
            }
        }
    }

    func notifyFamilyMembers(title: String, body: String, type: FamoriaNotificationType, excludeUserId: String? = nil) {
        guard let members = currentFamily?.members else {
            Log.notifications.debug("notifyFamilyMembers skipped — no currentFamily")
            return
        }
        let targets = members.filter { $0.id != excludeUserId }
        Log.notifications.debug("writing \(targets.count) notification(s): \(title, privacy: .public)")
        for member in targets {
            writeNotification(userId: member.id, title: title, body: body, type: type)
        }
    }

    func notifyUsers(_ userIds: [String], title: String, body: String, type: FamoriaNotificationType, excludeUserId: String? = nil) {
        let targets = userIds.filter { $0 != excludeUserId }
        Log.notifications.debug("writing \(targets.count) notification(s) to specific users: \(title, privacy: .public)")
        for uid in targets {
            writeNotification(userId: uid, title: title, body: body, type: type)
        }
    }

    /// Writes a notification document using an explicit dictionary so the
    /// schema is stable regardless of Codable encoding behaviour. Surfaces
    /// failures to the console rather than swallowing them.
    private func writeNotification(userId: String, title: String, body: String, type: FamoriaNotificationType) {
        let docId = UUID().uuidString
        let payload: [String: Any] = [
            "id": docId,
            "userId": userId,
            "title": title,
            "body": body,
            "type": type.rawValue,
            "isRead": false,
            "createdDate": Timestamp(date: Date())
        ]
        db.collection("famoria_notifications").document(docId).setData(payload) { error in
            if let error {
                Log.notifications.error("write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Debug helper: writes a notification addressed to the current user.
    /// Used by the "Send Test Notification" button on the Profile screen so
    /// the whole bell pipeline can be verified end-to-end without needing
    /// a second device. Returns the error string on failure (or nil on
    /// success) so the UI can show a result.
    @discardableResult
    func sendTestNotificationToSelf() async -> String? {
        guard let user = currentUser else { return "Not signed in" }
        let docId = UUID().uuidString
        let payload: [String: Any] = [
            "id": docId,
            "userId": user.id,
            "title": "Test notification",
            "body": "If you can read this, your notification pipeline works.",
            "type": FamoriaNotificationType.system.rawValue,
            "isRead": false,
            "createdDate": Timestamp(date: Date())
        ]
        return await withCheckedContinuation { continuation in
            db.collection("famoria_notifications").document(docId).setData(payload) { error in
                if let error {
                    Log.notifications.error("test write failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: error.localizedDescription)
                } else {
                    Log.notifications.debug("test write succeeded")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Firestore instance
    private let db = Firestore.firestore()
    
    // Services - use Firebase in production, StubAuthService for testing
    var auth: AuthService = FirebaseAuthService()
    private let familyService = FirebaseFamilyService()
    private let contentService = FirebaseContentService()
    private let chatService = FirebaseChatService()
    let activityService = FamilyActivityService()

    /// StoreKit 2 wrapper. Provides product list + current entitlement.
    let subscriptionManager = SubscriptionManager()
    /// Cloud Storage usage counter.
    let storageQuota = StorageQuotaManager()
    /// Bridges StoreKit changes into the family Firestore doc.
    private let subscriptionSync = SubscriptionSyncService()

    /// Centralised "can this user do X" derived from the family's
    /// current subscription + signed-in user role. Recomputed on read,
    /// no state of its own.
    var entitlements: EntitlementManager {
        EntitlementManager(
            subscription: currentFamily?.subscription ?? .free,
            userRole: currentUser?.role
        )
    }

    /// Captures the StoreKit closure once so we don't accidentally
    /// rewire it on every observe call.
    private var wiredSubscriptionSync = false
    
    // Real-time listeners
    private var familyListener: ListenerRegistration?
    private var postsListener: ListenerRegistration?
    private var eventsListener: ListenerRegistration?
    private var chatsListener: ListenerRegistration?
    private var messagesListeners: [String: ListenerRegistration] = [:]
    
    init() {}

    /// Call on app launch to restore a persisted Firebase Auth session.
    func checkAuthState() {
        guard UserDefaults.standard.bool(forKey: "famoria.staySignedIn") != false else { return }
        if let authService = auth as? FirebaseAuthService {
            Task {
                if let user = await authService.restoreSession() {
                    self.currentUser = user
                    self.isAuthenticated = true
                    if let familyId = user.familyId {
                        await loadFamilyData(familyId: familyId)
                    }
                    observeChats()
                    startListeningToNotifications()
                }
            }
        }
    }
    
    deinit {
        familyListener?.remove()
        postsListener?.remove()
        eventsListener?.remove()
        chatsListener?.remove()
        notificationsListener?.remove()
        for listener in messagesListeners.values {
            listener.remove()
        }
    }
    
    func handleSignIn(email: String, password: String) async throws {
        Log.auth.debug("handleSignIn starting for email=\(email, privacy: .private)")
        do {
            let user = try await auth.signIn(email: email, password: password)
            Log.auth.debug("handleSignIn: auth.signIn returned uid=\(user.id, privacy: .private) familyId=\(user.familyId ?? "<none>", privacy: .public)")
            self.currentUser = user
            self.isAuthenticated = true

            if let familyId = user.familyId {
                await loadFamilyData(familyId: familyId)
            }

            observeChats()
            startListeningToNotifications()
            Log.auth.debug("handleSignIn: completed, isAuthenticated=true")
        } catch {
            Self.logAuthError(error, label: "handleSignIn")
            throw error
        }
    }

    func handleSignUp(name: String, email: String, password: String) async throws {
        Log.auth.debug("handleSignUp starting for email=\(email, privacy: .private)")
        do {
            let user = try await auth.signUp(email: email, password: password, name: name)
            Log.auth.debug("handleSignUp: auth.signUp returned uid=\(user.id, privacy: .private)")
            self.currentUser = user
            self.isAuthenticated = true

            observeChats()
            startListeningToNotifications()
            Log.auth.debug("handleSignUp: completed, isAuthenticated=true")
        } catch {
            Self.logAuthError(error, label: "handleSignUp")
            throw error
        }
    }

    /// Dumps a Firebase Auth error in detail, including the userInfo dictionary
    /// (where Identity Toolkit puts the real cause for the catch-all 17999
    /// "internal error" code). Use this when diagnosing auth failures.
    private static func logAuthError(_ error: Error, label: String) {
        let nsError = error as NSError
        Log.auth.error("\(label, privacy: .public) FAILED: domain=\(nsError.domain, privacy: .public) code=\(nsError.code) desc=\(error.localizedDescription, privacy: .public)")
        // Identity Toolkit stuffs the underlying HTTP response into userInfo.
        // Logging it verbatim is the fastest way to find out whether the real
        // cause is App Check, a missing API key, a disabled provider, etc.
        Log.auth.error("\(label, privacy: .public) userInfo=\(String(describing: nsError.userInfo), privacy: .public)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            Log.auth.error("\(label, privacy: .public) underlying: domain=\(underlying.domain, privacy: .public) code=\(underlying.code) desc=\(underlying.localizedDescription, privacy: .public) userInfo=\(String(describing: underlying.userInfo), privacy: .public)")
        }
    }
    
    func signOut() async {
        familyListener?.remove()
        postsListener?.remove()
        eventsListener?.remove()
        chatsListener?.remove()
        notificationsListener?.remove()
        for listener in messagesListeners.values {
            listener.remove()
        }
        messagesListeners.removeAll()

        // Clear saved session if not staying signed in
        if !UserDefaults.standard.bool(forKey: "famoria.staySignedIn") {
            UserDefaults.standard.removeObject(forKey: "famoria.savedEmail")
        }
        
        do {
            try await auth.signOut()
        } catch {
            Log.auth.error("Error signing out: \(error.localizedDescription, privacy: .public)")
        }
        currentUser = nil
        currentFamily = nil
        isAuthenticated = false
        events = []
        posts = []
        chats = []
        messagesByChat = [:]
        activeChatId = nil
        storageQuota.stop()
        wiredSubscriptionSync = false
        subscriptionManager.onStatusChanged = nil
    }
    
    // MARK: - Family Management
    
    /// Creates a new family with the current user as owner
    func createFamily(name: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        
        let family = try await familyService.createFamily(name: name, ownerUser: user)
        self.currentFamily = family
        self.currentUser?.familyId = family.id
        self.currentUser?.role = .owner
        
        // Start observing the family
        await loadFamilyData(familyId: family.id)
    }
    
    /// Generates an invite code for the current family
    func generateInviteCode() async throws -> String {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }

        let code = try await familyService.generateInviteCode(
            familyId: family.id,
            familyName: family.name,
            createdBy: user.id
        )

        return code
    }

    /// Fetches the latest valid invite code for the current family
    func fetchLatestInviteCode() async throws -> String? {
        guard let family = currentFamily else {
            throw AppStateError.noFamily
        }
        return try await familyService.fetchLatestInviteCode(familyId: family.id)
    }

    /// Validates and joins a family using an invite code
    func joinFamilyWithCode(_ code: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        
        let family = try await familyService.joinFamily(withCode: code, user: user)
        self.currentFamily = family
        self.currentUser?.familyId = family.id
        self.currentUser?.role = .member
        
        // Start observing the family
        await loadFamilyData(familyId: family.id)
    }
    
    /// Validates an invite code without joining
    func validateInviteCode(_ code: String) async throws -> (familyId: String, familyName: String) {
        return try await familyService.validateInviteCode(code)
    }
    
    // MARK: - Content Management
    
    /// Creates a new post in the family feed
    func createPost(content: String) async throws {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }
        
        let post = try await contentService.createPost(
            familyId: family.id,
            authorName: user.name,
            authorId: user.id,
            content: content
        )

        self.posts.insert(post, at: 0)

        notifyFamilyMembers(
            title: "\(user.name) posted an update",
            body: String(content.prefix(80)),
            type: .familyUpdate,
            excludeUserId: user.id
        )
    }
    
    /// Creates a new event in the family calendar. If `id` is provided, the
    /// event is created with that document id (used when the caller has
    /// already inserted a richer local representation under the same id).
    /// V2 fields are persisted to Firestore so every family member sees them.
    func createEvent(
        title: String,
        date: Date,
        id: String? = nil,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        eventTypeRaw: String? = nil,
        isRecurring: Bool? = nil,
        reminderOffsetsRaw: [String]? = nil
    ) async throws {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }

        let event = try await contentService.createEvent(
            familyId: family.id,
            title: title,
            date: date,
            createdBy: user.id,
            id: id,
            endDate: endDate,
            startTime: startTime,
            endTime: endTime,
            location: location,
            notes: notes,
            eventTypeRaw: eventTypeRaw,
            isRecurring: isRecurring,
            reminderOffsetsRaw: reminderOffsetsRaw
        )

        // Avoid duplicating an event that the caller already inserted locally.
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
        } else {
            events.append(event)
        }
        events.sort { $0.date < $1.date }

        let dateStr = date.formatted(date: .abbreviated, time: .shortened)
        notifyFamilyMembers(
            title: "\(user.name) created an event",
            body: "\(title) — \(dateStr)",
            type: .event,
            excludeUserId: user.id
        )
        Task {
            await activityService.log(
                familyId: family.id,
                kind: .eventCreated,
                actorName: user.name,
                actorId: user.id,
                title: "Added event: \(title)",
                body: dateStr
            )
        }
    }

    /// Pushes an event edit to Firestore so other family members see the change.
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
        isRecurring: Bool? = nil,
        reminderOffsetsRaw: [String]? = nil
    ) async throws {
        try await contentService.updateEvent(
            familyId: familyId,
            eventId: eventId,
            title: title,
            date: date,
            endDate: endDate,
            startTime: startTime,
            endTime: endTime,
            location: location,
            notes: notes,
            eventTypeRaw: eventTypeRaw,
            isRecurring: isRecurring,
            reminderOffsetsRaw: reminderOffsetsRaw
        )
    }

    /// Deletes a post
    func deletePost(_ post: FamilyPost) async throws {
        guard let family = currentFamily else {
            throw AppStateError.noFamily
        }

        try await contentService.deletePost(familyId: family.id, postId: post.id)

        // Remove optimistically
        self.posts.removeAll { $0.id == post.id }
    }

    /// Edits a post's content
    func updatePost(_ post: FamilyPost, newContent: String) async throws {
        guard let family = currentFamily else { throw AppStateError.noFamily }
        try await contentService.updatePost(familyId: family.id, postId: post.id, newContent: newContent)
        if let idx = self.posts.firstIndex(where: { $0.id == post.id }) {
            self.posts[idx].content = newContent
        }
    }

    /// Adds a reply to a post
    func addReply(to post: FamilyPost, content: String) async throws {
        guard let family = currentFamily,
              let user = currentUser else { throw AppStateError.noFamily }
        let reply = PostReply(authorName: user.name, content: content)
        try await contentService.addReply(familyId: family.id, postId: post.id, reply: reply)
        if let idx = self.posts.firstIndex(where: { $0.id == post.id }) {
            self.posts[idx].replies.append(reply)
        }
    }

    /// Looks up a family member's avatarURL by display name. Used by views
    /// that only know the author name (posts, replies) so they can still
    /// render the right photo when the member updates their avatar.
    func avatarURL(forName name: String) -> String? {
        guard !name.isEmpty else { return nil }
        if let me = currentUser, me.name == name {
            return me.avatarURL
        }
        return currentFamily?.members.first(where: { $0.name == name })?.avatarURL
    }

    /// Uploads the user's avatar photo and updates the URL on both the
    /// `users` document and the family members list.
    func updateUserAvatar(jpegData: Data) async throws {
        guard let user = currentUser,
              let authService = auth as? FirebaseAuthService else { return }
        let url = try await authService.uploadAvatar(
            userId: user.id,
            familyId: user.familyId,
            jpegData: jpegData
        )
        self.currentUser?.avatarURL = url
        if let idx = currentFamily?.members.firstIndex(where: { $0.id == user.id }) {
            currentFamily?.members[idx].avatarURL = url
        }
    }

    /// Updates the current user's display name in Firebase Auth, the
    /// `users` document, and the family's members list.
    func updateUserName(_ newName: String) async throws {
        guard let user = currentUser,
              let authService = auth as? FirebaseAuthService else { return }
        try await authService.updateUserName(
            userId: user.id,
            newName: newName,
            familyId: user.familyId
        )
        self.currentUser?.name = newName
        if let familyId = user.familyId,
           let idx = currentFamily?.members.firstIndex(where: { $0.id == user.id }) {
            currentFamily?.members[idx].name = newName
            _ = familyId
        }
    }

    /// Toggles a user's reaction emoji on a post
    func toggleReaction(_ emoji: String, on post: FamilyPost) async throws {
        guard let family = currentFamily,
              let user = currentUser else { throw AppStateError.noFamily }
        try await contentService.toggleReaction(
            familyId: family.id,
            postId: post.id,
            emoji: emoji,
            userName: user.name
        )
    }
    
    /// Deletes an event
    func deleteEvent(_ event: FamilyEvent) async throws {
        guard let family = currentFamily else {
            throw AppStateError.noFamily
        }

        try await contentService.deleteEvent(familyId: family.id, eventId: event.id)

        // Remove optimistically
        self.events.removeAll { $0.id == event.id }
        EventReminderScheduler.cancelAll(eventId: event.id)
    }
    
    // MARK: - Chat Management
    
    /// Fetch all chats for current user
    func fetchChats() async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        let fetchedChats = try await chatService.fetchChats(forUserId: user.id)
        self.chats = fetchedChats
    }
    
    /// Fetch messages for a specific chat
    func fetchMessages(for chatId: String) async throws {
        let fetchedMessages = try await chatService.fetchMessages(chatId: chatId)
        messagesByChat[chatId] = fetchedMessages
    }
    
    /// Send a message to a chat
    func sendMessage(to chatId: String, content: String, replyTo: ChatMessage? = nil) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        let message = try await chatService.sendMessage(
            chatId: chatId,
            senderId: user.id,
            senderName: user.name,
            content: content,
            replyTo: replyTo
        )

        var currentMessages = messagesByChat[chatId] ?? []
        currentMessages.append(message)
        messagesByChat[chatId] = currentMessages

        if let chat = chats.first(where: { $0.id == chatId }) {
            let recipientIds = chat.participants.map(\.id)
            notifyUsers(
                recipientIds,
                title: "\(user.name) sent a message",
                body: String(content.prefix(80)),
                type: .message,
                excludeUserId: user.id
            )
        }
    }
    
    /// Add a reaction to a message
    func addReaction(_ emoji: String, to messageId: String, in chatId: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        try await chatService.addReaction(
            emoji: emoji,
            toMessage: messageId,
            inChat: chatId,
            userId: user.id,
            userName: user.name
        )
    }
    
    /// Set typing status
    func setTyping(_ isTyping: Bool, in chatId: String) async throws {
        guard let user = currentUser else { return }
        try await chatService.setTyping(isTyping, userId: user.id, chatId: chatId)
    }
    
    /// Create a new group chat
    func createGroupChat(with userIds: [String], participantNames: [String: String], name: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        let chat = try await chatService.createGroupChat(
            creatorId: user.id,
            participantIds: userIds,
            participantNames: participantNames,
            name: name
        )
        chats.append(chat)
    }
    
    /// Send an image message
    func sendImageMessage(to chatId: String, imageURL: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        let message = try await chatService.sendImageMessage(
            chatId: chatId,
            senderId: user.id,
            senderName: user.name,
            imageURL: imageURL
        )
        var currentMessages = messagesByChat[chatId] ?? []
        currentMessages.append(message)
        messagesByChat[chatId] = currentMessages
    }

    /// Delete a message
    func deleteMessage(_ messageId: String, in chatId: String) async throws {
        try await chatService.deleteMessage(messageId: messageId, chatId: chatId)
        messagesByChat[chatId]?.removeAll { $0.id == messageId }
    }

    /// Sends a voice-note message. The recorder produces a temp file
    /// URL; we upload it to Storage under chat_voice/{chatId}/ and then
    /// post the message.
    func sendVoiceMessage(to chatId: String, fileURL: URL, duration: TimeInterval) async throws {
        guard let user = currentUser else { throw AppStateError.notAuthenticated }
        let storageRef = Storage.storage().reference()
            .child("chat_voice/\(chatId)/\(fileURL.lastPathComponent)")
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        _ = try await storageRef.putFileAsync(from: fileURL, metadata: metadata)
        let url = try await storageRef.downloadURL().absoluteString

        let message = try await chatService.sendVoiceMessage(
            chatId: chatId,
            senderId: user.id,
            senderName: user.name,
            voiceURL: url,
            duration: duration
        )

        var current = messagesByChat[chatId] ?? []
        current.append(message)
        messagesByChat[chatId] = current

        // Clean up the temp file once it's safely on Storage.
        try? FileManager.default.removeItem(at: fileURL)

        if let chat = chats.first(where: { $0.id == chatId }) {
            let recipientIds = chat.participants.map(\.id)
            notifyUsers(
                recipientIds,
                title: "\(user.name) sent a voice note",
                body: "🎤 \(Int(duration.rounded()))s",
                type: .message,
                excludeUserId: user.id
            )
        }
    }

    /// Marks a message as seen by the current user. Safe to call from
    /// `onAppear` of each message bubble; cheap no-op when already read.
    func markMessageRead(_ messageId: String, in chatId: String) {
        guard let user = currentUser else { return }
        Task { await chatService.markMessageRead(messageId: messageId, chatId: chatId, userId: user.id) }
    }

    /// Delete an entire chat
    func deleteChat(_ chatId: String) async throws {
        try await chatService.deleteChat(chatId: chatId)
        chats.removeAll { $0.id == chatId }
        messagesByChat.removeValue(forKey: chatId)
    }

    /// Create a direct chat with one user
    func createDirectChat(with userId: String, userName: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        let chat = try await chatService.createDirectChat(
            userId1: user.id,
            userName1: user.name,
            userId2: userId,
            userName2: userName
        )
        chats.append(chat)
    }
    
    /// Observe chats in real-time
    func observeChats() {
        guard let user = currentUser else { return }
        chatsListener?.remove()
        chatsListener = chatService.observeChats(forUserId: user.id) { [weak self] (chats: [Chat]) in
            Task { @MainActor in
                self?.chats = chats
            }
        }
    }
    
    /// Observe messages for a specific chat in real-time
    func observeMessages(for chatId: String) {
        messagesListeners[chatId]?.remove()
        messagesListeners[chatId] = chatService.observeMessages(chatId: chatId) { [weak self] (messages: [ChatMessage]) in
            Task { @MainActor in
                self?.messagesByChat[chatId] = messages
            }
        }
    }

    /// Stop observing messages for a specific chat. Call from `onDisappear`
    /// of the chat detail view to avoid accumulating Firestore listeners.
    func stopObservingMessages(for chatId: String) {
        messagesListeners[chatId]?.remove()
        messagesListeners[chatId] = nil
    }

    /// Stop the global chat-list listener. Call from `onDisappear` of the
    /// direct-messages list when it's no longer visible.
    func stopObservingChats() {
        chatsListener?.remove()
        chatsListener = nil
    }
    
    // MARK: - Data Loading
    
    /// Loads all family data and sets up real-time listeners
    func loadFamilyData(familyId: String) async {
        do {
            // Fetch initial data
            let family = try await familyService.fetchFamily(familyId: familyId)
            self.currentFamily = family

            let (posts, events) = try await contentService.fetchAllContent(familyId: familyId)
            self.posts = posts
            self.events = events

            // Set up real-time listeners
            observeLiveUpdates(familyId: familyId)

            // Subscription + storage quota
            storageQuota.start(familyId: familyId)
            await startSubscriptionLifecycle(familyId: familyId)
        } catch {
            Log.appState.error("Error loading family data: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Boots the StoreKit listener, loads products, refreshes the user's
    /// entitlement, and (if they own billing) wires the StoreKit → Firestore
    /// sync. Idempotent — calling it multiple times is safe.
    private func startSubscriptionLifecycle(familyId: String) async {
        await subscriptionManager.loadProducts()
        await subscriptionManager.refreshEntitlement()

        guard !wiredSubscriptionSync else { return }
        wiredSubscriptionSync = true
        subscriptionManager.onStatusChanged = { [weak self] in
            await self?.syncSubscriptionToFamily()
        }
        await syncSubscriptionToFamily()
    }

    /// Writes the current SubscriptionManager state to the family doc —
    /// but only when the signed-in user is the family billing owner.
    /// Non-owners read the family doc and inherit; they never write.
    private func syncSubscriptionToFamily() async {
        guard let family = currentFamily,
              let user = currentUser,
              entitlements.canManageBilling else { return }
        await subscriptionSync.syncToFamily(
            familyId: family.id,
            ownerUserId: user.id,
            status: subscriptionManager.currentStatus,
            expiresAt: subscriptionManager.expiresAt,
            activeProductId: subscriptionManager.activeProductId,
            inTrial: subscriptionManager.inTrial
        )
    }
    
    /// Sets up real-time listeners for family, posts, and events
    func observeLiveUpdates(familyId: String) {
        // Clean up existing listeners
        familyListener?.remove()
        postsListener?.remove()
        eventsListener?.remove()
        
        // Observe family members
        familyListener = familyService.observeFamily(familyId: familyId) { [weak self] family in
            Task { @MainActor in
                self?.currentFamily = family
            }
        }
        
        // Observe posts
        postsListener = contentService.observePosts(familyId: familyId) { [weak self] posts in
            Task { @MainActor in
                self?.posts = posts
            }
        }
        
        // Observe events
        eventsListener = contentService.observeEvents(familyId: familyId) { [weak self] events in
            Task { @MainActor in
                self?.events = events
            }
        }
    }
    
    // MARK: - Invites (Legacy - keeping for compatibility)
    func createInvite(for email: String) {
        guard let family = currentFamily else { return }
        let invite = Invite(id: UUID().uuidString, familyId: family.id, familyName: family.name, invitedEmail: email)
        pendingInvites.append(invite)
    }
    
    func accept(invite: Invite) {
        // In a real backend flow, validate and fetch the family by id
        if currentFamily == nil {
            currentFamily = Family(id: invite.familyId, name: invite.familyName, members: currentUser.map { [$0] } ?? [])
        }
        currentUser?.familyId = invite.familyId
        pendingInvites.removeAll { $0.id == invite.id }
    }
    
    // MARK: - Deep Link Handling
    func handleIncomingInviteLink(id: String) {
        // In a real app, fetch invite by id from backend then accept
        if let invite = pendingInvites.first(where: { $0.id == id }) {
            accept(invite: invite)
        } else {
            // Placeholder: create a synthetic invite to allow acceptance demo
            if let email = currentUser?.email {
                let synthetic = Invite(id: id, familyId: UUID().uuidString, familyName: "Invited Family", invitedEmail: email)
                pendingInvites.append(synthetic)
                accept(invite: synthetic)
            }
        }
    }
    
    // MARK: - Member Management

    func remove(member: User) {
        guard let family = currentFamily else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.familyService.removeMember(userId: member.id, fromFamily: family.id)
                // Update will come through the listener
            } catch {
                Log.appState.error("Error removing member: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func removeMemberAsync(_ member: User) async throws {
        guard let family = currentFamily else { throw AppStateError.noFamily }
        try await familyService.removeMember(userId: member.id, fromFamily: family.id)
        currentFamily?.members.removeAll { $0.id == member.id }
    }

    func updateMemberRole(_ member: User, to newRole: MemberRole) async throws {
        guard let family = currentFamily else { throw AppStateError.noFamily }
        try await familyService.updateMemberRole(userId: member.id, familyId: family.id, newRole: newRole)
        if let index = currentFamily?.members.firstIndex(where: { $0.id == member.id }) {
            currentFamily?.members[index].role = newRole
        }
    }
    
    /// Creates a Firebase user and immediately creates a family with that user as owner.
    /// Intended for testing admin accounts.
    public func registerAdminAccount(adminName: String, email: String, password: String, familyName: String) async throws {
        let user = try await auth.signUp(email: email, password: password, name: adminName)
        self.currentUser = user
        self.isAuthenticated = true
        
        let family = try await familyService.createFamily(name: familyName, ownerUser: user)
        self.currentFamily = family
        self.currentUser?.familyId = family.id
        self.currentUser?.role = .owner
        
        await loadFamilyData(familyId: family.id)
    }
}
// MARK: - Errors

enum AppStateError: LocalizedError {
    case notAuthenticated
    case noFamily
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .noFamily:
            return "You must be in a family to perform this action."
        }
    }
}


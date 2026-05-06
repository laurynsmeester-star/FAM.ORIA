import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

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

    @Published var events: [FamilyEvent] = []
    @Published var posts: [FamilyPost] = []
    
    @Published var chats: [Chat] = [] // All DM/group threads
    @Published var messagesByChat: [String: [ChatMessage]] = [:] // Chat ID → messages
    @Published var activeChatId: String? = nil // Currently viewed chat

    // Notifications
    @Published var notifications: [FamoriaNotification] = []
    private var notificationsListener: ListenerRegistration?

    func startListeningToNotifications() {
        notificationsListener?.remove()
        notificationsListener = db.collection("famoria_notifications")
            .order(by: "createdDate", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                self.notifications = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(FamoriaNotification.self, from: data)
                }
            }
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func markNotificationRead(_ id: String) {
        db.collection("famoria_notifications").document(id).updateData(["isRead": true])
    }

    func markAllNotificationsRead() {
        for notif in notifications where !notif.isRead {
            db.collection("famoria_notifications").document(notif.id).updateData(["isRead": true])
        }
    }

    func removeNotification(_ id: String) {
        db.collection("famoria_notifications").document(id).delete()
    }

    func addNotification(title: String, body: String, type: FamoriaNotificationType) {
        let notification = FamoriaNotification(
            id: UUID().uuidString,
            title: title,
            body: body,
            type: type,
            isRead: false,
            createdDate: Date()
        )
        try? db.collection("famoria_notifications").document(notification.id).setData(from: notification)
    }
    
    // Firestore instance
    private let db = Firestore.firestore()
    
    // Example Firestore usage snippet
    func exampleFirestoreUsage() {
        let docRef = db.collection("users").document("userID")
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let dataDescription = document.data().map(String.init(describing:)) ?? "nil"
                print("Document data: \(dataDescription)")
            } else {
                print("Document does not exist")
            }
        }
    }
    
    // Services - use Firebase in production, StubAuthService for testing
    var auth: AuthService = FirebaseAuthService()
    private let familyService = FirebaseFamilyService()
    private let contentService = FirebaseContentService()
    private let chatService = FirebaseChatService()
    
    // Real-time listeners
    private var familyListener: ListenerRegistration?
    private var postsListener: ListenerRegistration?
    private var eventsListener: ListenerRegistration?
    private var chatsListener: ListenerRegistration?
    private var messagesListeners: [String: ListenerRegistration] = [:]
    
    init() {
        startListeningToNotifications()
    }

    /// Call on app launch to restore a persisted Firebase Auth session.
    func checkAuthState() {
        guard UserDefaults.standard.bool(forKey: "famoria.staySignedIn") != false else { return }
        // Firebase Auth automatically persists the session.
        // FirebaseAuthService.restoreSession can re-hydrate currentUser.
        if let authService = auth as? FirebaseAuthService {
            Task {
                if let user = await authService.restoreSession() {
                    self.currentUser = user
                    self.isAuthenticated = true
                    if let familyId = user.familyId {
                        await loadFamilyData(familyId: familyId)
                    }
                    observeChats()
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
        let user = try await auth.signIn(email: email, password: password)
        self.currentUser = user
        self.isAuthenticated = true
        
        // Load user's family data if they have one
        if let familyId = user.familyId {
            await loadFamilyData(familyId: familyId)
        }
        
        // Start observing chats
        observeChats()
    }
    
    func handleSignUp(name: String, email: String, password: String) async throws {
        let user = try await auth.signUp(email: email, password: password, name: name)
        self.currentUser = user
        self.isAuthenticated = true
        
        // Start observing chats
        observeChats()
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
        
        do { try await auth.signOut() } catch { print(error) }
        currentUser = nil
        currentFamily = nil
        isAuthenticated = false
        events = []
        posts = []
        chats = []
        messagesByChat = [:]
        activeChatId = nil
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
            createdBy: user.id
        )
        
        return code
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
        
        // Post will be updated via listener, but we can add it immediately for optimistic UI
        self.posts.insert(post, at: 0)
    }
    
    /// Creates a new event in the family calendar
    func createEvent(title: String, date: Date) async throws {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }
        
        let event = try await contentService.createEvent(
            familyId: family.id,
            title: title,
            date: date,
            createdBy: user.id
        )
        
        // Event will be updated via listener
        self.events.append(event)
        self.events.sort { $0.date < $1.date }
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
    
    /// Deletes an event
    func deleteEvent(_ event: FamilyEvent) async throws {
        guard let family = currentFamily else {
            throw AppStateError.noFamily
        }
        
        try await contentService.deleteEvent(familyId: family.id, eventId: event.id)
        
        // Remove optimistically
        self.events.removeAll { $0.id == event.id }
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
        
        // Optimistic update
        var currentMessages = messagesByChat[chatId] ?? []
        currentMessages.append(message)
        messagesByChat[chatId] = currentMessages
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
        } catch {
            print("Error loading family data: \(error)")
        }
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

        Task {
            do {
                try await familyService.removeMember(userId: member.id, fromFamily: family.id)
                // Update will come through the listener
            } catch {
                print("Error removing member: \(error)")
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


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

enum MemberRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var currentFamily: Family?
    @Published var isAuthenticated: Bool = false
    @Published var pendingInvites: [Invite] = []
    @Published var deepLinkInviteID: String? = nil
    
    @Published var events: [FamilyEvent] = []
    @Published var posts: [FamilyPost] = []
    
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
    // TODO: Switch back to FirebaseAuthService once Firebase SDK is properly installed
    var auth: AuthService = StubAuthService()
    // Temporarily commented out until Firebase SDK is fixed
    // private let familyService = FirebaseFamilyService()
    // private let contentService = FirebaseContentService()
    
    // Real-time listeners - commented out until Firebase is working
    // private var familyListener: ListenerRegistration?
    // private var postsListener: ListenerRegistration?
    // private var eventsListener: ListenerRegistration?
    
    init() {
        // Initialize with default values
    }
    
    deinit {
        // Clean up listeners - disabled until Firebase is working
        // familyListener?.remove()
        // postsListener?.remove()
        // eventsListener?.remove()
    }
    
    func handleSignIn(email: String, password: String) async throws {
        let user = try await auth.signIn(email: email, password: password)
        self.currentUser = user
        self.isAuthenticated = true
        
        // Load user's family data if they have one
        if let familyId = user.familyId {
            await loadFamilyData(familyId: familyId)
        }
    }
    
    func handleSignUp(name: String, email: String, password: String) async throws {
        let user = try await auth.signUp(email: email, password: password, name: name)
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func signOut() async {
        // Clean up listeners - disabled until Firebase is working
        // familyListener?.remove()
        // postsListener?.remove()
        // eventsListener?.remove()
        
        do { try await auth.signOut() } catch { print(error) }
        currentUser = nil
        currentFamily = nil
        isAuthenticated = false
        events = []
        posts = []
    }
    
    // MARK: - Family Management
    
    /// Creates a new family with the current user as owner
    func createFamily(name: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        let family = try await familyService.createFamily(name: name, ownerUser: user)
        self.currentFamily = family
        self.currentUser?.familyId = family.id
        self.currentUser?.role = .owner
        
        // Start observing the family
        await loadFamilyData(familyId: family.id)
        */
    }
    
    /// Generates an invite code for the current family
    func generateInviteCode() async throws -> String {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        let code = try await familyService.generateInviteCode(
            familyId: family.id,
            createdBy: user.id
        )
        
        return code
        */
    }
    
    /// Validates and joins a family using an invite code
    func joinFamilyWithCode(_ code: String) async throws {
        guard let user = currentUser else {
            throw AppStateError.notAuthenticated
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        let family = try await familyService.joinFamily(withCode: code, user: user)
        self.currentFamily = family
        self.currentUser?.familyId = family.id
        self.currentUser?.role = .member
        
        // Start observing the family
        await loadFamilyData(familyId: family.id)
        */
    }
    
    /// Validates an invite code without joining
    func validateInviteCode(_ code: String) async throws -> (familyId: String, familyName: String) {
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        // return try await familyService.validateInviteCode(code)
    }
    
    // MARK: - Content Management
    
    /// Creates a new post in the family feed
    func createPost(content: String) async throws {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        let post = try await contentService.createPost(
            familyId: family.id,
            authorName: user.name,
            authorId: user.id,
            content: content
        )
        
        // Post will be updated via listener, but we can add it immediately for optimistic UI
        self.posts.insert(post, at: 0)
        */
    }
    
    /// Creates a new event in the family calendar
    func createEvent(title: String, date: Date) async throws {
        guard let family = currentFamily,
              let user = currentUser else {
            throw AppStateError.noFamily
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        let event = try await contentService.createEvent(
            familyId: family.id,
            title: title,
            date: date,
            createdBy: user.id
        )
        
        // Event will be updated via listener
        self.events.append(event)
        self.events.sort { $0.date < $1.date }
        */
    }
    
    /// Deletes a post
    func deletePost(_ post: FamilyPost) async throws {
        guard let family = currentFamily else {
            throw AppStateError.noFamily
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        try await contentService.deletePost(familyId: family.id, postId: post.id)
        
        // Remove optimistically
        self.posts.removeAll { $0.id == post.id }
        */
    }
    
    /// Deletes an event
    func deleteEvent(_ event: FamilyEvent) async throws {
        guard let family = currentFamily else {
            throw AppStateError.noFamily
        }
        
        // TODO: Re-enable once Firebase SDK is installed
        fatalError("Firebase integration temporarily disabled. Please install Firebase SDK.")
        
        /*
        try await contentService.deleteEvent(familyId: family.id, eventId: event.id)
        
        // Remove optimistically
        self.events.removeAll { $0.id == event.id }
        */
    }
    
    // MARK: - Data Loading
    
    /// Loads all family data and sets up real-time listeners
    func loadFamilyData(familyId: String) async {
        // TODO: Re-enable once Firebase SDK is installed
        print("Firebase integration temporarily disabled. Cannot load family data.")
        
        /*
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
        */
    }
    
    /// Sets up real-time listeners for family, posts, and events
    func observeLiveUpdates(familyId: String) {
        // TODO: Re-enable once Firebase SDK is installed
        print("Firebase integration temporarily disabled. Cannot observe live updates.")
        
        /*
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
        */
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
        
        // TODO: Re-enable once Firebase SDK is installed
        print("Firebase integration temporarily disabled. Cannot remove member.")
        
        /*
        Task {
            do {
                try await familyService.removeMember(userId: member.id, fromFamily: family.id)
                // Update will come through the listener
            } catch {
                print("Error removing member: \(error)")
            }
        }
        */
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

call exampleFirestoreUsage()



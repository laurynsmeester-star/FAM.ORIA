import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class FirebaseAuthService: AuthService {
    private let db = Firestore.firestore()
    private let familyService = FirebaseFamilyService()
    
    init() {
        // Ensure Firebase is configured (safe if called multiple times)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let fbUser = result.user
        
        // Try to fetch user data from Firestore (includes familyId and role)
        if let existingUser = try await familyService.fetchUser(userId: fbUser.uid) {
            return existingUser
        }
        
        // Fallback if no Firestore data exists
        return User(
            id: fbUser.uid,
            name: fbUser.displayName ?? "User",
            email: fbUser.email ?? email,
            familyId: nil,
            role: nil
        )
    }
    
    func signUp(email: String, password: String, name: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let fbUser = result.user
        
        // Update display name in Firebase Auth
        let changeRequest = fbUser.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        
        // Create user document in Firestore
        let user = User(
            id: fbUser.uid,
            name: name,
            email: fbUser.email ?? email,
            familyId: nil,
            role: nil
        )
        
        try await db.collection("users").document(user.id).setData([
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        return user
    }
    
    func signOut() async throws {
        try Auth.auth().signOut()
    }

    /// Restore the currently signed-in Firebase Auth user (session persists across launches).
    func restoreSession() async -> User? {
        guard let fbUser = Auth.auth().currentUser else { return nil }
        do {
            if let existing = try await familyService.fetchUser(userId: fbUser.uid) {
                return existing
            }
        } catch { }
        return User(
            id: fbUser.uid,
            name: fbUser.displayName ?? "User",
            email: fbUser.email ?? "",
            familyId: nil,
            role: nil
        )
    }
}


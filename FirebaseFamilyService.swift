import Foundation
import os
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Service responsible for family creation, joining, and invite code validation
final class FirebaseFamilyService {
    private let db = Firestore.firestore()
    
    // MARK: - Collection References
    private var familiesRef: CollectionReference {
        db.collection("families")
    }
    
    private var invitesRef: CollectionReference {
        db.collection("invites")
    }
    
    private var usersRef: CollectionReference {
        db.collection("users")
    }
    
    // MARK: - Family Creation
    
    /// Creates a new family with the current user as owner
    func createFamily(name: String, ownerUser: User) async throws -> Family {
        let familyId = UUID().uuidString
        
        // Create owner user with role
        var owner = ownerUser
        owner.familyId = familyId
        owner.role = .owner
        
        let family = Family(
            id: familyId,
            name: name,
            members: [owner]
        )
        
        // Write to Firestore in a batch
        let batch = db.batch()
        
        // 1. Create family document
        let familyRef = familiesRef.document(familyId)
        batch.setData([
            "id": family.id,
            "name": family.name,
            "createdAt": FieldValue.serverTimestamp(),
            "ownerUserId": owner.id
        ], forDocument: familyRef)
        
        // 2. Add owner as member
        let memberRef = familyRef.collection("members").document(owner.id)
        batch.setData([
            "id": owner.id,
            "name": owner.name,
            "email": owner.email,
            "role": owner.role?.rawValue ?? "member",
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef)
        
        // 3. Update user document with familyId
        let userRef = usersRef.document(owner.id)
        batch.setData([
            "id": owner.id,
            "name": owner.name,
            "email": owner.email,
            "familyId": familyId,
            "role": "owner"
        ], forDocument: userRef, merge: true)
        
        try await batch.commit()
        
        return family
    }
    
    // MARK: - Invite Code Management
    
    /// Generates a unique 6-character invite code for a family
    func generateInviteCode(familyId: String, familyName: String, createdBy: String, expiresInHours: Int = 168) async throws -> String {
        let code = generateReadableCode()

        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresInHours * 3600))

        let inviteData: [String: Any] = [
            "code": code,
            "familyId": familyId,
            "familyName": familyName,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: expiresAt),
            "usedCount": 0,
            "maxUses": 10
        ]

        try await invitesRef.document(code).setData(inviteData)

        return code
    }

    /// Fetches the latest valid invite code for a family
    func fetchLatestInviteCode(familyId: String) async throws -> String? {
        let snapshot = try await invitesRef
            .whereField("familyId", isEqualTo: familyId)
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "expiresAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let code = doc.data()["code"] as? String,
              let usedCount = doc.data()["usedCount"] as? Int,
              let maxUses = doc.data()["maxUses"] as? Int,
              usedCount < maxUses else {
            return nil
        }

        return code
    }

    /// Validates an invite code and returns the family information
    func validateInviteCode(_ code: String) async throws -> (familyId: String, familyName: String) {
        let inviteDoc = try await invitesRef.document(code.uppercased()).getDocument()

        guard inviteDoc.exists,
              let data = inviteDoc.data(),
              let familyId = data["familyId"] as? String,
              let expiresAt = data["expiresAt"] as? Timestamp else {
            throw FamilyServiceError.invalidInviteCode
        }

        if expiresAt.dateValue() < Date() {
            throw FamilyServiceError.inviteCodeExpired
        }

        let usedCount = data["usedCount"] as? Int ?? 0
        let maxUses = data["maxUses"] as? Int ?? Int.max

        if usedCount >= maxUses {
            throw FamilyServiceError.inviteCodeExhausted
        }

        let familyName = data["familyName"] as? String ?? "Family"

        return (familyId, familyName)
    }
    
    /// Joins a family using a valid invite code
    func joinFamily(withCode code: String, user: User) async throws -> Family {
        // Validate code first
        let (familyId, _) = try await validateInviteCode(code)
        
        // Check if user is already in a family
        if user.familyId != nil {
            throw FamilyServiceError.userAlreadyInFamily
        }
        
        var member = user
        member.familyId = familyId
        member.role = .member
        
        let batch = db.batch()
        
        // 1. Add user to family members
        let familyRef = familiesRef.document(familyId)
        let memberRef = familyRef.collection("members").document(user.id)
        batch.setData([
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "role": "member",
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef)
        
        // 2. Update user document
        let userRef = usersRef.document(user.id)
        batch.updateData([
            "familyId": familyId,
            "role": "member"
        ], forDocument: userRef)
        
        // 3. Increment invite code usage
        let inviteRef = invitesRef.document(code.uppercased())
        batch.updateData([
            "usedCount": FieldValue.increment(Int64(1))
        ], forDocument: inviteRef)
        
        try await batch.commit()
        
        // Fetch complete family data
        return try await fetchFamily(familyId: familyId)
    }
    
    // MARK: - Family Data Fetching
    
    /// Fetches complete family data including all members
    func fetchFamily(familyId: String) async throws -> Family {
        let familyDoc = try await familiesRef.document(familyId).getDocument()
        
        guard familyDoc.exists,
              let data = familyDoc.data(),
              let name = data["name"] as? String else {
            throw FamilyServiceError.familyNotFound
        }
        
        // Fetch all members
        let membersSnapshot = try await familiesRef.document(familyId)
            .collection("members")
            .getDocuments()
        
        let members = membersSnapshot.documents.compactMap { doc -> User? in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let name = data["name"] as? String,
                  let email = data["email"] as? String else {
                return nil
            }
            
            let roleString = data["role"] as? String
            let role = MemberRole(rawValue: roleString ?? "member")
            let avatarURL = data["avatarURL"] as? String

            return User(
                id: id,
                name: name,
                email: email,
                familyId: familyId,
                role: role,
                avatarURL: avatarURL
            )
        }

        let subscription = SubscriptionSyncService.decodeFamilySubscription(from: data)
        let storageBytes = (data["storageUsedBytes"] as? Int64)
            ?? Int64(data["storageUsedBytes"] as? Int ?? 0)

        return Family(
            id: familyId,
            name: name,
            members: members,
            subscription: subscription,
            storageUsedBytes: storageBytes
        )
    }
    
    /// Fetches user data from Firestore
    func fetchUser(userId: String) async throws -> User? {
        let userDoc = try await usersRef.document(userId).getDocument()
        
        guard userDoc.exists, let data = userDoc.data() else {
            return nil
        }
        
        let id = data["id"] as? String ?? userId
        let name = data["name"] as? String ?? "User"
        let email = data["email"] as? String ?? ""
        let familyId = data["familyId"] as? String
        let roleString = data["role"] as? String
        let role = roleString.flatMap { MemberRole(rawValue: $0) }
        
        return User(
            id: id,
            name: name,
            email: email,
            familyId: familyId,
            role: role
        )
    }
    
    // MARK: - Member Management
    
    /// Removes a member from the family
    func removeMember(userId: String, fromFamily familyId: String) async throws {
        let batch = db.batch()
        
        // 1. Remove from family members
        let memberRef = familiesRef.document(familyId).collection("members").document(userId)
        batch.deleteDocument(memberRef)
        
        // 2. Update user document
        let userRef = usersRef.document(userId)
        batch.updateData([
            "familyId": FieldValue.delete(),
            "role": FieldValue.delete()
        ], forDocument: userRef)
        
        try await batch.commit()
    }
    
    /// Updates a member's role in the family
    func updateMemberRole(userId: String, familyId: String, newRole: MemberRole) async throws {
        let batch = db.batch()
        
        let memberRef = familiesRef.document(familyId).collection("members").document(userId)
        batch.updateData(["role": newRole.rawValue], forDocument: memberRef)
        
        let userRef = usersRef.document(userId)
        batch.updateData(["role": newRole.rawValue], forDocument: userRef)
        
        try await batch.commit()
    }
    
    // MARK: - Real-time Listeners
    
    /// Sets up a real-time listener for family updates
    func observeFamily(familyId: String, onChange: @escaping (Family?) -> Void) -> ListenerRegistration {
        let listener = familiesRef.document(familyId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Log.family.error("observeFamily failed: \(error.localizedDescription, privacy: .public)")
                }
                guard let self, (snapshot?.documents) != nil else {
                    onChange(nil)
                    return
                }

                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let family = try await self.fetchFamily(familyId: familyId)
                        onChange(family)
                    } catch {
                        Log.family.error("Error fetching family: \(error.localizedDescription, privacy: .public)")
                        onChange(nil)
                    }
                }
            }

        return listener
    }
    
    // MARK: - Helper Methods
    
    private func generateReadableCode() -> String {
        // Generate 6-character code without ambiguous characters (0, O, I, 1, etc.)
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Errors

enum FamilyServiceError: LocalizedError {
    case invalidInviteCode
    case inviteCodeExpired
    case inviteCodeExhausted
    case familyNotFound
    case userAlreadyInFamily
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidInviteCode:
            return "This invite code is invalid."
        case .inviteCodeExpired:
            return "This invite code has expired."
        case .inviteCodeExhausted:
            return "This invite code has reached its usage limit."
        case .familyNotFound:
            return "Family not found."
        case .userAlreadyInFamily:
            return "You are already in a family. Leave your current family first."
        case .notAuthorized:
            return "You don't have permission to perform this action."
        }
    }
}


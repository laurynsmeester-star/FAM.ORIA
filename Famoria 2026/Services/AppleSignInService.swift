//
//  AppleSignInService.swift
//  Famoria 2026
//
//  Translated from appleAuthCallback.ts
//
//  The TypeScript version ran server-side and:
//    1. Decoded the Apple JWT, verified issuer/audience/expiry
//    2. Checked if a user already existed in the DB
//    3. Created a session for returning users → redirected to Home
//    4. Signed up new users → redirected to Onboarding
//
//  Here all JWT validation is handled by Firebase Auth automatically.
//  The name extraction and new-vs-returning user branching faithfully
//  mirrors the original logic.
//
//  SETUP NOTES:
//    • Add "Sign In with Apple" capability in Xcode → Signing & Capabilities
//    • Add AuthenticationServices.framework to linked frameworks
//    • In Firebase Console → Authentication → Sign-in method → enable Apple
//

import Foundation
import os
import Combine
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

// MARK: - Apple Sign In Service

@MainActor
final class AppleSignInService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Called after sign-in completes.
    /// Parameters: (user, isNewUser, error)
    /// isNewUser == true  → route to Onboarding  (mirrors TS redirect to /Onboarding)
    /// isNewUser == false → route to Home         (mirrors TS redirect to /)
    var onCompletion: ((User?, Bool, Error?) -> Void)?

    private let db = Firestore.firestore()
    private var currentNonce: String?

    // MARK: - Nonce Helpers
    // Required by Firebase for secure Sign in with Apple.

    private func randomNonceString(length: Int = 32) -> String? {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            Log.auth.error("SecRandomCopyBytes failed with OSStatus \(errorCode, privacy: .public)")
            return nil
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public API

    /// Build an ASAuthorizationController pre-configured for Apple sign-in.
    /// Present it from your view using `.signInWithAppleButtonStyle` or manually.
    func makeAuthorizationController() -> ASAuthorizationController? {
        guard let nonce = randomNonceString() else {
            onCompletion?(nil, false, AppleSignInError.nonceGenerationFailed)
            return nil
        }
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        // Request email + full name — Apple only sends these on the very first auth,
        // mirroring the TS comment: "Apple only sends user info on first authorization"
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        return controller
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = self.currentNonce,
                let tokenData = appleCredential.identityToken,
                let idTokenString = String(data: tokenData, encoding: .utf8)
            else {
                self.onCompletion?(nil, false, AppleSignInError.invalidCredential)
                return
            }

            // Firebase validates issuer (https://appleid.apple.com), audience, and expiry
            // — mirrors the TS JWT verification block
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            await self.handleFirebaseSignIn(credential: credential, appleCredential: appleCredential)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // User cancelled or hardware error — not a sign-in failure per se
        if (error as? ASAuthorizationError)?.code == .canceled { return }
        Task { @MainActor in
            self.onCompletion?(nil, false, error)
        }
    }
}

// MARK: - Firebase Auth Handler

extension AppleSignInService {

    private func handleFirebaseSignIn(
        credential: OAuthCredential,
        appleCredential: ASAuthorizationAppleIDCredential
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(with: credential)
            let fbUser = result.user
            let isNewUser = result.additionalUserInfo?.isNewUser ?? false

            // Extract full name — Apple only provides it on first authorization.
            // Mirrors the TS: `if (userParam) { const userData = JSON.parse(userParam); ... }`
            var fullName = fbUser.displayName ?? ""
            if let nameComponents = appleCredential.fullName {
                let formatted = PersonNameComponentsFormatter()
                    .string(from: nameComponents)
                    .trimmingCharacters(in: .whitespaces)
                if !formatted.isEmpty {
                    fullName = formatted
                    // Persist to Firebase Auth profile so it's available on future sign-ins
                    let changeRequest = fbUser.createProfileChangeRequest()
                    changeRequest.displayName = fullName
                    try await changeRequest.commitChanges()
                }
            }

            let email = fbUser.email ?? appleCredential.email ?? ""

            if isNewUser {
                // New user — mirrors the TS `base44.asServiceRole.auth.signup(...)` block
                // Fallback name mirrors: `fullName || email.split('@')[0]`
                let name = fullName.isEmpty
                    ? String(email.split(separator: "@").first ?? Substring("User"))
                    : fullName

                let newUser = User(
                    id: fbUser.uid,
                    name: name,
                    email: email,
                    familyId: nil,
                    role: nil
                )

                // Write to Firestore (consistent with FirebaseAuthService.signUp)
                try await db.collection("users").document(fbUser.uid).setData([
                    "id": fbUser.uid,
                    "name": name,
                    "email": email,
                    "createdAt": FieldValue.serverTimestamp()
                ])

                // isNewUser = true → caller routes to Onboarding
                onCompletion?(newUser, true, nil)

            } else {
                // Existing user — mirrors the TS `base44.asServiceRole.auth.createSession(...)` block
                let doc = try await db.collection("users").document(fbUser.uid).getDocument()
                if let data = doc.data() {
                    let existing = User(
                        id: fbUser.uid,
                        name: data["name"] as? String ?? fullName,
                        email: data["email"] as? String ?? email,
                        familyId: data["familyId"] as? String,
                        role: (data["role"] as? String).flatMap { MemberRole(rawValue: $0) }
                    )
                    // isNewUser = false → caller routes to Home
                    onCompletion?(existing, false, nil)
                } else {
                    // Firestore document missing — create a fallback
                    let fallback = User(id: fbUser.uid, name: fullName, email: email, familyId: nil, role: nil)
                    onCompletion?(fallback, false, nil)
                }
            }

        } catch {
            onCompletion?(nil, false, error)
        }
    }
}

// MARK: - Errors

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingEmail
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple credential. Please try again."
        case .missingEmail:
            return "No email was provided by Apple. Check your Apple ID settings and try again."
        case .nonceGenerationFailed:
            return "Unable to start Apple Sign-In securely. Please try again."
        }
    }
}

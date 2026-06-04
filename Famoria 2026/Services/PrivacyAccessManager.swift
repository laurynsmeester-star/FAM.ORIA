//
//  PrivacyAccessManager.swift
//  Famoria 2026
//
//  Pure-logic permission checks for documents, health records, and any
//  other per-member content that supports the four PrivacyLevel values.
//  Mirrors firestore.rules so the client never offers UI for an action
//  the rules will reject.
//
//  Callers pass the smallest possible context (owner uid, privacy level,
//  optional allowlist) — no AppState, no Firestore reads here.
//

import Foundation

/// Lightweight "actor" the checks evaluate against. We pass this instead
/// of plumbing User everywhere because some checks need just the role
/// + uid.
struct PermissionActor {
    let userId: String
    let role: MemberRole?
    var isAdmin: Bool { role == .admin || role == .owner }
}

enum PrivacyAccessManager {

    // MARK: - Documents

    static func canViewDocument(
        ownerUserId: String,
        privacy: PrivacyLevel,
        sharedWith: [String] = [],
        actor: PermissionActor
    ) -> Bool {
        if actor.userId == ownerUserId { return true }
        switch privacy {
        case .private:                   return false
        case .sharedWithSelectedMembers: return sharedWith.contains(actor.userId)
        case .familyVisible:             return true
        case .adminOnly:                 return actor.isAdmin
        }
    }

    static func canEditDocument(
        ownerUserId: String,
        privacy: PrivacyLevel,
        actor: PermissionActor
    ) -> Bool {
        // Only the owner edits — admins can delete (see below) but not
        // silently rewrite someone else's document.
        actor.userId == ownerUserId
    }

    static func canDeleteDocument(
        ownerUserId: String,
        privacy: PrivacyLevel,
        actor: PermissionActor
    ) -> Bool {
        // The owner can always delete; admins can also delete (e.g. to
        // remove inappropriate content). Other members cannot.
        actor.userId == ownerUserId || actor.isAdmin
    }

    // MARK: - Health records

    static func canViewHealthRecord(
        ownerUserId: String,
        privacy: PrivacyLevel,
        sharedWith: [String] = [],
        actor: PermissionActor
    ) -> Bool {
        // Health uses the same privacy ladder as documents; kept as a
        // separate entry-point so callers self-document intent and we
        // can diverge in the future (e.g. require an explicit "I am a
        // caregiver" opt-in for adminOnly).
        canViewDocument(ownerUserId: ownerUserId,
                        privacy: privacy,
                        sharedWith: sharedWith,
                        actor: actor)
    }

    static func canPrintRecord(
        ownerUserId: String,
        privacy: PrivacyLevel,
        sharedWith: [String] = [],
        actor: PermissionActor
    ) -> Bool {
        // Print = export = high-trust action. We require view permission
        // AND the actor be either the owner or an admin.
        guard canViewHealthRecord(
            ownerUserId: ownerUserId,
            privacy: privacy,
            sharedWith: sharedWith,
            actor: actor
        ) else { return false }
        return actor.userId == ownerUserId || actor.isAdmin
    }
}

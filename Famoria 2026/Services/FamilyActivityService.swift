//
//  FamilyActivityService.swift
//  Famoria 2026
//
//  Writes "activity" entries to the family posts feed when something
//  family-visible happens — a new album, an uploaded photo, an event
//  created/updated, etc. These show up in Family Updates alongside the
//  human-authored posts so anyone scanning the feed sees what the family
//  has been up to.
//
//  We store activity entries as `FamilyPost` documents with an
//  `activityKind` field set. The Family Updates card renders them with
//  a distinct system-style chrome (icon + colour, no reply/react UI).
//

import Foundation
import os
import FirebaseFirestore

enum FamilyActivityKind: String {
    case albumCreated     = "album_created"
    case photoAdded       = "photo_added"
    case eventCreated     = "event_created"
    case eventUpdated     = "event_updated"
    case journalAdded     = "journal_added"
    case recipeAdded      = "recipe_added"
    case documentAdded    = "document_added"
    case memberJoined     = "member_joined"
}

final class FamilyActivityService {
    private let db = Firestore.firestore()

    func log(
        familyId: String,
        kind: FamilyActivityKind,
        actorName: String,
        actorId: String,
        title: String,
        body: String
    ) async {
        let id = UUID().uuidString
        let data: [String: Any] = [
            "id": id,
            "authorName": actorName,
            "authorId": actorId,
            "content": "\(title)\n\(body)",
            "timestamp": Timestamp(date: Date()),
            "reactions": [],
            "replies": [],
            "activityKind": kind.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("families")
                .document(familyId)
                .collection("posts")
                .document(id)
                .setData(data)
        } catch {
            Log.appState.error("activity log failed for \(kind.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

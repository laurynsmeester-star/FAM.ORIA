//
//  FirebaseUserTasksService.swift
//  Famoria 2026
//
//  Firestore-backed persistence for the per-user "Tasks" card on the home
//  page. Previously these tasks lived in UserDefaults, which meant they
//  never synced across devices — that's fine for a single-device demo,
//  but the reviewer family needs to treat its content as real data, so we
//  store them in Firestore under each user's own subcollection.
//
//  Schema:
//    famoria_user_tasks/{userId}/tasks/{taskId} — UserTaskDoc
//

import Foundation
import os
import Combine
@preconcurrency import FirebaseFirestore

/// One personal to-do for a user. Mirrors `UserTasksCard.UserTask`.
public struct UserTaskDoc: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var title: String
    public var isDone: Bool
    public var createdAt: Date

    public init(id: String = UUID().uuidString,
                title: String,
                isDone: Bool = false,
                createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

/// Live, per-user view of the personal task list. Each instance is bound
/// to a single userId; pass a new userId via `start(userId:)` when the
/// signed-in user changes.
@MainActor
public final class UserTasksStore: ObservableObject {

    @Published public private(set) var tasks: [UserTaskDoc] = []
    @Published public var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentUserId: String?

    public init() {}

    public func start(userId: String) {
        // Re-attaching for the same user is a no-op so we don't churn
        // the listener every time the home tab redraws.
        guard userId != currentUserId else { return }

        listener?.remove()
        currentUserId = userId

        listener = collection(for: userId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Log.tasks.error("user tasks listener failed: \(error.localizedDescription, privacy: .public)")
                    Task { @MainActor in self?.errorMessage = error.localizedDescription }
                    return
                }
                guard let self, let snapshot else { return }
                self.tasks = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(UserTaskDoc.self, from: data)
                }
            }
    }

    public func stop() {
        listener?.remove()
        listener = nil
        currentUserId = nil
        tasks = []
    }

    public func add(title: String) {
        guard let uid = currentUserId else { return }
        let task = UserTaskDoc(title: title)
        do {
            try collection(for: uid).document(task.id).setData(from: task)
        } catch {
            Log.tasks.error("Failed to add task: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't save task: \(error.localizedDescription)"
        }
    }

    public func toggle(_ id: String) {
        guard let uid = currentUserId,
              let existing = tasks.first(where: { $0.id == id }) else { return }
        let newValue = !existing.isDone
        collection(for: uid).document(id).updateData(["isDone": newValue]) { [weak self] err in
            if let err {
                Log.tasks.error("Failed to toggle task: \(err.localizedDescription, privacy: .public)")
                let message = err.localizedDescription
                Task { @MainActor [weak self] in self?.errorMessage = message }
            }
        }
    }

    public func delete(_ id: String) {
        guard let uid = currentUserId else { return }
        collection(for: uid).document(id).delete { [weak self] err in
            if let err {
                Log.tasks.error("Failed to delete task: \(err.localizedDescription, privacy: .public)")
                let message = err.localizedDescription
                Task { @MainActor [weak self] in self?.errorMessage = message }
            }
        }
    }

    private func collection(for userId: String) -> CollectionReference {
        db.collection("famoria_user_tasks").document(userId).collection("tasks")
    }
}

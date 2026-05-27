//
//  AlbumStoreManager.swift
//  Famoria Update 2026
//
//  Firebase Firestore + Storage data layer for Photo Albums.
//
//  Requirements:
//    • FirebaseFirestore  (already in project)
//    • FirebaseStorage    (add to Podfile/SPM if not present:
//                          pod 'Firebase/Storage'  OR
//                          .package FirebaseStorage via SPM)
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseStorage

// MARK: - AlbumStoreManager

@MainActor
final class AlbumStoreManager: ObservableObject {

    // ── Published state ──────────────────────────────────────────────
    @Published var albums:      [FamoriaAlbum] = []
    @Published var photos:      [FamoriaPhoto] = []
    @Published var isLoading:   Bool = false
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?

    // ── Private Firebase refs ────────────────────────────────────────
    private let db      = Firestore.firestore()
    private let storage = Storage.storage()

    private var albumsListener: ListenerRegistration?
    private var photosListener: ListenerRegistration?

    // MARK: - Albums — Real-time listener

    /// Begin streaming all albums, sorted newest-first.
    func startListeningToAlbums() {
        albumsListener?.remove()
        isLoading = true

        albumsListener = db.collection("famoria_albums")
            .order(by: "created_at", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.albums = snapshot?.documents.compactMap {
                    try? $0.data(as: FamoriaAlbum.self)
                } ?? []
            }
    }

    func stopListeningToAlbums() {
        albumsListener?.remove()
        albumsListener = nil
    }

    // MARK: - Albums — CRUD

    func createAlbum(_ album: FamoriaAlbum) async throws {
        _ = try db.collection("famoria_albums").addDocument(from: album)
    }

    func updateAlbum(_ album: FamoriaAlbum) async throws {
        guard let id = album.id else { return }
        try db.collection("famoria_albums").document(id).setData(from: album, merge: true)
    }

    /// Deletes the album and all its photos from Firestore.
    func deleteAlbum(_ album: FamoriaAlbum) async throws {
        guard let id = album.id else { return }

        let snap = try await db.collection("famoria_photos")
            .whereField("album_id", isEqualTo: id)
            .getDocuments()

        for doc in snap.documents {
            try await doc.reference.delete()
        }
        try await db.collection("famoria_albums").document(id).delete()
    }

    // MARK: - Photos — Real-time listener

    /// Begin streaming photos for the given album, newest-first.
    func startListeningToPhotos(albumId: String) {
        photosListener?.remove()

        photosListener = db.collection("famoria_photos")
            .whereField("album_id", isEqualTo: albumId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.photos = (snapshot?.documents.compactMap {
                    try? $0.data(as: FamoriaPhoto.self)
                } ?? []).sorted { $0.dateTaken > $1.dateTaken }
            }
    }

    func stopListeningToPhotos() {
        photosListener?.remove()
        photosListener = nil
        photos = []
    }

    // MARK: - Photos — CRUD

    func addPhoto(_ photo: FamoriaPhoto) async throws {
        _ = try db.collection("famoria_photos").addDocument(from: photo)

        // Increment the album's photo counter
        try await db.collection("famoria_albums")
            .document(photo.albumId)
            .updateData(["photo_count": FieldValue.increment(Int64(1))])
    }

    func deletePhoto(_ photo: FamoriaPhoto) async throws {
        guard let id = photo.id else { return }
        try await db.collection("famoria_photos").document(id).delete()

        // Decrement the album's photo counter
        try? await db.collection("famoria_albums")
            .document(photo.albumId)
            .updateData(["photo_count": FieldValue.increment(Int64(-1))])
    }

    // MARK: - Image Upload (Firebase Storage)

    /// Compresses and uploads a UIImage; returns the public download URL string.
    func uploadImage(_ image: UIImage, albumId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.80) else {
            throw UploadError.compressionFailed
        }

        isUploading = true
        defer { isUploading = false }

        let filename = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("famoria_albums/\(albumId)/\(filename)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
        } catch {
            let nsErr = error as NSError
            print("[AlbumStore] putData failed: domain=\(nsErr.domain) code=\(nsErr.code) info=\(nsErr.userInfo)")
            throw UploadError.uploadFailed(underlying: nsErr)
        }

        do {
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            // "Object does not exist" after a putData that did not actually
            // throw usually means a Storage rule or App Check rejected the
            // write silently. Surface that clearly to the user.
            let nsErr = error as NSError
            print("[AlbumStore] downloadURL failed: domain=\(nsErr.domain) code=\(nsErr.code) info=\(nsErr.userInfo)")
            throw UploadError.objectMissing(underlying: nsErr)
        }
    }

    enum UploadError: LocalizedError {
        case compressionFailed
        case uploadFailed(underlying: NSError)
        case objectMissing(underlying: NSError)

        var errorDescription: String? {
            switch self {
            case .compressionFailed:
                return "Could not compress image for upload."
            case .uploadFailed(let err):
                return "Upload failed: \(err.localizedDescription). Check Firebase Storage rules and your network connection."
            case .objectMissing:
                return "Upload was rejected by Firebase Storage. This usually means the Storage security rules don't allow writes to famoria_albums/, or App Check is blocking the request. Update your Storage rules in the Firebase Console."
            }
        }
    }
}


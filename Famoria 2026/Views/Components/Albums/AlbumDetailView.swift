//
//  AlbumDetailView.swift
//  Famoria Update 2026
//
//  Shows a single album's photo grid.
//  Tapping a photo starts the slideshow at that index.
//  Includes Add Photos (multi-pick), Edit Album, and delete photo support.
//

import SwiftUI
import PhotosUI

// MARK: - AlbumDetailView

@MainActor
struct AlbumDetailView: View {

    let album: FamoriaAlbum
    @ObservedObject var store: AlbumStoreManager
    @EnvironmentObject var appState: AppState

    // Local copies for editing
    @State private var currentAlbum: FamoriaAlbum

    // Sheet / overlay state
    @State private var showEditAlbum      = false
    @State private var showAddPhotos      = false
    @State private var showSlideshow      = false
    @State private var slideshowStartIdx  = 0
    @State private var photoToDelete: FamoriaPhoto? = nil
    @State private var showDeleteConfirm  = false

    // Photo picker items
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var captionDraft = ""
    @State private var dateTakenDraft = Date()
    @State private var uploadError: String? = nil
    @State private var isUploading = false

    @Environment(\.dismiss) private var dismiss

    init(album: FamoriaAlbum, store: AlbumStoreManager) {
        self.album = album
        self.store = store
        _currentAlbum = State(initialValue: album)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                photoGridView
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(currentAlbum.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    Button { showEditAlbum = true } label: {
                        Image(systemName: "pencil")
                    }
                    if !store.photos.isEmpty {
                        Button {
                            slideshowStartIdx = 0
                            showSlideshow = true
                        } label: {
                            Image(systemName: "play.fill")
                        }
                    }
                }
            }
        }
        .onAppear { store.startListeningToPhotos(albumId: album.id ?? "") }
        .onDisappear { store.stopListeningToPhotos() }
        // Edit album sheet
        .sheet(isPresented: $showEditAlbum) {
            AlbumFormView(store: store, existingAlbum: currentAlbum) { updated in
                currentAlbum = updated
            }
        }
        // Add photos sheet
        .sheet(isPresented: $showAddPhotos) {
            addPhotosSheet
        }
        // Slideshow full-screen
        .fullScreenCover(isPresented: $showSlideshow) {
            PhotoSlideshowView(
                photos: store.photos,
                startIndex: slideshowStartIdx,
                isPresented: $showSlideshow
            )
        }
        // Delete photo confirmation
        .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = photoToDelete {
                    Task { try? await store.deletePhoto(p) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Upload Error", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK") { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {

                if let date = currentAlbum.date {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(date, style: .date)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }

                if !currentAlbum.albumDescription.isEmpty {
                    Text(currentAlbum.albumDescription)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(.top, 4)
                }
            }

            // Add Photos button
            Button { showAddPhotos = true } label: {
                Label("Add Photos", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(LinearGradient.famoriaPrimary)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Photo Grid

    @ViewBuilder
    private var photoGridView: some View {
        if store.photos.isEmpty {
            emptyPhotosState
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(store.photos.enumerated()), id: \.element.id) { idx, photo in
                    PhotoThumbnailCell(photo: photo)
                        .onTapGesture {
                            slideshowStartIdx = idx
                            showSlideshow = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                photoToDelete = photo
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Photo", systemImage: "trash")
                            }
                        }
                }
            }
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.06), radius: 6)
        }
    }

    private var emptyPhotosState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.92, blue: 0.94),
                                Color(red: 0.95, green: 0.91, blue: 0.99)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(LinearGradient.famoriaPrimary)
            }

            VStack(spacing: 6) {
                Text("No photos yet")
                    .font(.title3.weight(.semibold))
                Text("Start adding photos to this album")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button { showAddPhotos = true } label: {
                Label("Add First Photos", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(LinearGradient.famoriaPrimary)
                    .cornerRadius(14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }

    // MARK: - Add Photos Sheet

    private var addPhotosSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Caption
                VStack(alignment: .leading, spacing: 6) {
                    Text("Caption (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    TextField("Add a memory…", text: $captionDraft)
                        .textFieldStyle(.roundedBorder)
                }

                // Date taken
                VStack(alignment: .leading, spacing: 6) {
                    Text("Date Taken")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $dateTakenDraft, displayedComponents: .date)
                        .labelsHidden()
                }

                // Photo picker
                let uploading = isUploading || store.isUploading
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 30,
                    matching: .images
                ) {
                    VStack(spacing: 10) {
                        if uploading {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text("Uploading…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 44))
                                .foregroundStyle(LinearGradient.famoriaPrimary)
                            Text("Tap to select photos")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.label))
                            Text("You can pick multiple at once")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient.famoriaPrimary,
                                style: StrokeStyle(lineWidth: 2, dash: [6])
                            )
                    )
                }
                .disabled(uploading)
                .onChange(of: pickerItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    uploadPickedPhotos(newItems)
                }

                if let err = uploadError {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showAddPhotos = false }
                }
            }
        }
    }

    // MARK: - Upload Helpers

    private func uploadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard let albumId = album.id else { return }

        Task {
            isUploading = true
            uploadError = nil
            var firstError: String?

            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }

                do {
                    let url = try await store.uploadImage(image, albumId: albumId)
                    let photo = FamoriaPhoto(
                        albumId: albumId,
                        imageURL: url,
                        caption: captionDraft,
                        dateTaken: dateTakenDraft
                    )
                    try await store.addPhoto(photo)
                    if let familyId = appState.currentFamily?.id,
                       let user = appState.currentUser {
                        await appState.activityService.log(
                            familyId: familyId,
                            kind: .photoAdded,
                            actorName: user.name,
                            actorId: user.id,
                            title: "Added a photo to \(currentAlbum.title)",
                            body: captionDraft.isEmpty ? "Tap to view." : captionDraft
                        )
                    }
                } catch {
                    if firstError == nil { firstError = error.localizedDescription }
                }
            }

            pickerItems = []
            captionDraft = ""
            dateTakenDraft = Date()
            isUploading = false

            if let firstError {
                // Keep sheet open so the error is visible inline; don't trigger
                // a sheet-dismissal + alert-presentation race.
                uploadError = firstError
            } else {
                showAddPhotos = false
            }
        }
    }
}

// MARK: - PhotoThumbnailCell

struct PhotoThumbnailCell: View {
    let photo: FamoriaPhoto

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: photo.imageURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Color(UIColor.systemFill)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    default:
                        Color(UIColor.systemFill)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

                // Caption overlay on hover / long-press handled via contextMenu
                if !photo.caption.isEmpty {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    Text(photo.caption)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

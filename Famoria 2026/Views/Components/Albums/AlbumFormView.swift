//
//  AlbumFormView.swift
//  Famoria Update 2026
//
//  Sheet for creating a new album or editing an existing one.
//  Fields: Title, Category (picker), Date, Cover Photo, Description.
//
//  Mirrors AlbumFormDialog.jsx from the web reference.
//

import SwiftUI
import PhotosUI

// MARK: - AlbumFormView

struct AlbumFormView: View {

    @ObservedObject var store: AlbumStoreManager
    @EnvironmentObject var appState: AppState
    var existingAlbum: FamoriaAlbum?
    /// Called with the saved album on successful update (edit mode only)
    var onSaved: ((FamoriaAlbum) -> Void)?

    // Form state
    @State private var title       = ""
    @State private var category    = AlbumCategory.event
    @State private var date        = Date()
    @State private var hasDate     = false
    @State private var description = ""
    @State private var coverURL: String? = nil

    // Cover photo picker
    @State private var coverPickerItem: PhotosPickerItem? = nil
    @State private var coverUIImage: UIImage?   = nil

    // Async state
    @State private var isSaving    = false
    @State private var errorMsg: String? = nil

    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { existingAlbum != nil }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    titleField
                    categoryPicker
                    datePicker
                    coverPhotoPicker
                    descriptionField
                    Spacer(minLength: 20)
                    actionButtons
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Album" : "New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: populateIfEditing)
            // React to cover picker selection
            .onChange(of: coverPickerItem) { _, item in
                loadCoverImage(from: item)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Fields

    private var titleField: some View {
        FormSection(label: "Album Title") {
            TextField("e.g. Christmas 2025", text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var categoryPicker: some View {
        FormSection(label: "Category") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AlbumCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.25)) { category = cat }
                        } label: {
                            Text(cat.displayName)
                                .font(.subheadline.weight(category == cat ? .semibold : .regular))
                                .foregroundColor(category == cat ? .white : Color(UIColor.label))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    category == cat
                                        ? AnyView(LinearGradient.famoriaPrimary)
                                        : AnyView(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var datePicker: some View {
        FormSection(label: "Date") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasDate) {
                    Text("Include a date")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.label))
                }
                .tint(.famoriaRose)

                if hasDate {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: hasDate)
        }
    }

    private var coverPhotoPicker: some View {
        FormSection(label: "Cover Photo") {
            if let img = coverUIImage {
                // Preview selected image
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)

                    PhotosPicker(selection: $coverPickerItem, matching: .images) {
                        Text("Change")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(8)
                            .padding(10)
                    }
                }
            } else if let urlStr = coverURL, let url = URL(string: urlStr) {
                // Preview existing URL (edit mode)
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Color(UIColor.systemFill)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(12)

                    PhotosPicker(selection: $coverPickerItem, matching: .images) {
                        Text("Change")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(8)
                            .padding(10)
                    }
                }
            } else {
                // Empty picker trigger
                PhotosPicker(selection: $coverPickerItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(LinearGradient.famoriaPrimary)
                        Text("Tap to add a cover photo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient.famoriaPrimary,
                                style: StrokeStyle(lineWidth: 2, dash: [6])
                            )
                    )
                }
            }
        }
    }

    private var descriptionField: some View {
        FormSection(label: "Story / Description") {
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("What's the story behind this album?")
                        .foregroundColor(Color(UIColor.placeholderText))
                        .font(.body)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $description)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(UIColor.separator), lineWidth: 0.5))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let err = errorMsg {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: saveAlbum) {
                Group {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text(isEditing ? "Save Changes" : "Create Album")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    title.trimmingCharacters(in: .whitespaces).isEmpty
                        ? AnyView(Color.gray.opacity(0.4))
                        : AnyView(LinearGradient.famoriaPrimary)
                )
                .cornerRadius(16)
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let a = existingAlbum else { return }
        title       = a.title
        category    = a.category
        description = a.albumDescription
        coverURL    = a.coverImageURL
        if let d = a.date { date = d; hasDate = true }
    }

    private func loadCoverImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img  = UIImage(data: data) {
                await MainActor.run { coverUIImage = img }
            }
        }
    }

    private func saveAlbum() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true
        errorMsg = nil

        Task {
            do {
                var finalCoverURL = coverURL
                if let img = coverUIImage {
                    let albumId = existingAlbum?.id ?? UUID().uuidString
                    do {
                        finalCoverURL = try await store.uploadImage(img, albumId: albumId)
                    } catch {
                        // Cover upload failed — save locally and continue without remote URL
                        if let jpeg = img.jpegData(compressionQuality: 0.85) {
                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let localFile = docs.appendingPathComponent("album_cover_\(albumId).jpg")
                            try? jpeg.write(to: localFile, options: .atomic)
                            finalCoverURL = localFile.absoluteString
                        }
                    }
                }

                var album = FamoriaAlbum(
                    id: existingAlbum?.id,
                    title: trimmedTitle,
                    category: category,
                    date: hasDate ? date : nil,
                    description: description,
                    coverImageURL: finalCoverURL
                )
                album.photoCount = existingAlbum?.photoCount ?? 0

                if isEditing {
                    try await store.updateAlbum(album)
                    onSaved?(album)
                } else {
                    try await store.createAlbum(album)
                    if let familyId = appState.currentFamily?.id,
                       let user = appState.currentUser {
                        await appState.activityService.log(
                            familyId: familyId,
                            kind: .albumCreated,
                            actorName: user.name,
                            actorId: user.id,
                            title: "Created album: \(album.title)",
                            body: album.category.displayName
                        )
                    }
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - FormSection

/// Reusable labeled section wrapper for form fields
struct FormSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            content
        }
    }
}

//
//  DocumentsView.swift
//  Famoria 2026
//
//  Replaces the previous DocumentsView.swift.
//
//  Adds:
//   • Import via UIDocumentPicker (any file) and PhotosPicker (images)
//   • Export via ShareLink
//   • Search + category filter + sort/group menu
//   • Privacy controls per document (private / admins / family / specific)
//   • Visibility-aware list (only shows what the viewer can see)
//   • Comments thread with resolve toggle
//   • Link to a FamilyEventV2 for collaboration
//   • One-tap "AI organize" suggestion (title / category / tags) on import
//
//  IMPORTANT: delete the inline `FamilyDocument` struct from your old file —
//  the canonical type now lives in MoreModels.swift.
//

import SwiftUI
import os
import UIKit
import UniformTypeIdentifiers
import PhotosUI
import QuickLook
import FirebaseStorage

// MARK: - DocumentsView

struct DocumentsView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var store = DocumentsStore()
    private let assistant: AIImportAssistant = HeuristicAIImportAssistant()

    // UI state
    @State private var showAddDocument = false
    @State private var selectedDocument: FamilyDocument? = nil
    @State private var categoryFilter: DocumentCategory? = nil
    @State private var sortMode: SortMode = .newest
    @State private var groupMode: GroupMode = .none

    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "Newest", oldest = "Oldest", titleAZ = "Title A–Z", typeAZ = "Type"
        var id: String { rawValue }
    }
    enum GroupMode: String, CaseIterable, Identifiable {
        case none = "No grouping", category = "By category", uploader = "By uploader", linkedEvent = "By linked event"
        var id: String { rawValue }
    }

    private var currentUserName: String { appState.currentUser?.name ?? "Unknown" }
    private var isAdmin: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role == .admin || role == .owner
    }

    private var eventsV2: [FamilyEventV2] {
        appState.events.map {
            FamilyEventV2(
                id: $0.id,
                title: $0.title,
                date: $0.date,
                endDate: $0.endDate,
                startTime: $0.startTime,
                endTime: $0.endTime,
                location: $0.location,
                notes: $0.notes,
                eventType: $0.eventTypeRaw.flatMap(EventType.init(rawValue:)) ?? .other,
                isRecurring: $0.isRecurring ?? false,
                createdBy: $0.createdBy
            )
        }
    }

    // MARK: View

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Family Documents")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $sortMode) {
                                ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                            }
                            Picker("Group", selection: $groupMode) {
                                ForEach(GroupMode.allCases) { Text($0.rawValue).tag($0) }
                            }
                            Divider()
                            Button {
                                showAddDocument = true
                            } label: {
                                Label("Upload Document", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showAddDocument) {
                    AddDocumentSheet(store: store, assistant: assistant,
                                     uploader: currentUserName,
                                     family: nil)
                }
                .sheet(item: $selectedDocument) { doc in
                    DocumentDetailSheet(
                        store: store, document: doc,
                        currentUser: currentUserName, isAdmin: isAdmin,
                        family: nil,
                        events: eventsV2
                    )
                }
                .onAppear { store.startListening() }
                .onDisappear { store.stopListening() }
                .alert(
                    "Couldn't save",
                    isPresented: Binding(
                        get: { store.errorMessage != nil },
                        set: { if !$0 { store.errorMessage = nil } }
                    ),
                    presenting: store.errorMessage
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let visible = visibleDocuments
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                categoryChipBar
                if visible.isEmpty {
                    emptyState
                } else {
                    groupedList(visible)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showAddDocument = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.purple)
                    .clipShape(Circle())
                    .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
    }

    private var categoryChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", systemImage: "tray.full",
                     active: categoryFilter == nil, color: .purple) {
                    categoryFilter = nil
                }
                ForEach(DocumentCategory.allCases) { cat in
                    Chip(title: cat.displayName, systemImage: cat.systemImage,
                         active: categoryFilter == cat, color: cat.color) {
                        categoryFilter = (categoryFilter == cat) ? nil : cat
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(store.documents.isEmpty ? "No documents yet" : "Nothing matches your filters")
                .font(.headline)
            if store.documents.isEmpty {
                Text("Upload contracts, photos, recipes — tag and share them with your family.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button { showAddDocument = true } label: {
                    Label("Upload Document", systemImage: "square.and.arrow.up")
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    @ViewBuilder
    private func groupedList(_ docs: [FamilyDocument]) -> some View {
        switch groupMode {
        case .none:
            LazyVStack(spacing: 10) {
                ForEach(docs) { doc in row(doc) }
            }
        case .category:
            ForEach(DocumentCategory.allCases) { cat in
                let bucket = docs.filter { $0.category == cat }
                if !bucket.isEmpty { sectionHeader(cat.displayName) ; LazyVStack(spacing: 10) { ForEach(bucket) { row($0) } } }
            }
        case .uploader:
            let uploaders = Array(Set(docs.map(\.uploadedBy))).sorted()
            ForEach(uploaders, id: \.self) { name in
                let bucket = docs.filter { $0.uploadedBy == name }
                sectionHeader(name)
                LazyVStack(spacing: 10) { ForEach(bucket) { row($0) } }
            }
        case .linkedEvent:
            let linked = docs.filter { $0.linkedEventId != nil }
            let unlinked = docs.filter { $0.linkedEventId == nil }
            if !linked.isEmpty {
                sectionHeader("Linked to events")
                LazyVStack(spacing: 10) { ForEach(linked) { row($0) } }
            }
            if !unlinked.isEmpty {
                sectionHeader("Unlinked")
                LazyVStack(spacing: 10) { ForEach(unlinked) { row($0) } }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    private func row(_ doc: FamilyDocument) -> some View {
        DocumentRow(
            document: doc,
            commentCount: store.comments(for: doc.id).count,
            linkedEventTitle: linkedEventTitle(for: doc),
            onTap: { selectedDocument = doc }
        )
    }

    // MARK: Filtering / sorting

    private var visibleDocuments: [FamilyDocument] {
        var docs = store.documents.filter { $0.canBeViewed(by: currentUserName, isAdmin: isAdmin) }
        if let cat = categoryFilter { docs = docs.filter { $0.category == cat } }
        switch sortMode {
        case .newest:  docs.sort { $0.createdDate > $1.createdDate }
        case .oldest:  docs.sort { $0.createdDate < $1.createdDate }
        case .titleAZ: docs.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .typeAZ:  docs.sort { $0.fileType.rawValue < $1.fileType.rawValue }
        }
        return docs
    }

    private func linkedEventTitle(for doc: FamilyDocument) -> String? {
        guard let id = doc.linkedEventId else { return nil }
        return eventsV2.first(where: { $0.id == id })?.title
    }
}

// MARK: - Row

private struct DocumentRow: View {
    let document: FamilyDocument
    let commentCount: Int
    let linkedEventTitle: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(document.category.emoji).font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(document.category.color.opacity(0.12))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        miniBadge(document.category.displayName, color: document.category.color)
                        miniBadge(document.fileType.rawValue.uppercased(), color: .secondary)
                        if commentCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left.fill").font(.system(size: 9))
                                Text("\(commentCount)").font(.caption2)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                            .foregroundColor(.purple)
                        }
                        Image(systemName: document.visibility.systemImage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let event = linkedEventTitle {
                        Label(event, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    Text("By \(document.uploadedBy) • \(document.createdDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func miniBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }
}

// MARK: - Chip

private struct Chip: View {
    let title: String
    let systemImage: String
    let active: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(title).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule().fill(active ? color.opacity(0.18) : Color(.secondarySystemBackground))
            )
            .foregroundColor(active ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Document Sheet

private struct AddDocumentSheet: View {
    @ObservedObject var store: DocumentsStore
    let assistant: AIImportAssistant
    let uploader: String
    let family: Family?

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var category: DocumentCategory = .other
    @State private var visibility: DocumentVisibility = .family
    @State private var allowedMembers: Set<String> = []
    @State private var tags: [String] = []
    @State private var newTag = ""

    @State private var pickedURL: URL? = nil
    @State private var pickedFilename: String? = nil
    @State private var pickedFileType: DocumentFileType = .other
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var showFileImporter = false
    @State private var aiSuggestion: DocumentSuggestion? = nil
    @State private var isOrganizing = false
    @State private var isUploading = false
    @State private var uploadError: String? = nil

    private var familyMembers: [String] {
        family?.members.map(\.name) ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("File") {
                    pickerButtons
                    if let f = pickedFilename {
                        Label(f, systemImage: pickedFileType.systemImage)
                            .font(.footnote).foregroundColor(.secondary)
                    } else if photoData != nil {
                        Label("Photo selected", systemImage: "photo.fill")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    if isOrganizing {
                        ProgressView("Organizing with AI…").font(.caption)
                    } else if pickedFilename != nil || photoData != nil {
                        Button {
                            Task { await runAIOrganize() }
                        } label: {
                            Label("Organize with AI", systemImage: "sparkles")
                        }
                    }
                    if let suggestion = aiSuggestion {
                        suggestionBlock(suggestion)
                    }
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(DocumentCategory.allCases) { c in
                            Label(c.displayName, systemImage: c.systemImage).tag(c)
                        }
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Tags") {
                    HStack {
                        TextField("Add tag", text: $newTag)
                        Button {
                            let t = newTag.trimmingCharacters(in: .whitespaces).lowercased()
                            guard !t.isEmpty, !tags.contains(t) else { return }
                            tags.append(t); newTag = ""
                        } label: { Image(systemName: "plus.circle.fill") }
                    }
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { t in
                                    HStack(spacing: 4) {
                                        Text("#\(t)").font(.caption)
                                        Button { tags.removeAll { $0 == t } } label: {
                                            Image(systemName: "xmark.circle.fill").font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.purple.opacity(0.15)))
                                    .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }

                Section("Privacy") {
                    Picker("Who can see this?", selection: $visibility) {
                        ForEach(DocumentVisibility.allCases) { v in
                            Label(v.displayName, systemImage: v.systemImage).tag(v)
                        }
                    }
                    if visibility == .specific {
                        ForEach(familyMembers, id: \.self) { name in
                            Toggle(name, isOn: Binding(
                                get: { allowedMembers.contains(name) },
                                set: { on in if on { allowedMembers.insert(name) } else { allowedMembers.remove(name) } }
                            ))
                        }
                    }
                }
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isUploading {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Uploading…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isUploading || title.trimmingCharacters(in: .whitespaces).isEmpty || (pickedURL == nil && photoData == nil))
                }
            }
            .alert(
                "Upload failed",
                isPresented: Binding(
                    get: { uploadError != nil },
                    set: { if !$0 { uploadError = nil } }
                ),
                presenting: uploadError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                handleFileImport(result)
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photoData = data
                        pickedFilename = "Photo.jpg"
                        pickedFileType = .image
                        if title.isEmpty { title = "Photo \(Date().formatted(date: .abbreviated, time: .omitted))" }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pickerButtons: some View {
        HStack {
            Button {
                showFileImporter = true
            } label: {
                Label("Choose File", systemImage: "folder.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Photo", systemImage: "photo.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func suggestionBlock(_ s: DocumentSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI suggestion", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundColor(.purple)
            Text("Title: \(s.title)").font(.caption)
            Text("Category: \(s.category.displayName)").font(.caption)
            if !s.tags.isEmpty {
                Text("Tags: \(s.tags.map { "#\($0)" }.joined(separator: " "))").font(.caption)
            }
            HStack {
                Button("Apply") {
                    if title.isEmpty { title = s.title }
                    category = s.category
                    for t in s.tags where !tags.contains(t) { tags.append(t) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)
                Button("Dismiss") { aiSuggestion = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.07)))
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let src = urls.first else { return }
            // Copy into app's Documents directory so it persists.
            let didStartAccess = src.startAccessingSecurityScopedResource()
            defer { if didStartAccess { src.stopAccessingSecurityScopedResource() } }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dest = docs.appendingPathComponent(UUID().uuidString + "_" + src.lastPathComponent)
            try? FileManager.default.copyItem(at: src, to: dest)

            pickedURL = dest
            pickedFilename = src.lastPathComponent
            pickedFileType = DocumentFileType.detect(from: src)
            if title.isEmpty {
                title = (src.lastPathComponent as NSString).deletingPathExtension
            }
        case .failure:
            break
        }
    }

    private func runAIOrganize() async {
        isOrganizing = true
        defer { isOrganizing = false }
        let filename = pickedFilename ?? "untitled"
        aiSuggestion = await assistant.organizeDocument(
            filename: filename,
            fileType: pickedFileType,
            textSnippet: notes.isEmpty ? nil : notes
        )
    }

    @MainActor
    private func save() async {
        // 1. Resolve the bytes to upload + the local cache filename.
        var fileURL: URL? = pickedURL
        var localFilename: String? = pickedURL?.lastPathComponent
        let bytes: Data
        let contentType: String

        if let url = pickedURL {
            // Picked from Files. Read the bytes we already copied into the
            // app's Documents directory (see handleFileImport).
            do {
                bytes = try Data(contentsOf: url)
            } catch {
                uploadError = "Couldn't read selected file: \(error.localizedDescription)"
                return
            }
            contentType = pickedFileType.mimeType
        } else if let data = photoData {
            // Picked from PhotosPicker. Also cache to disk for fast local preview.
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let local = docs.appendingPathComponent(UUID().uuidString + ".jpg")
            try? data.write(to: local)
            fileURL = local
            localFilename = local.lastPathComponent
            bytes = data
            contentType = "image/jpeg"
        } else {
            uploadError = "No file selected."
            return
        }

        // 2. Upload to Firebase Storage so other family members can open it.
        let docId = UUID().uuidString
        let filename = pickedFilename ?? localFilename ?? "\(docId).bin"
        let ref = Storage.storage().reference()
            .child("famoria_documents/\(docId)/\(filename)")
        let metadata = StorageMetadata()
        metadata.contentType = contentType

        isUploading = true
        let remoteURLString: String
        do {
            _ = try await ref.putDataAsync(bytes, metadata: metadata)
            let url = try await ref.downloadURL()
            remoteURLString = url.absoluteString
        } catch {
            Log.app.error("Document upload failed: \(error.localizedDescription, privacy: .public)")
            uploadError = "Upload failed: \(error.localizedDescription). Check Firebase Storage rules and your network connection."
            isUploading = false
            return
        }
        isUploading = false

        // 3. Write the Firestore metadata document (with the remote URL so
        //    other devices can download the file).
        let doc = FamilyDocument(
            id: docId,
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes,
            fileURL: fileURL,
            localFilename: localFilename,
            remoteURL: remoteURLString,
            fileType: pickedFileType,
            category: category,
            tags: tags,
            uploadedBy: uploader,
            visibility: visibility,
            allowedMembers: visibility == .specific ? Array(allowedMembers) : []
        )
        store.add(doc)
        dismiss()
    }
}

// MARK: - Detail Sheet

private struct DocumentDetailSheet: View {
    @ObservedObject var store: DocumentsStore
    let document: FamilyDocument
    let currentUser: String
    let isAdmin: Bool
    let family: Family?
    let events: [FamilyEventV2]

    @Environment(\.dismiss) private var dismiss
    @State private var newComment: String = ""
    @State private var workingDoc: FamilyDocument
    @State private var showLinkPicker = false
    @State private var showPreview = false
    @State private var previewURL: URL? = nil
    @State private var isFetching = false
    @State private var fetchError: String? = nil

    init(store: DocumentsStore, document: FamilyDocument,
         currentUser: String, isAdmin: Bool, family: Family?,
         events: [FamilyEventV2]) {
        self.store = store
        self.document = document
        self.currentUser = currentUser
        self.isAdmin = isAdmin
        self.family = family
        self.events = events
        _workingDoc = State(initialValue: document)
    }

    /// Returns a local file URL that QuickLook / ShareLink can open. If the
    /// file is already on disk we use it directly; otherwise we download it
    /// from Firebase Storage to a temp file and cache it for the session.
    @MainActor
    private func resolveLocalURL() async -> URL? {
        if let local = workingDoc.fileURL, FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        // If we stored a localFilename when uploading on THIS device, try
        // resolving it against the current Documents directory (the absolute
        // path stored in fileURL may have been from a previous launch).
        if let name = workingDoc.localFilename {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let candidate = docs.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        guard let remote = workingDoc.remoteURL, let url = URL(string: remote) else {
            fetchError = "This document has no downloadable file."
            return nil
        }

        isFetching = true
        defer { isFetching = false }
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            // Move to a named temp file so QuickLook shows the right name.
            let suggestedName = workingDoc.localFilename ?? url.lastPathComponent
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString)-\(suggestedName)")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            return dest
        } catch {
            Log.app.error("Document download failed: \(error.localizedDescription, privacy: .public)")
            fetchError = "Couldn't download document: \(error.localizedDescription)"
            return nil
        }
    }

    private func openPreview() {
        Task {
            if let url = await resolveLocalURL() {
                previewURL = url
                showPreview = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metadataCard
                    actionRow
                    eventLinkSection
                    commentsSection
                }
                .padding()
            }
            .navigationTitle(workingDoc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            openPreview()
                        } label: {
                            Label("Preview", systemImage: "eye.fill")
                        }
                        Divider()
                        Button(role: .destructive) {
                            store.remove(workingDoc.id); dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                if let url = previewURL {
                    QuickLookPreview(url: url)
                }
            }
            .overlay {
                if isFetching {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Downloading…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert(
                "Couldn't open",
                isPresented: Binding(
                    get: { fetchError != nil },
                    set: { if !$0 { fetchError = nil } }
                ),
                presenting: fetchError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: pieces

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workingDoc.category.emoji).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 4) {
                    Text(workingDoc.title).font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        miniBadge(workingDoc.category.displayName, color: workingDoc.category.color)
                        miniBadge(workingDoc.fileType.rawValue.uppercased(), color: .secondary)
                        Label(workingDoc.visibility.displayName, systemImage: workingDoc.visibility.systemImage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !workingDoc.notes.isEmpty {
                Text(workingDoc.notes).font(.subheadline).foregroundColor(.secondary)
            }
            if !workingDoc.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workingDoc.tags, id: \.self) { t in
                            Text("#\(t)")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.purple.opacity(0.15)))
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            Text("Uploaded by \(workingDoc.uploadedBy) on \(workingDoc.createdDate.formatted(date: .long, time: .omitted))")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private var actionRow: some View {
        HStack {
            // The file may not be on this device yet — Open downloads from
            // Firebase Storage on demand, then hands the local URL to
            // QuickLook (which has its own Share button in the toolbar).
            Button {
                openPreview()
            } label: {
                Label(workingDoc.remoteURL == nil ? "Open" : "Open", systemImage: "doc.viewfinder.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(isFetching || (workingDoc.remoteURL == nil && workingDoc.fileURL == nil))
        }
    }

    private var eventLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Linked event", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
            if let id = workingDoc.linkedEventId, let ev = events.first(where: { $0.id == id }) {
                HStack {
                    Image(systemName: ev.eventType.icon).foregroundColor(ev.eventType.colors.fill)
                    Text(ev.title).font(.subheadline)
                    Spacer()
                    Button {
                        workingDoc.linkedEventId = nil
                        store.update(workingDoc)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))
            } else {
                Button {
                    showLinkPicker = true
                } label: {
                    Label("Link to an event…", systemImage: "link.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showLinkPicker) {
            EventLinkPicker(events: events) { picked in
                workingDoc.linkedEventId = picked.id
                store.update(workingDoc)
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Comments (\(store.comments(for: workingDoc.id).count))",
                  systemImage: "bubble.left.and.bubble.right.fill")
                .font(.subheadline.weight(.semibold))

            ForEach(store.comments(for: workingDoc.id)) { c in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(c.authorName).font(.caption.weight(.semibold))
                        Text(c.createdDate, format: .dateTime.month().day().hour().minute())
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Button { store.toggleResolve(c.id) } label: {
                            Image(systemName: c.isResolved ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(c.isResolved ? .green : .secondary)
                        }
                    }
                    Text(c.content).font(.subheadline)
                        .foregroundColor(c.isResolved ? .secondary : .primary)
                        .strikethrough(c.isResolved)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
            }

            HStack {
                TextField("Add a comment…", text: $newComment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Button {
                    let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addComment(DocumentComment(
                        documentId: workingDoc.id,
                        authorName: currentUser,
                        content: trimmed
                    ))
                    newComment = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.purple))
                }
            }
        }
    }

    private func miniBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }
}

// MARK: - Event link picker

private struct EventLinkPicker: View {
    let events: [FamilyEventV2]
    let onPick: (FamilyEventV2) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [FamilyEventV2] {
        guard !query.isEmpty else { return events }
        return events.filter { $0.title.lowercased().contains(query.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { ev in
                Button {
                    onPick(ev); dismiss()
                } label: {
                    HStack {
                        Image(systemName: ev.eventType.icon).foregroundColor(ev.eventType.colors.fill)
                        VStack(alignment: .leading) {
                            Text(ev.title).font(.subheadline.weight(.medium))
                            Text(ev.date, format: .dateTime.month().day().year())
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Find event")
            .navigationTitle("Link to Event")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - QuickLook wrapper

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}


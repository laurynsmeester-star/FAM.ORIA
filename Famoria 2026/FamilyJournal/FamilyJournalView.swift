import SwiftUI
import os
import FirebaseFirestore

// MARK: - Family Journal (Tabbed Container)
//
// Top-level view for the Family Journal feature.
// Hosts two segments: "Journal" (the original entries view) and "Wishlists"
// (gift-giving lists per family member with surprise mode and claims).
//
// The original journal content has been preserved intact and lives under
// the .journal segment so existing functionality stays untouched.

struct FamilyJournalView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSegment: FamilyJournalSegment = .journal

    enum FamilyJournalSegment: String, CaseIterable, Identifiable {
        case journal   = "Journal"
        case wishlists = "Wishlists"
        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .journal:   return "book.fill"
            case .wishlists: return "gift.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            segmentBar
            Divider().opacity(0.4)
            ZStack {
                switch selectedSegment {
                case .journal:
                    JournalEntriesTab()
                case .wishlists:
                    wishlistsTab
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Segment bar

    private var segmentBar: some View {
        HStack(spacing: 0) {
            ForEach(FamilyJournalSegment.allCases) { seg in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedSegment = seg }
                } label: {
                    VStack(spacing: 6) {
                        Label(seg.rawValue, systemImage: seg.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedSegment == seg ? .primary : .secondary)
                        Capsule()
                            .fill(selectedSegment == seg
                                  ? AnyShapeStyle(LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.clear))
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 0)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Wishlists tab

    @ViewBuilder
    private var wishlistsTab: some View {
        if let family = appState.currentFamily, let user = appState.currentUser {
            WishlistView(viewModel: WishlistViewModel(
                familyId: family.id,
                currentUserId: user.id,
                currentUserName: user.name,
                currentUserRole: user.role,
                familyMembers: family.members
            ))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Join a family to use wishlists")
                    .font(.headline)
                Text("Wishlists are shared with your family members.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Journal Entries (original behavior, preserved)

private struct JournalEntriesTab: View {
    @EnvironmentObject var appState: AppState
    @State private var entries: [FamilyJournalEntry] = []
    @State private var showNewEntry = false
    @State private var editingEntry: FamilyJournalEntry? = nil
    @State private var showDeleteConfirm = false
    @State private var deleteTargetId: String? = nil
    @State private var listener: ListenerRegistration?

    private let db = Firestore.firestore()

    private func startListening() {
        listener?.remove()
        listener = db.collection("famoria_journal_entries")
            .order(by: "createdDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Log.journal.error("FamilyJournalView listener failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let snapshot else { return }
                entries = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(FamilyJournalEntry.self, from: data)
                }
            }
    }

    private func saveEntry(_ entry: FamilyJournalEntry) {
        do {
            try db.collection("famoria_journal_entries").document(entry.id).setData(from: entry)
        } catch {
            Log.journal.error("Failed to save journal entry: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteEntry(_ id: String) {
        db.collection("famoria_journal_entries").document(id).delete()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Family Journal")
                            .font(.title3).fontWeight(.semibold)
                        Text("Capture memories, milestones, and everyday moments.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button {
                            showNewEntry = true
                        } label: {
                            Label("Write First Entry", systemImage: "pencil.line")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.purple)
                                .cornerRadius(20)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(entries) { entry in
                            FamilyJournalEntryCard(
                                entry: entry,
                                onEdit: { editingEntry = entry },
                                onDelete: {
                                    deleteTargetId = entry.id
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
        .overlay(alignment: .bottomTrailing) {
            if !entries.isEmpty {
                Button {
                    showNewEntry = true
                } label: {
                    Image(systemName: "pencil.line")
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
        .onAppear { startListening() }
        .onDisappear { listener?.remove(); listener = nil }
        .sheet(isPresented: $showNewEntry) {
            NewFamilyJournalEntrySheet(onSave: saveEntry, authorName: appState.currentUser?.name ?? "Unknown")
        }
        .sheet(item: $editingEntry) { entry in
            NewFamilyJournalEntrySheet(onSave: saveEntry, authorName: entry.authorName, editingEntry: entry)
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { deleteTargetId = nil }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetId {
                    deleteEntry(id)
                }
                deleteTargetId = nil
            }
        } message: {
            Text("Are you sure you want to delete this journal entry?")
        }
    }
}

struct FamilyJournalEntry: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var body: String
    var authorName: String
    var mood: String
    var createdDate: Date
}

private struct FamilyJournalEntryCard: View {
    let entry: FamilyJournalEntry
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.mood)
                    .font(.system(size: 32))
                    .frame(width: 48, height: 48)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(entry.title)
                    .font(.headline)
                Spacer()
                Text(entry.createdDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundColor(.secondary)

                Menu {
                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }

            Text(entry.body)
                .font(.body)
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(4)

            HStack {
                Text("by \(entry.authorName)")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

private struct NewFamilyJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (FamilyJournalEntry) -> Void
    let authorName: String
    var editingEntry: FamilyJournalEntry? = nil

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedMood = "\u{1F4DD}"

    private let moods: [(emoji: String, label: String)] = [
        ("\u{1F4DD}", "Note"), ("\u{1F60A}", "Happy"), ("\u{1F389}", "Celebrate"),
        ("\u{2764}\u{FE0F}", "Love"), ("\u{1F31F}", "Inspired"), ("\u{1F3E0}", "Home"),
        ("\u{1F382}", "Birthday"), ("\u{2708}\u{FE0F}", "Travel"), ("\u{1F64F}", "Grateful"), ("\u{1F622}", "Sad")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("How are you feeling?") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(moods, id: \.emoji) { mood in
                                Button {
                                    selectedMood = mood.emoji
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.emoji)
                                            .font(.system(size: 38))
                                        Text(mood.label)
                                            .font(.caption)
                                            .foregroundColor(selectedMood == mood.emoji ? .purple : .secondary)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedMood == mood.emoji ? Color.purple.opacity(0.15) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedMood == mood.emoji ? Color.purple : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Entry") {
                    TextField("Title", text: $title)
                    TextField("Write your thoughts...", text: $bodyText, axis: .vertical)
                        .lineLimit(5...12)
                }
            }
            .navigationTitle(editingEntry != nil ? "Edit Entry" : "New Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = FamilyJournalEntry(
                            id: editingEntry?.id ?? UUID().uuidString,
                            title: title,
                            body: bodyText,
                            authorName: editingEntry?.authorName ?? authorName,
                            mood: selectedMood,
                            createdDate: editingEntry?.createdDate ?? Date()
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || bodyText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let e = editingEntry {
                    title = e.title
                    bodyText = e.body
                    selectedMood = e.mood
                }
            }
        }
    }
}

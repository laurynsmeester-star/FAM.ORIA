import SwiftUI
import os
import FirebaseFirestore

/// One thing the user can @-mention in a post. Wraps anything in the app
/// that has its own page (member, event, album, journal entry, recipe,
/// document) so all of them appear in the same picker.
struct Mentionable: Identifiable, Hashable {
    enum Kind: String {
        case member, event, album, journal, recipe, document
        var icon: String {
            switch self {
            case .member:   return "person.fill"
            case .event:    return "calendar"
            case .album:    return "photo.on.rectangle"
            case .journal:  return "book.closed.fill"
            case .recipe:   return "fork.knife"
            case .document: return "doc.text.fill"
            }
        }
        var color: Color {
            switch self {
            case .member:   return .purple
            case .event:    return .orange
            case .album:    return .pink
            case .journal:  return .green
            case .recipe:   return .red
            case .document: return .blue
            }
        }
    }
    let id: String
    let name: String
    let kind: Kind
}

struct FamilyUpdatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var newPost = ""
    @State private var showMentionPicker = false
    @State private var extraMentionables: [Mentionable] = []

    private var familyMembers: [User] {
        appState.currentFamily?.members ?? []
    }

    /// All things the user can @-mention right now, in the order they should
    /// appear in the picker (members first, then events, then everything
    /// else loaded from Firestore).
    private var mentionables: [Mentionable] {
        var items: [Mentionable] = familyMembers.map {
            Mentionable(id: "member-\($0.id)", name: $0.name, kind: .member)
        }
        items.append(contentsOf: appState.events.prefix(20).map {
            Mentionable(id: "event-\($0.id)", name: $0.title, kind: .event)
        })
        items.append(contentsOf: extraMentionables)
        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Post composer with @ mention support
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Share an update...", text: $newPost, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .onChange(of: newPost) { _, value in
                                showMentionPicker = value.last == "@"
                            }

                        Button {
                            addPost()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.purple)
                                .clipShape(Circle())
                        }
                        .disabled(newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if showMentionPicker {
                        mentionSuggestions
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if appState.posts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Updates Yet")
                            .font(.title3).fontWeight(.semibold)
                        Text("Share something with your family!")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedPosts) { post in
                            UpdateCard(
                                post: post,
                                currentUserName: appState.currentUser?.name ?? "",
                                familyMembers: familyMembers,
                                onEdit: { newContent in
                                    Task { await editPost(post, newContent: newContent) }
                                },
                                onDelete: {
                                    Task { await deletePost(post) }
                                },
                                onReply: { content in
                                    Task { await addReply(to: post, content: content) }
                                },
                                onReact: { emoji in
                                    Task { await toggleReaction(emoji, on: post) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadExtraMentionables()
        }
    }

    private var sortedPosts: [FamilyPost] {
        appState.posts.sorted { $0.timestamp > $1.timestamp }
    }

    private func deletePost(_ post: FamilyPost) async {
        do {
            try await appState.deletePost(post)
        } catch {
            Log.appState.error("deletePost failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func editPost(_ post: FamilyPost, newContent: String) async {
        do {
            try await appState.updatePost(post, newContent: newContent)
        } catch {
            Log.appState.error("updatePost failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func addReply(to post: FamilyPost, content: String) async {
        do {
            try await appState.addReply(to: post, content: content)
        } catch {
            Log.appState.error("addReply failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func toggleReaction(_ emoji: String, on post: FamilyPost) async {
        do {
            try await appState.toggleReaction(emoji, on: post)
        } catch {
            Log.appState.error("toggleReaction failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var mentionSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mentionables) { item in
                    Button {
                        insertMention(item.name)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.kind.color.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: item.kind.icon)
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(item.kind.color)
                                )
                            Text(item.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func insertMention(_ name: String) {
        if newPost.hasSuffix("@") {
            newPost = String(newPost.dropLast()) + "@\(name) "
        } else {
            newPost += "@\(name) "
        }
        showMentionPicker = false
    }

    /// One-shot fetch of recent items in collections that have their own
    /// page in the app. Used to populate the @-mention picker without
    /// opening live listeners.
    private func loadExtraMentionables() async {
        let db = Firestore.firestore()
        async let albums = fetchNames(db: db, collection: "famoria_albums", titleKey: "title")
        async let journal = fetchNames(db: db, collection: "famoria_journal_entries", titleKey: "title")
        async let recipes = fetchNames(db: db, collection: "famoria_recipes", titleKey: "title")
        async let documents = fetchNames(db: db, collection: "famoria_documents", titleKey: "title")

        let albumItems = (await albums).map { Mentionable(id: "album-\($0.0)", name: $0.1, kind: .album) }
        let journalItems = (await journal).map { Mentionable(id: "journal-\($0.0)", name: $0.1, kind: .journal) }
        let recipeItems = (await recipes).map { Mentionable(id: "recipe-\($0.0)", name: $0.1, kind: .recipe) }
        let docItems = (await documents).map { Mentionable(id: "doc-\($0.0)", name: $0.1, kind: .document) }

        await MainActor.run {
            self.extraMentionables = albumItems + journalItems + recipeItems + docItems
        }
    }

    private func fetchNames(db: Firestore, collection: String, titleKey: String) async -> [(String, String)] {
        do {
            let snap = try await db.collection(collection).limit(to: 20).getDocuments()
            return snap.documents.compactMap { doc in
                guard let title = doc.data()[titleKey] as? String, !title.isEmpty else { return nil }
                return (doc.documentID, title)
            }
        } catch {
            Log.appState.error("mentionables fetch failed for \(collection, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func addPost() {
        let trimmed = newPost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newPost = ""
        showMentionPicker = false
        Task {
            do {
                try await appState.createPost(content: trimmed)
            } catch {
                Log.appState.error("createPost failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Update Card

private struct UpdateCard: View {
    let post: FamilyPost
    let currentUserName: String
    let familyMembers: [User]
    var onEdit: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onReply: (String) -> Void = { _ in }
    var onReact: (String) -> Void = { _ in }

    @State private var showReplyField = false
    @State private var replyText = ""
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showDeleteConfirm = false
    @State private var showEmojiPicker = false

    private let quickReactions = ["❤️", "👍", "😂", "🎉", "😍", "🙏"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initials(for: post.authorName))
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.purple)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundColor(.secondary)
                }
                Spacer()

                if post.authorName == currentUserName {
                    Menu {
                        Button {
                            editText = post.content
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                }
            }

            // Content (with @mention highlighting)
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Edit post...", text: $editText, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    HStack {
                        Button("Cancel") { isEditing = false }
                            .font(.caption)
                        Spacer()
                        Button("Save") {
                            let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                onEdit(trimmed)
                            }
                            isEditing = false
                        }
                        .font(.caption.weight(.semibold))
                        .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                highlightedContent(post.content)
            }

            // Reactions row
            if !post.reactions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(post.reactions.indices, id: \.self) { idx in
                        let reaction = post.reactions[idx]
                        Button {
                            toggleReaction(reaction.emoji)
                        } label: {
                            HStack(spacing: 4) {
                                Text(reaction.emoji)
                                Text("\(reaction.userNames.count)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(reaction.userNames.contains(currentUserName) ? .purple : .secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(reaction.userNames.contains(currentUserName) ? Color.purple.opacity(0.12) : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(reaction.userNames.contains(currentUserName) ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    showEmojiPicker.toggle()
                } label: {
                    Label("React", systemImage: "face.smiling")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    showReplyField.toggle()
                } label: {
                    Label(post.replies.isEmpty ? "Reply" : "\(post.replies.count)", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Emoji picker
            if showEmojiPicker {
                HStack(spacing: 10) {
                    ForEach(quickReactions, id: \.self) { emoji in
                        Button {
                            toggleReaction(emoji)
                            showEmojiPicker = false
                        } label: {
                            Text(emoji).font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            // Replies
            if !post.replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(post.replies) { reply in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(String(reply.authorName.prefix(1)).uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.blue)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(reply.authorName)
                                        .font(.caption.weight(.semibold))
                                    Text(reply.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                highlightedContent(reply.content)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.leading, 12)
            }

            // Reply field
            if showReplyField {
                HStack(spacing: 8) {
                    TextField("Write a reply...", text: $replyText)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Button {
                        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onReply(trimmed)
                        replyText = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.purple)
                            .clipShape(Circle())
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete this post?")
        }
    }

    private func toggleReaction(_ emoji: String) {
        onReact(emoji)
    }

    @ViewBuilder
    private func highlightedContent(_ text: String) -> some View {
        Text(attributedContent(text))
            .font(.body)
    }

    private func attributedContent(_ text: String) -> AttributedString {
        var result = AttributedString()
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        for (i, word) in words.enumerated() {
            if word.hasPrefix("@") {
                var mention = AttributedString(String(word))
                mention.foregroundColor = .purple
                mention.font = .body.weight(.semibold)
                result.append(mention)
            } else {
                result.append(AttributedString(String(word)))
            }
            if i < words.count - 1 {
                result.append(AttributedString(" "))
            }
        }
        return result
    }

    private func initials(for name: String) -> String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

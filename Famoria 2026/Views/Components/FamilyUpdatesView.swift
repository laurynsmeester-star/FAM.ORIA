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

    /// Called when the user taps a mention link. The wrapper page sets
    /// `currentPage` accordingly.
    var onNavigate: (FamoriaPage) -> Void = { _ in }

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
                                mentionables: mentionables,
                                onMentionTapped: handleMentionTap,
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

    private func handleMentionTap(_ item: Mentionable) {
        switch item.kind {
        case .member:
            onNavigate(.familyTree)
        case .event:
            if let event = appState.events.first(where: { "event-\($0.id)" == item.id }) {
                appState.pendingEventDate = event.date
            }
            onNavigate(.events)
        case .album:
            onNavigate(.albums)
        case .journal:
            onNavigate(.journal)
        case .recipe:
            onNavigate(.recipes)
        case .document:
            onNavigate(.documents)
        }
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
        Haptics.selection()
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
    var mentionables: [Mentionable] = []
    var onMentionTapped: (Mentionable) -> Void = { _ in }
    var onEdit: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onReply: (String) -> Void = { _ in }
    var onReact: (String) -> Void = { _ in }

    @State private var showReplyField = false
    @State private var replyText = ""
    @State private var showReplyMentionPicker = false
    @State private var showShareSheet = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showDeleteConfirm = false
    @State private var showEmojiPicker = false

    private let quickReactions = ["❤️", "👍", "😂", "🎉", "😍", "🙏"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                if let kind = activityKind {
                    ZStack {
                        Circle().fill(kind.color.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: kind.icon)
                            .foregroundColor(kind.color)
                    }
                } else {
                    AvatarView(
                        name: post.authorName,
                        imageURL: avatarURL(for: post.authorName),
                        size: 40
                    )
                }

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

                // External link preview (first URL in the post)
                if let url = LinkExtractor.firstURL(in: post.content) {
                    LinkPreviewView(url: url)
                }
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

                Button {
                    showShareSheet = true
                    Haptics.selection()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
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
                            AvatarView(
                                name: reply.authorName,
                                imageURL: avatarURL(for: reply.authorName),
                                size: 28,
                                tint: .blue
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Write a reply...", text: $replyText)
                            .font(.caption)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .onChange(of: replyText) { _, value in
                                showReplyMentionPicker = value.last == "@"
                            }
                        Button {
                            let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onReply(trimmed)
                            replyText = ""
                            showReplyMentionPicker = false
                            return
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

                    if showReplyMentionPicker {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(mentionables) { item in
                                    Button {
                                        if replyText.hasSuffix("@") {
                                            replyText = String(replyText.dropLast()) + "@\(item.name) "
                                        } else {
                                            replyText += "@\(item.name) "
                                        }
                                        showReplyMentionPicker = false
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: item.kind.icon)
                                                .font(.caption2)
                                                .foregroundColor(item.kind.color)
                                            Text(item.name).font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(10)
                                        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }

        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .sheet(isPresented: $showShareSheet) {
            FamoriaShareSheet(items: [FamoriaSharePayload(
                title: "From \(post.authorName)",
                bodyText: post.content
            )])
        }
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
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "famoria",
                      let host = url.host,
                      let id = url.pathComponents.dropFirst().first,
                      let item = mentionables.first(where: { $0.id == "\(host)-\(id)" || $0.id == id }) else {
                    return .systemAction
                }
                onMentionTapped(item)
                return .handled
            })
    }

    /// Builds an `AttributedString` where each `@Name` (matched against the
    /// known mentionables list) becomes a tappable link to the right page.
    /// Multi-word names ("@Family Dinner") are matched greedily so the whole
    /// span — not just the first word — is highlighted and tappable.
    private func attributedContent(_ text: String) -> AttributedString {
        var result = AttributedString()
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "@" {
                let after = text.index(after: i)
                if let (matched, item) = longestMentionMatch(in: text, startingAt: after) {
                    var mention = AttributedString("@" + matched)
                    mention.foregroundColor = .purple
                    mention.font = .body.weight(.semibold)
                    mention.link = mentionURL(for: item)
                    result.append(mention)
                    i = text.index(after, offsetBy: matched.count)
                    continue
                }
            }
            result.append(AttributedString(String(text[i])))
            i = text.index(after: i)
        }
        return result
    }

    /// Returns the longest mentionable-name that the substring starting at
    /// `index` begins with, so "@Family Dinner Plans" matches the event
    /// "Family Dinner" rather than just the word "Family".
    private func longestMentionMatch(in text: String, startingAt index: String.Index)
        -> (String, Mentionable)? {
        let tail = String(text[index...])
        var best: (String, Mentionable)?
        for item in mentionables {
            guard tail.hasPrefix(item.name) else { continue }
            if best == nil || item.name.count > (best?.0.count ?? 0) {
                best = (item.name, item)
            }
        }
        return best
    }

    private func mentionURL(for item: Mentionable) -> URL? {
        // famoria://<kind>/<id-with-prefix-stripped>
        let stripped: String = {
            let parts = item.id.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            return parts.count == 2 ? String(parts[1]) : item.id
        }()
        return URL(string: "famoria://\(item.kind.rawValue)/\(stripped)")
    }

    private func initials(for name: String) -> String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }

    private func avatarURL(for name: String) -> String? {
        familyMembers.first(where: { $0.name == name })?.avatarURL
    }

    /// Decodes the post's `activityKind` raw value (if any) into icon/color
    /// metadata so activity-posts get a distinct chrome from human posts.
    private var activityKind: (icon: String, color: Color)? {
        guard let raw = post.activityKind,
              let kind = FamilyActivityKind(rawValue: raw) else { return nil }
        switch kind {
        case .albumCreated:  return ("photo.on.rectangle.angled", .pink)
        case .photoAdded:    return ("camera.fill", .pink)
        case .eventCreated:  return ("calendar.badge.plus", .orange)
        case .eventUpdated:  return ("calendar.badge.exclamationmark", .orange)
        case .journalAdded:  return ("book.closed.fill", .green)
        case .recipeAdded:   return ("fork.knife", .red)
        case .documentAdded: return ("doc.text.fill", .blue)
        case .memberJoined:  return ("person.crop.circle.badge.plus", .purple)
        }
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

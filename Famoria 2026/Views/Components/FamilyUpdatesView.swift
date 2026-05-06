import SwiftUI

struct FamilyUpdatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var newPost = ""
    @State private var showMentionPicker = false

    private var familyMembers: [User] {
        appState.currentFamily?.members ?? []
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
                        ForEach(sortedPosts.indices, id: \.self) { index in
                            UpdateCard(
                                post: binding(for: index),
                                currentUserName: appState.currentUser?.name ?? "",
                                familyMembers: familyMembers,
                                onDelete: { deletePost(at: index) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var sortedPosts: [FamilyPost] {
        appState.posts.sorted { $0.timestamp > $1.timestamp }
    }

    private func binding(for sortedIndex: Int) -> Binding<FamilyPost> {
        let sortedPost = sortedPosts[sortedIndex]
        guard let realIndex = appState.posts.firstIndex(where: { $0.id == sortedPost.id }) else {
            return .constant(sortedPost)
        }
        return $appState.posts[realIndex]
    }

    private func deletePost(at sortedIndex: Int) {
        let post = sortedPosts[sortedIndex]
        appState.posts.removeAll { $0.id == post.id }
    }

    private var mentionSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(familyMembers) { member in
                    Button {
                        // Replace trailing @ with @Name
                        if newPost.hasSuffix("@") {
                            newPost = String(newPost.dropLast()) + "@\(member.name) "
                        } else {
                            newPost += "@\(member.name) "
                        }
                        showMentionPicker = false
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(member.name.prefix(1)).uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.purple)
                                )
                            Text(member.name)
                                .font(.caption.weight(.medium))
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

    private func addPost() {
        let trimmed = newPost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let post = FamilyPost(
            id: UUID().uuidString,
            authorName: appState.currentUser?.name ?? "Unknown",
            content: trimmed,
            timestamp: Date()
        )
        appState.posts.append(post)
        newPost = ""
        showMentionPicker = false
    }
}

// MARK: - Update Card

private struct UpdateCard: View {
    @Binding var post: FamilyPost
    let currentUserName: String
    let familyMembers: [User]
    var onDelete: () -> Void = {}

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
                                post.content = trimmed
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
                        let reply = PostReply(authorName: currentUserName, content: trimmed)
                        post.replies.append(reply)
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
        if let idx = post.reactions.firstIndex(where: { $0.emoji == emoji }) {
            if post.reactions[idx].userNames.contains(currentUserName) {
                post.reactions[idx].userNames.removeAll { $0 == currentUserName }
                if post.reactions[idx].userNames.isEmpty {
                    post.reactions.remove(at: idx)
                }
            } else {
                post.reactions[idx].userNames.append(currentUserName)
            }
        } else {
            post.reactions.append(PostReaction(emoji: emoji, userNames: [currentUserName]))
        }
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

import SwiftUI
import PhotosUI

struct ChatDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let chat: Chat
    @State private var messageText = ""
    @State private var replyingTo: ChatMessage? = nil
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showReactionPicker: ChatMessage? = nil
    @State private var messageToDelete: ChatMessage? = nil
    @State private var showDeleteConfirm = false
    @State private var showMentionPicker = false
    @State private var showAttachMenu = false
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @FocusState private var isInputActive: Bool

    private var messages: [ChatMessage] {
        appState.messagesByChat[chat.id] ?? []
    }

    private var currentUserId: String? { appState.currentUser?.id }

    private var chatTitle: String {
        if let name = chat.name { return name }
        return chat.participants.first(where: { $0.id != currentUserId })?.name ?? "Chat"
    }

    private var chatSubtitle: String? {
        if chat.isGroup {
            let names = chat.participants.prefix(3).map(\.name)
            let text = names.joined(separator: ", ")
            if chat.participants.count > 3 {
                return text + " +\(chat.participants.count - 3)"
            }
            return text
        }
        return nil
    }

    // MARK: - Mention Items

    private struct MentionItem: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        enum Kind { case person, event, album }
        let kind: Kind
    }

    private var mentionItems: [MentionItem] {
        var items: [MentionItem] = []
        for p in chat.participants where p.id != currentUserId {
            items.append(MentionItem(id: p.id, name: p.name, icon: "person.fill", color: .blue, kind: .person))
        }
        for event in appState.events {
            items.append(MentionItem(id: "event-\(event.id)", name: event.title, icon: "calendar", color: .orange, kind: .event))
        }
        return items
    }

    private var filteredMentionItems: [MentionItem] {
        guard let atRange = messageText.range(of: "@", options: .backwards) else { return mentionItems }
        let query = String(messageText[atRange.upperBound...]).lowercased()
        if query.isEmpty { return mentionItems }
        return mentionItems.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            typingIndicatorBar
            replyBar
            if showMentionPicker {
                mentionPicker
            }
            inputBar
        }
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
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
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(chatTitle)
                        .font(.headline)
                    if let subtitle = chatSubtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            Task { try? await appState.fetchMessages(for: chat.id) }
            appState.observeMessages(for: chat.id)
        }
        .onDisappear {
            Task { try? await appState.setTyping(false, in: chat.id) }
        }
        .overlay {
            if let msg = showReactionPicker {
                reactionOverlay(for: msg)
            }
        }
        .alert("Delete Message", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { messageToDelete = nil }
            Button("Delete", role: .destructive) {
                if let msg = messageToDelete {
                    Task { try? await appState.deleteMessage(msg.id, in: chat.id) }
                    messageToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this message?")
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            sendPhotos(newItems)
            selectedPhotos = []
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                        let showSender = shouldShowSender(at: index)
                        let showTimestamp = shouldShowTimestamp(at: index)

                        if showTimestamp {
                            dateHeader(for: msg.timestamp)
                        }

                        if msg.isSystem || msg.messageType == .system {
                            systemMessage(msg)
                        } else {
                            messageBubble(msg, showSender: showSender)
                                .id(msg.id)
                                .onLongPressGesture {
                                    showReactionPicker = msg
                                }
                                .contextMenu {
                                    Button {
                                        replyingTo = msg
                                        isInputActive = true
                                    } label: {
                                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                                    }
                                    Button {
                                        UIPasteboard.general.string = msg.content
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        showReactionPicker = msg
                                    } label: {
                                        Label("React", systemImage: "face.smiling")
                                    }
                                    if msg.senderId == currentUserId {
                                        Divider()
                                        Button(role: .destructive) {
                                            messageToDelete = msg
                                            showDeleteConfirm = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Date Header

    private func dateHeader(for date: Date) -> some View {
        Text(dateHeaderText(date))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
            .padding(.vertical, 8)
    }

    private func dateHeaderText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - System Message

    private func systemMessage(_ msg: ChatMessage) -> some View {
        Text(msg.content)
            .font(.caption)
            .foregroundColor(.secondary)
            .italic()
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: ChatMessage, showSender: Bool) -> some View {
        let isSelf = msg.senderId == currentUserId

        return HStack(alignment: .bottom, spacing: 6) {
            if isSelf { Spacer(minLength: 50) }

            if !isSelf {
                if showSender {
                    avatarCircle(for: msg)
                } else {
                    Color.clear.frame(width: 30, height: 30)
                }
            }

            VStack(alignment: isSelf ? .trailing : .leading, spacing: 2) {
                if showSender && !isSelf {
                    Text(msg.senderName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }

                if let replyContent = msg.replyToContent, let replySender = msg.replyToSenderName {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(replySender)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Text(replyContent)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isSelf ? Color.blue.opacity(0.15) : Color(.systemGray5))
                    .cornerRadius(12)
                }

                if msg.messageType == .image, let urlString = msg.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220, maxHeight: 300)
                                .cornerRadius(16)
                        default:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                                .frame(width: 200, height: 150)
                                .overlay(ProgressView())
                        }
                    }
                }

                if !msg.content.isEmpty && msg.messageType != .image {
                    styledMessageContent(msg.content, isSelf: isSelf)
                }

                if !msg.reactions.isEmpty {
                    reactionsView(for: msg)
                }

                Text(msg.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(isSelf ? .trailing : .leading, 4)
            }

            if !isSelf { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }

    private func styledMessageContent(_ content: String, isSelf: Bool) -> some View {
        let parts = parseMentions(content)
        var text = Text("")
        for part in parts {
            if part.isMention {
                text = text + Text(part.text).bold().foregroundColor(isSelf ? .white.opacity(0.9) : .blue)
            } else {
                text = text + Text(part.text)
            }
        }

        return text
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(isSelf ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelf ? .white : .primary)
            .cornerRadius(20, corners: isSelf
                           ? [.topLeft, .topRight, .bottomLeft]
                           : [.topLeft, .topRight, .bottomRight])
    }

    private func avatarCircle(for msg: ChatMessage) -> some View {
        let initials = msg.senderName.split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()

        return Circle()
            .fill(Color.blue.opacity(0.15))
            .frame(width: 30, height: 30)
            .overlay(
                Text(initials)
                    .font(.system(size: 11))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            )
    }

    // MARK: - Reactions

    private func reactionsView(for msg: ChatMessage) -> some View {
        let grouped = Dictionary(grouping: msg.reactions, by: \.emoji)
        return HStack(spacing: 4) {
            ForEach(Array(grouped.keys.sorted()), id: \.self) { emoji in
                HStack(spacing: 2) {
                    Text(emoji)
                        .font(.caption)
                    if let count = grouped[emoji]?.count, count > 1 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            }
        }
    }

    private func reactionOverlay(for msg: ChatMessage) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { showReactionPicker = nil }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(["❤️", "👍", "😂", "😮", "😢", "🔥"], id: \.self) { emoji in
                        Button {
                            Task {
                                try? await appState.addReaction(emoji, to: msg.id, in: chat.id)
                            }
                            showReactionPicker = nil
                        } label: {
                            Text(emoji)
                                .font(.largeTitle)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThickMaterial)
                .clipShape(Capsule())
                .shadow(radius: 10)
            }
        }
    }

    // MARK: - Typing Indicator Bar

    @ViewBuilder
    private var typingIndicatorBar: some View {
        let typingNames = chat.typingUsers
            .filter { $0 != currentUserId }
            .compactMap { uid in chat.participants.first(where: { $0.id == uid })?.name }

        if !typingNames.isEmpty {
            HStack(spacing: 6) {
                TypingDotsView()
                Text(typingNames.joined(separator: ", ") + (typingNames.count == 1 ? " is" : " are") + " typing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Reply Bar

    @ViewBuilder
    private var replyBar: some View {
        if let reply = replyingTo {
            HStack {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Replying to \(reply.senderName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text(reply.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    replyingTo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
    }

    // MARK: - Mention Picker

    private var mentionPicker: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredMentionItems) { item in
                        Button {
                            insertMention(item)
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(item.color.opacity(0.15))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: item.icon)
                                        .font(.caption)
                                        .foregroundColor(item.color)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(mentionKindLabel(item.kind))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func mentionKindLabel(_ kind: MentionItem.Kind) -> String {
        switch kind {
        case .person: return "Person"
        case .event: return "Event"
        case .album: return "Album"
        }
    }

    private func insertMention(_ item: MentionItem) {
        if let atRange = messageText.range(of: "@", options: .backwards) {
            messageText.replaceSubrange(atRange.lowerBound..., with: "@\(item.name) ")
        } else {
            messageText += "@\(item.name) "
        }
        showMentionPicker = false
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    messageText += "@"
                    showMentionPicker = true
                    isInputActive = true
                } label: {
                    Label("Mention", systemImage: "at")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            TextField("Message...", text: $messageText, axis: .vertical)
                .focused($isInputActive)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .onChange(of: messageText) {
                    Task { try? await appState.setTyping(!messageText.isEmpty, in: chat.id) }
                    if messageText.hasSuffix("@") {
                        showMentionPicker = true
                    } else if !messageText.contains("@") {
                        showMentionPicker = false
                    }
                }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func send() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let reply = replyingTo
        Task {
            try? await appState.sendMessage(
                to: chat.id,
                content: trimmed,
                replyTo: reply
            )
            try? await appState.setTyping(false, in: chat.id)
        }
        messageText = ""
        replyingTo = nil
        showMentionPicker = false
    }

    private func sendPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }

                let storage = FirebaseStorage.Storage.storage()
                let filename = "\(UUID().uuidString).jpg"
                let ref = storage.reference().child("chat_images/\(chat.id)/\(filename)")

                guard let jpegData = image.jpegData(compressionQuality: 0.75) else { continue }

                let metadata = FirebaseStorage.StorageMetadata()
                metadata.contentType = "image/jpeg"

                do {
                    _ = try await ref.putDataAsync(jpegData, metadata: metadata)
                    let url = try await ref.downloadURL()

                    try? await appState.sendImageMessage(
                        to: chat.id,
                        imageURL: url.absoluteString
                    )
                } catch {
                    print("[ChatDetail] Photo upload error: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func shouldShowSender(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        return current.senderId != previous.senderId
            || current.timestamp.timeIntervalSince(previous.timestamp) > 120
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        return !Calendar.current.isDate(current.timestamp, inSameDayAs: previous.timestamp)
    }

    private struct TextPart {
        let text: String
        let isMention: Bool
    }

    private func parseMentions(_ content: String) -> [TextPart] {
        var parts: [TextPart] = []
        var allMentionNames = Set(chat.participants.map { "@\($0.name)" })
        for event in appState.events {
            allMentionNames.insert("@\(event.title)")
        }
        var remaining = content

        while !remaining.isEmpty {
            if let atRange = remaining.range(of: "@") {
                if atRange.lowerBound > remaining.startIndex {
                    parts.append(TextPart(text: String(remaining[remaining.startIndex..<atRange.lowerBound]), isMention: false))
                }

                let afterAt = remaining[atRange.lowerBound...]
                var matched = false
                for name in allMentionNames.sorted(by: { $0.count > $1.count }) {
                    if afterAt.hasPrefix(name) {
                        parts.append(TextPart(text: name, isMention: true))
                        remaining = String(afterAt.dropFirst(name.count))
                        matched = true
                        break
                    }
                }
                if !matched {
                    parts.append(TextPart(text: "@", isMention: false))
                    remaining = String(afterAt.dropFirst())
                }
            } else {
                parts.append(TextPart(text: remaining, isMention: false))
                break
            }
        }
        return parts
    }
}

// MARK: - Typing Dots Animation

struct TypingDotsView: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                    .offset(y: sin(phase + Double(i) * 0.8) * 3)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - RoundedCorner Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
            chat: Chat(
                id: "chat1",
                name: "Family Group",
                participants: [],
                lastMessage: nil
            )
        )
        .environmentObject(AppState())
    }
}

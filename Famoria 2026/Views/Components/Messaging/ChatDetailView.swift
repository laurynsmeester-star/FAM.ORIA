import SwiftUI
import PhotosUI

struct ChatDetailView: View {
    @EnvironmentObject var appState: AppState
    let chat: Chat
    @State private var messageText = ""
    @State private var replyingTo: ChatMessage? = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showReactionPicker: ChatMessage? = nil
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

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            typingIndicatorBar
            replyBar
            inputBar
        }
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                                }
                        }
                    }

                    // Read receipt at bottom
                    if let lastSelfMsg = messages.last(where: { $0.senderId == currentUserId }) {
                        readReceipt(for: lastSelfMsg)
                            .padding(.trailing, 16)
                            .frame(maxWidth: .infinity, alignment: .trailing)
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

                // Reply context
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

                // Image message
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

                // Text content
                if !msg.content.isEmpty && msg.messageType != .image {
                    Text(msg.content)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(isSelf ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundColor(isSelf ? .white : .primary)
                        .cornerRadius(20, corners: isSelf
                                       ? [.topLeft, .topRight, .bottomLeft]
                                       : [.topLeft, .topRight, .bottomRight])
                }

                // Reactions
                if !msg.reactions.isEmpty {
                    reactionsView(for: msg)
                }

                // Time
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

    // MARK: - Read Receipt

    private func readReceipt(for msg: ChatMessage) -> some View {
        HStack(spacing: 3) {
            if msg.readAt != nil {
                Text("Read")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else if msg.deliveredAt != nil {
                Text("Delivered")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Sent")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 4)
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

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Photo picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.fill")
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

import SwiftUI
import Combine

/// Main messaging view — lists all DM and group chat threads.
struct DirectMessagesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewChat = false
    @State private var showNewGroup = false
    @State private var searchText = ""

    private var filteredChats: [Chat] {
        if searchText.isEmpty { return appState.chats }
        let query = searchText.lowercased()
        return appState.chats.filter { chat in
            if let name = chat.name, name.lowercased().contains(query) { return true }
            return chat.participants.contains { $0.name.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.chats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .sheet(isPresented: $showNewGroup) {
                NewGroupChatView()
            }
        }
        .onAppear {
            appState.observeChats()
            Task { try? await appState.fetchChats() }
        }
    }

    // MARK: - Chat List

    private var chatList: some View {
        List {
            ForEach(filteredChats) { chat in
                NavigationLink(destination: ChatDetailView(chat: chat)) {
                    ChatRowView(chat: chat, currentUserId: appState.currentUser?.id)
                }
            }
            .onDelete(perform: deleteChats)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search conversations")
    }

    private func deleteChats(at offsets: IndexSet) {
        // Placeholder — wire to Firestore deletion if needed
        for index in offsets {
            let _ = filteredChats[index]
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Start chatting with your family members.\nTap the compose button to begin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showNewChat = true
            } label: {
                Label("Start a Chat", systemImage: "plus.message.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Chat Row

struct ChatRowView: View {
    let chat: Chat
    let currentUserId: String?

    private var displayName: String {
        if let name = chat.name { return name }
        return chat.participants.first(where: { $0.id != currentUserId })?.name ?? "Chat"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ").compactMap { $0.first }
        return parts.prefix(2).map(String.init).joined().uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView
            contentView
        }
        .padding(.vertical, 4)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(chat.isGroup
                      ? LinearGradient(colors: [.purple.opacity(0.25), .blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [.blue.opacity(0.15), .cyan.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)

            if chat.isGroup {
                Image(systemName: "person.3.fill")
                    .font(.callout)
                    .foregroundColor(.purple)
            } else {
                Text(initials)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let lastMsg = chat.lastMessage {
                    Text(lastMsg.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Group {
                    if !chat.typingUsers.isEmpty {
                        TypingIndicatorText()
                    } else if let lastMsg = chat.lastMessage {
                        Text(lastMsg.senderName + ": " + lastMsg.content)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No messages yet")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .font(.subheadline)
                .lineLimit(1)

                Spacer()

                if chat.unreadCount > 0 {
                    Text("\(chat.unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorText: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("typing" + String(repeating: ".", count: dotCount + 1))
            .foregroundColor(.blue)
            .italic()
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 3
            }
    }
}

// MARK: - New Chat (DM) Sheet

struct NewChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var familyMembers: [User] {
        let currentId = appState.currentUser?.id
        return (appState.currentFamily?.members ?? []).filter { $0.id != currentId }
    }

    private var filtered: [User] {
        if searchText.isEmpty { return familyMembers }
        let query = searchText.lowercased()
        return familyMembers.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if familyMembers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No family members to chat with yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(filtered) { member in
                        Button {
                            startChat(with: member)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(String(member.name.prefix(1)).uppercased())
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(member.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search family members")
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func startChat(with member: User) {
        Task {
            try? await appState.createDirectChat(with: member.id, userName: member.name)
            dismiss()
        }
    }
}

// MARK: - New Group Chat Sheet

struct NewGroupChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var groupName = ""
    @State private var selectedMembers: Set<String> = []

    private var familyMembers: [User] {
        let currentId = appState.currentUser?.id
        return (appState.currentFamily?.members ?? []).filter { $0.id != currentId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)
                            Image(systemName: "camera.fill")
                                .foregroundColor(.purple)
                        }
                        TextField("Group Name", text: $groupName)
                            .font(.title3)
                    }
                }

                Section("Select Members (\(selectedMembers.count) selected)") {
                    ForEach(familyMembers) { member in
                        Button {
                            toggleMember(member.id)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(member.name.prefix(1)).uppercased())
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    )

                                Text(member.name)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: selectedMembers.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMembers.contains(member.id) ? .blue : .secondary)
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createGroup() }
                        .fontWeight(.semibold)
                        .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedMembers.isEmpty)
                }
            }
        }
    }

    private func toggleMember(_ id: String) {
        if selectedMembers.contains(id) {
            selectedMembers.remove(id)
        } else {
            selectedMembers.insert(id)
        }
    }

    private func createGroup() {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !selectedMembers.isEmpty else { return }

        let allMembers = appState.currentFamily?.members ?? []
        var nameMap: [String: String] = [:]
        for m in allMembers { nameMap[m.id] = m.name }
        if let user = appState.currentUser { nameMap[user.id] = user.name }

        Task {
            try? await appState.createGroupChat(
                with: Array(selectedMembers),
                participantNames: nameMap,
                name: name
            )
            dismiss()
        }
    }
}

#Preview {
    DirectMessagesView()
        .environmentObject(AppState())
}

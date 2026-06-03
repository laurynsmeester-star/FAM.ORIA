import SwiftUI
import os

struct EnhancedHomeTab: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var albumStore = AlbumStoreManager()
    @State private var newPost = ""
    @State private var profileMember: User?

    var onNavigate: (FamoriaPage) -> Void = { _ in }

    var notifications: [AppNotification] = []
    var journalEntries: [JournalEntry] = []

    // Derived feed: pull the latest message across all chats so the
    // Updates card reflects real activity.
    private var derivedMessages: [FeedMessage] {
        let recents: [FeedMessage] = appState.chats.compactMap { chat in
            guard let last = chat.lastMessage else { return nil }
            return FeedMessage(
                id: last.id,
                authorName: last.senderName,
                content: last.content,
                createdDate: last.timestamp
            )
        }
        return recents.sorted { $0.createdDate > $1.createdDate }
    }

    // Derived feed: real albums from Firestore.
    private var derivedAlbums: [Album] {
        albumStore.albums.compactMap { fa in
            guard let id = fa.id else { return nil }
            return Album(id: id, title: fa.title, coverImage: fa.coverImageURL)
        }
    }

    /// Returns the next upcoming event, falling back to the most recent past
    /// event if nothing is scheduled. This keeps the Updates card meaningful
    /// when the user only has historical events on record.
    private var nextOrLatestEvent: FamilyEvent? {
        let upcoming = appState.events
            .filter { $0.upcomingDate >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.upcomingDate < $1.upcomingDate }
            .first
        if let upcoming { return upcoming }
        return appState.events.sorted { $0.date > $1.date }.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // 1. Greeting + avatar
                GreetingHeaderView(user: appState.currentUser)

                // 2. Tasks + Countdown (header row — replaces the family banner)
                HStack(alignment: .top, spacing: 12) {
                    UserTasksCard(onOpenEvent: { task in
                        if let event = appState.events.first(where: { $0.id == task.eventId }) {
                            appState.pendingEventDate = event.date
                        } else if let due = task.dueDate {
                            appState.pendingEventDate = due
                        }
                        onNavigate(.events)
                    })
                    .frame(maxWidth: .infinity)

                    CelebrationCountdown(
                        currentUserName: appState.currentUser?.name,
                        nextEvent: appState.events
                            .filter { $0.date >= Date() }
                            .sorted { $0.date < $1.date }
                            .first,
                        onTap: {
                            if let d = appState.events
                                .filter({ $0.upcomingDate >= Calendar.current.startOfDay(for: Date()) })
                                .sorted(by: { $0.upcomingDate < $1.upcomingDate })
                                .first?.date {
                                appState.pendingEventDate = d
                            }
                            onNavigate(.events)
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                // 3. Family Members horizontal scroll
                FamilyMembersSection(
                    members: appState.currentFamily?.members ?? [],
                    onMemberTap: { profileMember = $0 }
                )
                .padding(.horizontal)

                // 4. "Share something with your family…" composer
                PostComposerView(newPost: $newPost, onPost: addPost)
                    .padding(.horizontal)

                // 5. Three most recent posts
                LazyVStack(spacing: 12) {
                    ForEach(appState.posts.sorted { $0.timestamp > $1.timestamp }.prefix(3)) { post in
                        PostCard(post: post)
                    }
                }
                .padding(.horizontal)

                // 6. Updates summary card — each row links to its source location
                UpdatesSection(
                    latestMessage: derivedMessages.first,
                    hasUpcomingEvents: !appState.events.isEmpty,
                    hasRecentAlbums: !derivedAlbums.isEmpty,
                    nextEventTitle: nextOrLatestEvent?.title,
                    nextEventDate: nextOrLatestEvent?.date,
                    recentAlbumTitle: derivedAlbums.first?.title,
                    onMessageTap: { onNavigate(.chat) },
                    onEventTap: {
                        if let d = nextOrLatestEvent?.date {
                            appState.pendingEventDate = d
                        }
                        onNavigate(.events)
                    },
                    onAlbumTap: { onNavigate(.albums) }
                )
                .padding(.horizontal)

                // 6. AI-powered quick actions grid
                AIQuickActionsGrid(
                    latestMessageAuthor: derivedMessages.first?.authorName,
                    onReply: { onNavigate(.chat) },
                    onPlanEvent: { onNavigate(.events) },
                    onUploadPhoto: { onNavigate(.albums) }
                )
                .padding(.horizontal)

                // 7. Upcoming Events vertical list with date badge
                UpcomingEventsList(
                    events: appState.events
                        .filter { $0.date >= Date() }
                        .sorted { $0.date < $1.date },
                    onEventTap: { event in
                        appState.pendingEventDate = event.date
                        onNavigate(.events)
                    },
                    onSeeAll: { onNavigate(.events) }
                )
                .padding(.horizontal)

                // Recent messages
                RecentMessagesSection(
                    messages: derivedMessages,
                    currentUserName: appState.currentUser?.name ?? ""
                )

                // 11. Photo memories
                PhotoMemoriesSection(albums: derivedAlbums)

                Spacer(minLength: 20)
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $profileMember) { member in
            FamilyMemberProfileSheet(member: member)
        }
        .onAppear { albumStore.startListeningToAlbums() }
        .onDisappear { albumStore.stopListeningToAlbums() }
    }

    private func addPost() {
        let trimmed = newPost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newPost = ""
        Task {
            do {
                try await appState.createPost(content: trimmed)
            } catch {
                Log.appState.error("createPost failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

#Preview {
    EnhancedHomeTab()
        .environmentObject(AppState())
}

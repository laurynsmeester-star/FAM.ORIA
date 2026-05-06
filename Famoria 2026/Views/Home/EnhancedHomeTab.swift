import SwiftUI

struct EnhancedHomeTab: View {
    @EnvironmentObject var appState: AppState
    @State private var newPost = ""

    var onNavigate: (FamoriaPage) -> Void = { _ in }

    var messages: [FeedMessage] = []
    var albums: [Album] = []
    var notifications: [AppNotification] = []
    var journalEntries: [JournalEntry] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // 1. Greeting + avatar
                GreetingHeaderView(user: appState.currentUser)

                // 2. Family banner
                FamilyBannerCard(familyName: appState.currentFamily?.name ?? "Our Family")

                // 3. Family Members horizontal scroll
                FamilyMembersSection(
                    members: appState.currentFamily?.members ?? []
                )
                .padding(.horizontal)

                // 4. Quick links
                QuickLinksRow(onSelect: { name in
                    switch name {
                    case "Messages": onNavigate(.chat)
                    case "Events":   onNavigate(.events)
                    case "Albums":   onNavigate(.albums)
                    default: break
                    }
                })

                // 5. Updates summary card
                UpdatesSection(
                    latestMessage: messages.first,
                    hasUpcomingEvents: !appState.events
                        .filter { $0.date >= Date() }.isEmpty,
                    hasRecentAlbums: !albums.isEmpty
                )
                .padding(.horizontal)

                // 6. AI-powered quick actions grid
                AIQuickActionsGrid(
                    latestMessageAuthor: messages.first?.authorName,
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
                    onSeeAll: { onNavigate(.events) }
                )
                .padding(.horizontal)

                // 8. Post composer
                PostComposerView(newPost: $newPost, onPost: addPost)
                    .padding(.horizontal)

                // 9. Posts feed
                LazyVStack(spacing: 12) {
                    ForEach(appState.posts.sorted { $0.timestamp > $1.timestamp }) { post in
                        PostCard(post: post)
                    }
                }
                .padding(.horizontal)

                // 10. Recent messages
                RecentMessagesSection(
                    messages: messages,
                    currentUserName: appState.currentUser?.name ?? ""
                )

                // 11. Photo memories
                PhotoMemoriesSection(albums: albums)

                // 12. Tasks + Countdown side by side
                HStack(alignment: .top, spacing: 12) {
                    // User tasks column
                    UserTasksCard()
                        .frame(maxWidth: .infinity)

                    // Countdown card
                    CelebrationCountdown(
                        currentUserName: appState.currentUser?.name,
                        nextEvent: appState.events
                            .filter { $0.date >= Date() }
                            .sorted { $0.date < $1.date }
                            .first,
                        onTap: { onNavigate(.events) }
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func addPost() {
        guard !newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let post = FamilyPost(
            id: UUID().uuidString,
            authorName: appState.currentUser?.name ?? "Unknown",
            content: newPost,
            timestamp: Date()
        )
        appState.posts.append(post)
        newPost = ""
    }
}

#Preview {
    EnhancedHomeTab()
        .environmentObject(AppState())
}

//
//  HomePageExtensions.swift
//  Famoria 2026
//
//  Created by Claude – extends HomePageView.swift
//  Translated from: pages/Home (web) + functions/getPersonalizedFeed.ts
//
//  Drop this file into the same target as HomePageView.swift.
//  It adds new models, an AppState extension, and an EnhancedHomeTab
//  that replaces HomeTab in HomePageView.HomePageView body if desired.
//

import SwiftUI

// MARK: - Additional Models

/// Mirrors ChatMessage entity from the web app (renamed to avoid conflict with Messaging ChatMessage)
struct FeedMessage: Identifiable {
    let id: String
    let authorName: String
    let content: String
    let createdDate: Date
}

/// Mirrors Album entity from the web app
struct Album: Identifiable {
    let id: String
    let title: String
    let coverImage: String?   // URL string; nil shows placeholder
}

/// Mirrors Photo entity
struct Photo: Identifiable {
    let id: String
    let url: String
    let albumId: String
    let createdDate: Date
}

/// Mirrors JournalEntry entity
struct JournalEntry: Identifiable {
    let id: String
    let title: String
    let content: String
    let authorName: String
    let createdDate: Date
}

/// Mirrors Notification entity
struct AppNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let isRead: Bool
    let createdDate: Date
}

// MARK: - Feed Models  (from getPersonalizedFeed.ts response schema)

enum FeedItemType: String {
    case message, event, photo, notification, journal

    var icon: String {
        switch self {
        case .message:      return "bubble.left.fill"
        case .event:        return "calendar"
        case .photo:        return "photo.fill"
        case .notification: return "bell.fill"
        case .journal:      return "book.closed.fill"
        }
    }

    var color: Color {
        switch self {
        case .message:      return .blue
        case .event:        return .orange
        case .photo:        return .pink
        case .notification: return .purple
        case .journal:      return .green
        }
    }
}

enum FeedPriority: Int, Comparable {
    case high = 3, medium = 2, low = 1
    static func < (lhs: FeedPriority, rhs: FeedPriority) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct FeedItem: Identifiable {
    let id: String
    let type: FeedItemType
    let title: String
    let description: String
    let priority: FeedPriority
}

struct QuickAction: Identifiable {
    let id: String
    let label: String
    let description: String
    let icon: String
    let color: Color
}

struct SectionPriorities {
    var messages: Int
    var events: Int
    var photos: Int
    var journal: Int
}

// MARK: - AppState Extension (new data buckets)

extension AppState {
    // Use associated-object storage so we don't touch the original class
    // In practice add these as @Published vars directly to AppState.

    /// Seed data helpers – call once in your app's init / onboarding flow
    func seedSampleFeedData() {
        // No-op placeholder – replace with real API fetch
    }
}

// MARK: - Personalized Feed Engine  (local translation of getPersonalizedFeed.ts)

/// Replicates the ranking logic from getPersonalizedFeed.ts without the AI/base44 call.
/// Pass in the raw lists fetched from your API and receive a ranked result.
struct PersonalizedFeedEngine {

    // Translates the recurring-event date parsing from the web app
    static func parseEventDate(_ event: FamilyEvent) -> Date {
        // FamilyEvent.date is assumed to be a Date already in the Swift model.
        // If you store it as a String add the MM-DD recurring logic here:
        //
        // if isRecurring && dateString.count == 5 {          // "MM-DD"
        //     let parts = dateString.split(separator: "-").compactMap { Int($0) }
        //     guard parts.count == 2 else { return Date() }
        //     var comps = DateComponents(month: parts[0], day: parts[1])
        //     comps.year = Calendar.current.component(.year, from: Date())
        //     var d = Calendar.current.date(from: comps) ?? Date()
        //     if d < Date() { d = Calendar.current.date(byAdding: .year, value: 1, to: d) ?? d }
        //     return d
        // }
        return event.date
    }

    static func upcomingEvents(from events: [FamilyEvent], limit: Int = 5) -> [FamilyEvent] {
        events
            .filter { parseEventDate($0) >= Date() }
            .sorted { parseEventDate($0) < parseEventDate($1) }
            .prefix(limit)
            .map { $0 }
    }

    static func recentMessages(
        from messages: [FeedMessage],
        excludingAuthor currentUserName: String,
        limit: Int = 5
    ) -> [FeedMessage] {
        messages
            .filter { $0.authorName != currentUserName }
            .sorted { $0.createdDate > $1.createdDate }
            .prefix(limit)
            .map { $0 }
    }

    static func unreadNotifications(from notifications: [AppNotification], limit: Int = 5) -> [AppNotification] {
        notifications
            .filter { !$0.isRead }
            .sorted { $0.createdDate > $1.createdDate }
            .prefix(limit)
            .map { $0 }
    }

    /// Ranks content into FeedItems by priority – mirrors the AI prompt logic locally.
    /// Priority rules (from the prompt in getPersonalizedFeed.ts):
    ///   1. Unread messages from family        → high
    ///   2. Events within next 7 days          → high
    ///   3. Recent photos (last week)          → medium
    ///   4. Unread notifications               → medium
    ///   5. Recent journal entries             → low
    static func buildPersonalizedFeed(
        messages: [FeedMessage],
        events: [FamilyEvent],
        albums: [Album],
        notifications: [AppNotification],
        journalEntries: [JournalEntry],
        currentUserName: String
    ) -> (items: [FeedItem], quickActions: [QuickAction], sectionPriorities: SectionPriorities) {

        var items: [FeedItem] = []
        var actions: [QuickAction] = []
        let now = Date()
        let oneWeek: TimeInterval = 7 * 24 * 3600

        // 1. Unread messages → high priority
        let unread = messages.filter { $0.authorName != currentUserName }
        if !unread.isEmpty {
            items.append(FeedItem(
                id: "msg-summary",
                type: .message,
                title: "Unread Messages",
                description: "\(unread.count) new message\(unread.count == 1 ? "" : "s") from your family",
                priority: .high
            ))
            if let latest = unread.first {
                actions.append(QuickAction(
                    id: "reply-\(latest.id)",
                    label: "Reply to \(latest.authorName)",
                    description: latest.content,
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .blue
                ))
            }
        }

        // 2. Events within 7 days → high priority
        let soonEvents = events.filter {
            let d = parseEventDate($0)
            return d >= now && d <= now.addingTimeInterval(oneWeek)
        }
        for event in soonEvents.prefix(3) {
            let daysAway = Calendar.current.dateComponents([.day], from: now, to: parseEventDate(event)).day ?? 0
            let when = daysAway == 0 ? "Today" : daysAway == 1 ? "Tomorrow" : "In \(daysAway) days"
            items.append(FeedItem(
                id: "event-\(event.id)",
                type: .event,
                title: event.title,
                description: when,
                priority: .high
            ))
            actions.append(QuickAction(
                id: "rsvp-\(event.id)",
                label: "RSVP to \(event.title)",
                description: when,
                icon: "calendar.badge.checkmark",
                color: .orange
            ))
        }

        // 3. Recent albums / photos → medium priority
        let recentAlbums = albums.prefix(3)
        if !recentAlbums.isEmpty {
            items.append(FeedItem(
                id: "photos-summary",
                type: .photo,
                title: "New Photo Memories",
                description: "\(recentAlbums.count) album\(recentAlbums.count == 1 ? "" : "s") added recently",
                priority: .medium
            ))
        }

        // 4. Unread notifications → medium priority
        let unreadNotifs = notifications.filter { !$0.isRead }
        if !unreadNotifs.isEmpty {
            items.append(FeedItem(
                id: "notif-summary",
                type: .notification,
                title: "Notifications",
                description: "\(unreadNotifs.count) unread notification\(unreadNotifs.count == 1 ? "" : "s")",
                priority: .medium
            ))
        }

        // 5. Recent journal entries → low priority
        let recentJournal = journalEntries
            .filter { now.timeIntervalSince($0.createdDate) < oneWeek }
            .prefix(2)
        for entry in recentJournal {
            items.append(FeedItem(
                id: "journal-\(entry.id)",
                type: .journal,
                title: entry.title,
                description: "by \(entry.authorName)",
                priority: .low
            ))
        }

        // Section priorities (mirrors section_priorities in the API response)
        let priorities = SectionPriorities(
            messages: unread.count > 0 ? 4 : 1,
            events: soonEvents.count > 0 ? 3 : 2,
            photos: recentAlbums.isEmpty ? 1 : 2,
            journal: recentJournal.isEmpty ? 1 : 2
        )

        let sortedItems = items.sorted { $0.priority > $1.priority }.prefix(5).map { $0 }
        return (sortedItems, Array(actions.prefix(3)), priorities)
    }
}

// MARK: - Greeting Helpers  (from Home.jsx getGreeting())

private func timeOfDayGreeting() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 12 { return "Good morning" }
    if hour < 18 { return "Good afternoon" }
    return "Good evening"
}

private func initials(for name: String) -> String {
    name.split(separator: " ")
        .compactMap { $0.first.map { String($0) } }
        .joined()
        .uppercased()
        .prefix(2)
        .map { String($0) }
        .joined()
}

// MARK: - Greeting Header  (mirrors top section of Home.jsx)

struct GreetingHeaderView: View {
    let user: User?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeOfDayGreeting())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(user?.name ?? "Guest")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            Spacer()

            // Avatar circle – mirrors the profile picture / initials fallback in Home.jsx
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                Text(initials(for: user?.name ?? "?"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Family Banner  (mirrors the rose gradient Card in Home.jsx)

struct FamilyBannerCard: View {
    let familyName: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.97, green: 0.44, blue: 0.44),
                                 Color(red: 0.93, green: 0.35, blue: 0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .pink.opacity(0.4), radius: 8, y: 4)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 48, height: 48)
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(familyName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

// MARK: - Quick Links Row  (mirrors the 3-icon grid in Home.jsx)

struct QuickLinksRow: View {
    struct QuickLink: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
    }

    let links: [QuickLink] = [
        QuickLink(name: "Messages", icon: "message.fill"),
        QuickLink(name: "Events",   icon: "calendar"),
        QuickLink(name: "Albums",   icon: "camera.fill")
    ]

    /// Provide a binding or callback to drive navigation in your app
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(links) { link in
                Button { onSelect(link.name) } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 48)
                            Image(systemName: link.icon)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        Text(link.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Upcoming Events Section  (mirrors Home.jsx upcomingEvents block)

struct UpcomingEventsSection: View {
    let events: [FamilyEvent]

    private var upcoming: [FamilyEvent] {
        PersonalizedFeedEngine.upcomingEvents(from: events, limit: 3)
    }

    var body: some View {
        if upcoming.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Upcoming Events", destination: "Events")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcoming) { event in
                            EventCard(event: event)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct EventCard: View {
    let event: FamilyEvent
    private var date: Date { PersonalizedFeedEngine.parseEventDate(event) }

    var body: some View {
        HStack(spacing: 12) {
            // Date badge  (mirrors the amber→rose gradient box in Home.jsx)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.3), Color.pink.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 56, height: 64)

                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.day()))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)

                    Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("by \(event.createdBy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .frame(width: 240)
    }
}

// MARK: - Recent Messages Section  (mirrors Home.jsx Recent Messages block)

struct RecentMessagesSection: View {
    let messages: [FeedMessage]
    let currentUserName: String

    private var recent: [FeedMessage] {
        PersonalizedFeedEngine.recentMessages(
            from: messages,
            excludingAuthor: currentUserName,
            limit: 5
        )
    }

    var body: some View {
        if recent.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Recent Messages", destination: "Chat")

                VStack(spacing: 10) {
                    ForEach(recent) { message in
                        MessageCard(message: message)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct MessageCard: View {
    let message: FeedMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "person.2.fill")
                    .font(.callout)
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.authorName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(message.content)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(message.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Photo Memories Section  (mirrors Home.jsx Photo Memories / Albums block)

struct PhotoMemoriesSection: View {
    let albums: [Album]

    private var displayed: [Album] { Array(albums.prefix(4)) }

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        if displayed.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Photo Memories", destination: "Albums")

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(displayed) { album in
                        AlbumThumbnail(album: album)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct AlbumThumbnail: View {
    let album: Album

    var body: some View {
        ZStack(alignment: .bottom) {
            // Cover image or gradient placeholder (mirrors Home.jsx camera placeholder)
            if let url = album.coverImage, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        albumPlaceholder
                    }
                }
            } else {
                albumPlaceholder
            }

            // Title overlay  (mirrors `absolute inset-x-0 bottom-0 bg-gradient-to-t` in Home.jsx)
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(album.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }

    private var albumPlaceholder: some View {
        LinearGradient(
            colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundColor(.pink.opacity(0.5))
        )
    }
}

// MARK: - Personalized Feed Section  (from getPersonalizedFeed.ts AI recommendations)

struct PersonalizedFeedSection: View {
    let items: [FeedItem]

    var body: some View {
        if items.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("For You")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(items) { item in
                        FeedItemRow(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct FeedItemRow: View {
    let item: FeedItem

    var priorityAccent: Color {
        switch item.priority {
        case .high:   return .red.opacity(0.8)
        case .medium: return .orange.opacity(0.8)
        case .low:    return .gray.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: item.type.icon)
                    .font(.callout)
                    .foregroundColor(item.type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Priority indicator
            Circle()
                .fill(priorityAccent)
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Quick Actions Row  (from getPersonalizedFeed.ts quick_actions)

struct QuickActionsRow: View {
    let actions: [QuickAction]

    var body: some View {
        if actions.isEmpty { EmptyView() } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(actions) { action in
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.caption)
                            Text(action.label)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(action.color.opacity(0.12))
                        .foregroundColor(action.color)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Shared Section Header

private struct SectionHeader: View {
    let title: String
    let destination: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Button("View all") { /* drive navigation via your router */ }
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.pink)
        }
        .padding(.horizontal)
    }
}
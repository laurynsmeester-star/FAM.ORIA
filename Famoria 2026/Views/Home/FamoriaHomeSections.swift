//
//  FamoriaHomeSections.swift
//  Famoria 2026
//
//  Created by Claude – translates additional Home.jsx sections into SwiftUI.
//  All base44 references intentionally omitted.
//
//  Provides:
//    • FamilyMembersSection    – horizontal avatars, 6 most-recent active members
//    • UpdatesSection          – summary card with bullet rows (messages/events/photos)
//    • AIQuickActionsGrid      – 2-col grid of "Reply / Plan / Upload" cards
//    • UpcomingEventsList      – vertical list of event cards with date badge
//    • CelebrationCountdown    – placeholder that matches the web component name
//
//  Wire these up inside any page that needs them (e.g. EnhancedHomeTab).
//

import SwiftUI

// MARK: - Shared Helpers

private enum HomeSectionTheme {
    static let rose       = Color(red: 0.96, green: 0.31, blue: 0.43)   // rose-500
    static let violet     = Color(red: 0.55, green: 0.36, blue: 0.96)   // violet-500
    static let slateText  = Color(red: 0.20, green: 0.25, blue: 0.33)   // slate-700
    static let slateLight = Color(red: 0.58, green: 0.64, blue: 0.72)   // slate-400

    static let avatarPlaceholder = LinearGradient(
        colors: [
            Color(red: 0.86, green: 0.84, blue: 0.96),   // violet-200
            Color(red: 0.99, green: 0.81, blue: 0.81)    // rose-200
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dateBadge = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.93, blue: 0.80),   // amber-100
            Color(red: 0.99, green: 0.89, blue: 0.89)    // rose-100
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Mirrors the `getInitials` helper referenced in Home.jsx.
private func getInitials(for name: String) -> String {
    let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
    return parts.prefix(2).joined().uppercased()
}

// MARK: - Section Heading  (mirrors the flex/justify-between heading block)

private struct HomeSectionHeading: View {
    let title: String
    var linkText: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(HomeSectionTheme.slateText)

            Spacer()

            if let onTap = onTap {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        if let linkText = linkText {
                            Text(linkText)
                                .font(.footnote)
                        }
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundColor(HomeSectionTheme.rose)
                }
                .buttonStyle(.plain)
            }
            // When there is no onTap action, render no trailing arrow at all
            // (the previous behavior of a disabled grey arrow was misleading).
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Family Members Section
// Mirrors the `{/* Family Members */}` block.

struct FamilyMembersSection: View {
    let members: [User]
    var onMemberTap: (User) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    private var displayed: [User] { Array(members.prefix(6)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeading(title: "Family Members")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(displayed) { member in
                        Button { onMemberTap(member) } label: {
                            VStack(spacing: 8) {
                                MemberAvatar(member: member)

                                Text(member.name)
                                    .font(.footnote)
                                    .foregroundColor(HomeSectionTheme.slateText)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

private struct MemberAvatar: View {
    let member: User

    var body: some View {
        AvatarView(
            name: member.name,
            imageURL: member.avatarURL,
            size: 64,
            tint: HomeSectionTheme.slateText
        )
    }
}

// MARK: - Updates Section
// Mirrors the `{/* Updates Section */}` card of bullet rows.

struct UpdatesSection: View {
    let latestMessage: FeedMessage?
    let hasUpcomingEvents: Bool
    let hasRecentAlbums: Bool
    var nextEventTitle: String? = nil
    var nextEventDate: Date? = nil
    var recentAlbumTitle: String? = nil

    /// Tapping the "Message from …" row.
    var onMessageTap: () -> Void = {}
    /// Tapping the "Upcoming: …" row.
    var onEventTap: () -> Void = {}
    /// Tapping the "New album: …" row.
    var onAlbumTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeading(title: "Updates")

            VStack(spacing: 14) {
                // Row 1: messages
                if let message = latestMessage {
                    BulletRow(
                        bulletColor: HomeSectionTheme.rose,
                        title: "Message from \(message.authorName)",
                        detail: shortened(message.content),
                        onTap: onMessageTap
                    )
                } else {
                    BulletRow(
                        bulletColor: HomeSectionTheme.slateLight,
                        title: "No recent messages",
                        detail: "Start a conversation with your family!",
                        onTap: onMessageTap
                    )
                }

                // Row 2: events
                if hasUpcomingEvents, let title = nextEventTitle {
                    BulletRow(
                        bulletColor: HomeSectionTheme.violet,
                        title: "Upcoming: \(title)",
                        detail: nextEventDate.map { dateRelative($0) } ?? "Coming up soon",
                        onTap: onEventTap
                    )
                } else if !hasUpcomingEvents {
                    BulletRow(
                        bulletColor: HomeSectionTheme.slateLight,
                        title: "No upcoming events",
                        detail: "Currently, there are no family events scheduled. Plan something fun together soon!",
                        onTap: onEventTap
                    )
                }

                // Row 3: photos
                if hasRecentAlbums, let title = recentAlbumTitle {
                    BulletRow(
                        bulletColor: HomeSectionTheme.rose,
                        title: "New album: \(title)",
                        detail: "Check out the latest family photos.",
                        onTap: onAlbumTap
                    )
                } else if !hasRecentAlbums {
                    BulletRow(
                        bulletColor: HomeSectionTheme.slateLight,
                        title: "No recent photos",
                        detail: "You haven't uploaded any new photos this week. Share a moment with your family!",
                        onTap: onAlbumTap
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }

    private func shortened(_ text: String) -> String {
        let trimmed = text.prefix(100)
        return trimmed.count == text.count ? String(trimmed) : "\(trimmed)..."
    }

    private func dateRelative(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days == -1 { return "Yesterday" }
        if days > 0 && days < 7 { return "In \(days) days" }
        if days < 0 && days > -7 { return "\(-days) days ago" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct BulletRow: View {
    let bulletColor: Color
    let title: String
    let detail: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(bulletColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(HomeSectionTheme.slateText)
                    Text(detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

// MARK: - AI-Powered Quick Actions
// Mirrors the `{/* AI-Powered Quick Actions */}` 2-col grid.

struct AIQuickActionsGrid: View {
    let latestMessageAuthor: String?
    var onReply: () -> Void = {}
    var onPlanEvent: () -> Void = {}
    var onUploadPhoto: () -> Void = {}

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            AIActionCard(
                title: "Reply to \(latestMessageAuthor ?? "family")'s message",
                detail: "Stay connected by responding to the message from \(latestMessageAuthor ?? "your family").",
                action: onReply
            )

            AIActionCard(
                title: "Plan an event",
                detail: "Create a family event and invite everyone for some quality time.",
                action: onPlanEvent
            )

            AIActionCard(
                title: "Upload a photo",
                detail: "Share a recent moment with your family to keep everyone updated.",
                action: onUploadPhoto
            )
        }
    }
}

private struct AIActionCard: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundColor(HomeSectionTheme.violet)

                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(HomeSectionTheme.slateText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming Events List
// Mirrors the `{/* Upcoming Events */}` block (vertical cards with date badge).

struct UpcomingEventsList: View {
    let events: [FamilyEvent]
    var onEventTap: (FamilyEvent) -> Void = { _ in }
    var onSeeAll: () -> Void = {}

    var body: some View {
        if events.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeading(title: "Upcoming Events",
                                   linkText: "View all",
                                   onTap: onSeeAll)

                VStack(spacing: 10) {
                    ForEach(events) { event in
                        Button { onEventTap(event) } label: {
                            UpcomingEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct UpcomingEventRow: View {
    let event: FamilyEvent

    var body: some View {
        HStack(spacing: 16) {
            // Date badge (mirrors the amber→rose gradient min-w-[60px] block)
            VStack(spacing: 2) {
                Text(event.upcomingDate.formatted(.dateTime.day()))
                    .font(.title).fontWeight(.bold)
                    .foregroundColor(HomeSectionTheme.rose)

                Text(event.upcomingDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2).fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 60, minHeight: 60)
            .padding(10)
            .background(HomeSectionTheme.dateBadge)
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(HomeSectionTheme.slateText)
                    .lineLimit(2)

                // event_type in the web model — surfaced from createdBy as a fallback here
                Text("by \(event.createdBy)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Celebration Countdown

struct CelebrationCountdown: View {
    let currentUserName: String?
    var nextEvent: FamilyEvent? = nil
    var onTap: () -> Void = {}

    private var daysUntil: Int? {
        guard let event = nextEvent else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: event.upcomingDate)).day
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                if let event = nextEvent, let days = daysUntil, days >= 0 {
                    VStack(alignment: .center, spacing: 4) {
                        Text("Countdown to...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                        Text("\(days)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text(days == 1 ? "DAY" : "DAYS")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                        Text("until \(event.title)!")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("No upcoming events")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.85, green: 0.65, blue: 0.95),
                        Color(red: 0.96, green: 0.70, blue: 0.65),
                        Color(red: 0.98, green: 0.85, blue: 0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Family Member Profile Sheet

/// Lightweight read-only profile shown when tapping a family member bubble
/// (or selecting one in the search overlay). Avoids routing to the Family Tree.
struct FamilyMemberProfileSheet: View {
    let member: User
    @Environment(\.dismiss) private var dismiss

    private var initials: String {
        member.name.split(separator: " ").compactMap { $0.first.map(String.init) }
            .prefix(2).joined().uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                        Text(initials)
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 16)

                    VStack(spacing: 6) {
                        Text(member.name)
                            .font(.title2.weight(.bold))
                        Text(member.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let role = member.role {
                            Text(role.rawValue.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(roleColor(role))
                                .cornerRadius(12)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func roleColor(_ role: MemberRole) -> Color {
        switch role {
        case .owner: return .orange
        case .admin: return .purple
        case .member: return .blue
        }
    }
}

// MARK: - User Tasks Card

struct UserTasksCard: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = UserTasksStore()
    @State private var newTaskText = ""
    @State private var showAddField = false

    /// Called when the user taps an event-assigned task. EnhancedHomeTab
    /// uses this to set `appState.pendingEventDate` and switch to the
    /// events tab.
    var onOpenEvent: (AssignedEventTask) -> Void = { _ in }

    /// Combined list: personal tasks first, then event tasks the user is
    /// assigned to. Limited to a few rows because the card sits in a side-
    /// by-side column on the home page.
    private var combinedRowCount: Int {
        store.tasks.count + store.assignedEventTasks.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tasks")
                    .font(.caption.weight(.bold))
                    .foregroundColor(HomeSectionTheme.slateText)
                Spacer()
                Button { showAddField.toggle() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .accessibilityLabel("Add task")
            }

            if combinedRowCount == 0 && !showAddField {
                Text("No tasks yet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(store.tasks.prefix(4)) { task in
                HStack(spacing: 8) {
                    Button {
                        if !task.isDone { Haptics.success() } else { Haptics.selection() }
                        store.toggle(task.id)
                    } label: {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline)
                            .foregroundColor(task.isDone ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(task.title)
                        .font(.caption)
                        .strikethrough(task.isDone)
                        .foregroundColor(task.isDone ? .secondary : .primary)
                        .lineLimit(1)
                }
            }

            ForEach(store.assignedEventTasks.prefix(max(0, 4 - store.tasks.count)), id: \.id) { task in
                HStack(spacing: 8) {
                    Button {
                        if !task.isDone { Haptics.success() } else { Haptics.selection() }
                        store.toggleAssignedEventTask(task)
                    } label: {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline)
                            .foregroundColor(task.isDone ? .green : .blue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onOpenEvent(task)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(task.title)
                                .font(.caption)
                                .strikethrough(task.isDone)
                                .foregroundColor(task.isDone ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if showAddField {
                HStack(spacing: 6) {
                    TextField("New task", text: $newTaskText)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        addTask()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.purple)
                    }
                    .disabled(newTaskText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .onAppear { startIfPossible() }
        .onDisappear { store.stop() }
        .onChange(of: appState.currentUser?.id) { _, _ in
            startIfPossible()
        }
        .onChange(of: appState.currentFamily?.id) { _, _ in
            startIfPossible()
        }
    }

    private func startIfPossible() {
        guard let uid = appState.currentUser?.id else {
            store.stop()
            return
        }
        store.start(userId: uid)
        if let familyId = appState.currentFamily?.id,
           let name = appState.currentUser?.name, !name.isEmpty {
            store.startAssignedEventTasks(familyId: familyId, userName: name)
        }
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.add(title: trimmed)
        newTaskText = ""
        showAddField = false
    }
}

// MARK: - Preview

#Preview("Home Sections") {
    let sampleUsers: [User] = [
        User(id: "1", name: "Mom",    email: "mom@example.com",    familyId: "f1", role: .admin),
        User(id: "2", name: "Dad",    email: "dad@example.com",    familyId: "f1", role: .member),
        User(id: "3", name: "Grandpa",email: "gp@example.com",     familyId: "f1", role: .member),
        User(id: "4", name: "Lauryn", email: "lauryn@example.com", familyId: "f1", role: .member)
    ]

    let sampleEvents: [FamilyEvent] = [
        FamilyEvent(id: "e1", title: "Family Reunion", date: Date().addingTimeInterval(86400 * 3), createdBy: "Mom"),
        FamilyEvent(id: "e2", title: "Mom's Birthday", date: Date().addingTimeInterval(86400 * 6), createdBy: "Lauryn")
    ]

    let latest = FeedMessage(
        id: "m1",
        authorName: "Mom",
        content: "Did you see Grandpa's photos from the trip? He looked so happy in that last one!",
        createdDate: Date().addingTimeInterval(-1800)
    )

    ScrollView {
        VStack(spacing: 24) {
            FamilyMembersSection(members: sampleUsers)
            UpdatesSection(
                latestMessage: latest,
                hasUpcomingEvents: !sampleEvents.isEmpty,
                hasRecentAlbums: false
            )
            AIQuickActionsGrid(latestMessageAuthor: latest.authorName)
            UpcomingEventsList(events: sampleEvents)
            CelebrationCountdown(currentUserName: "Lauryn", nextEvent: sampleEvents.first)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

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
            } else {
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .foregroundColor(HomeSectionTheme.slateLight)
            }
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
            HomeSectionHeading(title: "Family Members", onTap: onSeeAll)

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
        ZStack {
            Circle()
                .fill(HomeSectionTheme.avatarPlaceholder)
                .frame(width: 64, height: 64)

            // Placeholder for AsyncImage(url: member.photoURL) when available
            Text(getInitials(for: member.name))
                .font(.title3).fontWeight(.bold)
                .foregroundColor(HomeSectionTheme.slateText)
        }
    }
}

// MARK: - Updates Section
// Mirrors the `{/* Updates Section */}` card of bullet rows.

struct UpdatesSection: View {
    let latestMessage: FeedMessage?
    let hasUpcomingEvents: Bool
    let hasRecentAlbums: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeading(title: "Updates")

            VStack(spacing: 14) {
                // Row 1: messages
                if let message = latestMessage {
                    BulletRow(
                        bulletColor: HomeSectionTheme.rose,
                        title: "Message from \(message.authorName)",
                        detail: shortened(message.content)
                    )
                } else {
                    BulletRow(
                        bulletColor: HomeSectionTheme.slateLight,
                        title: "No recent messages",
                        detail: "Start a conversation with your family!"
                    )
                }

                // Row 2: events (only when there are none, per the original)
                if !hasUpcomingEvents {
                    BulletRow(
                        bulletColor: HomeSectionTheme.slateLight,
                        title: "No upcoming events",
                        detail: "Currently, there are no family events scheduled. Plan something fun together soon!"
                    )
                }

                // Row 3: photos (only when there are none, per the original)
                if !hasRecentAlbums {
                    BulletRow(
                        bulletColor: HomeSectionTheme.slateLight,
                        title: "No recent photos",
                        detail: "You haven't uploaded any new photos this week. Share a moment with your family!"
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
}

private struct BulletRow: View {
    let bulletColor: Color
    let title: String
    let detail: String

    var body: some View {
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
                Text(event.date.formatted(.dateTime.day()))
                    .font(.title).fontWeight(.bold)
                    .foregroundColor(HomeSectionTheme.rose)

                Text(event.date.formatted(.dateTime.month(.abbreviated)).uppercased())
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
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: event.date)).day
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

// MARK: - User Tasks Card

struct UserTasksCard: View {
    @AppStorage("famoria.userTasks") private var tasksData: Data = Data()
    @State private var tasks: [UserTask] = []
    @State private var newTaskText = ""
    @State private var showAddField = false

    struct UserTask: Identifiable, Codable {
        let id: String
        var title: String
        var isDone: Bool
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
            }

            if tasks.isEmpty && !showAddField {
                Text("No tasks yet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(tasks.prefix(4)) { task in
                HStack(spacing: 8) {
                    Button {
                        toggleTask(task.id)
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
        .onAppear { loadTasks() }
    }

    private func loadTasks() {
        guard !tasksData.isEmpty else { return }
        if let decoded = try? JSONDecoder().decode([UserTask].self, from: tasksData) {
            tasks = decoded
        }
    }

    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            tasksData = encoded
        }
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks.append(UserTask(id: UUID().uuidString, title: trimmed, isDone: false))
        newTaskText = ""
        showAddField = false
        saveTasks()
    }

    private func toggleTask(_ id: String) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isDone.toggle()
            // Move completed tasks to end after a delay
            if tasks[idx].isDone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tasks.removeAll { $0.id == id && $0.isDone }
                    saveTasks()
                }
            }
            saveTasks()
        }
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

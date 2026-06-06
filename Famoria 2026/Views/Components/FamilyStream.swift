//
//  FamilyStream.swift
//  Famoria 2026
//
//  Builds the merged "Family Stream" feed for the home page — a single
//  chronological list of recent posts, new events, new uploads, journal
//  snippets, and "On This Day" memories surfaced from past years.
//
//  Lives as a pure helper that takes the raw arrays AppState already
//  observes (events, posts, etc.) and returns a sorted [StreamItem]
//  the home tab can render with one ForEach.
//

import SwiftUI

/// One item in the merged home stream. Each `kind` decides the icon,
/// colour, and tap-destination the StreamCard renders.
struct StreamItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case post(FamilyPost)
        case event(FamilyEvent)
        case onThisDay(FamilyPost)
        case albumActivity(authorName: String, title: String)
    }

    let id: String
    let date: Date
    let kind: Kind

    var icon: String {
        switch kind {
        case .post:            return "bubble.left.fill"
        case .event:           return "calendar"
        case .onThisDay:       return "sparkles"
        case .albumActivity:   return "photo.on.rectangle.angled"
        }
    }

    var iconColor: Color {
        switch kind {
        case .post:            return .purple
        case .event:           return .orange
        case .onThisDay:       return .pink
        case .albumActivity:   return .blue
        }
    }

    var headline: String {
        switch kind {
        case .post(let post):
            return "\(post.authorName) shared"
        case .event(let event):
            return event.title
        case .onThisDay(let post):
            return "On this day · \(post.authorName)"
        case .albumActivity(let author, _):
            return "\(author) added to an album"
        }
    }

    var body: String {
        switch kind {
        case .post(let post):           return post.content
        case .event(let event):
            let df = DateFormatter()
            df.dateStyle = .medium
            return df.string(from: event.upcomingDate)
        case .onThisDay(let post):      return post.content
        case .albumActivity(_, let t):  return t
        }
    }
}

enum FamilyStreamBuilder {
    /// Returns up to `limit` items merged in descending date order.
    /// `posts` and `events` come from AppState. `onThisDay` is computed
    /// from posts whose month+day match today but in earlier years.
    static func build(
        posts: [FamilyPost],
        events: [FamilyEvent],
        limit: Int = 25
    ) -> [StreamItem] {
        var items: [StreamItem] = []

        // Posts (latest 20) — split human posts from album-activity
        // posts (which are tagged with `activityKind == "album_..."`).
        for post in posts.prefix(20) {
            if let raw = post.activityKind, raw.hasPrefix("album") {
                items.append(StreamItem(
                    id: "album-\(post.id)",
                    date: post.timestamp,
                    kind: .albumActivity(authorName: post.authorName, title: post.content)
                ))
            } else {
                items.append(StreamItem(
                    id: "post-\(post.id)",
                    date: post.timestamp,
                    kind: .post(post)
                ))
            }
        }

        // Upcoming events — surfaces the next 5 chronologically.
        let upcomingCutoff = Calendar.current.startOfDay(for: Date())
        let upcoming = events
            .filter { $0.upcomingDate >= upcomingCutoff }
            .sorted { $0.upcomingDate < $1.upcomingDate }
            .prefix(5)
        for event in upcoming {
            items.append(StreamItem(
                id: "event-\(event.id)",
                date: event.upcomingDate,
                kind: .event(event)
            ))
        }

        // "On this day" — posts whose month+day match today's, from
        // any year other than this one.
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        for post in posts {
            let comps = cal.dateComponents([.year, .month, .day], from: post.timestamp)
            if comps.month == today.month,
               comps.day == today.day,
               comps.year != cal.component(.year, from: Date()) {
                items.append(StreamItem(
                    id: "onthisday-\(post.id)",
                    date: Date(),
                    kind: .onThisDay(post)
                ))
            }
        }

        // Sort newest-first, then cap.
        items.sort { $0.date > $1.date }
        return Array(items.prefix(limit))
    }
}

// MARK: - Card UI

struct StreamCard: View {
    let item: StreamItem
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.iconColor.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: item.icon)
                        .foregroundColor(item.iconColor)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(item.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    Text(item.date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabel))
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily Prompt Card

/// Rotating "what made you smile today?" prompt that posts the answer
/// as a normal FamilyPost (with a `dailyPrompt` activityKind) when the
/// user taps Share.
struct DailyPromptCard: View {
    @EnvironmentObject var appState: AppState
    @State private var answer = ""
    @State private var isSubmitting = false

    /// 14 prompts rotated by day-of-year so each user sees the same one
    /// for any given calendar day.
    private static let prompts: [String] = [
        "What made you smile today?",
        "Share one small win from today.",
        "Who in the family are you grateful for right now?",
        "What's something new you learned this week?",
        "Share a photo or memory you've been thinking about.",
        "What are you most excited about this week?",
        "What's one thing you'd love to do as a family soon?",
        "Drop a song that's on repeat for you lately.",
        "Share a recipe or meal you'd recommend.",
        "What's the best thing you ate today?",
        "Drop a quote that's stuck with you.",
        "Tell the family something proud-worthy.",
        "Share a tiny act of kindness you saw today.",
        "What's a goal you're working on?"
    ]

    private var prompt: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.prompts[dayOfYear % Self.prompts.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Today's family prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.purple)
            }
            Text(prompt)
                .font(.headline)

            TextField("Share with the family…", text: $answer, axis: .vertical)
                .lineLimit(1...3)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

            HStack {
                Spacer()
                Button {
                    submit()
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Sharing…" : "Share")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(answer.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray
                                : Color.purple)
                    .cornerRadius(10)
                }
                .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color.purple.opacity(0.10), Color.pink.opacity(0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
    }

    private func submit() {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        Haptics.send()
        let body = "\(prompt)\n\n\(trimmed)"
        Task {
            do {
                try await appState.createPost(content: body)
                await MainActor.run {
                    answer = ""
                    isSubmitting = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    Haptics.warning()
                }
            }
        }
    }
}

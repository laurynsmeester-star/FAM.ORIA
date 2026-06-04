//
//  HomePageView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI
import EventKit
import os
import PhotosUI

/// The main home page view shown after successful authentication
struct HomePageView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage: FamoriaPage = .home

    var body: some View {
        FamoriaLayoutView(
            currentPage: $currentPage
        ) {
            switch currentPage {
            case .home:
                EnhancedHomeTab(onNavigate: { page in currentPage = page })
            case .events:
                CalendarTab()
            case .albums:
                AlbumsView()
            case .familyTree:
                familyTreeTab
            case .profile:
                ProfileTab()
            case .chat:
                DirectMessagesView(onNavigate: { page in currentPage = page })
            case .familySettings:
                FamilyAdminView()
            case .familyUpdates:
                FamilyUpdatesView(onNavigate: { page in currentPage = page })
            case .documents:
                DocumentsView()
                    .requiresPremium(
                        featureName: "Document Vault",
                        featureBlurb: "Store and share legal, medical, insurance, and family records with privacy controls.",
                        icon: "folder.fill.badge.person.crop"
                    )
            case .journal:
                FamilyJournalView()
            case .recipes:
                RecipesView()
            case .health:
                FamilyHealthView()
                    .requiresPremium(
                        featureName: "Health Center",
                        featureBlurb: "Track appointments, set health goals, and generate printable family summaries.",
                        icon: "heart.text.square"
                    )
            case .menu:
                EnhancedHomeTab(onNavigate: { page in currentPage = page })
            }
        }
        .onChange(of: appState.deepLinkPage) { _, newPage in
            if let newPage {
                currentPage = newPage
                appState.deepLinkPage = nil
            }
        }
    }

    /// Builds the interactive family tree view with the current user's context.
    @ViewBuilder
    private var familyTreeTab: some View {
        if let familyId = appState.currentFamily?.id,
           let user = appState.currentUser {
            FamilyTreeView(
                familyId: familyId,
                currentUserId: user.id,
                currentUserRole: user.role,
                currentUserDisplayName: user.name,
                currentUserPhotoURL: nil
            )
        } else {
            FamilyTab()
        }
    }
}

// MARK: - Home Tab (legacy, kept for reference)

struct HomeTab: View {
    @EnvironmentObject var appState: AppState
    @State private var newPost = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FamilyHeaderView()

                PostComposerView(newPost: $newPost, onPost: addPost)
                    .padding(.horizontal)
                    .padding(.top)

                VStack(spacing: 20) {
                    FamilyMembersSection(members: appState.currentFamily?.members ?? [])
                    UpdatesSection(
                        latestMessage: nil as FeedMessage?,
                        hasUpcomingEvents: !appState.events.filter { $0.upcomingDate >= Calendar.current.startOfDay(for: Date()) }.isEmpty,
                        hasRecentAlbums: false
                    )
                    AIQuickActionsGrid(latestMessageAuthor: nil)
                    UpcomingEventsList(events: appState.events.filter { $0.upcomingDate >= Calendar.current.startOfDay(for: Date()) })
                    CelebrationCountdown(currentUserName: appState.currentUser?.name)

                    LazyVStack(spacing: 12) {
                        ForEach(appState.posts.sorted { $0.timestamp > $1.timestamp }) { post in
                            PostCard(post: post)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
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

struct FamilyHeaderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentFamily?.name ?? "My Family")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Welcome, \(appState.currentUser?.name ?? "User")!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "house.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct PostComposerView: View {
    @Binding var newPost: String
    let onPost: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Share something with your family...", text: $newPost, axis: .vertical)
                    .lineLimit(1...3)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                Button(action: onPost) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(newPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 8) {
                Button {
                    pasteLink()
                } label: {
                    Label("Paste link", systemImage: "link")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                Spacer()
            }

            if let url = LinkExtractor.firstURL(in: newPost) {
                LinkPreviewView(url: url)
            }
        }
    }

    private func pasteLink() {
        #if canImport(UIKit)
        if let pasted = UIPasteboard.general.string,
           LinkExtractor.firstURL(in: pasted) != nil {
            if newPost.isEmpty {
                newPost = pasted
            } else if !newPost.hasSuffix(" ") {
                newPost += " " + pasted
            } else {
                newPost += pasted
            }
        }
        #endif
    }
}

struct PostCard: View {
    let post: FamilyPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.headline)
                    Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            Text(post.content)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Calendar Tab (custom grid with event dots, edit/plan support)

struct CalendarTab: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var showAddEvent = false
    @State private var calendarAccessGranted = false
    @State private var appleCalendarEvents: [EKEvent] = []
    @State private var showListView = false
    @State private var editingEvent: FamilyEventV2? = nil
    @State private var planningEvent: FamilyEventV2? = nil

    private let eventStore = EKEventStore()
    private let calendar = Calendar.current

    private var monthName: String {
        displayedMonth.formatted(.dateTime.month(.wide))
    }
    private var yearString: String {
        displayedMonth.formatted(.dateTime.year())
    }
    private var allMonths: [String] {
        calendar.monthSymbols
    }
    private var currentMonthIndex: Int {
        calendar.component(.month, from: displayedMonth) - 1
    }

    private var upcomingEvents: [FamilyEvent] {
        appState.events
            .sorted { $0.date < $1.date }
    }

    private func v2Event(from legacy: FamilyEvent) -> FamilyEventV2 {
        let resolvedType: EventType = {
            guard let raw = legacy.eventTypeRaw else { return .other }
            return EventType(rawValue: raw) ?? .other
        }()
        return FamilyEventV2(
            id: legacy.id,
            title: legacy.title,
            date: legacy.date,
            endDate: legacy.endDate,
            startTime: legacy.startTime,
            endTime: legacy.endTime,
            location: legacy.location,
            notes: legacy.notes,
            eventType: resolvedType,
            isRecurring: legacy.isRecurring ?? false,
            createdBy: legacy.createdBy
        )
    }

    private func eventDates() -> Set<DateComponents> {
        var dates = Set<DateComponents>()
        for event in appState.events {
            let start = calendar.startOfDay(for: event.date)
            let end = calendar.startOfDay(for: event.endDate ?? event.date)
            var current = start
            while current <= end {
                dates.insert(calendar.dateComponents([.year, .month, .day], from: current))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        return dates
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $showListView) {
                Label("Calendar", systemImage: "calendar").tag(false)
                Label("List", systemImage: "list.bullet").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if showListView {
                upcomingListView
            } else {
                calendarView
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAddEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(initialDate: selectedDate)
        }
        .sheet(item: $editingEvent) { event in
            AddEventView(editing: event)
        }
        .sheet(item: $planningEvent) { event in
            EventPlanningView(event: event)
        }
        .task {
            await requestCalendarAccess()
        }
        .onAppear { applyPendingEventDate() }
        .onChange(of: appState.pendingEventDate) { _, _ in
            applyPendingEventDate()
        }
    }

    /// If a deep-link asked us to jump to a specific event's date, do it
    /// once, then clear the pending date so refreshes don't re-trigger it.
    private func applyPendingEventDate() {
        guard let date = appState.pendingEventDate else { return }
        selectedDate = date
        displayedMonth = date
        showListView = false
        appState.pendingEventDate = nil
    }

    // MARK: - Custom Calendar Grid

    private var calendarView: some View {
        VStack(spacing: 0) {
            monthNavigationHeader
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            calendarGrid
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))

            if calendarAccessGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Synced with Apple Calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if eventsForSelectedDay.isEmpty && appleCalendarEvents.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No events for this day")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(eventsForSelectedDay) { event in
                            EventRow(event: event, onEdit: {
                                editingEvent = v2Event(from: event)
                            }, onPlan: {
                                planningEvent = v2Event(from: event)
                            })
                            .padding(.horizontal)
                        }

                        if !appleCalendarEvents.isEmpty {
                            Text("From Apple Calendar")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            ForEach(appleCalendarEvents, id: \.eventIdentifier) { ekEvent in
                                AppleCalendarEventRow(event: ekEvent)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Calendar Grid with Event Dots

    private var calendarGrid: some View {
        let daysInMonth = daysForDisplayedMonth()
        let weekdaySymbols = calendar.veryShortWeekdaySymbols
        let eventDaySet = eventDates()

        return VStack(spacing: 6) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(daysInMonth, id: \.self) { dateItem in
                    if let date = dateItem {
                        let day = calendar.component(.day, from: date)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        let comps = calendar.dateComponents([.year, .month, .day], from: date)
                        let hasEvent = eventDaySet.contains(comps)

                        Button {
                            selectedDate = date
                            if calendarAccessGranted {
                                fetchAppleCalendarEvents(for: date)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(day)")
                                    .font(.subheadline.weight(isToday ? .bold : .regular))
                                    .foregroundColor(isSelected ? .white : isToday ? .purple : .primary)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle().fill(isSelected ? Color.purple : isToday ? Color.purple.opacity(0.12) : Color.clear)
                                    )

                                Circle()
                                    .fill(hasEvent ? Color.pink : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 2) {
                            Text("")
                                .frame(width: 34, height: 34)
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func daysForDisplayedMonth() -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            var dc = comps
            dc.day = day
            days.append(calendar.date(from: dc))
        }
        return days
    }

    // MARK: - List View

    private var upcomingListView: some View {
        ScrollView {
            if upcomingEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No events yet")
                        .font(.headline).foregroundColor(.secondary)
                    Text("Tap + to create your first event")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(upcomingEvents) { event in
                        upcomingEventRow(event)
                            .onTapGesture {
                                editingEvent = v2Event(from: event)
                            }
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func upcomingEventRow(_ event: FamilyEvent) -> some View {
        let isPast = event.date < Date()
        let daysAway = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.date)).day ?? 0

        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(event.date.formatted(.dateTime.day()))
                    .font(.title2.weight(.bold))
                    .foregroundColor(isPast ? .secondary : .purple)
                Text(event.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 56, height: 56)
            .background(isPast ? Color(.secondarySystemBackground) : Color.purple.opacity(0.1))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("by \(event.createdBy)")
                        .font(.caption2).foregroundColor(.secondary)
                    if !isPast {
                        Text(daysAway == 0 ? "Today" : daysAway == 1 ? "Tomorrow" : "In \(daysAway) days")
                            .font(.caption2)
                            .foregroundColor(daysAway <= 3 ? .orange : .secondary)
                    } else {
                        Text("Past").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Month Navigation Header

    private var monthNavigationHeader: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(0..<allMonths.count, id: \.self) { index in
                    Button {
                        setMonth(to: index + 1)
                    } label: {
                        HStack {
                            Text(allMonths[index])
                            if index == currentMonthIndex { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(monthName)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Menu {
                let currentYear = Calendar.current.component(.year, from: Date())
                ForEach((currentYear-5)...(currentYear+5), id: \.self) { y in
                    Button {
                        var comps = calendar.dateComponents([.year, .month, .day], from: displayedMonth)
                        comps.year = y
                        if let newDate = calendar.date(from: comps) {
                            withAnimation { displayedMonth = newDate; selectedDate = newDate }
                        }
                    } label: {
                        HStack {
                            Text("\(y)")
                            if "\(y)" == yearString { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(yearString)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                withAnimation {
                    selectedDate = Date()
                    displayedMonth = Date()
                }
            } label: {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 0)

            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Month Navigation Helpers

    private func shiftMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation {
                displayedMonth = newDate
                let comps = calendar.dateComponents([.year, .month], from: newDate)
                if let firstOfMonth = calendar.date(from: comps) {
                    selectedDate = firstOfMonth
                }
            }
        }
    }

    private func setMonth(to month: Int) {
        var comps = calendar.dateComponents([.year, .month, .day], from: displayedMonth)
        comps.month = month
        if let newDate = calendar.date(from: comps) {
            withAnimation {
                displayedMonth = newDate
                selectedDate = newDate
            }
        }
    }

    // MARK: - EventKit Integration

    private func requestCalendarAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                calendarAccessGranted = granted
                if granted {
                    fetchAppleCalendarEvents(for: selectedDate)
                }
            }
        } catch {
            print("Calendar access error: \(error)")
        }
    }

    private func fetchAppleCalendarEvents(for date: Date) {
        guard calendarAccessGranted else { return }

        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        self.appleCalendarEvents = events
    }

    private var eventsForSelectedDay: [FamilyEvent] {
        appState.events.filter { event in
            let start = calendar.startOfDay(for: event.date)
            let end = calendar.startOfDay(for: event.endDate ?? event.date)
            let selected = calendar.startOfDay(for: selectedDate)
            return selected >= start && selected <= end
        }
    }
}

struct EventRow: View {
    let event: FamilyEvent
    var onEdit: () -> Void = {}
    var onPlan: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.purple)
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    HStack {
                        if let startTime = event.startTime {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(startTime.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                        } else {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text("All day")
                                .font(.caption)
                        }
                        Spacer()
                        Text("by \(event.createdBy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Button { onEdit() } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                }

                Button { onPlan() } label: {
                    Label("Plan", systemImage: "checklist")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.pink.opacity(0.1))
                        .foregroundColor(.pink)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct AppleCalendarEventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled")
                    .font(.headline)
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.caption2)
                    if let start = event.startDate {
                        Text(start.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                    }
                    if let location = event.location, !location.isEmpty {
                        Text("• \(location)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Family Tab

struct FamilyTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showInvite = false

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.currentFamily?.name ?? "My Family")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("\(appState.currentFamily?.members.count ?? 0) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        showInvite = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }

            Section("Members") {
                if let members = appState.currentFamily?.members {
                    ForEach(members) { member in
                        MemberRow(member: member)
                    }
                }
            }

            Section("Pending Invites") {
                if appState.pendingInvites.isEmpty {
                    Text("No pending invites")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appState.pendingInvites) { invite in
                        InviteRow(invite: invite)
                    }
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteSheet()
        }
    }
}

struct MemberRow: View {
    let member: User

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.body)
                Text(member.email).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if let role = member.role {
                Text(role.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(role == .admin ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundColor(role == .admin ? .purple : .blue)
                    .cornerRadius(8)
            }
        }
    }
}

struct InviteRow: View {
    @EnvironmentObject var appState: AppState
    let invite: Invite

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.familyName).font(.body)
                Text(invite.invitedEmail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button("Accept") {
                appState.accept(invite: invite)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct InviteSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Invite Family Member")
                } footer: {
                    Text("Enter the email address of the person you want to invite to your family.")
                }
            }
            .navigationTitle("Send Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        appState.createInvite(for: email)
                        dismiss()
                    }
                    .disabled(email.isEmpty || !email.contains("@"))
                }
            }
        }
    }
}

// MARK: - Profile Tab

struct ProfileTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("famoria.darkMode") private var darkMode = false
    @AppStorage("famoria.staySignedIn") private var staySignedIn = true
    @State private var showSignOutAlert = false
    @State private var showEditName = false
    @State private var editedName = ""
    @State private var activeSheet: ProfileSheet?
    @State private var isSendingTestNotification = false
    @State private var testNotificationResult: String?
    @State private var showTestNotificationResult = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    private enum ProfileSheet: String, Identifiable {
        case notifications, security, help, share, subscription
        var id: String { rawValue }
    }

    private var user: User? { appState.currentUser }
    private var family: Family? { appState.currentFamily }
    private var isAdmin: Bool {
        user?.role == .admin || user?.role == .owner
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                        .padding(.top, 16)
                    if let family = family { familyCard(family) }
                    premiumSection
                    settingsSection
                    preferencesSection
                    appearanceSection
                    debugSection
                    dangerSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onChange(of: avatarPickerItem) { _, newItem in
                Task { await handleAvatarSelection(newItem) }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await appState.signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Edit Name", isPresented: $showEditName) {
                TextField("Your name", text: $editedName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        do {
                            try await appState.updateUserName(trimmed)
                        } catch {
                            Log.appState.error("updateUserName failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            } message: {
                Text("Enter your new display name")
            }
            .alert("Test Notification", isPresented: $showTestNotificationResult) {
                Button("OK", role: .cancel) {}
            } message: {
                if let err = testNotificationResult {
                    Text("Failed: \(err)")
                } else {
                    Text("Notification written successfully. Tap the bell to see it.")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .notifications: NotificationPreferencesView()
                case .security: SecuritySettingsView()
                case .help: HelpSupportView()
                case .share: ShareFamoriaSheet(familyName: family?.name ?? "Our Family")
                case .subscription: SubscriptionView().environmentObject(appState)
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)

                        if let urlString = user?.avatarURL,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    Text(initials(for: user?.name ?? ""))
                                        .font(.title).fontWeight(.bold)
                                        .foregroundColor(.purple)
                                }
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                        } else {
                            Text(initials(for: user?.name ?? ""))
                                .font(.title).fontWeight(.bold)
                                .foregroundColor(.purple)
                        }

                        if isUploadingAvatar {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 90, height: 90)
                            ProgressView()
                                .tint(.white)
                        }
                    }

                    Image(systemName: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.purple)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploadingAvatar)
            VStack(spacing: 4) {
                Text(user?.name ?? "User")
                    .font(.title2).fontWeight(.bold)
                Text(user?.email ?? "")
                    .font(.subheadline).foregroundColor(.secondary)
                if let role = user?.role {
                    Text(role.rawValue.capitalized)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(roleBadgeColor(role))
                        .cornerRadius(12)
                        .padding(.top, 4)
                }
            }
            HStack(spacing: 12) {
                Button {
                    editedName = user?.name ?? ""
                    showEditName = true
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(20)
                }

                Button { activeSheet = .share } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.pink)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func handleAvatarSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let jpegData = compressForAvatar(data)
            try await appState.updateUserAvatar(jpegData: jpegData)
        } catch {
            Log.appState.error("updateUserAvatar failed: \(error.localizedDescription, privacy: .public)")
        }
        avatarPickerItem = nil
    }

    /// Re-encodes the picker's selected image into a reasonably-sized JPEG
    /// so we don't push multi-megabyte avatars to Storage.
    private func compressForAvatar(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 512
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1)
        if scale == 1 {
            return image.jpegData(compressionQuality: 0.8) ?? data
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    private func familyCard(_ family: Family) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "house.fill")
                .font(.title2).foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 2) {
                Text(family.name).font(.headline)
                Text("\(family.members.count) member\(family.members.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isAdmin {
                Image(systemName: "crown.fill").foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var premiumSection: some View {
        let entitlements = appState.entitlements
        let subscription = appState.currentFamily?.subscription ?? .free
        let tier = subscription.tier
        let isPremium = entitlements.isPremium

        return VStack(alignment: .leading, spacing: 0) {
            Text("Famoria Plus")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4).padding(.bottom, 8)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: isPremium ? [.purple, .pink] : [.gray.opacity(0.4), .gray.opacity(0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        Image(systemName: isPremium ? "sparkles" : "star")
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.displayName).font(.headline)
                        if isPremium, let exp = subscription.expiresAt {
                            Text("Renews \(exp.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundColor(.secondary)
                        } else if !isPremium {
                            Text("Upgrade to unlock the full app.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                // Storage progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Storage")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(appState.storageQuota.displayString(tier: tier))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: appState.storageQuota.fraction(tier: tier))
                        .tint(appState.storageQuota.isApproachingLimit(tier: tier) ? .orange : .purple)
                }

                if entitlements.canManageBilling {
                    if !isPremium {
                        Button {
                            activeSheet = .subscription
                        } label: {
                            Text("Start free trial")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(LinearGradient(colors: [.purple, .pink],
                                                           startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(12)
                        }
                    } else {
                        Button {
                            Task { await appState.subscriptionManager.openManageSubscriptions() }
                        } label: {
                            Label("Manage Subscription", systemImage: "creditcard")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                    Button {
                        Task { await appState.subscriptionManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4).padding(.bottom, 8)
            VStack(spacing: 0) {
                Button { activeSheet = .notifications } label: {
                    profileRow(icon: "bell.fill", color: .red, title: "Notifications")
                }.buttonStyle(.plain)
                Divider().padding(.leading, 48)
                Button { activeSheet = .security } label: {
                    profileRow(icon: "lock.fill", color: .blue, title: "Privacy & Security")
                }.buttonStyle(.plain)
                Divider().padding(.leading, 48)
                Button { activeSheet = .help } label: {
                    profileRow(icon: "questionmark.circle.fill", color: .green, title: "Help & Support")
                }.buttonStyle(.plain)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Preferences")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4).padding(.bottom, 8)
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "key.fill")
                        .font(.body).foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.teal).cornerRadius(8)
                    Text("Stay Signed In").font(.body)
                    Spacer()
                    Toggle("", isOn: $staySignedIn).labelsHidden()
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Appearance")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4).padding(.bottom, 8)
            HStack(spacing: 14) {
                Image(systemName: darkMode ? "moon.fill" : "sun.max.fill")
                    .font(.body).foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(darkMode ? Color.indigo : Color.orange)
                    .cornerRadius(8)
                Text("Dark Mode").font(.body)
                Spacer()
                Toggle("", isOn: $darkMode).labelsHidden()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Debug")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4).padding(.bottom, 8)

            Button {
                Task {
                    isSendingTestNotification = true
                    testNotificationResult = await appState.sendTestNotificationToSelf()
                    isSendingTestNotification = false
                    showTestNotificationResult = true
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.body).foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.purple).cornerRadius(8)
                    Text("Send Test Notification").font(.body).foregroundColor(.primary)
                    Spacer()
                    if isSendingTestNotification {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .disabled(isSendingTestNotification)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var dangerSection: some View {
        VStack(spacing: 0) {
            Button {
                showSignOutAlert = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.body).foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.orange).cornerRadius(8)
                    Text("Sign Out").font(.body).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func profileRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body).foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color).cornerRadius(8)
            Text(title).font(.body).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }
        .padding()
    }

    private func initials(for name: String) -> String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }

    private func roleBadgeColor(_ role: MemberRole) -> Color {
        switch role {
        case .owner: return .orange
        case .admin: return .purple
        case .member: return .blue
        }
    }
}

// MARK: - Notification Preferences

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("famoria.notif.messages") private var messagesNotif = true
    @AppStorage("famoria.notif.events") private var eventsNotif = true
    @AppStorage("famoria.notif.albums") private var albumsNotif = true
    @AppStorage("famoria.notif.reminders") private var remindersNotif = true
    @AppStorage("famoria.notif.familyUpdates") private var familyUpdatesNotif = true

    var body: some View {
        NavigationStack {
            List {
                Section("Activity") {
                    Toggle("Messages", isOn: $messagesNotif)
                    Toggle("Events & Calendar", isOn: $eventsNotif)
                    Toggle("Photo Albums", isOn: $albumsNotif)
                    Toggle("Family Updates", isOn: $familyUpdatesNotif)
                }
                Section("Reminders") {
                    Toggle("Event Reminders", isOn: $remindersNotif)
                    if remindersNotif {
                        ReminderTimingPicker()
                    }
                }
                Section {
                    Text("Notifications are delivered through Apple's push notification service. You can also manage notifications in Settings > Famoria.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reminder Timing Picker

struct ReminderTimingPicker: View {
    @AppStorage("famoria.reminder.timing") private var reminderTiming = "1day"

    private let options: [(label: String, value: String)] = [
        ("15 minutes before", "15min"),
        ("30 minutes before", "30min"),
        ("1 hour before", "1hour"),
        ("1 day before", "1day"),
        ("1 week before", "1week"),
    ]

    var body: some View {
        Picker("Remind me", selection: $reminderTiming) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("famoria.staySignedIn") private var staySignedIn = true
    @AppStorage("famoria.biometricLock") private var biometricLock = false
    @State private var showChangePassword = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Authentication") {
                    Toggle("Stay Signed In", isOn: $staySignedIn)
                    Toggle("Require Face ID / Touch ID", isOn: $biometricLock)
                }
                Section("Password") {
                    Button("Change Password") { showChangePassword = true }
                }
                Section("Data") {
                    Button("Download My Data") { }
                        .foregroundColor(.primary)
                    Button("Delete Account", role: .destructive) { }
                }
                Section {
                    Text("Your data is encrypted in transit and at rest. We never share your personal information with third parties.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Change Password", isPresented: $showChangePassword) {
                SecureField("Current password", text: $currentPassword)
                SecureField("New password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
                Button("Cancel", role: .cancel) {
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
                Button("Change") {
                    // Password change would integrate with Firebase Auth
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            }
        }
    }
}

// MARK: - Help & Support

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Getting Started") {
                    helpRow(icon: "house.fill", title: "Setting Up Your Family", detail: "Learn how to create or join a family group")
                    helpRow(icon: "person.badge.plus", title: "Inviting Members", detail: "Send invites via email or invite code")
                    helpRow(icon: "camera.fill", title: "Photo Albums", detail: "Create albums and share family photos")
                }
                Section("Features") {
                    helpRow(icon: "calendar", title: "Events & Calendar", detail: "Plan and track family events")
                    helpRow(icon: "message.fill", title: "Messaging", detail: "Chat with family members")
                    helpRow(icon: "person.3.fill", title: "Family Tree", detail: "Build and explore your family tree")
                    helpRow(icon: "book.fill", title: "Journal & Wishlist", detail: "Keep a family journal and wishlists")
                }
                Section("Support") {
                    helpRow(icon: "envelope.fill", title: "Contact Us", detail: "support@famoria.app")
                    helpRow(icon: "star.fill", title: "Rate Famoria", detail: "Leave a review on the App Store")
                    helpRow(icon: "doc.text.fill", title: "Privacy Policy", detail: "View our privacy policy")
                    helpRow(icon: "doc.text.fill", title: "Terms of Service", detail: "View our terms of service")
                }
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Famoria").font(.headline)
                            Text("Version 1.0.0").font(.caption).foregroundColor(.secondary)
                            Text("Made with 💕 for families").font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout).foregroundColor(.purple)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Share Famoria Sheet

struct ShareFamoriaSheet: View {
    @Environment(\.dismiss) private var dismiss
    let familyName: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Share Famoria")
                        .font(.title2).fontWeight(.bold)
                    Text("Invite others to join \(familyName) or recommend Famoria to friends")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    ShareLink(
                        item: "Join our family on Famoria! Download the app and use our family code to connect.",
                        subject: Text("Join \(familyName) on Famoria"),
                        message: Text("I'd love for you to join our family on Famoria!")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Invite Link")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                    }

                    ShareLink(
                        item: "Check out Famoria — the app that keeps families connected! Photos, events, messaging & more.",
                        subject: Text("Try Famoria"),
                        message: Text("You should try Famoria for your family!")
                    ) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Recommend to a Friend")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.purple)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Notifications View

struct NotificationsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if appState.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Notifications")
                            .font(.title3).fontWeight(.semibold)
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(appState.notifications) { notification in
                            NotificationRow(notification: notification)
                                .onTapGesture {
                                    appState.markNotificationRead(notification.id)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        appState.removeNotification(notification.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appState.removeNotification(notification.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    if !notification.isRead {
                                        Button {
                                            appState.markNotificationRead(notification.id)
                                        } label: {
                                            Label("Mark as Read", systemImage: "checkmark.circle")
                                        }
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.map { appState.notifications[$0].id }
                            for id in ids {
                                appState.removeNotification(id)
                            }
                        }

                        if appState.unreadNotificationCount > 0 {
                            Button("Mark All as Read") {
                                appState.markAllNotificationsRead()
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.purple)
                        }

                        Button(role: .destructive) {
                            for n in appState.notifications {
                                appState.removeNotification(n.id)
                            }
                        } label: {
                            Label("Clear All", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: FamoriaNotification

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: notification.type.icon)
                    .font(.callout)
                    .foregroundColor(notification.type.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(notification.isRead ? .secondary : .primary)
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(notification.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomePageView()
        .environmentObject({
            let state = AppState()
            state.isAuthenticated = true
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "f1", role: .admin)
            state.currentFamily = Family(id: "f1", name: "The Doe Family", members: [
                User(id: "1", name: "John Doe", email: "john@example.com", familyId: "f1", role: .admin),
                User(id: "2", name: "Jane Doe", email: "jane@example.com", familyId: "f1", role: .member)
            ])
            state.posts = [
                FamilyPost(id: "1", authorName: "John Doe", content: "Welcome to our family page!", timestamp: Date()),
                FamilyPost(id: "2", authorName: "Jane Doe", content: "Looking forward to our trip this weekend!", timestamp: Date().addingTimeInterval(-3600))
            ]
            state.events = [
                FamilyEvent(id: "1", title: "Family Dinner", date: Date(), createdBy: "John Doe")
            ]
            return state
        }())
}

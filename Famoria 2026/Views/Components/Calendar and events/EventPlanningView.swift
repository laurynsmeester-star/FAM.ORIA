//
//  EventPlanningView.swift
//  Famoria 2026
//
//  Planning sheet for an event — translates the React `EventPlanningDialog`.
//  Tabs (segmented):  RSVP · Tasks · Schedule · Polls
//
//  All data is held in an `@StateObject` view model. Wire it to your
//  Firebase service (or whichever backend) by replacing the
//  in-memory CRUD methods on `EventPlanningStore`.
//

import SwiftUI
import Combine
import FirebaseFirestore
import os

// MARK: - Store / View model

@MainActor
final class EventPlanningStore: ObservableObject {
    @Published var rsvps: [EventRSVP] = []
    @Published var tasks: [EventTask] = []
    @Published var schedule: [EventScheduleItem] = []
    @Published var polls: [EventPoll] = []
    @Published var votes: [PollVote] = []
    @Published var documents: [EventDocument] = []

    let event: FamilyEventV2

    private let service = FirebaseEventPlanningService()
    private var familyId: String?
    private var listeners: [ListenerRegistration] = []

    init(event: FamilyEventV2) { self.event = event }

    deinit {
        for l in listeners { l.remove() }
    }

    /// Begin listening to Firestore for this event's planning data. Idempotent.
    func start(familyId: String) {
        guard self.familyId != familyId else { return }
        self.familyId = familyId
        for l in listeners { l.remove() }
        listeners.removeAll()

        listeners.append(service.observeRSVPs(familyId: familyId, eventId: event.id) { [weak self] items in
            Task { @MainActor in self?.rsvps = items }
        })
        listeners.append(service.observeTasks(familyId: familyId, eventId: event.id) { [weak self] items in
            Task { @MainActor in self?.tasks = items }
        })
        listeners.append(service.observeSchedule(familyId: familyId, eventId: event.id) { [weak self] items in
            Task { @MainActor in self?.schedule = items.sorted { $0.time < $1.time } }
        })
        listeners.append(service.observePolls(familyId: familyId, eventId: event.id) { [weak self] items in
            Task { @MainActor in self?.polls = items }
        })
        listeners.append(service.observeVotes(familyId: familyId, eventId: event.id) { [weak self] items in
            Task { @MainActor in self?.votes = items }
        })
        listeners.append(service.observeDocuments(familyId: familyId, eventId: event.id) { [weak self] items in
            Task { @MainActor in self?.documents = items.sorted { $0.addedDate > $1.addedDate } }
        })
    }

    // RSVP
    func addRSVPs(for members: [String], notes: String) {
        guard let familyId else { return }
        for memberName in members {
            let rsvp = EventRSVP(eventId: event.id, memberName: memberName, status: .pending, guests: 0, notes: notes)
            Task { try? await service.upsert(rsvp: rsvp, familyId: familyId, eventId: event.id) }
        }
    }
    func updateRSVP(_ id: String, status: RSVPStatus) {
        guard let familyId, let i = rsvps.firstIndex(where: { $0.id == id }) else { return }
        var updated = rsvps[i]
        updated.status = status
        Haptics.success()
        Task { try? await service.upsert(rsvp: updated, familyId: familyId, eventId: event.id) }
    }
    func deleteRSVP(_ id: String) {
        guard let familyId else { return }
        Task { try? await service.delete(rsvpId: id, familyId: familyId, eventId: event.id) }
    }

    // Tasks
    func addTask(_ task: EventTask) {
        guard let familyId else { return }
        Task { try? await service.upsert(task: task, familyId: familyId, eventId: event.id) }
    }
    func toggleTask(_ id: String) {
        guard let familyId, let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        var updated = tasks[i]
        updated.isCompleted.toggle()
        if updated.isCompleted { Haptics.success() } else { Haptics.selection() }
        Task { try? await service.upsert(task: updated, familyId: familyId, eventId: event.id) }
    }
    func deleteTask(_ id: String) {
        guard let familyId else { return }
        Task { try? await service.delete(taskId: id, familyId: familyId, eventId: event.id) }
    }

    // Schedule
    func addScheduleItem(_ item: EventScheduleItem) {
        guard let familyId else { return }
        Task { try? await service.upsert(scheduleItem: item, familyId: familyId, eventId: event.id) }
    }
    func deleteScheduleItem(_ id: String) {
        guard let familyId else { return }
        Task { try? await service.delete(scheduleItemId: id, familyId: familyId, eventId: event.id) }
    }

    // Polls
    func addPoll(_ poll: EventPoll) {
        guard let familyId else { return }
        Task { try? await service.upsert(poll: poll, familyId: familyId, eventId: event.id) }
    }
    func deletePoll(_ id: String) {
        guard let familyId else { return }
        Task { try? await service.delete(pollId: id, familyId: familyId, eventId: event.id) }
    }
    func togglePollClosed(_ id: String) {
        guard let familyId, let i = polls.firstIndex(where: { $0.id == id }) else { return }
        var updated = polls[i]
        updated.isClosed.toggle()
        Task { try? await service.upsert(poll: updated, familyId: familyId, eventId: event.id) }
    }
    func castVote(pollId: String, option: String, voter: String) {
        guard let familyId, let poll = polls.first(where: { $0.id == pollId }) else { return }
        // Toggle off if user already voted for this exact option.
        if let existing = votes.first(where: { $0.pollId == pollId && $0.voterName == voter && $0.selectedOption == option }) {
            Task { try? await service.delete(voteId: existing.id, familyId: familyId, eventId: event.id) }
            return
        }
        Task {
            if !poll.multipleChoice {
                // Clear the user's previous vote(s) for this poll.
                for prior in self.votes where prior.pollId == pollId && prior.voterName == voter {
                    try? await service.delete(voteId: prior.id, familyId: familyId, eventId: event.id)
                }
            }
            let newVote = PollVote(pollId: pollId, voterName: voter, selectedOption: option)
            try? await service.upsert(vote: newVote, familyId: familyId, eventId: event.id)
        }
    }

    // Documents
    func addDocument(_ doc: EventDocument) {
        guard let familyId else { return }
        Task { try? await service.upsert(document: doc, familyId: familyId, eventId: event.id) }
    }
    func deleteDocument(_ id: String) {
        guard let familyId else { return }
        Task { try? await service.delete(documentId: id, familyId: familyId, eventId: event.id) }
    }
}

// MARK: - Event Document Model

struct EventDocument: Identifiable, Equatable, Hashable {
    let id: String
    var eventId: String
    var title: String
    var note: String
    var addedBy: String
    var addedDate: Date

    init(
        id: String = UUID().uuidString,
        eventId: String,
        title: String,
        note: String = "",
        addedBy: String,
        addedDate: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.title = title
        self.note = note
        self.addedBy = addedBy
        self.addedDate = addedDate
    }
}

// MARK: - Tabs

enum PlanningTab: String, CaseIterable, Identifiable {
    case rsvp, tasks, schedule, polls, docs
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rsvp:     return "RSVPs"
        case .tasks:    return "Tasks"
        case .schedule: return "Schedule"
        case .polls:    return "Polls"
        case .docs:     return "Docs"
        }
    }
    var icon: String {
        switch self {
        case .rsvp:     return "person.2.fill"
        case .tasks:    return "checkmark.square.fill"
        case .schedule: return "clock.fill"
        case .polls:    return "chart.bar.fill"
        case .docs:     return "doc.text.fill"
        }
    }
}

// MARK: - Main view

struct EventPlanningView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: EventPlanningStore

    @State private var activeTab: PlanningTab

    init(event: FamilyEventV2, initialTab: PlanningTab = .rsvp) {
        _store = StateObject(wrappedValue: EventPlanningStore(event: event))
        _activeTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBlock

                    if let loc = store.event.location, !loc.isEmpty {
                        EventMapView(location: loc, eventTitle: store.event.title)
                    }

                    tabBar

                    Group {
                        switch activeTab {
                        case .rsvp:     RSVPTab(store: store)
                        case .tasks:    TasksTab(store: store)
                        case .schedule: ScheduleTab(store: store)
                        case .polls:    PollsTab(store: store, currentVoter: appState.currentUser?.name ?? "")
                        case .docs:     DocsTab(store: store, currentUser: appState.currentUser?.name ?? "")
                        }
                    }
                    .transition(.opacity)
                }
                .padding()
            }
            .navigationTitle("Plan: \(store.event.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if let familyId = appState.currentFamily?.id {
                    store.start(familyId: familyId)
                }
            }
        }
    }

    // MARK: Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: store.event.eventType.icon)
                    .foregroundColor(store.event.eventType.colors.fill)
                Text(store.event.title)
                    .font(.title3.weight(.semibold))
            }

            Text(headerDateString)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color.pink.opacity(0.10), Color.purple.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private var headerDateString: String {
        let df = DateFormatter()
        df.dateStyle = .full
        let datePart: String
        if store.event.isRecurring {
            let mf = DateFormatter()
            mf.dateFormat = "MMMM d"
            datePart = "Every \(mf.string(from: store.event.date))"
        } else {
            datePart = df.string(from: store.event.date)
        }
        if let s = store.event.startTime {
            let tf = DateFormatter()
            tf.timeStyle = .short
            return "\(datePart) • \(tf.string(from: s))"
        }
        return datePart
    }

    // MARK: Tab bar (custom segmented + counts)

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(PlanningTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { activeTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.body)
                        if let badge = badge(for: tab) {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.7)))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(activeTab == tab ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                    )
                    .foregroundColor(activeTab == tab ? .accentColor : .primary)
                    .accessibilityLabel(tab.title)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func badge(for tab: PlanningTab) -> String? {
        switch tab {
        case .rsvp:
            let n = store.rsvps.filter { $0.status == .attending }.count
            return n > 0 ? "\(n)" : nil
        case .tasks:
            guard !store.tasks.isEmpty else { return nil }
            let done = store.tasks.filter { $0.isCompleted }.count
            return "\(done)/\(store.tasks.count)"
        case .schedule:
            return store.schedule.isEmpty ? nil : "\(store.schedule.count)"
        case .polls:
            return store.polls.isEmpty ? nil : "\(store.polls.count)"
        case .docs:
            return store.documents.isEmpty ? nil : "\(store.documents.count)"
        }
    }
}

// MARK: - RSVP Tab

private struct RSVPTab: View {
    @ObservedObject var store: EventPlanningStore
    @EnvironmentObject var appState: AppState
    @State private var selectedMembers: Set<String> = []
    @State private var notes: String = ""

    private var attendingCount: Int { store.rsvps.filter { $0.status == .attending }.count }
    private var totalGuests: Int { store.rsvps.filter { $0.status == .attending }.reduce(0) { $0 + $1.guests } }

    private var familyNames: [String] {
        appState.currentFamily?.members.map(\.name) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(attendingCount) attending")
                    .font(.subheadline.weight(.semibold))
                Text("• \(totalGuests) guests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color.pink.opacity(0.1), Color.purple.opacity(0.08)],
                                         startPoint: .leading, endPoint: .trailing))
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Invite members")
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                    ForEach(familyNames, id: \.self) { name in
                        Button {
                            if selectedMembers.contains(name) { selectedMembers.remove(name) }
                            else { selectedMembers.insert(name) }
                        } label: {
                            Text(name)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedMembers.contains(name)
                                              ? Color.pink.opacity(0.18) : Color(.secondarySystemBackground))
                                )
                                .foregroundColor(selectedMembers.contains(name) ? .pink : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("Notes (optional)", text: $notes)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.addRSVPs(for: Array(selectedMembers), notes: notes)
                    selectedMembers.removeAll(); notes = ""
                } label: {
                    Label("Send RSVP requests", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(selectedMembers.isEmpty)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            // Existing RSVPs
            ForEach(store.rsvps) { rsvp in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rsvp.memberName).font(.subheadline.weight(.semibold))
                        HStack(spacing: 6) {
                            Picker("Status", selection: Binding(
                                get: { rsvp.status },
                                set: { store.updateRSVP(rsvp.id, status: $0) }
                            )) {
                                ForEach(RSVPStatus.allCases) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.menu)
                            if rsvp.guests > 0 { Text("+\(rsvp.guests) guests").font(.caption2).foregroundColor(.secondary) }
                        }
                        if !rsvp.notes.isEmpty {
                            Text(rsvp.notes).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button { store.deleteRSVP(rsvp.id) } label: {
                        Image(systemName: "trash").foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
            }
        }
    }
}

// MARK: - Tasks Tab

private struct TasksTab: View {
    @ObservedObject var store: EventPlanningStore
    @EnvironmentObject var appState: AppState
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var assignees: Set<String> = []
    @State private var hasDueDate = false
    @State private var dueDate: Date = Date()

    private var familyNames: [String] {
        appState.currentFamily?.members.map(\.name) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Task name", text: $name).textFieldStyle(.roundedBorder)
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                }
                DisclosureGroup("Assign to (\(assignees.count))") {
                    ForEach(familyNames, id: \.self) { n in
                        Toggle(n, isOn: Binding(
                            get: { assignees.contains(n) },
                            set: { on in if on { assignees.insert(n) } else { assignees.remove(n) } }
                        ))
                    }
                }
                Button {
                    let task = EventTask(
                        eventId: store.event.id,
                        taskName: name, description: description,
                        assignedTo: Array(assignees),
                        dueDate: hasDueDate ? dueDate : nil
                    )
                    store.addTask(task)
                    name = ""; description = ""; assignees.removeAll(); hasDueDate = false
                } label: {
                    Label("Add task", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            ForEach(store.tasks) { task in
                HStack(alignment: .top, spacing: 10) {
                    Button { store.toggleTask(task.id) } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(task.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.taskName)
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .font(.subheadline.weight(.semibold))
                        if !task.description.isEmpty {
                            Text(task.description).font(.caption).foregroundColor(.secondary)
                        }
                        HStack(spacing: 6) {
                            ForEach(task.assignedTo, id: \.self) { who in
                                Text(who)
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.purple.opacity(0.15)))
                                    .foregroundColor(.purple)
                            }
                            if let due = task.dueDate {
                                Text("Due \(due, format: .dateTime.month().day())")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    Button { store.deleteTask(task.id) } label: {
                        Image(systemName: "trash").foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
            }
        }
    }
}

// MARK: - Schedule Tab

private struct ScheduleTab: View {
    @ObservedObject var store: EventPlanningStore
    @State private var time: Date = Date()
    @State private var activity: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                TextField("Activity", text: $activity).textFieldStyle(.roundedBorder)
                TextField("Location (optional)", text: $location).textFieldStyle(.roundedBorder)
                TextField("Notes (optional)", text: $notes).textFieldStyle(.roundedBorder)
                Button {
                    let item = EventScheduleItem(
                        eventId: store.event.id,
                        time: time, activity: activity,
                        location: location, notes: notes,
                        order: store.schedule.count
                    )
                    store.addScheduleItem(item)
                    activity = ""; location = ""; notes = ""
                } label: {
                    Label("Add to schedule", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(activity.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            ForEach(store.schedule.sorted(by: { $0.time < $1.time })) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.time, format: .dateTime.hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.pink)
                        .frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.activity).font(.subheadline.weight(.semibold))
                        if !item.location.isEmpty {
                            Label(item.location, systemImage: "mappin.and.ellipse")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        if !item.notes.isEmpty {
                            Text(item.notes).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button { store.deleteScheduleItem(item.id) } label: {
                        Image(systemName: "trash").foregroundColor(.red.opacity(0.7))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
            }
        }
    }
}

// MARK: - Polls Tab

private struct PollsTab: View {
    @ObservedObject var store: EventPlanningStore
    let currentVoter: String

    @State private var question: String = ""
    @State private var options: [String] = ["", ""]
    @State private var multipleChoice: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Create poll
            VStack(alignment: .leading, spacing: 10) {
                Label("Create new poll", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.purple)
                TextField("Poll question", text: $question)
                    .textFieldStyle(.roundedBorder)

                ForEach(options.indices, id: \.self) { i in
                    HStack {
                        TextField("Option \(i + 1)", text: Binding(
                            get: { options[i] },
                            set: { options[i] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        if options.count > 2 {
                            Button { options.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Button { options.append("") } label: {
                    Label("Add option", systemImage: "plus")
                }
                .font(.caption)

                Toggle("Allow multiple selections", isOn: $multipleChoice)
                    .font(.caption)

                Button {
                    let valid = options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    guard !question.isEmpty, valid.count >= 2 else { return }
                    let poll = EventPoll(eventId: store.event.id, question: question,
                                         options: valid, multipleChoice: multipleChoice)
                    store.addPoll(poll)
                    question = ""; options = ["", ""]; multipleChoice = false
                } label: {
                    Label("Create poll", systemImage: "chart.bar.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.07)))

            if store.polls.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar").font(.title).foregroundColor(.secondary)
                    Text("No polls yet").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(store.polls) { poll in
                    pollCard(poll)
                }
            }
        }
    }

    private func pollCard(_ poll: EventPoll) -> some View {
        let pollVotes = store.votes.filter { $0.pollId == poll.id }
        let total = pollVotes.count
        let userVotes = Set(pollVotes.filter { $0.voterName == currentVoter }.map(\.selectedOption))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(poll.question).font(.subheadline.weight(.semibold))
                Spacer()
                Button { store.togglePollClosed(poll.id) } label: {
                    Image(systemName: poll.isClosed ? "lock.fill" : "lock.open.fill").font(.caption)
                }
                .tint(.secondary)
                Button { store.deletePoll(poll.id) } label: {
                    Image(systemName: "trash").font(.caption).foregroundColor(.red.opacity(0.7))
                }
            }

            HStack(spacing: 6) {
                Text("\(total) vote\(total == 1 ? "" : "s")")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().stroke(Color.secondary, lineWidth: 0.5))
                if poll.multipleChoice {
                    Text("Multiple choice")
                        .font(.caption2).foregroundColor(.purple)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.15)))
                }
                if poll.isClosed {
                    Text("Closed")
                        .font(.caption2).foregroundColor(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                }
            }

            ForEach(poll.options, id: \.self) { option in
                let count = pollVotes.filter { $0.selectedOption == option }.count
                let pct = total > 0 ? Double(count) / Double(total) : 0
                let voted = userVotes.contains(option)

                Button {
                    guard !poll.isClosed else { return }
                    store.castVote(pollId: poll.id, option: option, voter: currentVoter)
                } label: {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.18))
                                .frame(width: max(geo.size.width * pct, 0))
                        }
                        HStack {
                            Image(systemName: voted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(voted ? .purple : .secondary)
                            Text(option).font(.subheadline)
                            Spacer()
                            Text("\(count)").font(.caption.weight(.semibold))
                            Text("\(Int((pct * 100).rounded()))%").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(10)
                    }
                    .frame(minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(voted ? Color.purple : Color(.separator), lineWidth: voted ? 1.5 : 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(poll.isClosed)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - Docs Tab

private struct DocsTab: View {
    @ObservedObject var store: EventPlanningStore
    let currentUser: String
    @State private var title = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Link a Document", systemImage: "doc.text.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.blue)
                TextField("Document title", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes or link (optional)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let doc = EventDocument(
                        eventId: store.event.id,
                        title: title,
                        note: note,
                        addedBy: currentUser
                    )
                    store.addDocument(doc)
                    title = ""; note = ""
                } label: {
                    Label("Add Document", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            if store.documents.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text").font(.title).foregroundColor(.secondary)
                    Text("No documents linked yet").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(store.documents) { doc in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doc.title).font(.subheadline.weight(.semibold))
                            if !doc.note.isEmpty {
                                Text(doc.note).font(.caption).foregroundColor(.secondary)
                            }
                            Text("Added by \(doc.addedBy) • \(doc.addedDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button { store.deleteDocument(doc.id) } label: {
                            Image(systemName: "trash").foregroundColor(.red.opacity(0.7))
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
                }
            }
        }
    }
}

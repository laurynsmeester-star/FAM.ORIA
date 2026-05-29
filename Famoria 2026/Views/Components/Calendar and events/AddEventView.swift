//
//  AddEventView.swift
//  Famoria 2026
//
//  Add/edit event sheet. Pass `editing:` to edit an existing event;
//  otherwise creates a new one at `initialDate`.
//

import SwiftUI
import os

struct AddEventView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date = Date()
    var editing: FamilyEventV2? = nil

    @State private var title: String = ""
    @State private var eventType: EventType = .other
    @State private var date: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    @State private var hasTimeRange: Bool = false
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(60 * 60)
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isRecurring: Bool = false
    @State private var selectedReminders: Set<ReminderOffset> = []
    @State private var appleRemindersStatus: AppleRemindersStatus = .idle

    @State private var showValidationError: Bool = false

    private enum AppleRemindersStatus: Equatable {
        case idle, saving, saved, failed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Event title", text: $title)
                        .textInputAutocapitalization(.words)

                    Picker("Type", selection: $eventType) {
                        ForEach(EventType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }

                    HStack {
                        Image(systemName: eventType.icon)
                            .foregroundColor(eventType.colors.fill)
                        Text(eventType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Toggle("Multi-day event", isOn: $hasEndDate.animation())
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate,
                                   in: date..., displayedComponents: .date)
                    }

                    Toggle("Set time", isOn: $hasTimeRange.animation())
                    if hasTimeRange {
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End time",   selection: $endTime,   displayedComponents: .hourAndMinute)
                    }

                    Toggle("Repeats yearly", isOn: $isRecurring)
                }

                Section("Where") {
                    TextField("Location (optional)", text: $location)
                        .textInputAutocapitalization(.words)
                    if !location.isEmpty {
                        EventMapView(location: location, eventTitle: title.isEmpty ? "Event" : title)
                            .frame(height: 180)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section("Notes") {
                    TextField("Anything else…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    ForEach(ReminderOffset.allCases) { offset in
                        Toggle(isOn: bindingForReminder(offset)) {
                            Label(offset.displayName, systemImage: "bell.fill")
                        }
                    }
                    Button {
                        Task { await exportToAppleReminders() }
                    } label: {
                        HStack {
                            Label("Add to Apple Reminders", systemImage: "list.bullet.rectangle.portrait")
                            Spacer()
                            switch appleRemindersStatus {
                            case .idle: EmptyView()
                            case .saving:
                                ProgressView().controlSize(.small)
                            case .saved:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            case .failed:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .disabled(appleRemindersStatus == .saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Reminders & Alerts")
                } footer: {
                    Text("In-app alerts fire automatically at the times you pick. Apple Reminders syncs once when you tap the button.")
                }

                if showValidationError {
                    Section {
                        Label("Please add a title.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle(editing == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Save" : "Update", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        if let e = editing {
            title = e.title
            eventType = e.eventType
            date = e.date
            hasEndDate = e.endDate != nil
            endDate = e.endDate ?? e.date
            hasTimeRange = e.startTime != nil || e.endTime != nil
            startTime = e.startTime ?? Date()
            endTime = e.endTime ?? Date().addingTimeInterval(60 * 60)
            location = e.location ?? ""
            notes = e.notes ?? ""
            isRecurring = e.isRecurring
            selectedReminders = Set(e.reminderOffsets)
        } else {
            date = initialDate
            endDate = initialDate
        }
    }

    private func bindingForReminder(_ offset: ReminderOffset) -> Binding<Bool> {
        Binding(
            get: { selectedReminders.contains(offset) },
            set: { isOn in
                if isOn { selectedReminders.insert(offset) }
                else { selectedReminders.remove(offset) }
            }
        )
    }

    private func currentEventDraft() -> FamilyEventV2 {
        let creator = appState.currentUser?.name ?? ""
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return FamilyEventV2(
            id: editing?.id ?? UUID().uuidString,
            title: trimmed,
            date: date,
            endDate: hasEndDate ? endDate : nil,
            startTime: hasTimeRange ? startTime : nil,
            endTime: hasTimeRange ? endTime : nil,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            eventType: eventType,
            isRecurring: isRecurring,
            createdBy: creator,
            reminderOffsetsRaw: selectedReminders.map(\.rawValue)
        )
    }

    private func exportToAppleReminders() async {
        appleRemindersStatus = .saving
        let ok = await EventReminderScheduler.addToAppleReminders(currentEventDraft())
        appleRemindersStatus = ok ? .saved : .failed
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { showValidationError = true }
            return
        }

        let new = currentEventDraft()

        let isNew = (editing == nil)
        appState.upsertEvent(new)
        Task { await EventReminderScheduler.schedule(for: new) }

        // For a newly created event, persist to Firestore so other family members
        // see it on their devices, and write a notification so they're alerted.
        // V2 fields are now part of the Firestore document so the full event
        // syncs cross-device (location, time range, type, notes, recurring).
        let reminderRaw = selectedReminders.map(\.rawValue)
        if isNew {
            Task {
                do {
                    try await appState.createEvent(
                        title: trimmed,
                        date: date,
                        id: new.id,
                        endDate: hasEndDate ? endDate : nil,
                        startTime: hasTimeRange ? startTime : nil,
                        endTime: hasTimeRange ? endTime : nil,
                        location: location.isEmpty ? nil : location,
                        notes: notes.isEmpty ? nil : notes,
                        eventTypeRaw: eventType.rawValue,
                        isRecurring: isRecurring,
                        reminderOffsetsRaw: reminderRaw
                    )
                } catch {
                    Log.appState.error("Failed to persist event: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else if let editingId = editing?.id, let family = appState.currentFamily {
            // Edit path — push the updated V2 fields to Firestore.
            Task {
                do {
                    try await appState.updateEvent(
                        familyId: family.id,
                        eventId: editingId,
                        title: trimmed,
                        date: date,
                        endDate: hasEndDate ? endDate : nil,
                        startTime: hasTimeRange ? startTime : nil,
                        endTime: hasTimeRange ? endTime : nil,
                        location: location.isEmpty ? nil : location,
                        notes: notes.isEmpty ? nil : notes,
                        eventTypeRaw: eventType.rawValue,
                        isRecurring: isRecurring,
                        reminderOffsetsRaw: reminderRaw
                    )
                } catch {
                    Log.appState.error("Failed to update event: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        dismiss()
    }
}

// MARK: - AppState bridge

extension AppState {
    /// Inserts or updates a V2 event in the legacy `events` array. The
    /// `FamilyEvent` model now carries the V2 fields natively, so the full
    /// payload is preserved (not just title + date).
    func upsertEvent(_ event: FamilyEventV2) {
        let legacy = FamilyEvent(
            id: event.id,
            title: event.title,
            date: event.date,
            endDate: event.endDate,
            createdBy: event.createdBy,
            startTime: event.startTime,
            endTime: event.endTime,
            location: event.location,
            notes: event.notes,
            eventTypeRaw: event.eventType.rawValue,
            isRecurring: event.isRecurring,
            reminderOffsetsRaw: event.reminderOffsetsRaw
        )
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = legacy
        } else {
            events.append(legacy)
        }
    }

}

#Preview {
    AddEventView()
        .environmentObject(AppState())
}

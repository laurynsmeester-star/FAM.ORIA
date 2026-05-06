//
//  AddEventView.swift
//  Famoria 2026
//
//  Optimized add/edit event sheet — replaces the bare title+date version.
//  Translated from web reference (event_type, location, recurring, time range,
//  end date for multi-day events, optional notes).
//
//  Pass `editing:` to edit an existing event; otherwise creates a new one.
//

import SwiftUI

struct AddEventView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Optional inputs
    var initialDate: Date = Date()
    var editing: FamilyEventV2? = nil

    // Form state
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

    @State private var showValidationError: Bool = false

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
        } else {
            date = initialDate
            endDate = initialDate
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { showValidationError = true }
            return
        }

        let creator = appState.currentUser?.name ?? ""
        let new = FamilyEventV2(
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
            createdBy: creator
        )

        // Persist back through your AppState. Adjust to match whatever
        // mutation API you expose (Firebase, async store, etc.).
        appState.upsertEvent(new)
        dismiss()
    }
}

// MARK: - AppState bridge

extension AppState {
    /// Inserts or updates a V2 event. Adapt to your Firebase service as needed.
    func upsertEvent(_ event: FamilyEventV2) {
        let legacy = FamilyEvent(
            id: event.id,
            title: event.title,
            date: event.date,
            endDate: event.endDate,
            createdBy: event.createdBy
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

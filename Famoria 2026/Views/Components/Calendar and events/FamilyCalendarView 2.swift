//
//  FamilyCalendarView.swift
//  Famoria 2026
//
//  Optimized month-grid calendar — replaces the basic DatePicker version.
//  Translated from the React `EventCalendar` component:
//   • Month + Year picker, Today / Prev / Next nav
//   • Color-coded event chips by EventType
//   • Highlighted event support
//   • Multi-day event spans
//   • Tap an event chip to open the planning sheet
//   • Tap a day to filter the list below
//
//  Backed by `FamilyEventV2` from EventModels.swift.
//

import SwiftUI

struct FamilyCalendarView: View {

    @EnvironmentObject var appState: AppState

    // Inputs the parent can provide; defaults pull from AppState.
    var events: [FamilyEventV2] = []
    var highlightedEventId: String? = nil

    @State private var currentDate = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showAddEvent = false
    @State private var planningEvent: FamilyEventV2? = nil
    @State private var showListView = false

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1 // Sunday — matches react-big-calendar default
        return c
    }()

    private let monthSymbols: [String] = DateFormatter().standaloneMonthSymbols ?? Calendar.current.monthSymbols
    private let weekdaySymbols: [String] = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

    // Effective event source — prefers the prop, falls back to AppState.
    private var eventsSource: [FamilyEventV2] {
        events.isEmpty ? appState.eventsV2 : events
    }

    var body: some View {
        VStack(spacing: 0) {
            viewToggle

            if showListView {
                upcomingListView
            } else {
                header
                weekdayRow
                monthGrid
                Divider().padding(.vertical, 8)
                agendaList
            }
        }
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddEvent = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(initialDate: selectedDate)
        }
        .sheet(item: $planningEvent) { event in
            EventPlanningView(event: event)
        }
        .onAppear {
            if let id = highlightedEventId,
               let target = eventsSource.first(where: { $0.id == id }) {
                currentDate = target.isRecurring ? target.nextOccurrence : target.date
            }
        }
    }

    // MARK: - View toggle (Calendar / List)

    private var viewToggle: some View {
        Picker("View", selection: $showListView) {
            Label("Calendar", systemImage: "calendar").tag(false)
            Label("List", systemImage: "list.bullet").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 8)
    }

    // MARK: - Upcoming events list view

    private var upcomingListView: some View {
        let upcoming = eventsSource
            .sorted { ($0.isRecurring ? $0.nextOccurrence : $0.date) < ($1.isRecurring ? $1.nextOccurrence : $1.date) }

        return ScrollView {
            if upcoming.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No events yet")
                        .font(.headline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(upcoming) { event in
                        Button { planningEvent = event } label: {
                            eventListRow(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func eventListRow(_ event: FamilyEventV2) -> some View {
        let eventDate = event.isRecurring ? event.nextOccurrence : event.date
        let palette = event.eventType.colors
        let daysAway = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: eventDate)).day ?? 0
        let isPast = eventDate < Date()

        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(eventDate.formatted(.dateTime.day()))
                    .font(.title2.weight(.bold))
                    .foregroundColor(palette.fill)
                Text(eventDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 56, height: 56)
            .background(palette.fill.opacity(0.12))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: event.eventType.icon)
                        .font(.caption)
                        .foregroundColor(palette.fill)
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let loc = event.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1)
                    }
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Header (Month / Year selectors + Today / Prev / Next)

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Menu {
                    ForEach(0..<12, id: \.self) { idx in
                        Button(monthSymbols[idx]) { setMonth(idx) }
                    }
                } label: {
                    pickerLabel(text: monthSymbols[currentMonthIndex])
                        .frame(minWidth: 110, alignment: .leading)
                }

                Menu {
                    ForEach(yearOptions, id: \.self) { year in
                        Button("\(year)") { setYear(year) }
                    }
                } label: {
                    pickerLabel(text: "\(currentYear)")
                        .frame(minWidth: 70, alignment: .leading)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button("Today") { goToday() }
                    .foregroundColor(.black)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())

                navButton(systemImage: "chevron.left") { shiftMonth(-1) }
                navButton(systemImage: "chevron.right") { shiftMonth(1) }
            }
        }
        .padding(.vertical, 8)
    }

    private func pickerLabel(text: String) -> some View {
        HStack(spacing: 4) {
            Text(text).italic()
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.system(size: 15, design: .serif))
        .foregroundColor(.primary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(.black)
                .font(.caption.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday header row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let days = monthGridDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: currentDate, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let dayEvents = eventsForDay(day)

        return Button {
            selectedDate = calendar.startOfDay(for: day)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.caption.weight(isToday ? .bold : .regular))
                        .foregroundColor(inMonth ? .primary : .secondary)
                        .padding(4)
                        .background(
                            Circle().fill(isToday ? Color.accentColor.opacity(0.18) : .clear)
                        )
                    Spacer()
                }

                // Colored dots for events on this day
                if !dayEvents.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(dayEvents.prefix(3)) { event in
                            Circle()
                                .fill(event.eventType.colors.fill)
                                .frame(width: 6, height: 6)
                        }
                        if dayEvents.count > 3 {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.leading, 4)
                }

                ForEach(dayEvents.prefix(2)) { event in
                    eventChip(event)
                }
                if dayEvents.count > 2 {
                    Text("+\(dayEvents.count - 2) more")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground).opacity(inMonth ? 1 : 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func eventChip(_ event: FamilyEventV2) -> some View {
        let palette = event.eventType.colors
        let isHighlighted = (event.id == highlightedEventId)
        return Button {
            planningEvent = event
        } label: {
            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.pink.opacity(isHighlighted ? 0.7 : 0), lineWidth: 2)
                )
                .scaleEffect(isHighlighted ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Agenda list (selected day)

    private var agendaList: some View {
        let dayEvents = eventsForDay(selectedDate)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.headline.italic())
                Spacer()
                Text("\(dayEvents.count) event\(dayEvents.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if dayEvents.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No events").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(dayEvents) { event in
                            agendaRow(event)
                        }
                    }
                }
            }
        }
    }

    private func agendaRow(_ event: FamilyEventV2) -> some View {
        let palette = event.eventType.colors
        return Button { planningEvent = event } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4).fill(palette.fill).frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: event.eventType.icon)
                            .font(.caption)
                            .foregroundColor(palette.fill)
                        Text(event.title).font(.subheadline.weight(.semibold))
                    }
                    if let loc = event.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let start = event.startTime {
                        Text(start, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date math

    private var currentMonthIndex: Int { calendar.component(.month, from: currentDate) - 1 }
    private var currentYear: Int { calendar.component(.year, from: currentDate) }

    private var yearOptions: [Int] {
        let y = currentYear
        return Array((y - 5)...(y + 5))
    }

    private func setMonth(_ idx: Int) {
        var comps = calendar.dateComponents([.year, .day], from: currentDate)
        comps.month = idx + 1
        comps.day = 1
        if let new = calendar.date(from: comps) { currentDate = new }
    }

    private func setYear(_ year: Int) {
        var comps = calendar.dateComponents([.month, .day], from: currentDate)
        comps.year = year
        comps.day = 1
        if let new = calendar.date(from: comps) { currentDate = new }
    }

    private func shiftMonth(_ delta: Int) {
        if let new = calendar.date(byAdding: .month, value: delta, to: currentDate) {
            currentDate = new
        }
    }

    private func goToday() {
        currentDate = Date()
        selectedDate = calendar.startOfDay(for: Date())
    }

    /// Builds a 6-row * 7-column grid of dates covering the current month.
    private func monthGridDays() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return [] }
        let firstOfMonth = monthInterval.start
        let weekdayOffset = calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday
        let normalizedOffset = (weekdayOffset + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -normalizedOffset, to: firstOfMonth) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// Resolves recurring events to their next occurrence, then matches to `day`.
    private func eventsForDay(_ day: Date) -> [FamilyEventV2] {
        eventsSource.filter { event in
            let primary = event.isRecurring ? event.nextOccurrence : event.date
            if calendar.isDate(primary, inSameDayAs: day) { return true }
            // Multi-day: span between date...endDate
            if let end = event.endDate {
                let start = calendar.startOfDay(for: event.date)
                let endDay = calendar.startOfDay(for: end)
                let target = calendar.startOfDay(for: day)
                return target >= start && target <= endDay
            }
            return false
        }
        .sorted { ($0.startTime ?? $0.date) < ($1.startTime ?? $1.date) }
    }
}

// MARK: - AppState convenience (so the view compiles standalone)

extension AppState {
    /// Bridge to the V2 model. If your AppState already exposes V2 events,
    /// remove this extension. Otherwise it adapts the legacy `events`.
    var eventsV2: [FamilyEventV2] {
        events.map { legacy in
            FamilyEventV2(
                id: legacy.id,
                title: legacy.title,
                date: legacy.date,
                endDate: legacy.endDate,
                createdBy: legacy.createdBy
            )
        }
    }
}
#Preview {
    FamilyCalendarView ()
}

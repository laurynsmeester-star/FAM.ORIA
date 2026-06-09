import SwiftUI
import os
import Charts
import FirebaseFirestore

struct FamilyHealthView: View {
    @EnvironmentObject var appState: AppState
    @State private var records: [HealthRecord] = []
    @State private var medications: [FamoriaMedication] = []
    @State private var showAddRecord = false
    @State private var showAddMedication = false
    @State private var listener: ListenerRegistration?
    @State private var medListener: ListenerRegistration?

    private let medicationService = MedicationService()

    private let db = Firestore.firestore()

    private var members: [User] {
        appState.currentFamily?.members ?? []
    }

    private func startListening() {
        listener?.remove()
        listener = db.collection("famoria_health_records")
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Log.health.error("FamilyHealthView listener failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let snapshot else { return }
                records = snapshot.documents.compactMap { doc in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(HealthRecord.self, from: data)
                }
            }
    }

    private func saveRecord(_ record: HealthRecord) {
        do {
            try db.collection("famoria_health_records").document(record.id).setData(from: record)
        } catch {
            Log.health.error("Failed to save health record: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if records.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Family Health")
                            .font(.title3).fontWeight(.semibold)
                        Text("Track appointments, medications, and health notes for your family.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button {
                            showAddRecord = true
                        } label: {
                            Label("Add Health Record", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(20)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    HealthTrendCard(records: records)
                        .padding(.horizontal)

                    MedicationSection(
                        medications: medications,
                        onAdd: { showAddMedication = true },
                        onDelete: { id in
                            guard let familyId = appState.currentFamily?.id else { return }
                            Task { try? await medicationService.delete(id, familyId: familyId) }
                        }
                    )
                    .padding(.horizontal)

                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            HealthRecordCard(record: record)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            if !records.isEmpty {
                Button {
                    showAddRecord = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startListening()
            startMedicationListener()
        }
        .onDisappear {
            listener?.remove(); listener = nil
            medListener?.remove(); medListener = nil
        }
        .sheet(isPresented: $showAddRecord) {
            AddHealthRecordSheet(onSave: saveRecord, members: members)
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationSheet(members: members) { med in
                guard let familyId = appState.currentFamily?.id else { return }
                Task { try? await medicationService.upsert(med, familyId: familyId) }
            }
        }
    }

    private func startMedicationListener() {
        guard let familyId = appState.currentFamily?.id else { return }
        medListener?.remove()
        medListener = medicationService.observe(familyId: familyId) { items in
            self.medications = items.sorted { $0.name < $1.name }
        }
    }
}

struct HealthRecord: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var memberName: String
    var category: String
    var title: String
    var notes: String
    var date: Date
}

private struct HealthRecordCard: View {
    let record: HealthRecord

    private var categoryIcon: String {
        switch record.category.lowercased() {
        case "appointment":  return "stethoscope"
        case "medication":   return "pills.fill"
        case "vaccination":  return "syringe.fill"
        case "allergy":      return "exclamationmark.triangle.fill"
        default:             return "heart.text.square.fill"
        }
    }

    private var categoryColor: Color {
        switch record.category.lowercased() {
        case "appointment":  return .blue
        case "medication":   return .green
        case "vaccination":  return .purple
        case "allergy":      return .orange
        default:             return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: categoryIcon)
                .font(.title3).foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(categoryColor)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 6) {
                    Text(record.memberName)
                        .font(.caption).foregroundColor(.secondary)
                    Text(record.category)
                        .font(.caption).foregroundColor(categoryColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(categoryColor.opacity(0.1))
                        .cornerRadius(4)
                }
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

private struct AddHealthRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (HealthRecord) -> Void
    let members: [User]
    @State private var memberName = ""
    @State private var title = ""
    @State private var category = "Appointment"
    @State private var notes = ""
    @State private var date = Date()

    private let categories = ["Appointment", "Medication", "Vaccination", "Allergy", "General"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    if members.isEmpty {
                        TextField("Family Member", text: $memberName)
                    } else {
                        Picker("Family Member", selection: $memberName) {
                            Text("Select...").tag("")
                            ForEach(members) { member in
                                Text(member.name).tag(member.name)
                            }
                        }
                    }
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    DatePicker("Date", selection: $date)
                }
                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Health Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let record = HealthRecord(
                            id: UUID().uuidString,
                            memberName: memberName,
                            category: category,
                            title: title,
                            notes: notes,
                            date: date
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || memberName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Health Trend Card (Swift Charts)

/// Stacked-area chart breaking down the family's health records over
/// the last 12 weeks by category (appointments, medications, etc.) so
/// the user can spot trends at a glance.
struct HealthTrendCard: View {
    let records: [HealthRecord]

    private struct Bucket: Identifiable {
        let id: String
        let weekStart: Date
        let category: String
        let count: Int
    }

    private var buckets: [Bucket] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? Date()
        let recent = records.filter { $0.date >= cutoff }

        // Group by (weekStart × category).
        var dict: [String: Int] = [:]
        for r in recent {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: r.date)
            guard let weekStart = cal.date(from: comps) else { continue }
            let key = "\(weekStart.timeIntervalSince1970)|\(r.category.lowercased())"
            dict[key, default: 0] += 1
        }
        return dict.compactMap { key, value in
            let parts = key.split(separator: "|")
            guard parts.count == 2,
                  let interval = TimeInterval(parts[0]) else { return nil }
            return Bucket(
                id: key,
                weekStart: Date(timeIntervalSince1970: interval),
                category: String(parts[1]).capitalized,
                count: value
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("12-week trend").font(.headline)
                Spacer()
                Text("\(records.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if buckets.isEmpty {
                Text("Not enough data yet for a trend.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                        y: .value("Count", bucket.count)
                    )
                    .foregroundStyle(by: .value("Category", bucket.category))
                }
                .frame(height: 160)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }
}

// MARK: - Medication Section

struct MedicationSection: View {
    let medications: [FamoriaMedication]
    var onAdd: () -> Void
    var onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Medications").font(.headline)
                Spacer()
                Button {
                    onAdd()
                    Haptics.selection()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.purple)
                }
            }
            if medications.isEmpty {
                Text("No medications tracked yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(medications) { med in
                        MedicationRow(medication: med, onDelete: { onDelete(med.id) })
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }
}

private struct MedicationRow: View {
    let medication: FamoriaMedication
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "pills.fill")
                .foregroundColor(.purple)
                .frame(width: 32, height: 32)
                .background(Color.purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(medication.memberName)
                    if !medication.dosage.isEmpty {
                        Text("• \(medication.dosage)")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)

                if !medication.reminderTimes.isEmpty {
                    Text("Reminders at \(medication.reminderTimes.joined(separator: ", "))")
                        .font(.caption2).foregroundColor(.secondary)
                }
                if let refill = medication.refillDate {
                    Text("Refill on \(refill.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(4)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Add Medication Sheet

struct AddMedicationSheet: View {
    let members: [User]
    var onSave: (FamoriaMedication) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var memberName = ""
    @State private var name = ""
    @State private var dosage = ""
    @State private var instructions = ""
    @State private var reminderTimes: [Date] = []
    @State private var hasRefill = false
    @State private var refillDate = Date().addingTimeInterval(30 * 24 * 3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    Picker("Family member", selection: $memberName) {
                        ForEach(members, id: \.id) { m in
                            Text(m.name).tag(m.name)
                        }
                    }
                }
                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Dosage (e.g. 5mg)", text: $dosage)
                    TextField("Instructions (optional)", text: $instructions)
                }
                Section("Reminder times") {
                    ForEach(reminderTimes.indices, id: \.self) { i in
                        DatePicker(
                            "Time \(i + 1)",
                            selection: Binding(
                                get: { reminderTimes[i] },
                                set: { reminderTimes[i] = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Button {
                        reminderTimes.append(Date())
                    } label: {
                        Label("Add reminder time", systemImage: "plus")
                    }
                    if !reminderTimes.isEmpty {
                        Button(role: .destructive) {
                            reminderTimes.removeLast()
                        } label: {
                            Label("Remove last", systemImage: "minus.circle")
                        }
                    }
                }
                Section("Refill") {
                    Toggle("Set refill reminder", isOn: $hasRefill.animation())
                    if hasRefill {
                        DatePicker("Refill date", selection: $refillDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || memberName.isEmpty)
                }
            }
            .onAppear {
                if memberName.isEmpty {
                    memberName = members.first?.name ?? ""
                }
            }
        }
    }

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let times = reminderTimes.map { formatter.string(from: $0) }
        let med = FamoriaMedication(
            memberName: memberName,
            name: name.trimmingCharacters(in: .whitespaces),
            dosage: dosage,
            instructions: instructions,
            reminderTimes: times,
            refillDate: hasRefill ? refillDate : nil
        )
        Haptics.send()
        onSave(med)
        dismiss()
    }
}

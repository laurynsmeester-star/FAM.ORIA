import SwiftUI
import os
import FirebaseFirestore

struct FamilyHealthView: View {
    @EnvironmentObject var appState: AppState
    @State private var records: [HealthRecord] = []
    @State private var showAddRecord = false
    @State private var listener: ListenerRegistration?

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
        .onAppear { startListening() }
        .onDisappear { listener?.remove(); listener = nil }
        .sheet(isPresented: $showAddRecord) {
            AddHealthRecordSheet(onSave: saveRecord, members: members)
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

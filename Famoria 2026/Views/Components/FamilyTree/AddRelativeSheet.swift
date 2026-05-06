//
//  AddRelativeSheet.swift
//  Famoria 2026
//
//  Bottom-sheet form for adding a new person to the family tree.
//  The "anchor" is the existing tree member the new relative connects to.
//  Optionally, an inviteEmail can be provided to invite the relative to
//  Famoria — the resulting ghost profile will upgrade automatically when
//  they accept the invite (server-side trigger or manual link).
//

import SwiftUI

struct AddRelativeSheet: View {

    @ObservedObject var viewModel: FamilyTreeViewModel
    let anchor: FamilyTreeMember
    let initialKind: AddRelativeKind
    let onClose: () -> Void

    // Form state
    @State private var kind: AddRelativeKind
    @State private var displayName: String = ""
    @State private var gender: TreeGender = .unspecified
    @State private var birthDate: Date = Date()
    @State private var hasBirthDate: Bool = false
    @State private var deathDate: Date = Date()
    @State private var hasDeathDate: Bool = false
    @State private var isDeceased: Bool = false
    @State private var notes: String = ""
    @State private var inviteEmail: String = ""
    @State private var photoURL: String = ""
    @State private var isSaving: Bool = false

    init(
        viewModel: FamilyTreeViewModel,
        anchor: FamilyTreeMember,
        initialKind: AddRelativeKind,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.anchor = anchor
        self.initialKind = initialKind
        self.onClose = onClose
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    relationshipPicker
                } header: {
                    Text("Relationship to \(anchor.displayName)")
                }

                Section("Details") {
                    TextField("Full name", text: $displayName)
                        .textInputAutocapitalization(.words)

                    Picker("Gender", selection: $gender) {
                        Text("Unspecified").tag(TreeGender.unspecified)
                        Text("Female").tag(TreeGender.female)
                        Text("Male").tag(TreeGender.male)
                        Text("Other").tag(TreeGender.other)
                    }

                    Toggle("Has birth date", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("Birth date", selection: $birthDate, displayedComponents: .date)
                    }

                    Toggle("Deceased", isOn: $isDeceased)
                    if isDeceased {
                        Toggle("Has date of passing", isOn: $hasDeathDate)
                        if hasDeathDate {
                            DatePicker("Date of passing", selection: $deathDate, displayedComponents: .date)
                        }
                    }
                }

                Section {
                    TextField("Photo URL (optional)", text: $photoURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Notes (e.g., 'Lived in Boston')", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    Text("Optional")
                }

                Section {
                    TextField("Email", text: $inviteEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    Text("If provided, we'll save it on this profile so you can send a Famoria invite later. The profile will appear as a 'ghost' until they join.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Invite to Famoria (optional)")
                }
            }
            .navigationTitle("Add Relative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Add").fontWeight(.semibold) }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    // MARK: - Relationship picker

    private var relationshipPicker: some View {
        VStack(spacing: 8) {
            ForEach(AddRelativeKind.allCases) { k in
                Button {
                    kind = k
                } label: {
                    HStack {
                        Image(systemName: k.systemImage)
                            .foregroundStyle(kind == k ? .white : .purple)
                            .frame(width: 28)
                        Text(k.label)
                            .foregroundStyle(kind == k ? .white : .primary)
                        Spacer()
                        if kind == k {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(kind == k
                                  ? AnyShapeStyle(LinearGradient(colors: [.purple, .pink],
                                                                 startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color(.secondarySystemBackground))
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
    }

    // MARK: - Save

    private func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        await viewModel.addRelative(
            kind: kind,
            relativeOf: anchor.id,
            displayName: trimmedName,
            gender: gender,
            birthDate: hasBirthDate ? birthDate : nil,
            deathDate: (isDeceased && hasDeathDate) ? deathDate : nil,
            isDeceased: isDeceased,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : notes,
            inviteEmail: inviteEmail.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : inviteEmail.lowercased(),
            photoURL: photoURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : photoURL
        )

        onClose()
    }
}

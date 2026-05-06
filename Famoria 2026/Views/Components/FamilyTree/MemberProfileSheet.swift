//
//  MemberProfileSheet.swift
//  Famoria 2026
//
//  Bottom sheet shown when the user taps a node in the family tree.
//  Displays the person's info plus quick-add buttons to extend the tree
//  outward from this node (add their parents, spouse, child, sibling).
//
//  For ghost profiles, shows an "Invite to Famoria" CTA.
//  For owners/admins: shows edit + delete.
//

import SwiftUI

struct MemberProfileSheet: View {

    @ObservedObject var viewModel: FamilyTreeViewModel
    let member: FamilyTreeMember
    let onAddRelative: (AddRelativeKind) -> Void
    let onClose: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    portraitHeader
                    relationshipChips
                    if !relativesPreview.isEmpty {
                        relativesSection
                    }
                    if let notes = member.notes, !notes.isEmpty {
                        notesSection(notes)
                    }
                    if viewModel.canEdit {
                        adminActions
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onClose() }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditMemberSheet(viewModel: viewModel, member: member, onClose: { showEditSheet = false })
                    .presentationDetents([.large])
            }
            .alert("Remove from tree?",
                   isPresented: $showDeleteConfirm,
                   actions: {
                       Button("Cancel", role: .cancel) {}
                       Button("Remove", role: .destructive) {
                           Task {
                               await viewModel.deleteMember(member)
                               onClose()
                           }
                       }
                   },
                   message: {
                       Text("This removes \(member.displayName) and all their relationships from the family tree. Linked Famoria accounts are not affected.")
                   })
        }
    }

    // MARK: - Header

    private var portraitHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let urlString = member.photoURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase { img.resizable().scaledToFill() }
                            else { initialsBubble }
                        }
                    } else {
                        initialsBubble
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(member.gender.accentColor.opacity(0.5), lineWidth: 3))
                .grayscale(member.isDeceased ? 0.8 : 0)

                if member.isGhost {
                    Image(systemName: "person.crop.circle.dashed")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Color.gray))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(spacing: 4) {
                Text(member.displayName)
                    .font(.title3).fontWeight(.bold)
                if let lifespan = member.lifespanLabel {
                    Text(lifespan)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if member.linkedUserId == viewModel.currentUserId {
                    Label("This is you", systemImage: "person.fill.checkmark")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.purple)
                } else if member.isGhost {
                    Label("Not yet on Famoria", systemImage: "person.crop.circle.dashed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("On Famoria", systemImage: "checkmark.seal.fill")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.top, 12)
    }

    private var initialsBubble: some View {
        ZStack {
            LinearGradient(
                colors: [member.gender.accentColor.opacity(0.95), member.gender.accentColor.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(member.initials)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Quick add chips

    @ViewBuilder
    private var relationshipChips: some View {
        if viewModel.canEdit {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add a relative")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    ForEach(AddRelativeKind.allCases) { kind in
                        Button {
                            onAddRelative(kind)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: kind.systemImage)
                                Text(kind.label).font(.callout).fontWeight(.medium)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Existing relatives

    private var relativesPreview: [(label: String, members: [FamilyTreeMember])] {
        let p = viewModel.tree.parents(of: member.id)
        let s = viewModel.tree.spouses(of: member.id)
        let c = viewModel.tree.children(of: member.id)
        let sib = viewModel.tree.siblings(of: member.id)
        var sections: [(String, [FamilyTreeMember])] = []
        if !p.isEmpty   { sections.append(("Parents",  p)) }
        if !s.isEmpty   { sections.append(("Spouse",   s)) }
        if !sib.isEmpty { sections.append(("Siblings", sib)) }
        if !c.isEmpty   { sections.append(("Children", c)) }
        return sections
    }

    private var relativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relatives")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            ForEach(relativesPreview, id: \.label) { sec in
                VStack(alignment: .leading, spacing: 6) {
                    Text(sec.label)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ForEach(sec.members) { rel in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(rel.gender.accentColor.opacity(0.6))
                                .frame(width: 8, height: 8)
                            Text(rel.displayName).font(.callout)
                            if let lifespan = rel.lifespanLabel {
                                Text(lifespan).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if rel.isGhost {
                                Text("ghost")
                                    .font(.caption2).fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().stroke(Color.secondary.opacity(0.4)))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    // MARK: - Admin row

    private var adminActions: some View {
        VStack(spacing: 10) {
            if member.isGhost, let email = member.inviteEmail, !email.isEmpty {
                Label("Invite \(email) to Famoria", systemImage: "envelope.fill")
                    .font(.callout).fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading, endPoint: .trailing
                            ))
                    )
                    .foregroundStyle(.white)
                    .onTapGesture {
                        // Hook this up to your existing invite-by-email flow.
                        // FirebaseFamilyService already has invite-code generation;
                        // wire it here to email the code to `member.inviteEmail`.
                    }
            }

            HStack(spacing: 10) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Edit Member Sheet

struct EditMemberSheet: View {

    @ObservedObject var viewModel: FamilyTreeViewModel
    let member: FamilyTreeMember
    let onClose: () -> Void

    @State private var displayName: String
    @State private var gender: TreeGender
    @State private var birthDate: Date
    @State private var hasBirthDate: Bool
    @State private var deathDate: Date
    @State private var hasDeathDate: Bool
    @State private var isDeceased: Bool
    @State private var notes: String
    @State private var photoURL: String
    @State private var isSaving: Bool = false

    init(viewModel: FamilyTreeViewModel, member: FamilyTreeMember, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.member = member
        self.onClose = onClose
        _displayName  = State(initialValue: member.displayName)
        _gender       = State(initialValue: member.gender)
        _birthDate    = State(initialValue: member.birthDate ?? Date())
        _hasBirthDate = State(initialValue: member.birthDate != nil)
        _deathDate    = State(initialValue: member.deathDate ?? Date())
        _hasDeathDate = State(initialValue: member.deathDate != nil)
        _isDeceased   = State(initialValue: member.isDeceased)
        _notes        = State(initialValue: member.notes ?? "")
        _photoURL     = State(initialValue: member.photoURL ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
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
                Section("Optional") {
                    TextField("Photo URL", text: $photoURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Edit \(member.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        var updated = member
        updated.displayName = trimmed
        updated.gender = gender
        updated.birthDate = hasBirthDate ? birthDate : nil
        updated.deathDate = (isDeceased && hasDeathDate) ? deathDate : nil
        updated.isDeceased = isDeceased
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        updated.photoURL = photoURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : photoURL
        updated.updatedAt = Date()

        await viewModel.updateMember(updated)
        onClose()
    }
}

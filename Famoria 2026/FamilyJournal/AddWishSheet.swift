//
//  AddWishSheet.swift
//  Famoria 2026
//
//  Sheet for adding a new wish to a family member's list.
//  - Recipient picker pulls from the family's User list, with an "Other"
//    option to type a free-text name (for kids or extended relatives not yet
//    on the app).
//  - Priority and occasion are pickers backed by enums.
//  - Link is validated lightly (URL(string:) check) at save time.
//

import SwiftUI

struct AddWishSheet: View {

    @ObservedObject var viewModel: WishlistViewModel
    let onClose: () -> Void

    // Form state
    @State private var recipientChoice: RecipientChoice = .none
    @State private var customRecipientName: String = ""
    @State private var itemName: String = ""
    @State private var itemDescription: String = ""
    @State private var link: String = ""
    @State private var priority: WishPriority = .wouldLove
    @State private var occasion: WishOccasion = .anyOccasion
    @State private var isSaving: Bool = false
    @State private var validationMessage: String?

    private enum RecipientChoice: Hashable {
        case none
        case familyMember(userId: String, name: String)
        case other
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("For whom?") {
                    recipientPicker
                    if recipientChoice == .other {
                        TextField("Name", text: $customRecipientName)
                            .textInputAutocapitalization(.words)
                    }
                }

                Section("What do they want?") {
                    TextField("e.g. Blue sweater, Nintendo Switch", text: $itemName)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Details (optional)") {
                    TextField("Size, color, specific model…", text: $itemDescription, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Link (optional)", text: $link)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(WishPriority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Occasion") {
                    Picker("Occasion", selection: $occasion) {
                        ForEach(WishOccasion.allCases) { o in
                            Label(o.label, systemImage: o.systemImage).tag(o)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let message = validationMessage {
                    Section {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add a Wish")
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
                    .disabled(!canSubmit || isSaving)
                }
            }
        }
    }

    // MARK: - Recipient picker

    @ViewBuilder
    private var recipientPicker: some View {
        Picker("Recipient", selection: $recipientChoice) {
            Text("Select…").tag(RecipientChoice.none)
            ForEach(viewModel.familyMembers, id: \.id) { member in
                Text(member.name).tag(RecipientChoice.familyMember(userId: member.id, name: member.name))
            }
            Text("Other (type a name)").tag(RecipientChoice.other)
        }
        .pickerStyle(.menu)
    }

    // MARK: - Validation

    private var canSubmit: Bool {
        guard !itemName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch recipientChoice {
        case .none: return false
        case .familyMember: return true
        case .other: return !customRecipientName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Save

    private func save() async {
        validationMessage = nil

        let trimmedItem = itemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedItem.isEmpty else { return }

        let recipient: (id: String?, name: String)
        switch recipientChoice {
        case .none:
            validationMessage = "Choose who this wish is for."
            return
        case .familyMember(let id, let name):
            recipient = (id, name)
        case .other:
            let trimmedName = customRecipientName.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty else {
                validationMessage = "Enter the recipient's name."
                return
            }
            recipient = (nil, trimmedName)
        }

        let trimmedLink = link.trimmingCharacters(in: .whitespaces)
        if !trimmedLink.isEmpty, URL(string: trimmedLink) == nil {
            validationMessage = "That link doesn't look right. Include http:// or https:// and try again."
            return
        }

        isSaving = true
        defer { isSaving = false }

        await viewModel.addWish(
            recipientName: recipient.name,
            recipientUserId: recipient.id,
            itemName: trimmedItem,
            description: itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : itemDescription,
            link: trimmedLink.isEmpty ? nil : trimmedLink,
            priority: priority,
            occasion: occasion
        )

        onClose()
    }
}

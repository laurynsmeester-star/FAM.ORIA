//
//  FamilyAdminView.swift
//  Famoria 2026
//
//  Admin-only page: invite code sharing, member management.
//

import SwiftUI

struct FamilyAdminView: View {
    @EnvironmentObject var appState: AppState
    @State private var inviteCode: String?
    @State private var isGeneratingCode = false
    @State private var codeCopied = false
    @State private var errorMessage: String?
    @State private var memberToRemove: User?
    @State private var showRemoveAlert = false
    @State private var memberToPromote: User?
    @State private var showRoleSheet = false

    private var family: Family? { appState.currentFamily }
    private var currentUserId: String { appState.currentUser?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                adminHeader

                // Invite code section
                inviteCodeSection

                // Members list
                membersSection

                // Error banner
                if let error = errorMessage {
                    errorBanner(error)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Remove Member", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { memberToRemove = nil }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    removeMember(member)
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.name) from the family? This cannot be undone.")
            }
        }
        .sheet(isPresented: $showRoleSheet) {
            if let member = memberToPromote {
                RolePickerSheet(member: member) { newRole in
                    updateRole(member, to: newRole)
                    showRoleSheet = false
                    memberToPromote = nil
                }
                .presentationDetents([.height(280)])
            }
        }
    }

    // MARK: - Admin Header

    private var adminHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("Family Admin")
                .font(.title2).fontWeight(.bold)

            if let family = family {
                Text(family.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Invite Code Section

    private var inviteCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Invite Code", systemImage: "envelope.badge.person.crop")
                .font(.headline)

            Text("Share this code with family members so they can join your family.")
                .font(.caption)
                .foregroundColor(.secondary)

            if let code = inviteCode {
                // Display the code
                VStack(spacing: 12) {
                    Text(code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.purple.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                )
                        )

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = code
                            codeCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                codeCopied = false
                            }
                        } label: {
                            Label(codeCopied ? "Copied!" : "Copy Code", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(codeCopied ? Color.green : Color.purple)
                                .cornerRadius(12)
                        }

                        ShareLink(item: "Join our family on Famoria! Use invite code: \(code)") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.purple)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                }
            }

            Button {
                generateCode()
            } label: {
                HStack {
                    if isGeneratingCode {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: inviteCode == nil ? "plus.circle.fill" : "arrow.clockwise")
                    }
                    Text(inviteCode == nil ? "Generate Invite Code" : "Generate New Code")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
            .disabled(isGeneratingCode)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Members (\(family?.members.count ?? 0))", systemImage: "person.2.fill")
                    .font(.headline)
                Spacer()
            }

            if let members = family?.members {
                VStack(spacing: 0) {
                    ForEach(members) { member in
                        memberRow(member)
                        if member.id != members.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private func memberRow(_ member: User) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarGradient(for: member.role))
                    .frame(width: 44, height: 44)

                Text(memberInitials(member.name))
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.body).fontWeight(.medium)

                    if member.id == currentUserId {
                        Text("You")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 6) {
                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let role = member.role {
                        Text(role.rawValue.capitalized)
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundColor(roleForeground(role))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleBackground(role))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // Actions (not shown for current user or owners)
            if member.id != currentUserId && member.role != .owner {
                Menu {
                    Button {
                        memberToPromote = member
                        showRoleSheet = true
                    } label: {
                        Label("Change Role", systemImage: "person.badge.key")
                    }

                    Divider()

                    Button(role: .destructive) {
                        memberToRemove = member
                        showRemoveAlert = true
                    } label: {
                        Label("Remove from Family", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
            Spacer()
            Button { errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func generateCode() {
        isGeneratingCode = true
        errorMessage = nil
        Task {
            do {
                let code = try await appState.generateInviteCode()
                inviteCode = code
            } catch {
                errorMessage = error.localizedDescription
            }
            isGeneratingCode = false
        }
    }

    private func removeMember(_ member: User) {
        Task {
            do {
                try await appState.removeMemberAsync(member)
            } catch {
                errorMessage = "Failed to remove \(member.name): \(error.localizedDescription)"
            }
            memberToRemove = nil
        }
    }

    private func updateRole(_ member: User, to role: MemberRole) {
        Task {
            do {
                try await appState.updateMemberRole(member, to: role)
            } catch {
                errorMessage = "Failed to update role: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func memberInitials(_ name: String) -> String {
        let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
        return parts.prefix(2).joined().uppercased()
    }

    private func avatarGradient(for role: MemberRole?) -> LinearGradient {
        switch role {
        case .owner:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .admin:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func roleForeground(_ role: MemberRole) -> Color {
        switch role {
        case .owner: return .orange
        case .admin: return .purple
        case .member: return .blue
        }
    }

    private func roleBackground(_ role: MemberRole) -> Color {
        switch role {
        case .owner: return .orange.opacity(0.15)
        case .admin: return .purple.opacity(0.15)
        case .member: return .blue.opacity(0.15)
        }
    }
}

// MARK: - Role Picker Sheet

private struct RolePickerSheet: View {
    let member: User
    let onSelect: (MemberRole) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Change role for **\(member.name)**")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    ForEach([MemberRole.member, .admin], id: \.self) { role in
                        Button {
                            onSelect(role)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(role.rawValue.capitalized)
                                        .font(.body).fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(roleDescription(role))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if member.role == role {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Change Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func roleDescription(_ role: MemberRole) -> String {
        switch role {
        case .owner: return "Full control over the family"
        case .admin: return "Can manage members and settings"
        case .member: return "Can view and post content"
        }
    }
}
#Preview {
    FamilyAdminView()
}

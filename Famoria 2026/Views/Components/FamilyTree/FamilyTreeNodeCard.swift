//
//  FamilyTreeNodeCard.swift
//  Famoria 2026
//
//  The "person card" rendered for every node on the canvas.
//  Visual rules:
//    - Real linked Famoria users: full-color card with their gender accent.
//    - Ghost profiles (extended relatives): dashed outline + muted color.
//    - Deceased: small "✦" indicator + grayscaled photo.
//    - Highlighted (search match or selected): purple/pink gradient ring.
//    - The current user has a subtle "You" pill.
//

import SwiftUI

struct FamilyTreeNodeCard: View {

    let member: FamilyTreeMember
    let isCurrentUser: Bool
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                avatar
                VStack(spacing: 2) {
                    Text(member.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                    if let lifespan = member.lifespanLabel {
                        Text(lifespan)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                            )
                            .foregroundStyle(.white)
                            .padding(.top, 2)
                    } else if member.isGhost {
                        Text("Not on Famoria")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(width: FamilyTreeViewModel.nodeWidth, height: FamilyTreeViewModel.nodeHeight)
            .padding(.vertical, 8)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: isHighlighted ? Color.purple.opacity(0.35) : Color.black.opacity(0.08),
                radius: isHighlighted ? 12 : 6,
                x: 0,
                y: isHighlighted ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isHighlighted)
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlString = member.photoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                        default:
                            initialsBubble
                        }
                    }
                } else {
                    initialsBubble
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(member.gender.accentColor.opacity(0.6), lineWidth: 2)
            )
            .grayscale(member.isDeceased ? 0.8 : 0)

            if member.isDeceased {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(Color.gray))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var initialsBubble: some View {
        ZStack {
            LinearGradient(
                colors: [member.gender.accentColor.opacity(0.9), member.gender.accentColor.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(member.initials)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Card chrome

    @ViewBuilder
    private var cardBackground: some View {
        if member.isGhost {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .opacity(0.85)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if isHighlighted {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.purple, .pink],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 3
                )
        } else if member.isGhost {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FamilyTreeNodeCard(
            member: FamilyTreeMember(
                familyId: "fam",
                linkedUserId: "u1",
                displayName: "Lauryn Smeester",
                gender: .female,
                birthDate: Calendar.current.date(from: DateComponents(year: 1990, month: 6, day: 1)),
                addedBy: "u1"
            ),
            isCurrentUser: true,
            isHighlighted: false,
            onTap: {}
        )
        FamilyTreeNodeCard(
            member: FamilyTreeMember(
                familyId: "fam",
                displayName: "Grandpa Joe",
                gender: .male,
                birthDate: Calendar.current.date(from: DateComponents(year: 1932, month: 3, day: 4)),
                deathDate: Calendar.current.date(from: DateComponents(year: 2010, month: 11, day: 22)),
                isDeceased: true,
                addedBy: "u1"
            ),
            isCurrentUser: false,
            isHighlighted: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

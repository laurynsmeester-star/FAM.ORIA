//
//  WishlistItemCard.swift
//  Famoria 2026
//
//  Single wishlist item card. Shows the item name, priority + occasion badges,
//  optional description and link, plus the actionable bottom row:
//    - Claim / "I'll get this" (hidden if you're the recipient)
//    - Already-claimed-by indicator
//    - Mark fulfilled checkmark (anyone)
//    - Delete (author or admin only)
//

import SwiftUI

struct WishlistItemCard: View {

    let item: WishlistItem
    let viewerIsRecipient: Bool
    let viewerCanDelete: Bool
    let viewerUserId: String

    let onClaim: () -> Void
    let onUnclaim: () -> Void
    let onToggleFulfilled: () -> Void
    let onDelete: () -> Void
    let onOpenLink: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let desc = item.itemDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().opacity(0.4)
            actionRow
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .opacity(item.isFulfilled ? 0.6 : 1)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.itemName)
                    .font(.headline)
                    .strikethrough(item.isFulfilled, color: .secondary)
                    .foregroundStyle(.primary)
                badgeRow
            }
            Spacer(minLength: 8)
            if let url = item.hasValidLink {
                Button {
                    onOpenLink(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var badgeRow: some View {
        HStack(spacing: 6) {
            Text(item.priority.shortLabel)
                .font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(item.priority.background))
                .foregroundStyle(item.priority.foreground)

            Label(item.occasion.label, systemImage: item.occasion.systemImage)
                .font(.caption2).fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            // Left: claim status / claim button
            if viewerIsRecipient {
                // Recipient never sees claim/fulfill controls (surprise filter
                // already hides claimed items, but extra defense if a stale
                // copy renders).
                EmptyView()
            } else if let claimedBy = item.claimedByName, item.isClaimed {
                if item.claimedByUserId == viewerUserId {
                    // I claimed it — I can unclaim.
                    Button(action: onUnclaim) {
                        Label("You're getting this", systemImage: "checkmark.seal.fill")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Claimed by \(claimedBy)", systemImage: "checkmark.circle.fill")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            } else {
                Button(action: onClaim) {
                    Label("I'll get this", systemImage: "gift.fill")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading, endPoint: .trailing
                            ))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Right: fulfill + delete
            if !viewerIsRecipient && !item.isFulfilled {
                Button(action: onToggleFulfilled) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.green.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark fulfilled")
            }

            if !viewerIsRecipient && item.isFulfilled {
                Button(action: onToggleFulfilled) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark unfulfilled")
            }

            if viewerCanDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.red.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete wish")
            }
        }
    }
}

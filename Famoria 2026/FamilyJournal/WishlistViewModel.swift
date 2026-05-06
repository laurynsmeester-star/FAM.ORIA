//
//  WishlistViewModel.swift
//  Famoria 2026
//
//  Owns the wishlist state and all the surprise-mode filtering rules.
//
//  Two surprise rules apply (combined):
//    1. Auto-hide on your own list — items where YOU are the recipient AND
//       are already claimed or fulfilled are always hidden from you.
//    2. Manual surprise toggle — when ON, claimed/fulfilled items are hidden
//       across every list (e.g. for older kids who want to keep surprises).
//
//  Items are grouped by recipient and displayed under per-member tabs plus
//  an "Everyone" tab.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// Selection state for the recipient tab bar.
public enum WishlistTabSelection: Equatable, Hashable {
    case everyone
    case member(String)   // recipientName

    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .member(let n): return n
        }
    }
}

@MainActor
final class WishlistViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var items: [WishlistItem] = []
    @Published var selectedTab: WishlistTabSelection = .everyone
    @Published var manualSurpriseModeOn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Inputs

    let familyId: String
    let currentUserId: String
    let currentUserName: String
    let currentUserRole: MemberRole?
    /// All real Famoria users in the family — used for the "For whom?" picker.
    let familyMembers: [User]

    var canEdit: Bool {
        // Anyone in the family can add/claim wishes — gift-giving is collaborative.
        // Only owners/admins can delete other people's wishes (enforced in UI).
        true
    }

    // MARK: - Dependencies

    private let service: FirebaseWishlistService
    private var listener: ListenerRegistration?

    // MARK: - Init

    init(
        familyId: String,
        currentUserId: String,
        currentUserName: String,
        currentUserRole: MemberRole?,
        familyMembers: [User],
        service: FirebaseWishlistService? = nil
    ) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        self.currentUserName = currentUserName
        self.currentUserRole = currentUserRole
        self.familyMembers = familyMembers
        self.service = service ?? FirebaseWishlistService()
    }

    // MARK: - Lifecycle

    func start() {
        isLoading = true
        listener = service.observeItems(familyId: familyId) { [weak self] items in
            Task { @MainActor in
                guard let self else { return }
                self.items = items
                self.isLoading = false
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Mutations

    func addWish(
        recipientName: String,
        recipientUserId: String?,
        itemName: String,
        description: String?,
        link: String?,
        priority: WishPriority,
        occasion: WishOccasion
    ) async {
        let item = WishlistItem(
            familyId: familyId,
            recipientUserId: recipientUserId,
            recipientName: recipientName,
            itemName: itemName,
            itemDescription: description,
            link: link,
            priority: priority,
            occasion: occasion,
            addedByUserId: currentUserId,
            addedByName: currentUserName
        )
        do {
            try await service.upsert(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func claim(_ item: WishlistItem) async {
        // Don't let people claim their own wishes — that defeats the surprise.
        guard !isRecipient(item, user: currentUserId, name: currentUserName) else { return }
        do {
            try await service.setClaim(
                itemId: item.id,
                familyId: familyId,
                userId: currentUserId,
                userName: currentUserName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unclaim(_ item: WishlistItem) async {
        // Only the person who claimed it can unclaim.
        guard item.claimedByUserId == currentUserId else { return }
        do {
            try await service.setClaim(itemId: item.id, familyId: familyId, userId: nil, userName: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFulfilled(_ item: WishlistItem) async {
        do {
            try await service.setFulfilled(itemId: item.id, familyId: familyId, fulfilled: !item.isFulfilled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: WishlistItem) async {
        // Only the author or owners/admins can delete.
        let canDelete = item.addedByUserId == currentUserId
            || currentUserRole == .owner
            || currentUserRole == .admin
        guard canDelete else { return }
        do {
            try await service.delete(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Derived state

    /// All distinct recipient names across the wishlist, sorted alphabetically,
    /// with the current user pinned to the top when present.
    var recipientNames: [String] {
        let unique = Array(Set(items.map(\.recipientName)))
        let sorted = unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let mine = sorted.first(where: { $0 == currentUserName }) {
            return [mine] + sorted.filter { $0 != mine }
        }
        return sorted
    }

    /// Items grouped by recipient, after applying tab + surprise filters.
    /// Returns ordered tuples so the caller can render them top-to-bottom.
    var visibleGrouped: [(recipientName: String, items: [WishlistItem])] {
        let visibleItems = items.filter { isVisible($0) }
        let filteredByTab: [WishlistItem]
        switch selectedTab {
        case .everyone:
            filteredByTab = visibleItems
        case .member(let name):
            filteredByTab = visibleItems.filter { $0.recipientName == name }
        }

        // Group by recipient.
        let grouped = Dictionary(grouping: filteredByTab) { $0.recipientName }

        // Order recipients to match recipientNames priority.
        let orderedRecipients = recipientNames.filter { grouped[$0] != nil }
        return orderedRecipients.map { name in
            let sortedItems = (grouped[name] ?? []).sorted { lhs, rhs in
                if lhs.isFulfilled != rhs.isFulfilled { return !lhs.isFulfilled }
                return lhs.createdAt > rhs.createdAt
            }
            return (recipientName: name, items: sortedItems)
        }
    }

    /// Total count after filtering, used for empty-state detection.
    var visibleItemCount: Int {
        visibleGrouped.reduce(0) { $0 + $1.items.count }
    }

    /// True when the wishlist is empty (raw, before filtering) — different
    /// from a filtered empty state which means "nothing matches your filters".
    var hasNoItemsAtAll: Bool { items.isEmpty }

    // MARK: - Filters

    /// Applies BOTH surprise rules.
    private func isVisible(_ item: WishlistItem) -> Bool {
        let viewerIsRecipient = isRecipient(item, user: currentUserId, name: currentUserName)

        // Rule 1: never let the recipient see their own claimed/fulfilled items.
        if viewerIsRecipient && (item.isClaimed || item.isFulfilled) {
            return false
        }
        // Rule 2: manual surprise toggle hides claimed/fulfilled across the board.
        if manualSurpriseModeOn && (item.isClaimed || item.isFulfilled) {
            return false
        }
        return true
    }

    private func isRecipient(_ item: WishlistItem, user: String, name: String) -> Bool {
        if let rid = item.recipientUserId { return rid == user }
        return item.recipientName.localizedCaseInsensitiveCompare(name) == .orderedSame
    }
}

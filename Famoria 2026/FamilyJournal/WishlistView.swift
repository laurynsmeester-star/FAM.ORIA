//
//  WishlistView.swift
//  Famoria 2026
//
//  Main wishlist screen, lives inside the FamilyJournal tabbed container.
//
//  Layout:
//    - Header: title + add button + manual surprise toggle
//    - Recipient tab strip ("Everyone" + per-member chips)
//    - Grouped vertical list ("X's Wishlist" → cards) with empty state
//

import SwiftUI

struct WishlistView: View {

    @StateObject var viewModel: WishlistViewModel

    @State private var showAddSheet: Bool = false
    @State private var pendingDelete: WishlistItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                surpriseModeBar
                recipientTabs
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) { addButton }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sheet(isPresented: $showAddSheet) {
            AddWishSheet(viewModel: viewModel, onClose: { showAddSheet = false })
                .presentationDetents([.large])
        }
        .alert("Delete this wish?",
               isPresented: Binding(
                   get: { pendingDelete != nil },
                   set: { if !$0 { pendingDelete = nil } }
               ),
               actions: {
                   Button("Cancel", role: .cancel) { pendingDelete = nil }
                   Button("Delete", role: .destructive) {
                       if let item = pendingDelete {
                           Task { await viewModel.delete(item) }
                       }
                       pendingDelete = nil
                   }
               },
               message: {
                   if let item = pendingDelete {
                       Text("Remove '\(item.itemName)' from \(item.recipientName)'s wishlist?")
                   }
               })
        .alert("Wishlist error",
               isPresented: Binding(
                   get: { viewModel.errorMessage != nil },
                   set: { if !$0 { viewModel.errorMessage = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(viewModel.errorMessage ?? "") })
    }

    // MARK: - Surprise toggle bar

    private var surpriseModeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.manualSurpriseModeOn ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(viewModel.manualSurpriseModeOn ? .pink : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Surprise mode")
                    .font(.subheadline).fontWeight(.semibold)
                Text(viewModel.manualSurpriseModeOn
                     ? "Hiding claimed & fulfilled wishes everywhere."
                     : "Auto-hides claimed wishes on your own list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $viewModel.manualSurpriseModeOn)
                .labelsHidden()
                .tint(.pink)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Recipient tabs

    private var recipientTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tabChip(label: "Everyone", selection: .everyone)
                ForEach(viewModel.recipientNames, id: \.self) { name in
                    tabChip(label: name, selection: .member(name))
                }
            }
        }
    }

    private func tabChip(label: String, selection: WishlistTabSelection) -> some View {
        let isSelected = viewModel.selectedTab == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.selectedTab = selection }
        } label: {
            Text(label)
                .font(.subheadline).fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color(.systemBackground))
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView("Loading wishlists…")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if viewModel.hasNoItemsAtAll {
            emptyStateInitial
        } else if viewModel.visibleItemCount == 0 {
            emptyStateFiltered
        } else {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.visibleGrouped, id: \.recipientName) { group in
                    groupSection(name: group.recipientName, items: group.items)
                }
            }
        }
    }

    private func groupSection(name: String, items: [WishlistItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("\(name)'s Wishlist")
                    .font(.title3).fontWeight(.semibold)
                Spacer()
                Text("\(items.count)")
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                ForEach(items) { item in
                    WishlistItemCard(
                        item: item,
                        viewerIsRecipient: viewerIsRecipient(item),
                        viewerCanDelete: viewerCanDelete(item),
                        viewerUserId: viewModel.currentUserId,
                        onClaim:           { Task { await viewModel.claim(item) } },
                        onUnclaim:         { Task { await viewModel.unclaim(item) } },
                        onToggleFulfilled: { Task { await viewModel.toggleFulfilled(item) } },
                        onDelete:          { pendingDelete = item },
                        onOpenLink: { url in openURL(url) }
                    )
                }
            }
        }
    }

    private var emptyStateInitial: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient(
                    colors: [.pink, .purple],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("No wishes yet")
                .font(.title3).fontWeight(.semibold)
            Text("Start adding gift ideas for your family.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("Add first wish", systemImage: "plus")
                    .font(.subheadline).fontWeight(.semibold)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }

    private var emptyStateFiltered: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Nothing to see here")
                .font(.headline)
            Text(viewModel.manualSurpriseModeOn
                 ? "Surprise mode is hiding all claimed & fulfilled wishes."
                 : "No matching wishes for this filter.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .shadow(color: .purple.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func viewerIsRecipient(_ item: WishlistItem) -> Bool {
        if let rid = item.recipientUserId { return rid == viewModel.currentUserId }
        return item.recipientName.localizedCaseInsensitiveCompare(viewModel.currentUserName) == .orderedSame
    }

    private func viewerCanDelete(_ item: WishlistItem) -> Bool {
        item.addedByUserId == viewModel.currentUserId
            || viewModel.currentUserRole == .owner
            || viewModel.currentUserRole == .admin
    }

    private func openURL(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

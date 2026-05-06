//
//  FamilyTreeView.swift
//  Famoria 2026
//
//  The main screen for the family tree feature.
//
//  Layout (top → bottom):
//    - Header: title, search bar, add/admin actions
//    - Empty state OR the interactive canvas
//    - Floating "fit to screen" + "add" buttons over the canvas
//
//  The canvas itself supports:
//    - Pan in any direction (drag gesture)
//    - Pinch-to-zoom (magnification gesture, clamped 0.4× → 2.5×)
//    - Double-tap to toggle zoom
//    - "Fit to screen" button to recenter and fit content
//    - Tap a node → open mini profile sheet
//    - Search match → animate canvas to center the matched node
//

import SwiftUI

struct FamilyTreeView: View {

    @StateObject private var viewModel: FamilyTreeViewModel

    /// Display name + photo for the current user — used to seed the "self" node
    /// the very first time the tree is opened.
    let currentUserDisplayName: String
    let currentUserPhotoURL: String?

    init(familyId: String, currentUserId: String, currentUserRole: MemberRole?, currentUserDisplayName: String, currentUserPhotoURL: String?) {
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(
            familyId: familyId,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
        self.currentUserDisplayName = currentUserDisplayName
        self.currentUserPhotoURL = currentUserPhotoURL
    }

    /// Init that accepts a pre-configured viewModel (used for previews).
    init(viewModel: FamilyTreeViewModel, currentUserDisplayName: String, currentUserPhotoURL: String?) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.currentUserDisplayName = currentUserDisplayName
        self.currentUserPhotoURL = currentUserPhotoURL
    }

    // Canvas transform state.
    @State private var canvasScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Selection / sheet state.
    @State private var selectedMember: FamilyTreeMember?
    @State private var addingRelativeOf: FamilyTreeMember?

    // Search UI state.
    @State private var isSearchFocused: Bool = false
    @State private var canvasViewportSize: CGSize = .zero

    private let minScale: CGFloat = 0.4
    private let maxScale: CGFloat = 2.5

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            content
        }
        .background(canvasBackground.ignoresSafeArea())
        .task {
            guard viewModel.tree.members.isEmpty else { return }
            viewModel.start()
            await viewModel.ensureSelfNode(
                displayName: currentUserDisplayName,
                photoURL: currentUserPhotoURL
            )
        }
        .onDisappear { viewModel.stop() }
        .sheet(item: $selectedMember) { member in
            MemberProfileSheet(
                viewModel: viewModel,
                member: member,
                onAddRelative: { kind in
                    selectedMember = nil
                    addingRelativeOf = member
                    addRelativeKind = kind
                },
                onClose: { selectedMember = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $addingRelativeOf) { anchor in
            AddRelativeSheet(
                viewModel: viewModel,
                anchor: anchor,
                initialKind: addRelativeKind ?? .child,
                onClose: { addingRelativeOf = nil }
            )
            .presentationDetents([.large])
        }
        .alert("Tree error",
               isPresented: Binding(
                   get: { viewModel.errorMessage != nil },
                   set: { if !$0 { viewModel.errorMessage = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(viewModel.errorMessage ?? "") }
        )
    }

    @State private var addRelativeKind: AddRelativeKind?

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Family Tree")
                        .font(.title2).fontWeight(.bold)
                    Text("\(viewModel.tree.members.count) people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    fitToScreen()
                } label: {
                    Label("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 17, weight: .semibold))
                        .padding(8)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }

                if viewModel.canEdit {
                    Button {
                        if let me = viewModel.tree.members.first(where: { $0.linkedUserId == viewModel.currentUserId }) {
                            addRelativeKind = .parent
                            addingRelativeOf = me
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(
                                Circle().fill(LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                            )
                    }
                }
            }
            searchBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search relatives", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit {
                    if let first = viewModel.searchMatches.first {
                        center(on: first)
                    }
                }
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(alignment: .top) {
            if !viewModel.searchMatches.isEmpty && !viewModel.searchQuery.isEmpty {
                searchResultsList
                    .offset(y: 42)
            }
        }
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.searchMatches.prefix(6)) { m in
                Button {
                    center(on: m)
                    viewModel.searchQuery = ""
                } label: {
                    HStack {
                        Image(systemName: m.isGhost ? "person.crop.circle.dashed" : "person.crop.circle.fill")
                            .foregroundStyle(m.gender.accentColor)
                        Text(m.displayName)
                            .font(.callout)
                        if let lifespan = m.lifespanLabel {
                            Text(lifespan)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .frame(maxWidth: .infinity)
        .zIndex(10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.tree.members.isEmpty {
            ProgressView("Loading tree…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tree.members.isEmpty {
            emptyState
        } else {
            canvas
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tree.fill")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Text("Start your family tree")
                .font(.title3).fontWeight(.semibold)
            Text("Add yourself first, then build out your parents, siblings, and extended family.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let viewport = proxy.size

            ZStack {
                // The actual tree, transformed by scale + offset.
                ZStack(alignment: .topLeading) {
                    FamilyTreeConnectionsView(connections: viewModel.layout.connections)
                        .frame(
                            width: max(viewModel.layout.contentSize.width, 1),
                            height: max(viewModel.layout.contentSize.height, 1)
                        )

                    ForEach(viewModel.tree.members) { member in
                        let isMatch = viewModel.searchMatches.contains(where: { $0.id == member.id })
                        if let pos = viewModel.layout.positions[member.id] {
                            FamilyTreeNodeCard(
                                member: member,
                                isCurrentUser: member.linkedUserId == viewModel.currentUserId,
                                isHighlighted: isMatch || selectedMember?.id == member.id,
                                onTap: { selectedMember = member }
                            )
                            .position(
                                x: pos.x + FamilyTreeViewModel.nodeWidth / 2,
                                y: pos.y + FamilyTreeViewModel.nodeHeight / 2
                            )
                        }
                    }
                }
                .frame(
                    width: max(viewModel.layout.contentSize.width, viewport.width),
                    height: max(viewModel.layout.contentSize.height, viewport.height),
                    alignment: .topLeading
                )
                .scaleEffect(canvasScale, anchor: .topLeading)
                .offset(canvasOffset)
                .simultaneousGesture(panGesture)
                .simultaneousGesture(zoomGesture)
                .onTapGesture(count: 2) { withAnimation(.spring()) { toggleZoom(viewport: viewport) } }
            }
            .clipped()
            .contentShape(Rectangle())
            .onAppear { canvasViewportSize = viewport }
            .onChange(of: viewport) { _, newSize in
                canvasViewportSize = newSize
            }
            .onChange(of: viewModel.layout.contentSize) { _, _ in
                if canvasOffset == .zero && canvasScale == 1.0 {
                    fitToScreen()
                }
            }
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                canvasOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = canvasOffset
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastScale * value
                canvasScale = min(max(proposed, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = canvasScale
            }
    }

    private func toggleZoom(viewport: CGSize) {
        if canvasScale > 1.05 {
            canvasScale = 1.0
            lastScale = 1.0
        } else {
            canvasScale = 1.6
            lastScale = 1.6
        }
    }

    // MARK: - Camera helpers

    private func fitToScreen() {
        let size = viewModel.layout.contentSize
        guard size.width > 0, size.height > 0 else { return }
        let viewport = canvasViewportSize == .zero
            ? CGSize(width: 390, height: 700)
            : canvasViewportSize

        let padding: CGFloat = 32
        let scaleX = (viewport.width  - padding * 2) / size.width
        let scaleY = (viewport.height - padding * 2) / size.height
        let s = min(min(scaleX, scaleY), 1.0)
        let clamped = max(s, minScale)

        let scaledW = size.width * clamped
        let scaledH = size.height * clamped
        let dx = (viewport.width  - scaledW) / 2
        let dy = (viewport.height - scaledH) / 2

        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            canvasScale = clamped
            lastScale   = clamped
            canvasOffset = CGSize(width: dx, height: dy)
            lastOffset   = canvasOffset
        }
    }

    private func center(on member: FamilyTreeMember) {
        guard let pos = viewModel.layout.positions[member.id] else { return }
        let viewport = canvasViewportSize == .zero
            ? CGSize(width: 390, height: 700)
            : canvasViewportSize

        let cardCenter = CGPoint(
            x: pos.x + FamilyTreeViewModel.nodeWidth / 2,
            y: pos.y + FamilyTreeViewModel.nodeHeight / 2
        )
        let targetScale: CGFloat = max(canvasScale, 1.0)
        let dx = viewport.width  / 2 - cardCenter.x * targetScale
        let dy = viewport.height / 2 - cardCenter.y * targetScale

        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            canvasScale  = targetScale
            lastScale    = targetScale
            canvasOffset = CGSize(width: dx, height: dy)
            lastOffset   = canvasOffset
        }
    }

    // MARK: - Background

    private var canvasBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.97, blue: 1.00),
                Color(red: 1.00, green: 0.97, blue: 0.99)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview("Family Tree") {
    FamilyTreePreviewWrapper()
}

private struct FamilyTreePreviewWrapper: View {
    @StateObject private var viewModel: FamilyTreeViewModel = {
        let vm = FamilyTreeViewModel(
            familyId: "preview-family",
            currentUserId: "u-me",
            currentUserRole: .owner
        )

        let fam = "preview-family"
        let cal = Calendar.current

        // — Members —
        let me = FamilyTreeMember(
            id: "m-me", familyId: fam, linkedUserId: "u-me",
            displayName: "Lauryn Smeester",
            gender: .female,
            birthDate: cal.date(from: DateComponents(year: 1998, month: 6, day: 15)),
            addedBy: "u-me"
        )
        let partner = FamilyTreeMember(
            id: "m-partner", familyId: fam,
            displayName: "Marcus Johnson",
            gender: .male,
            birthDate: cal.date(from: DateComponents(year: 1996, month: 3, day: 22)),
            addedBy: "u-me"
        )
        let mom = FamilyTreeMember(
            id: "m-mom", familyId: fam, linkedUserId: "u-mom",
            displayName: "Diana Smeester",
            gender: .female,
            birthDate: cal.date(from: DateComponents(year: 1970, month: 9, day: 8)),
            addedBy: "u-me"
        )
        let dad = FamilyTreeMember(
            id: "m-dad", familyId: fam, linkedUserId: "u-dad",
            displayName: "Robert Smeester",
            gender: .male,
            birthDate: cal.date(from: DateComponents(year: 1968, month: 12, day: 3)),
            addedBy: "u-me"
        )
        let brother = FamilyTreeMember(
            id: "m-bro", familyId: fam,
            displayName: "Tyler Smeester",
            gender: .male,
            birthDate: cal.date(from: DateComponents(year: 2001, month: 4, day: 11)),
            addedBy: "u-me"
        )
        let grandmaM = FamilyTreeMember(
            id: "m-gm", familyId: fam,
            displayName: "Rose Williams",
            gender: .female,
            birthDate: cal.date(from: DateComponents(year: 1945, month: 5, day: 20)),
            deathDate: cal.date(from: DateComponents(year: 2019, month: 11, day: 2)),
            isDeceased: true,
            notes: "Grandma Rose, lived in Boston",
            addedBy: "u-me"
        )
        let grandpaM = FamilyTreeMember(
            id: "m-gp", familyId: fam,
            displayName: "Harold Williams",
            gender: .male,
            birthDate: cal.date(from: DateComponents(year: 1942, month: 8, day: 14)),
            isDeceased: false,
            addedBy: "u-me"
        )
        let child = FamilyTreeMember(
            id: "m-child", familyId: fam,
            displayName: "Lily Johnson",
            gender: .female,
            birthDate: cal.date(from: DateComponents(year: 2024, month: 1, day: 30)),
            addedBy: "u-me"
        )

        // — Relationships —
        let rels: [Relationship] = [
            Relationship(familyId: fam, fromMemberId: "m-gm", toMemberId: "m-mom", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-gp", toMemberId: "m-mom", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-gm", toMemberId: "m-gp", type: .spouse),
            Relationship(familyId: fam, fromMemberId: "m-mom", toMemberId: "m-me", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-dad", toMemberId: "m-me", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-mom", toMemberId: "m-bro", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-dad", toMemberId: "m-bro", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-mom", toMemberId: "m-dad", type: .spouse),
            Relationship(familyId: fam, fromMemberId: "m-me", toMemberId: "m-partner", type: .spouse),
            Relationship(familyId: fam, fromMemberId: "m-me", toMemberId: "m-child", type: .parent),
            Relationship(familyId: fam, fromMemberId: "m-partner", toMemberId: "m-child", type: .parent),
        ]

        let tree = FamilyTree(
            familyId: fam,
            members: [me, partner, mom, dad, brother, grandmaM, grandpaM, child],
            relationships: rels
        )
        vm.loadPreviewData(tree)
        return vm
    }()

    var body: some View {
        FamilyTreeView(
            viewModel: viewModel,
            currentUserDisplayName: "Lauryn Smeester",
            currentUserPhotoURL: nil
        )
    }
}


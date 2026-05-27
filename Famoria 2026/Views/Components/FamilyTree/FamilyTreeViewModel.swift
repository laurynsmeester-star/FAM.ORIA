//
//  FamilyTreeViewModel.swift
//  Famoria 2026
//
//  Owns the family tree state, talks to FirebaseFamilyTreeService, and
//  computes (x, y) layout positions for every member using a simple but
//  predictable "generations + spouse-grouping" algorithm.
//
//  Layout strategy (classic vertical pedigree):
//    1. Pick a root member (defaults to the current user's tree node).
//    2. Assign every reachable member a `generation` integer, where
//       parents = generation-1 and children = generation+1.
//    3. Group members within each generation into "couples" (spouse pairs)
//       and singles. Place couples adjacent.
//    4. For each couple/single, position children directly beneath them.
//    5. Resolve horizontal collisions by sliding subtrees right.
//
//  The result is a `LayoutSnapshot` of (memberId -> CGPoint) plus
//  precomputed couple-midpoints for drawing connection lines.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class FamilyTreeViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var tree: FamilyTree
    @Published private(set) var layout: LayoutSnapshot = .empty
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    /// User-provided search query, applied as a highlight on matching nodes.
    @Published var searchQuery: String = "" {
        didSet { recomputeMatches() }
    }
    @Published private(set) var searchMatches: [FamilyTreeMember] = []

    // MARK: - Inputs

    let familyId: String
    let currentUserId: String
    let currentUserRole: MemberRole?

    var canEdit: Bool {
        switch currentUserRole {
        case .owner, .admin: return true
        default: return false
        }
    }

    // MARK: - Dependencies

    private let service: FirebaseFamilyTreeService
    private var listeners: [ListenerRegistration] = []

    // MARK: - Layout constants

    /// Width of a person card.
    static let nodeWidth: CGFloat = 132
    /// Height of a person card.
    static let nodeHeight: CGFloat = 168
    /// Horizontal gap between adjacent siblings/units.
    static let hSpacing: CGFloat = 28
    /// Vertical gap between generations.
    static let vSpacing: CGFloat = 92
    /// Horizontal gap between a couple's two cards.
    static let coupleGap: CGFloat = 8

    // MARK: - Init

    init(
        familyId: String,
        currentUserId: String,
        currentUserRole: MemberRole?,
        service: FirebaseFamilyTreeService? = nil
    ) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        self.service = service ?? FirebaseFamilyTreeService()
        self.tree = FamilyTree(familyId: familyId)
    }

    // MARK: - Lifecycle

    func start() {
        guard !familyId.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        listeners = service.observeTree(familyId: familyId) { [weak self] newTree in
            Task { @MainActor in
                guard let self else { return }
                self.tree = newTree
                self.isLoading = false
                self.recomputeLayout()
                self.recomputeMatches()
            }
        }
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Mutations

    func addRelative(
        kind: AddRelativeKind,
        relativeOf anchorId: String,
        displayName: String,
        gender: TreeGender,
        birthDate: Date?,
        deathDate: Date?,
        isDeceased: Bool,
        notes: String?,
        inviteEmail: String?,
        photoURL: String?
    ) async {
        guard canEdit else { return }
        guard let anchor = tree.member(id: anchorId) else { return }

        let newMember = FamilyTreeMember(
            familyId: familyId,
            displayName: displayName,
            photoURL: photoURL,
            gender: gender,
            birthDate: birthDate,
            deathDate: deathDate,
            isDeceased: isDeceased,
            notes: notes,
            addedBy: currentUserId,
            inviteEmail: inviteEmail
        )

        do {
            try await service.upsertMember(newMember)
            try await createRelationships(for: kind, newMemberId: newMember.id, anchor: anchor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMember(_ updated: FamilyTreeMember) async {
        guard canEdit else { return }
        do {
            try await service.upsertMember(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMember(_ member: FamilyTreeMember) async {
        guard canEdit else { return }
        do {
            try await service.deleteMember(member)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Create a member representing the current user if one doesn't yet exist.
    /// Call this once when the user first opens the tree.
    func ensureSelfNode(displayName: String, photoURL: String?) async {
        guard !familyId.isEmpty else { return }
        // Wait briefly for the listener snapshot to arrive before deciding to create.
        if !isLoading, tree.members.contains(where: { $0.linkedUserId == currentUserId }) { return }
        // If still loading, wait up to 3 seconds for the first snapshot.
        if isLoading {
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if !isLoading { break }
            }
            if tree.members.contains(where: { $0.linkedUserId == currentUserId }) { return }
        }
        let me = FamilyTreeMember(
            familyId: familyId,
            linkedUserId: currentUserId,
            displayName: displayName,
            photoURL: photoURL,
            addedBy: currentUserId
        )
        do { try await service.upsertMember(me) }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Relationship plumbing

    private func createRelationships(
        for kind: AddRelativeKind,
        newMemberId: String,
        anchor: FamilyTreeMember
    ) async throws {
        switch kind {
        case .parent:
            // New person is a parent of anchor.
            try await service.upsertRelationship(Relationship(
                familyId: familyId,
                fromMemberId: newMemberId,
                toMemberId: anchor.id,
                type: .parent
            ))

        case .child:
            // Anchor is a parent of the new person. If anchor has a spouse,
            // add that spouse as a parent too (a child usually has 2 parents).
            try await service.upsertRelationship(Relationship(
                familyId: familyId,
                fromMemberId: anchor.id,
                toMemberId: newMemberId,
                type: .parent
            ))
            for spouse in tree.spouses(of: anchor.id) {
                try await service.upsertRelationship(Relationship(
                    familyId: familyId,
                    fromMemberId: spouse.id,
                    toMemberId: newMemberId,
                    type: .parent
                ))
            }

        case .spouse:
            try await service.upsertRelationship(Relationship(
                familyId: familyId,
                fromMemberId: anchor.id,
                toMemberId: newMemberId,
                type: .spouse
            ))

        case .sibling:
            // A sibling shares parents with the anchor. Copy each of anchor's
            // parents as a parent of the new member.
            let parents = tree.parents(of: anchor.id)
            for p in parents {
                try await service.upsertRelationship(Relationship(
                    familyId: familyId,
                    fromMemberId: p.id,
                    toMemberId: newMemberId,
                    type: .parent
                ))
            }
            // If anchor has no recorded parents, we can't define the sibling
            // link structurally. Skip silently — caller can add parents later.
        }
    }

    // MARK: - Search

    private func recomputeMatches() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            searchMatches = []
            return
        }
        searchMatches = tree.members
            .filter { $0.displayName.lowercased().contains(q) }
            .sorted { $0.displayName < $1.displayName }
    }

    #if DEBUG
    /// Inject a pre-built tree for SwiftUI previews. Skips Firebase entirely.
    func loadPreviewData(_ previewTree: FamilyTree) {
        self.tree = previewTree
        self.isLoading = false
        recomputeLayout()
    }
    #endif

    // MARK: - Layout engine

    func recomputeLayout() {
        layout = LayoutEngine(
            tree: tree,
            rootUserId: currentUserId,
            nodeWidth: Self.nodeWidth,
            nodeHeight: Self.nodeHeight,
            hSpacing: Self.hSpacing,
            vSpacing: Self.vSpacing,
            coupleGap: Self.coupleGap
        ).build()
    }
}

// MARK: - Layout Snapshot

/// A pre-computed positioning of every member on a 2D canvas.
struct LayoutSnapshot: Equatable {
    /// memberId → top-left position of its node card.
    var positions: [String: CGPoint]
    /// Drawing instructions for connection lines.
    var connections: [ConnectionLine]
    /// Total content size (used to fit-to-screen / size the canvas).
    var contentSize: CGSize

    static let empty = LayoutSnapshot(positions: [:], connections: [], contentSize: .zero)

    /// Center point of a given node.
    func center(of memberId: String, nodeSize: CGSize) -> CGPoint? {
        guard let p = positions[memberId] else { return nil }
        return CGPoint(x: p.x + nodeSize.width / 2, y: p.y + nodeSize.height / 2)
    }
}

/// One drawn line in the tree.
struct ConnectionLine: Equatable, Identifiable {
    enum Kind { case spouse, parentChild }
    let id: String
    let kind: Kind
    let from: CGPoint   // absolute canvas coordinates
    let to: CGPoint
    /// Optional intermediate control point (for the orthogonal "drop" of parent→children)
    let drop: CGPoint?

    init(kind: Kind, from: CGPoint, to: CGPoint, drop: CGPoint?) {
        self.kind = kind
        self.from = from
        self.to = to
        self.drop = drop
        // Stable identity derived from geometry so SwiftUI ForEach can diff
        // connection lines correctly across layout recomputations.
        if let drop {
            self.id = "\(kind)|\(from.x),\(from.y)->\(to.x),\(to.y)|\(drop.x),\(drop.y)"
        } else {
            self.id = "\(kind)|\(from.x),\(from.y)->\(to.x),\(to.y)"
        }
    }
}

// MARK: - Layout Engine (private)

private struct LayoutEngine {
    let tree: FamilyTree
    let rootUserId: String
    let nodeWidth: CGFloat
    let nodeHeight: CGFloat
    let hSpacing: CGFloat
    let vSpacing: CGFloat
    let coupleGap: CGFloat

    /// A "unit" is a single person OR a couple, treated as one block during layout.
    private struct Unit {
        let memberIds: [String]   // 1 = single, 2 = couple
        var width: CGFloat        // own block width (excluding outer spacing)
    }

    func build() -> LayoutSnapshot {
        guard !tree.members.isEmpty else { return .empty }

        // 1. Compute generation indices.
        let generations = computeGenerations()

        // 2. Group members by generation.
        let byGen: [Int: [FamilyTreeMember]] = Dictionary(grouping: tree.members) {
            generations[$0.id] ?? 0
        }
        let sortedGens = byGen.keys.sorted()

        // 3. For each generation (top → bottom), build "units" (couples / singles)
        //    and assign x-positions. Try to keep children centered under parents.

        var positions: [String: CGPoint] = [:]
        var connections: [ConnectionLine] = []

        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        // Track parent-couple x-center so children center beneath them.
        var memberCenterX: [String: CGFloat] = [:]

        for (rowIndex, gen) in sortedGens.enumerated() {
            let people = byGen[gen] ?? []
            let units = buildUnits(from: people)

            // Compute y for this row.
            let y = CGFloat(rowIndex) * (nodeHeight + vSpacing)
            maxY = max(maxY, y + nodeHeight)

            // Attempt to center each unit under its parents (if known and already laid out).
            // Otherwise simply pack left-to-right.
            var cursorX: CGFloat = 0
            // Sort units: those with already-laid-out parents first, ordered by parent center x.
            let sortedUnits = units.sorted { a, b in
                let ax = parentCenterX(for: a, memberCenterX: memberCenterX) ?? .greatestFiniteMagnitude
                let bx = parentCenterX(for: b, memberCenterX: memberCenterX) ?? .greatestFiniteMagnitude
                return ax < bx
            }

            for unit in sortedUnits {
                let desiredCenter = parentCenterX(for: unit, memberCenterX: memberCenterX)
                let unitX: CGFloat
                if let desired = desiredCenter {
                    let candidate = desired - unit.width / 2
                    unitX = max(candidate, cursorX)
                } else {
                    unitX = cursorX
                }

                placeUnit(unit, atX: unitX, y: y, positions: &positions, memberCenterX: &memberCenterX)
                cursorX = unitX + unit.width + hSpacing
                maxX = max(maxX, cursorX - hSpacing)
            }
        }

        // 4. Build connection lines.
        connections = buildConnections(positions: positions, memberCenterX: memberCenterX)

        let contentSize = CGSize(width: maxX, height: maxY)
        return LayoutSnapshot(positions: positions, connections: connections, contentSize: contentSize)
    }

    // MARK: Generations

    /// BFS from the root. If the root isn't in the tree, fall back to any member.
    private func computeGenerations() -> [String: Int] {
        var gens: [String: Int] = [:]
        guard !tree.members.isEmpty else { return gens }

        // Find a starting node: prefer the linked root user, else first member.
        let start: FamilyTreeMember = tree.members.first(where: { $0.linkedUserId == rootUserId })
            ?? tree.members[0]

        // BFS over parent + spouse + child relationships, propagating generation deltas.
        var queue: [(String, Int)] = [(start.id, 0)]
        gens[start.id] = 0

        while !queue.isEmpty {
            let (currentId, currentGen) = queue.removeFirst()

            for parent in tree.parents(of: currentId) {
                if gens[parent.id] == nil {
                    gens[parent.id] = currentGen - 1
                    queue.append((parent.id, currentGen - 1))
                }
            }
            for child in tree.children(of: currentId) {
                if gens[child.id] == nil {
                    gens[child.id] = currentGen + 1
                    queue.append((child.id, currentGen + 1))
                }
            }
            for spouse in tree.spouses(of: currentId) {
                if gens[spouse.id] == nil {
                    gens[spouse.id] = currentGen
                    queue.append((spouse.id, currentGen))
                }
            }
        }

        // Any disconnected members get gen 0 by default (so they don't disappear).
        for m in tree.members where gens[m.id] == nil {
            gens[m.id] = 0
        }
        return gens
    }

    // MARK: Units

    private func buildUnits(from members: [FamilyTreeMember]) -> [Unit] {
        var consumed = Set<String>()
        var units: [Unit] = []

        // Stable order: by birth year (older first), then by name.
        let sorted = members.sorted { lhs, rhs in
            let l = lhs.birthDate?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
            let r = rhs.birthDate?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
            if l != r { return l < r }
            return lhs.displayName < rhs.displayName
        }

        for m in sorted {
            if consumed.contains(m.id) { continue }
            // Look for a spouse in the same generation list.
            let spouseInRow = tree.spouses(of: m.id).first(where: { other in
                members.contains(where: { $0.id == other.id }) && !consumed.contains(other.id)
            })
            if let s = spouseInRow {
                let width = nodeWidth + coupleGap + nodeWidth
                units.append(Unit(memberIds: [m.id, s.id], width: width))
                consumed.insert(m.id)
                consumed.insert(s.id)
            } else {
                units.append(Unit(memberIds: [m.id], width: nodeWidth))
                consumed.insert(m.id)
            }
        }
        return units
    }

    private func placeUnit(
        _ unit: Unit,
        atX x: CGFloat,
        y: CGFloat,
        positions: inout [String: CGPoint],
        memberCenterX: inout [String: CGFloat]
    ) {
        if unit.memberIds.count == 1 {
            let id = unit.memberIds[0]
            positions[id] = CGPoint(x: x, y: y)
            memberCenterX[id] = x + nodeWidth / 2
        } else {
            // Couple — two adjacent cards.
            let leftId = unit.memberIds[0]
            let rightId = unit.memberIds[1]
            positions[leftId]  = CGPoint(x: x, y: y)
            positions[rightId] = CGPoint(x: x + nodeWidth + coupleGap, y: y)
            memberCenterX[leftId]  = x + nodeWidth / 2
            memberCenterX[rightId] = x + nodeWidth + coupleGap + nodeWidth / 2
        }
    }

    /// The desired x-center for a unit, based on its members' parents.
    private func parentCenterX(
        for unit: Unit,
        memberCenterX: [String: CGFloat]
    ) -> CGFloat? {
        // Combine parent positions of every member in the unit.
        var xs: [CGFloat] = []
        for memberId in unit.memberIds {
            for p in tree.parents(of: memberId) {
                if let cx = memberCenterX[p.id] { xs.append(cx) }
            }
        }
        guard !xs.isEmpty else { return nil }
        return xs.reduce(0, +) / CGFloat(xs.count)
    }

    // MARK: Connections

    private func buildConnections(
        positions: [String: CGPoint],
        memberCenterX: [String: CGFloat]
    ) -> [ConnectionLine] {
        var lines: [ConnectionLine] = []

        // Spouse lines: horizontal between adjacent couple cards.
        var seenSpousePairs = Set<String>()
        for rel in tree.relationships where rel.type == .spouse {
            let key = [rel.fromMemberId, rel.toMemberId].sorted().joined(separator: "|")
            if seenSpousePairs.contains(key) { continue }
            seenSpousePairs.insert(key)
            guard
                let aPos = positions[rel.fromMemberId],
                let bPos = positions[rel.toMemberId]
            else { continue }
            // Draw line at the vertical middle of the cards.
            let aCenter = CGPoint(x: aPos.x + nodeWidth / 2, y: aPos.y + nodeHeight / 2)
            let bCenter = CGPoint(x: bPos.x + nodeWidth / 2, y: bPos.y + nodeHeight / 2)
            lines.append(ConnectionLine(kind: .spouse, from: aCenter, to: bCenter, drop: nil))
        }

        // Parent → child lines, grouped by parent couple so children share a "drop" bus.
        // Group: (sortedParentIds string) → [childId]
        var byParentSet: [String: [String]] = [:]
        for rel in tree.relationships where rel.type == .parent {
            // Collect ALL parents of the child, not just this one, to dedupe later.
            byParentSet[parentSetKey(forChild: rel.toMemberId), default: []].append(rel.toMemberId)
        }
        // Dedupe child lists.
        for (k, v) in byParentSet { byParentSet[k] = Array(Set(v)) }

        for (key, childIds) in byParentSet {
            let parentIds = key.split(separator: "|").map(String.init)
            // Compute parent block bottom-center.
            let parentCenters = parentIds.compactMap { id -> CGPoint? in
                guard let p = positions[id] else { return nil }
                return CGPoint(x: p.x + nodeWidth / 2, y: p.y + nodeHeight)
            }
            guard !parentCenters.isEmpty else { continue }
            let parentX = parentCenters.map(\.x).reduce(0, +) / CGFloat(parentCenters.count)
            let parentY = parentCenters.map(\.y).max() ?? 0

            // For each child: parent bottom → drop point → child top.
            for childId in childIds {
                guard let cPos = positions[childId] else { continue }
                let childTop = CGPoint(x: cPos.x + nodeWidth / 2, y: cPos.y)
                let dropY = (parentY + childTop.y) / 2
                let drop = CGPoint(x: childTop.x, y: dropY)
                lines.append(ConnectionLine(
                    kind: .parentChild,
                    from: CGPoint(x: parentX, y: parentY),
                    to: childTop,
                    drop: drop
                ))
            }
        }

        return lines
    }

    private func parentSetKey(forChild childId: String) -> String {
        let ids = tree.relationships
            .filter { $0.type == .parent && $0.toMemberId == childId }
            .map(\.fromMemberId)
            .sorted()
        return ids.joined(separator: "|")
    }
}
